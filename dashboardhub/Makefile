export MIX_ENV?=dev

include ../Makefile

APP_NAME=dashboardhub
INTERNAL_API_BRANCH?=master
TMP_INTERNAL_REPO_DIR?=/tmp/internal_api
RELATIVE_INTERNAL_PB_OUTPUT_DIR=lib/internal_api
PUBLIC_API_BRANCH?=master
TMP_PUBLIC_REPO_DIR?=/tmp/public_api
RELATIVE_PUBLIC_PB_OUTPUT_DIR=lib/public_api
RT_PROTOC_IMG_VSN=1.14.5-3.20.1-0.12.0

#
# Environment variables required for app to run.
#
POSTGRES_DB_NAME="dashboardhub"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?=1
AMQP_URL?="amqp://0.0.0.0:5672"
LOG_LEVEL?=info
GRPC_API?=true

CONTAINER_ENV_VARS= \
  -e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
  -e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
  -e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
  -e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
	-e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
  -e AMQP_URL=$(AMQP_URL) \
  -e MIX_ENV=$(MIX_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL) \
  -e GRPC_API=$(GRPC_API) \
  -e CI=$(CI)

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

dev.console:
	docker compose -f docker-compose.yml build --build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) --build-arg MIX_ENV=$(MIX_ENV) app
	docker compose -f docker-compose.yml run --rm app /bin/bash

compile:
	mkdir -p deps _build
	docker run -v $(PWD)/deps:/app/deps -v $(PWD)/_build:/app/_build -e MIX_ENV=$(MIX_ENV) $(IMAGE):$(IMAGE_TAG) mix do deps.get, deps.compile

pb.clone:
	rm -rf $(TMP_INTERNAL_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_INTERNAL_REPO_DIR) && (cd $(TMP_INTERNAL_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	rm -rf $(TMP_PUBLIC_REPO_DIR)
	git clone git@github.com:semaphoreci/api.git $(TMP_PUBLIC_REPO_DIR) && (cd $(TMP_PUBLIC_REPO_DIR) && git checkout $(PUBLIC_API_BRANCH) && cd -)

pb.gen: pb.clone
ifeq ($(shell whoami), vagrant)
	sudo rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
	sudo rm -rf $(RELATIVE_PUBLIC_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_PUBLIC_PB_OUTPUT_DIR)
else
	rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
	rm -rf $(RELATIVE_PUBLIC_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_PUBLIC_PB_OUTPUT_DIR)
endif
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/protobuf/timestamp.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/organization.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/dashboardhub.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/repository_integrator.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/health.proto
	rm -rf $(TMP_INTERNAL_REPO_DIR)
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_PUBLIC_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source --elixir_out=plugins=grpc:$(RELATIVE_PUBLIC_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/semaphore/dashboards.v1alpha.proto
	rm -rf $(TMP_PUBLIC_REPO_DIR)
