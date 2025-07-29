export MIX_ENV?=dev

include ../Makefile

APP_NAME=$(shell grep 'app:' mix.exs | cut -d ':' -f3 | cut -d ',' -f1)
INTERNAL_API_BRANCH?=master
TMP_INTERNAL_REPO_DIR?=/tmp/internal_api
RELATIVE_INTERNAL_PB_OUTPUT_DIR=lib/internal_api
RT_PROTOC_IMG_VSN=1.18.1-3.20.1-0.13.0

IN_DOCKER?="true"
INTERNAL_API_URL_REPOSITORY?=localhost:50052
INTERNAL_API_URL_PROJECT?=localhost:50053
INTERNAL_API_URL_PLUMBER?=localhost:50054
INTERNAL_API_URL_USER?=localhost:50055
INTERNAL_API_URL_BRANCH?=localhost:50056
POSTGRES_DB_NAME="front"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?=1
WEBHOOK_PROVIDER?="test"
AMQP_URL?="amqp://0.0.0.0:5672"
LOG_LEVEL?=info

CONTAINER_ENV_VARS= \
  -e INTERNAL_API_URL_REPOSITORY=$(INTERNAL_API_URL_REPOSITORY) \
  -e INTERNAL_API_URL_PROJECT=$(INTERNAL_API_URL_PROJECT) \
  -e INTERNAL_API_URL_PLUMBER=$(INTERNAL_API_URL_PLUMBER) \
  -e INTERNAL_API_URL_USER=$(INTERNAL_API_URL_USER) \
  -e INTERNAL_API_BRANCH=$(INTERNAL_API_BRANCH) \
  -e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
  -e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
  -e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
  -e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
  -e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
  -e WEBHOOK_PROVIDER=$(WEBHOOK_PROVIDER) \
  -e AMQP_URL=$(AMQP_URL) \
  -e MIX_ENV=$(MIX_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL) \
  -e CI=$(CI)

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	sem-service start rabbitmq 3.8
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

pb.gen: pb.clone
ifeq ($(shell whoami), vagrant)
	sudo rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
else
	rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
endif
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/internal_api/response_status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/internal_api/status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/protobuf/timestamp.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/rpc/code.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/rpc/status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/rpc/google/protobuf/any.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/user.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/repository_integrator.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/projecthub.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/hooks.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/plumber_w_f.workflow.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/plumber.admin.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/plumber.pipeline.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/branch.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/repo_proxy.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/repository.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/health.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/rbac.proto
	rm -rf $(TMP_INTERNAL_REPO_DIR)
