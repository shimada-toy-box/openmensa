FROM ruby:3.1 AS build

ENV RAILS_ENV=production
ENV RAILS_GROUPS=assets

RUN mkdir --parents /etc/openmensa /opt/openmensa /var/log/openmensa && \
  ln --symbolic /tmp /opt/openmensa/tmp && \
  ln --symbolic /var/log/openmensa /opt/openmensa/log
WORKDIR /opt/openmensa

COPY Gemfile Gemfile.lock /opt/openmensa/
RUN gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)" && \
  bundle config set --local deployment 'true' && \
  bundle config set --local without 'development test' && \
  bundle install --jobs 4 --retry 3

COPY . /opt/openmensa/
RUN bundle exec rake assets:precompile
RUN rm -rf /opt/openmensa/log /opt/openmensa/tmp


FROM ruby:3.1

ENV RAILS_ENV=production

COPY --from=build /opt/openmensa /opt/openmensa
WORKDIR /opt/openmensa

RUN gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)" && \
  bundle config set --local deployment 'true' && \
  bundle config set --local without 'development test'

COPY --from=build /etc/openmensa /etc/openmensa

RUN mkdir --parents /opt/openmensa /var/log/openmensa && \
  ln --symbolic /tmp /opt/openmensa/tmp && \
  ln --symbolic /var/log/openmensa /opt/openmensa/log && \
  useradd --create-home --home-dir /var/lib/openmensa --shell /bin/bash openmensa && \
  chown openmensa:openmensa /var/log/openmensa

USER openmensa

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server"]
