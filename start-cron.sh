#!/bin/sh

echo "Starting cron..."

exec cron -f -L 7
