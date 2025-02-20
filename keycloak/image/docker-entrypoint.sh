#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [ -z $KC_DB_PASSWORD ];      then echo "DB username not set" && exit 1; fi
if [ -z $KC_DB_URL_HOST ];      then echo "DB host not set"     && exit 1; fi
if [ -z $KC_DB_URL_PORT ];      then echo "DB port not set"     && exit 1; fi
if [ -z $KC_DB_USERNAME ];      then echo "DB username not set" && exit 1; fi
if [ -z $KC_DB_URL_DATABASE ];  then echo "DB name not set"     && exit 1; fi

echo "Creating keycloak database..."
PGPASSWORD=${KC_DB_PASSWORD} createdb -h ${KC_DB_URL_HOST} -p ${KC_DB_URL_PORT} -U ${KC_DB_USERNAME} ${KC_DB_URL_DATABASE} -E UTF8 || true

echo "Starting keycloak..."
/opt/keycloak/bin/kc.sh start --optimized
