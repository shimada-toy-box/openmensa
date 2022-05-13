#!/bin/sh

cp -ar /opt/openmensa/public/. /mnt/openmensa-www

bundle exec rake db:create db:migrate

exec bundle exec rails server
