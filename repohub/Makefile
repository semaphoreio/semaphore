include ../Makefile

APP_NAME=repohub
APP_ENV=prod

test.setup:
	docker-compose build
	$(MAKE) db.create
	$(MAKE) db.migrate
	docker-compose run app go get ./...

lint: build
	docker-compose run --rm app revive -formatter friendly -config lint.toml ./...

test.go: build
	docker-compose run --rm app gotestsum --format short-verbose --junitfile out/test-reports.xml --packages="./..." -- -p 1

test.watch: build
	docker-compose run --rm app gotestsum --watch --format short-verbose --junitfile out/test-reports.xml --packages="./..." -- -p 1

test.bench: build
	docker-compose run --rm app go test -v ./pkg/publicapi -bench=. -benchmem -run Benchmark__PullJSONLogsFromRedis -memprofile memprofile.out

#
# Protobuf compilation
#

INTERNAL_API_BRANCH ?= master
INTERNAL_API_MODULES?=repository,project,repository_integrator,user,projecthub
TMP_INTERNAL_REPO_DIR?=/tmp/internal_api
pb.gen:
	rm -rf $(TMP_INTERNAL_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_INTERNAL_REPO_DIR) && (cd $(TMP_INTERNAL_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	docker-compose run --rm --no-deps app /app/scripts/protoc.sh $(INTERNAL_API_MODULES) $(INTERNAL_API_BRANCH) $(TMP_INTERNAL_REPO_DIR)
	rm -rf $(TMP_INTERNAL_REPO_DIR)

#
# Database and migrations
#

export DB_HOST=db
export DB_PORT=5432
export DB_NAME=repos
export DB_USERNAME=postgres
export DB_PASSWORD=the-cake-is-a-lie

db.create:
	docker-compose run app bash -c "scripts/db.sh create"

db.migration.create:
	docker-compose run app mkdir -p db/migrations
	docker-compose run app migrate create -ext sql -dir db/migrations $(NAME)
	ls -lah db/migrations/*$(NAME)*

db.migrate:
	rm -f db/structure.sql
	docker-compose run app bash -c "scripts/db.sh migrate"
	# echo dump schema to db/structure.sql
	docker-compose run --user $$(id -u):$$(id -g) -e PGPASSWORD=$(DB_PASSWORD) app bash -c "pg_dump --schema-only --no-privileges --no-owner -h db -p 5432 -U postgres -d $(DB_NAME)" > db/structure.sql
	docker-compose run --user $$(id -u):$$(id -g) -e PGPASSWORD=$(DB_PASSWORD) app bash -c "pg_dump --data-only --table schema_migrations -h db -p 5432 -U postgres -d $(DB_NAME)" >> db/structure.sql
