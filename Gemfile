# frozen_string_literal: true

source "https://rubygems.org"

ruby "~> 3.2.0"

gem "rails", "~> 7.1.0"
gem "rails-i18n", "~> 7.0"
gem "sprockets", "~> 4.0"
gem "sprockets-rails", "~> 3.4", require: "sprockets/railtie"

gem "puma", "~> 6.0"

gem "bcrypt"
gem "good_job", "~> 3.0"
gem "nokogiri"
gem "oj"
gem "pg", "~> 1.2"
gem "slim", "~> 5.0"

gem "cancancan", "~> 3.2"
gem "omniauth", "~> 2.0"
gem "omniauth-facebook"
gem "omniauth-github"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection", "~> 1.0"
gem "omniauth-twitter"

gem "parse-cron"
gem "rack-cors", require: "rack/cors"

gem "geocoder", "~> 1.6"
gem "gravtastic"
gem "leaflet-rails", "~> 1.7"
gem "rails-timeago"
gem "simple_form"

gem "api-responder"
gem "decorate-responder", "~> 2.1"
gem "draper", "~> 4.0"
gem "has_scope", "~> 0.8.0"
gem "paginate-responder", "~> 2.0"
gem "responders"
gem "will_paginate"

gem "sentry-rails"
gem "sentry-ruby"

group :assets do
  gem "autoprefixer-rails", "~> 10.2"
  gem "bourbon", "~> 7.0"
  gem "font-awesome-sass", "~> 6.4.2"
  gem "jquery-rails"
  gem "mini_racer", "~> 0.8.0"
  gem "sassc-embedded"
  gem "terser", "~> 1.1"
end

group :development do
  gem "brakeman"

  gem "listen"
  gem "spring"
  gem "spring-commands-rspec"

  gem "rubocop", "~> 1.57.0", require: false
  gem "rubocop-capybara", "~> 2.19.0", require: false
  gem "rubocop-factory_bot", "~> 2.24.0", require: false
  gem "rubocop-performance", "~> 1.19.1", require: false
  gem "rubocop-rails", "~> 2.21.2", require: false
  gem "rubocop-rspec", "~> 2.24.1", require: false
end

group :development, :test do
  gem "pry"
  gem "pry-byebug"
  gem "rspec-collection_matchers"
  gem "rspec-its"
  gem "rspec-rails", "6.0.3"
end

group :test do
  gem "capybara", "~> 3.35"
  gem "capybara-email", "~> 3.0"
  gem "cuprite", "~> 0.13"
  gem "factory_bot_rails", "~> 6.1"
  gem "rails-controller-testing"
  gem "timecop"
  gem "webmock"

  gem "simplecov", require: false
  gem "simplecov-cobertura", require: false
end
