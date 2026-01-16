include ../Makefile

.PHONY: pb.gen

APP_NAME=artifacthub
APP_ENV=prod

pb.gen:
	rm -rf tmp && mkdir -p tmp
	git clone git@github.com:semaphoreci/api.git tmp/public_api
	(git clone git@github.com:renderedtext/internal_api.git tmp/internal_api && cd tmp/internal_api && git checkout $(INTERNAL_API_BRANCH) && cd -)
	chmod -R 777 tmp
	docker compose run --rm app bash script/gen-apis

tidy:
	docker compose run --rm app go mod tidy

bash:
	docker compose run --rm app bash

lint:
	docker compose run --rm --no-deps app revive -formatter friendly -config lint.toml ./...

test.setup:
	docker compose build
	docker compose run app go get ./...
	-$(MAKE) db.test.create
	$(MAKE) db.migrate

test:
	docker compose run --rm app gotestsum --format short-verbose --junitfile out/test-reports.xml --packages="./..." -- -p 1

test.watch:
	docker compose run --rm app gotestsum --watch --format short-verbose --junitfile out/test-reports.xml --packages="./..." -- -p 1

#
# Database ops
#

DB_NAME=artifacthub
DB_PASSWORD=the-cake-is-a-lie

db.test.create:
	docker compose run --rm -e PGPASSWORD=$(DB_PASSWORD) app createdb -h db -p 5432 -U postgres $(DB_NAME)
	docker compose run -e PGPASSWORD=$(DB_PASSWORD) app psql -h db -p 5432 -U postgres $(DB_NAME) -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

db.migration.create:
	docker compose run app mkdir -p db/migrations
	docker compose run --rm -e PGPASSWORD=$(DB_PASSWORD) app migrate create -ext sql -dir db/migrations $(NAME)
	ls -lah db/migrations/*$(NAME)*

db.migrate:
	rm -f db/structure.sql
	docker compose run --rm -e PGPASSWORD=$(DB_PASSWORD) app migrate -source file://db/migrations -database postgres://postgres:$(DB_PASSWORD)@db:5432/$(DB_NAME)?sslmode=disable up
	docker compose run --rm -e PGPASSWORD=$(DB_PASSWORD) app bash -c "pg_dump --schema-only --no-privileges --no-owner -h db -p 5432 -U postgres -d $(DB_NAME)" > db/structure.sql
	docker compose run --rm -e PGPASSWORD=$(DB_PASSWORD) app bash -c "pg_dump --data-only --table schema_migrations -h db -p 5432 -U postgres -d $(DB_NAME)" >> db/structure.sql

db.test.delete:
	docker compose run --rm -e PGPASSWORD=$(DB_PASSWORD) app dropdb -h db -p 5432 -U postgres $(DB_NAME)

db.test.shell:
	docker compose exec -u postgres db sh -c 'psql artifacthub'
