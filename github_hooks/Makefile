export APP_ENV?=dev

include ../Makefile

BUILD_ENV=$(RAILS_ENV)
ifeq ($(BUILD_ENV),)
	BUILD_ENV=$(APP_ENV)
endif

DOCKER_BUILD_TARGET=runner
ifneq ($(BUILD_ENV),production)
	DOCKER_BUILD_TARGET=dev
endif

APP_NAME=github_hooks

POSTGRES_DB_NAME="front"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?=1
ENCRYPTOR_URL="localhost:50052"
AMQP_URL?="amqp://0.0.0.0:5672"
REDIS_SIDEKIQ_URL?="redis://0.0.0.0:6379"
REDIS_JOB_LOGS_URL?="redis://0.0.0.0:6379"
INTERNAL_API_URL_RBAC?="localhost:50051"
INTERNAL_API_URL_PLUMBER?="localhost:50051"
INTERNAL_API_URL_REPOSITORY?="localhost:50051"
INTERNAL_API_URL_HOOKS?="localhost:50051"
BASE_DOMAIN?="semaphore.test"
LOG_LEVEL?=info

CONTAINER_ENV_VARS= \
  -e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
  -e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
  -e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
  -e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
  -e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
  -e AMQP_URL=$(AMQP_URL) \
  -e ENCRYPTOR_URL=$(ENCRYPTOR_URL) \
  -e REDIS_SIDEKIQ_URL=$(REDIS_SIDEKIQ_URL) \
  -e REDIS_JOB_LOGS_URL=$(REDIS_JOB_LOGS_URL) \
  -e RAILS_ENV=$(RAILS_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL) \
  -e INTERNAL_API_URL_RBAC=$(INTERNAL_API_URL_RBAC) \
  -e INTERNAL_API_URL_PLUMBER=$(INTERNAL_API_URL_PLUMBER) \
  -e INTERNAL_API_URL_REPOSITORY=$(INTERNAL_API_URL_REPOSITORY) \
  -e INTERNAL_API_URL_HOOKS=$(INTERNAL_API_URL_HOOKS) \
  -e BASE_DOMAIN=$(BASE_DOMAIN) \
  -e CI=$(CI)

test.ruby.setup: export RAILS_ENV=test
test.ruby.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app bundle exec rake db:create db:migrate
	docker compose run --rm app bundle exec rspec $(FILE) $(FLAGS)
else
	$(MAKE) encryptor.run
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	sem-service start rabbitmq 3.8
	sem-service start redis 7.0
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) bundle exec rake db:create db:migrate
endif

test.ruby: export RAILS_ENV=test
test.ruby:
ifeq ($(CI),)
# Localy we use database supplied by docker-compose
	docker compose $(DOCKER_COMPOSE_OPTS) build --build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) --build-arg BUILD_ENV=$(RAILS_ENV) app
	$(MAKE) test.ruby.setup
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app bundle exec rspec $(FILE) $(FLAGS)
else
	$(MAKE) test.ruby.setup
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) bundle exec rspec $(TEST_FILE) $(TEST_FLAGS)
endif

format.ruby: build
ifeq ($(CI),)
# Localy we use database supplied by docker-compose
	docker-compose build app
	docker-compose run --rm app bundle exec rubocop --format progress --format offenses
else
# On CI we're relying on database supplied by sem-service
	docker run --rm $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) bundle exec rubocop --format progress --format offenses --format junit --out out/results.xml
endif

check.ruby.code: check.prepare
	$(MAKE) check.code LANGUAGE=ruby

check.ruby.deps: check.prepare
	$(MAKE) check.deps LANGUAGE=ruby CHECK_DEPS_OPTS="-w app,rt-watchman"

pb.gen:
	bash ./protobuffer/regenerate.sh
