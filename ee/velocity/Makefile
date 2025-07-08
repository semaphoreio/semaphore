include ../../Makefile

APP_NAME=velocity
APP_ENV=prod

#
# Lint, Test and Build
#

lint: build
	docker compose run --rm --no-deps app revive -formatter friendly -config lint.toml ./...

test.setup:
	docker compose build
	$(MAKE) db.create
	$(MAKE) db.migrate

test: build
	docker compose run --rm app gotestsum --format short-verbose --junitfile out/test-reports.xml --packages="./..." -- -p 1

wait.for.postgres:
	docker compose run --rm app scripts/wait-for-postgres.sh

#
# Database and migrations
#

export DB_HOST=db
export DB_PORT=5432
export DB_NAME=velocity
export DB_USERNAME=postgres
export DB_PASSWORD=the-cake-is-a-lie

db.create: wait.for.postgres
	docker compose run app bash -c "scripts/db.sh create"

db.migration.create: wait.for.postgres
	docker compose run app mkdir -p db/migrations
	docker compose run app migrate create -ext sql -dir db/migrations $(NAME)
	ls -lah db/migrations/*$(NAME)*

db.migrate: wait.for.postgres
	rm -f db/structure.sql
	docker compose run app bash -c "scripts/db.sh migrate"
	# echo dump schema to db/structure.sql
	docker compose run --user $$(id -u):$$(id -g) -e PGPASSWORD=$(DB_PASSWORD) app bash -c "pg_dump --schema-only --no-privileges --no-owner -h db -p 5432 -U postgres -d $(DB_NAME)" > db/structure.sql
	docker compose run --user $$(id -u):$$(id -g) -e PGPASSWORD=$(DB_PASSWORD) app bash -c "pg_dump --data-only --table schema_migrations -h db -p 5432 -U postgres -d $(DB_NAME)" >> db/structure.sql

db.test.console:
	docker compose run --user $$(id -u):$$(id -g) -e PGPASSWORD=$(DB_PASSWORD) app psql -h db -p 5432 -U postgres $(DB_NAME)

db.test.delete:
	docker compose run --user $$(id -u):$$(id -g) --rm -e PGPASSWORD=$(DB_PASSWORD) app dropdb -h db -p 5432 -U postgres $(DB_NAME)

#
# Protobuf compilation.
#

INTERNAL_API_BRANCH ?= master
MODULES = user,repository_integrator,projecthub,artifacthub,plumber_w_f.workflow,plumber.pipeline,velocity,server_farm.mq.job_state_exchange,server_farm.job,feature
pb.gen:
	rm -rf /tmp/internal_api
	git clone git@github.com:renderedtext/internal_api.git /tmp/internal_api && (cd /tmp/internal_api && git checkout $(INTERNAL_API_BRANCH) && cd -)
	docker compose run --rm app scripts/protoc.sh $(MODULES) $(INTERNAL_API_BRANCH)
