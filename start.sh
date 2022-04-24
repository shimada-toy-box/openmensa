#!/bin/sh

cp -ar /opt/openmensa/public/. /mnt/openmensa-www

exec bundle exec rails server
