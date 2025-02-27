include ../../Makefile

APP_NAME=gofer
APP_ENV=prod

INTERNAL_API_TMP_DIR ?= /tmp/internal_api
INTERNAL_API_BRANCH ?= master
PROTOC_IMAGE_TAG ?= 1.14.5-3.20.1-0.10.0

CHECK_DEPS_EXTRA_OPTS=-w util

POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"

CONTAINER_ENV_VARS= \
  -e DB_USERNAME=$(POSTGRES_DB_USER) \
  -e DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
  -e DB_HOSTNAME=$(POSTGRES_DB_HOST)

# Protobuf files

pb.gen: pb.gen.internal format

pb.gen.internal:
	rm -rf $(INTERNAL_API_TMP_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(INTERNAL_API_TMP_DIR)\
		&& (cd $(INTERNAL_API_TMP_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(INTERNAL_API_TMP_DIR):/home/protoc/source\
		-t renderedtext/protoc:$(PROTOC_IMAGE_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	scripts/vagrant_sudo chown -R $$(id -u $${USER}):$$(id -g $${USER}) lib/internal_api
	rm -rf $(INTERNAL_API_TMP_DIR)


test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	sem-service start rabbitmq 3.8
	sem-service start redis 5.0
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

dev.setup:
	docker compose $(DOCKER_COMPOSE_OPTS) run $(DOCKER_COMPOSE_RUN_OPTS) --rm app mix do deps.get, deps.compile