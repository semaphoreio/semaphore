#!/bin/sh

set -e
echo -n "Waiting for postgres to be ready"
until PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USERNAME" -d "postgres" -c '\q' > /dev/null 2>&1; do
  sleep 1
  echo -n .
done

echo "\nPostgres is up"
