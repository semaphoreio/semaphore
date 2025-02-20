export MIX_ENV?=dev

include ../../Makefile

DOCKER_BUILD_PATH=..
EX_CATCH_WARRNINGS_FLAG=

APP_NAME=ppl

IN_DOCKER?="true"
POSTGRES_DB_NAME?="ppl_repo"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?="5"
POSTGRES_DB_SSL="false"
BLOCK_POSTGRES_DB_NAME?="block_repo"
BLOCK_POSTGRES_DB_USER?="postgres"
BLOCK_POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
BLOCK_POSTGRES_DB_HOST?="0.0.0.0"
BLOCK_POSTGRES_DB_POOL_SIZE?="5"
BLOCK_POSTGRES_DB_SSL="false"
RABBITMQ_URL?="amqp://0.0.0.0:5672"
INTERNAL_API_URL_TASK="0.0.0.0:50051"
INTERNAL_API_URL_REPO_PROXY="0.0.0.0:50052"
REPO_PROXY_NEW_GRPC_URL="0.0.0.0:50052"
IN_FLIGHT_DESCRIBE_LIMIT=50
IN_FLIGHT_LIST_LIMIT=50
PPL_QUEUE_LIMIT=9
LOG_LEVEL?=info

CONTAINER_ENV_VARS= \
  -e IN_DOCKER=$(IN_DOCKER) \
  -e CI=$(CI) \
  -e MIX_ENV=$(MIX_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL) \
  -e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
  -e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
  -e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
  -e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
  -e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
  -e POSTGRES_DB_SSL=$(POSTGRES_DB_SSL) \
  -e BLOCK_POSTGRES_DB_NAME=$(BLOCK_POSTGRES_DB_NAME) \
  -e BLOCK_POSTGRES_DB_USER=$(BLOCK_POSTGRES_DB_USER) \
  -e BLOCK_POSTGRES_DB_PASSWORD=$(BLOCK_POSTGRES_DB_PASSWORD) \
  -e BLOCK_POSTGRES_DB_HOST=$(BLOCK_POSTGRES_DB_HOST) \
  -e BLOCK_POSTGRES_DB_POOL_SIZE=$(BLOCK_POSTGRES_DB_POOL_SIZE) \
  -e BLOCK_POSTGRES_DB_SSL=$(BLOCK_POSTGRES_DB_SSL) \
  -e RABBITMQ_URL=$(RABBITMQ_URL) \
  -e INTERNAL_API_URL_TASK=$(INTERNAL_API_URL_TASK) \
  -e INTERNAL_API_URL_REPO_PROXY=$(INTERNAL_API_URL_REPO_PROXY) \
  -e REPO_PROXY_NEW_GRPC_URL=$(REPO_PROXY_NEW_GRPC_URL) \
  -e IN_FLIGHT_DESCRIBE_LIMIT=$(IN_FLIGHT_DESCRIBE_LIMIT) \
  -e IN_FLIGHT_LIST_LIMIT=$(IN_FLIGHT_LIST_LIMIT) \
  -e PPL_QUEUE_LIMIT=$(PPL_QUEUE_LIMIT)

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	sem-service start rabbitmq 3.8
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

repo_proxy.run:
	cd ../repo_proxy_ref && \
		$(MAKE) build IMAGE=repo_proxy_ref/$(BRANCH) MASTER_IMAGE=repo_proxy_ref/master BUILD_ENV=prod IMAGE_TAG=prod && \
		docker run --network host -e GRPC_PORT=50052 -d repo_proxy_ref/$(BRANCH):prod && \
		cd -

task_api.run:
	cd ../task_api_referent && \
		$(MAKE) build IMAGE=task_api_referent/$(BRANCH) MASTER_IMAGE=task_api_referent/master BUILD_ENV=prod IMAGE_TAG=prod && \
		docker run --network host -e GRPC_PORT=50051 -d task_api_referent/$(BRANCH):prod && \
		cd -
