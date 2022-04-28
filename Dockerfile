# syntax = docker/dockerfile:1

FROM docker.io/ruby:2.7.6 AS build

ENV RAILS_ENV=production
ENV RAILS_GROUPS=assets

RUN mkdir --parents /opt/openmensa
WORKDIR /opt/openmensa

COPY Gemfile Gemfile.lock /opt/openmensa/
RUN <<EOF
  gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"
  bundle config set --local deployment 'true'
  bundle config set --local without 'development test'
  bundle install --jobs 4 --retry 3
EOF

# Note: see also .dockerignore
COPY . /opt/openmensa/
RUN <<EOF
  bundle exec rake assets:precompile
  rm -rf /opt/openmensa/log /opt/openmensa/tmp
EOF


FROM docker.io/ruby:2.7.6

ENV RAILS_ENV=production

COPY --from=build /opt/openmensa /opt/openmensa
WORKDIR /opt/openmensa

RUN <<EOF
  gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"
  bundle config set --local deployment 'true'
  bundle config set --local without 'development test'
  mkdir --parents /etc/openmensa /var/log/openmensa
  ln --symbolic /tmp /opt/openmensa/tmp
  ln --symbolic /var/log/openmensa /opt/openmensa/log
  ln -s /opt/openmensa/config/{database.yml,omniauth.yml,secrets.yml} /etc/openmensa
  useradd --create-home --home-dir /var/lib/openmensa --shell /bin/bash openmensa
  chown openmensa:openmensa /var/log/openmensa
EOF

COPY start.sh /bin/start.sh

USER openmensa

EXPOSE 3000

CMD ["/bin/start.sh"]
