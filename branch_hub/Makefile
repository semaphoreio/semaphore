export MIX_ENV?=dev

include ../Makefile

APP_NAME = branch_hub
SHELL := /bin/bash
PROTOC_TAG=1.12.1-3.17.3-0.7.1
TMP_REPO_DIR=/tmp/internal_api
INTERNAL_API_BRANCH ?= master

#
# Environment variables required for app to run.
#

IN_DOCKER?="true"
POSTGRES_DB_NAME?="front"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?="5"
AMQP_URL?="amqp://0.0.0.0:5672"

CONTAINER_ENV_VARS= \
	-e IN_DOCKER=$(IN_DOCKER) \
	-e CI=$(CI) \
	-e MIX_ENV=$(MIX_ENV) \
	-e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
	-e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
	-e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
	-e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
	-e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
	-e AMQP_URL=$(AMQP_URL) \

test.ex.setup: export MIX_ENV=test
test.ex.setup: build
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	sem-service start rabbitmq 3.8
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	rm -rf $(TMP_REPO_DIR)
	$(MAKE) format
