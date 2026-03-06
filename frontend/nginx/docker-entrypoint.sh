#!/bin/sh
set -e

# Substitute only $DOMAIN in the nginx config template, preserving nginx variables
envsubst '${DOMAIN}' < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
