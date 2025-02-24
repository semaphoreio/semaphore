export MIX_ENV?=dev

include ../../Makefile

DOCKER_BUILD_PATH=../..
OUT_VOLUME=$(PWD)/out:/app/audit/out
APP_NAME=$(shell grep 'app:' mix.exs | cut -d ':' -f3 | cut -d ',' -f1)
INTERNAL_API_BRANCH?=master
TMP_INTERNAL_REPO_DIR?=/tmp/internal_api
RELATIVE_INTERNAL_PB_OUTPUT_DIR=lib/internal_api
RT_PROTOC_IMG_VSN=1.12.1-3.17.3-0.7.1

IN_DOCKER?="true"
LOG_LEVEL?=info
AMQP_URL?="amqp://0.0.0.0:5672"
POSTGRES_DB_NAME?="audit"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?="5"
START_CONSUMER="true"
START_GRPC_API="true"
START_STREAMER="true"
S3_HOST=localhost

CONTAINER_ENV_VARS= \
  -e AMQP_URL=$(AMQP_URL) \
  -e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
  -e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
  -e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
  -e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
  -e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
  -e START_CONSUMER=$(START_CONSUMER) \
  -e START_GRPC_API=$(START_GRPC_API) \
  -e START_STREAMER=$(START_STREAMER) \
  -e S3_HOST=$(S3_HOST) \
  -e CI=$(CI) \
  -e MIX_ENV=$(MIX_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL)

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	sem-service start rabbitmq 3.8
	docker run --network host -p 9090:9090 -e initialBuckets=test-bucket -d -t adobe/s3mock:3.12.0
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

pb.gen: pb.clone
ifeq ($(shell whoami), vagrant)
	sudo rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
else
	rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
endif
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/protobuf/timestamp.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/protobuf/empty.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/rpc/google/protobuf/any.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/rpc/status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/rpc/code.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/internal_api/response_status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/internal_api/status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/repository_integrator.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/user.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/audit.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/feature.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/encryptor.proto
	rm -rf $(TMP_INTERNAL_REPO_DIR)
