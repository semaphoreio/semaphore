export MIX_ENV?=dev

include ../../Makefile

APP_NAME := $(shell grep 'app:' mix.exs | cut -d ':' -f3 | cut -d ',' -f1)
INTERNAL_API_BRANCH?=master
PROTOC_TAG=1.18.4-3.20.1-0.13.0
TMP_REPO_DIR?=/tmp/internal_api

POSTGRES_DB_NAME?="ephemeral_environments"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?=1

CONTAINER_ENV_VARS= \
	-e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
	-e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
	-e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
	-e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
	-e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
	-e MIX_ENV=$(MIX_ENV)

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	rm -rf $(TMP_REPO_DIR)
