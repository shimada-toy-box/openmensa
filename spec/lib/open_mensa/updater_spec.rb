require 'spec_helper'
require 'libxml'
include LibXML

describe OpenMensa::Updater do
  let(:canteen) { FactoryGirl.create :canteen }
  let(:updater) { OpenMensa::Updater.new(canteen, 2) }
  let(:today) { FactoryGirl.create :today, canteen: canteen }
  let(:document) { XML::Document.new }
  let(:root_element) do
    n = XML::Node.new('openmensa')
    ns = XML::Namespace.new(n, 'om', 'http://openmensa.org/open-mensa-v2')
    n.namespaces.namespace = ns
    #document.root.namespaces.default_prefix = 'om'
    document.root = n
  end

  context "#fetch" do
    before do
      stub_request(:any, "example.com/canteen_feed.xml").
        to_return(:body => mock_file("canteen_feed.xml"), :status => 200)
      stub_request(:any, "example.com/data.xml").
        to_return(:body => '<xml>', :status => 200)
      stub_request(:any, "example.com/301.xml").
        to_return(status: 301, headers: { location: 'http://example.com/data.xml' })
      stub_request(:any, "example.com/302.xml").
        to_return(status: 302, headers: { location: 'http://example.com/data.xml' })
      stub_request(:any, "example.com/500.xml").
        to_return(status: 500)
      stub_request(:any, "unknowndomain.org").
        to_raise(SocketError.new('getaddrinfo: Name or service not known'))
      stub_request(:any, "example.org/timeout.xml").
        to_timeout
    end

    it 'should skip on missing urls' do
      canteen.update_attribute :url, nil
      canteen.url.should be_nil
      updater.fetch.should be_false
    end

    it 'should skip invalid urls' do
      canteen.update_attribute :url, ':///:asdf'
      updater.fetch.should be_false
      m = canteen.messages.first
      m.should be_an_instance_of(FeedInvalidUrlError)
    end

    it 'should receive feed data via http' do
      canteen.update_attribute :url, 'http://example.com/data.xml'
      updater.fetch.read.should == '<xml>'
    end

    it 'should update feed url on 301 responses' do
      canteen.update_attribute :url, 'http://example.com/301.xml'
      updater.fetch.read.should == '<xml>'
      canteen.url.should == 'http://example.com/data.xml'
      m = canteen.messages.first
      m.should be_an_instance_of(FeedUrlUpdatedInfo)
      m.old_url.should == 'http://example.com/301.xml'
      m.new_url.should == 'http://example.com/data.xml'
    end

    it 'should not update feed url on 302 responses' do
      canteen.update_attribute :url, 'http://example.com/302.xml'
      updater.fetch.read.should == '<xml>'
      canteen.url.should == 'http://example.com/302.xml'
    end

    it 'should handle http errors correctly' do
      canteen.update_attribute :url, 'http://example.com/500.xml'
      updater.fetch.should be_false
      m = canteen.messages.first
      m.should be_an_instance_of(FeedFetchError)
      m.code.should == 500
    end

    it 'should handle network errors correctly' do
      canteen.update_attribute :url, 'http://unknowndomain.org'
      updater.fetch.should be_false
      m = canteen.messages.first
      m.should be_an_instance_of(FeedFetchError)
      m.code.should == nil
    end

    it 'should handle network timeout ' do
      canteen.update_attribute :url, 'http://example.org/timeout.xml'
      updater.fetch.should be_false
      m = canteen.messages.first
      m.should be_an_instance_of(FeedFetchError)
      m.code.should == nil
    end
  end

  context "should reject" do
    it "non-xml data" do
      updater.validate(mock_content('feed_garbage.dat')).should be_false
      m = canteen.messages.first
      m.should be_an_instance_of(FeedValidationError)
      m.kind.should == :no_xml
      m.version.should be_nil
    end
    it "well-formatted but non-valid xml data" do
      updater.validate(mock_content('feed_wellformated.xml')).should be_false
      m = canteen.messages.first
      m.should be_an_instance_of(FeedValidationError)
      m.kind.should == :invalid_xml
      m.version.should == 1
    end
    it "valid but non-openmensa xml data" do
      updater.validate(mock_content('carrier_ship.xml')).should be_false
      m = canteen.messages.first
      m.should be_an_instance_of(FeedValidationError)
      m.kind.should == :unknown_version
      m.version.should be_nil
    end
  end

  it "should return 1 on valid v1 openmensa xml feeds" do
    updater.validate(mock_content('canteen_feed.xml')).should == 1
  end
  it "should return 2 on valid v openmensa xml feeds" do
    updater.validate(mock_content('feed_v2.xml')).should == 2
  end

  context "with valid v2 feed" do
    it 'ignore empty feeds' do
      document = updater.validate mock_content 'feed2_empty.xml'
      document.should == 2
      lca = canteen.last_fetched_at
      updater.updateCanteen updater.document.root.first.next
      canteen.last_fetched_at.should == lca
    end

    context 'with new data' do
      it 'should add a new meals to a day' do
        meal_name = 'Essen 1'
        meal_category = 'Hauptgricht'

        root_element << meal = xml_meal(meal_name)
        meal << xml_text('note', 'vegan')
        meal << xml_text('note', 'vegetarisch')
        meal << t = xml_text('price', '1.70'); t['role'] = 'student'
        meal << t = xml_text('price', '2.70'); t['role'] = 'other'
        today.meals.size.should be_zero

        updater.addMeal(today, meal_category, meal)

        today.meals.size.should == 1
        today.meals.first.name.should == meal_name
        today.meals.first.prices[:student].should == 1.7
        today.meals.first.prices[:other].should == 2.7
        today.meals.first.notes.map(&:name).should =~ [ 'vegan', 'vegetarisch' ]

        updater.should be_changed
      end

      it 'should add a new day with meals entries' do
        # data
        category1_name = 'Hauptgricht'
        category1_meal1_name = 'Essen 1'
        category1_meal2_name = 'Essen 2'

        category2_name = 'Beilagen'
        category2_meal1_name = 'Beilage 1'

        # build xml data
        root_element << day = xml_node('day')
        day['date'] = Time.zone.today.to_s

        day << category = xml_node('category')
        category['name'] = category1_name
        category << xml_meal(category1_meal1_name)
        category << xml_meal(category1_meal2_name)

        day << category = xml_node('category')
        category['name'] = category2_name
        category << xml_meal(category2_meal1_name)

        # starting check
        canteen.days.size.should be_zero

        updater.addDay(day)

        canteen.days.size.should == 1
        day = canteen.days.first
        day.meals.size.should == 3
        day.meals.order(:category).map(&:category).should == [category2_name, category1_name, category1_name]

        updater.should be_changed
      end

      it 'should add closed days entries' do
        # build xml data
        root_element << day = xml_node('day')
        day['date'] = Time.zone.today.to_s
        day << xml_node('closed')

        # starting check
        canteen.days.size.should be_zero

        updater.addDay(day)

        canteen.days.size.should == 1
        day = canteen.days.first
        day.should be_closed
        day.meals.size.should be_zero

        updater.should be_changed
      end

      it 'should update last_fetch_at and not last_changed_at' do
        document = updater.validate mock_content('feed_v2.xml')
        document.should == 2

        canteen.update_attribute :last_fetched_at, Time.zone.now - 1.day
        last_fetched_at = canteen.last_fetched_at
        updated_at = canteen.updated_at

        updater.updateCanteen updater.document.root.first.next

        canteen.days.size.should == 4
        canteen.last_fetched_at.should > Time.zone.now - 1.minute
        canteen.updated_at.should == updated_at
      end
    end


    context 'with old data' do
      it 'should allow to close the canteen on given days' do
        # build xml data
        root_element << day = xml_node('day')
        day['date'] = today.date.to_s
        day << xml_node('closed')
        meal = FactoryGirl.create :meal, day: today

        # starting check
        today.meals.size.should == 1
        today.should_not be_closed

        updater.updateDay(today, day)

        today.meals.size.should be_zero
        today.should be_closed

        updater.should be_changed
      end


     it 'should allow to reopen a canteen on given days' do
        # data
        category_name = 'Hauptessen'
        meal_name = 'Essen 1'

        # close our test day
        today.update_attribute :closed, true

        # build xml data
        root_element << day = xml_node('day')
        day['date'] = today.date.to_s
        day << category = xml_node('category')
        category['name'] = category_name
        category <<  xml_meal(meal_name)

        # starting check
        today.meals.size.should == 0
        today.should be_closed

        updater.updateDay(today, day)

        today.meals.size.should == 1
        today.should_not be_closed

        updater.should be_changed
      end


      it 'should add new meals' do
        # data
        category_name = 'Hauptessen'
        meal_name = 'Essen 1'

        # close our test day
        meal = FactoryGirl.create :meal, day: today

        # build xml data
        root_element << day = xml_node('day')
        day['date'] = today.date.to_s
        day << category = xml_node('category')
        category['name'] = meal.category
        category << xml_meal(meal.name)
        day << category = xml_node('category')
        category['name'] = category_name
        category << xml_meal(meal_name)

        # starting check
        today.meals.size.should == 1

        updater.updateDay(today, day)

        today.meals.size.should == 2
        today.meals.map(&:name) == [meal.name, meal_name]

        updater.should be_changed
      end

      it 'should update changed meals' do
        meal1 = FactoryGirl.create :meal, day: today, prices: { student: 1.8, employee: 2.9, other: nil, pupil: nil}
        meal1.notes = [ 'vegan', 'vegetarisch' ]

        # build xml data
        root_element << day = xml_node('day')
        day['date'] = today.date.to_s
        day << category = xml_node('category')
        category['name'] = meal1.category
        category << meal = xml_meal(meal1.name)
        meal << xml_text('note', 'vegan')
        meal << xml_text('note', 'scharf')
        meal << t = xml_text('price', '1.70'); t['role'] = 'student'
        meal << t = xml_text('price', '2.70'); t['role'] = 'other'

        # starting check
        today.meals.size.should == 1
        updated_at = today.meals.first.updated_at - 1.second

        updater.updateDay(today, day)

        today.meals.size.should == 1
        today.meals.first.prices.should == { student: 1.7, other: 2.7 }
        today.meals.first.notes.map(&:name).should =~ [ 'vegan', 'scharf' ]
        today.meals.first.name.should == meal1.name
        today.meals.first.updated_at.should > updated_at
      end

      it 'should not update unchanged meals' do
        # close our test day
        meal1 = FactoryGirl.create :meal, day: today, prices: { student: 1.8, employee: 2.9, other: nil, pupil: nil}
        meal1.notes = [ 'vegan', 'vegetarisch' ]

        # build xml data
        root_element << day = xml_node('day')
        day['date'] = today.date.to_s
        day << category = xml_node('category')
        category['name'] = meal1.category
        category << meal = xml_meal(meal1.name)
        meal << xml_text('note', 'vegan')
        meal << xml_text('note', 'vegetarisch')
        meal << t = xml_text('price', '1.80'); t['role'] = 'student'
        meal << t = xml_text('price', '2.90'); t['role'] = 'employee'

        # starting check
        today.meals.size.should == 1
        updated_at = today.meals.first.updated_at

        updater.updateDay(today, day)

        today.meals.size.should == 1
        today.meals.first.prices.should == { student: 1.8, employee: 2.9 }
        today.meals.first.notes.map(&:name).should =~ [ 'vegan', 'vegetarisch' ]
        today.meals.first.name.should == meal1.name
        today.meals.first.updated_at.should == updated_at
      end

      it 'should drop disappeared meals' do
        # close our test day
        meal1 = FactoryGirl.create :meal, day: today
        meal2 = FactoryGirl.create :meal, day: today

        # build xml data
        root_element << day = xml_node('day')
        day['date'] = today.date.to_s
        day << category = xml_node('category')
        category['name'] = meal2.category
        category << xml_meal(meal2.name)

        # starting check
        today.meals.size.should == 2

        updater.updateDay(today, day)

        today.meals.size.should == 1
        today.meals.first.should == meal2

        updater.should be_changed
      end

      it 'should not update last_changed_at on unchanged meals' do
        # close our test day
        meal1 = FactoryGirl.create :meal, day: today

        # build xml data
        root_element << day = xml_node('day')
        day['date'] = today.date.to_s
        day << category = xml_node('category')
        category['name'] = meal1.category
        category << xml_meal(meal1.name)

        # starting check
        today.meals.size.should == 1
        updated_at = meal1.updated_at

        updater.updateDay(today, day)

        today.meals.size.should == 1
        meal1.updated_at.should == updated_at
      end

      it 'should update last_fetch_at and not last_changed_at' do
        document = updater.validate mock_content('feed_v2.xml')
        document.should == 2

        day1 = FactoryGirl.create :day, date: Date.new(2012, 05, 22), canteen: canteen
        meal1 = FactoryGirl.create :meal, day: day1, name: 'Tagessuppe'
        day2 = FactoryGirl.create :day, date: Date.new(2012, 05, 29), canteen: canteen
        meal2 = FactoryGirl.create :meal, day: day2
        meal3 = FactoryGirl.create :meal, day: day2
        meal4 = FactoryGirl.create :meal, day: today

        canteen.update_attribute :last_fetched_at, Time.zone.now - 1.day
        canteen.days.size.should == 3
        canteen.meals.size.should == 4

        last_fetched_at = canteen.last_fetched_at
        updated_at = canteen.updated_at

        updater.updateCanteen updater.document.root.first.next

        canteen.days.size.should == 5
        canteen.meals.size.should == 10
        canteen.last_fetched_at.should > Time.zone.now - 1.minute
        canteen.updated_at.should == updated_at
      end

    end

    context '#update' do
      before do
        stub_request(:any, "example.org/compact.xml").
          to_return(:body => mock_file("feed2_compact.xml"), :status => 200)
      end
      it 'should handle compact document' do
        canteen.url = 'http://example.org/compact.xml'
        updater.update.should be_true
        canteen.days.size.should == 1
        canteen.meals.size.should == 4
      end
    end
  end
end