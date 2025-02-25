include ../Makefile

APP_NAME=self_hosted_hub
APP_ENV=prod
INTERNAL_API_BRANCH ?= master
TMP_REPO_DIR ?= /tmp/internal_api

test.setup:
	docker-compose build
	docker-compose run app go get ./...
	-$(MAKE) db.test.create
	$(MAKE) db.migrate

lint:
	docker-compose run --rm --no-deps app revive -formatter friendly -config lint.toml ./...

test: build
	docker-compose run --rm app gotestsum --format short-verbose --junitfile junit-report.xml --packages="./..." -- -p 1

test.watch:
	docker-compose run --rm app gotestsum --watch --format short-verbose --junitfile junit-report.xml --packages="./..." -- -p 1

tidy:
	docker-compose run --rm app go mod tidy

#
# Database
#

DB_NAME=self-hosted-hub
DB_PASSWORD=the-cake-is-a-lie

db.test.create:
	-docker-compose run -e PGPASSWORD=the-cake-is-a-lie app createdb -h db -p 5432 -U postgres $(DB_NAME)
	docker-compose run -e PGPASSWORD=the-cake-is-a-lie app psql -h db -p 5432 -U postgres $(DB_NAME) -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

db.migration.create:
	docker-compose run app mkdir -p db/migrations
	docker-compose run app migrate create -ext sql -dir db/migrations $(NAME)
	ls -lah db/migrations/*$(NAME)*

db.migrate:
	rm -f db/structure.sql
	docker-compose run --user $$(id -u):$$(id -g) app migrate -source file://db/migrations -database postgres://postgres:$(DB_PASSWORD)@db:5432/$(DB_NAME)?sslmode=disable up
	# echo dump schema to db/structure.sql
	docker-compose run --user $$(id -u):$$(id -g) -e PGPASSWORD=$(DB_PASSWORD) app bash -c "pg_dump --schema-only --no-privileges --no-owner -h db -p 5432 -U postgres -d $(DB_NAME)" > db/structure.sql
	docker-compose run --user $$(id -u):$$(id -g) -e PGPASSWORD=$(DB_PASSWORD) app bash -c "pg_dump --data-only --table schema_migrations -h db -p 5432 -U postgres -d $(DB_NAME)" >> db/structure.sql

db.test.console:
	docker-compose run --user $$(id -u):$$(id -g) -e PGPASSWORD=the-cake-is-a-lie app psql -h db -p 5432 -U postgres $(DB_NAME)

db.test.delete:
	docker-compose run --user $$(id -u):$$(id -g) --rm -e PGPASSWORD=$(DB_PASSWORD) app dropdb -h db -p 5432 -U postgres $(DB_NAME)

#
# Protobuf compilation
#

INTERNAL_API_MODULES ?= include/internal_api/response_status,self_hosted,server_farm.job,server_farm.mq.job_state_exchange,loghub2,feature,audit
pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	docker-compose run --rm --no-deps app /app/scripts/protoc.sh $(INTERNAL_API_MODULES) $(INTERNAL_API_BRANCH) $(TMP_REPO_DIR)
	rm -rf $(TMP_REPO_DIR)