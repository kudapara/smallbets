#!/bin/sh
set -e
service ssh start
mkdir -p /home/campfire/storage
ln -s /home/campfire/storage /rails
exec bin/boot