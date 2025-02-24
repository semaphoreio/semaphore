export MIX_ENV?=dev

include ../Makefile

DOCKER_BUILD_PATH=..
APP_NAME=$(shell grep 'app:' mix.exs | cut -d ':' -f3 | cut -d ',' -f1)-grpc
PROTOC_TAG=1.12.1-3.20.3-0.11.0
TMP_REPO_DIR?=/tmp/internal_api
INTERNAL_API_BRANCH ?= master

#
# Environment variables required for app to run
#
AMQP_URL=amqp://127.0.0.1:5672
POSTGRES_DB_HOST=127.0.0.1
POSTGRES_DB_NAME=projecthub
POSTGRES_DB_USER=postgres
POSTGRES_DB_PASSWORD=the-cake-is-a-lie
START_INTERNAL_API=true

CONTAINER_ENV_VARS= \
	-e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
	-e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
	-e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
	-e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
	-e START_INTERNAL_API=$(START_INTERNAL_API) \
	-e AMQP_URL=$(AMQP_URL) \
	-e CI=$(CI) \
	-e MIX_ENV=$(MIX_ENV)

test.ex.setup: export MIX_ENV=test
test.ex.setup: build
ifeq ($(CI),)
	docker compose run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start rabbitmq 3.8
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	rm -rf lib/internal_api
	mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	rm -rf $(TMP_REPO_DIR)
	docker-compose run --rm app mix format
