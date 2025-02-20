#!/bin/bash

<< 'DOCS'
  Create and migrate database.
DOCS

# When creating/dropping the database we need to connect to different database than `velocity`
PG_DB_URL="postgres://$DB_USERNAME:$DB_PASSWORD@$DB_HOST:$DB_PORT/postgres?sslmode=disable"
DB_URL="postgres://$DB_USERNAME:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=disable"

OPERATION=$1

create_db() {
  echo "Creating DB..."
  psql $PG_DB_URL -c "CREATE DATABASE $DB_NAME" || true
}

migrate_db() {
  echo "Migrating DB..."
  # Move to migrations
  psql $DB_URL -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" || true
  migrate -path /app/db/migrations -database $DB_URL up
}

drop_db() {
  echo "Dropping DB..."
  psql $PG_DB_URL -c "DROP DATABASE $DB_NAME"
}

setup_db() {
  create_db && migrate_db
}

cli() {
  case "$OPERATION" in
    create|c)
      create_db
      ;;
    migrate|m)
      migrate_db
      ;;
    drop|d)
      drop_db
      ;;
    setup|s)
      setup_db
      ;;
    *)
      echo -e "Simple CLI for DB operations:\n"
      echo -e "Usage: db.sh [create|migrate|drop|setup]\n"
      echo -e "Available commands:"
      echo -e "  create|c   creates the database"
      echo -e "  migrate|m  migrates the database"
      echo -e "  drop|d     drops the database and all its data"
      echo -e "  setup|s    creates the database and migrates it"
      echo -e ""
      ;;
  esac
}

cli
