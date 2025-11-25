export MIX_ENV?=dev

include ../Makefile

DOCKER_BUILD_PATH=..
APP_NAME=zebra
TMP_REPO_DIR?=/tmp/internal_api
PUBLIC_API_BRANCH ?= master
INTERNAL_API_BRANCH ?= master
RT_PROTOC_IMG_VSN=1.6.6-3.3.0-0.5.4

#
# Environment variables required for application to run
#

POSTGRES_DB_NAME?="front"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?="5"
AMQP_URL?="amqp://0.0.0.0:5672"
START_JOB_REQUEST_FACTORY?="false"
START_DISPATCHER_WORKER?="false"
START_TASK_FINISHER_WORKER?="false"
START_JOB_STARTED_CALLBACK_WORKER?="false"
START_JOB_FINISHED_CALLBACK_WORKER?="false"
START_JOB_TEARDOWN_CALLBACK_WORKER?="false"
START_MONITOR?="false"
START_PUBLIC_JOB_API?="true"
START_INTERNAL_JOB_API?="true"
START_GRPC_HEALTH_CHECK?="true"
START_INTERNAL_TASK_API?="true"
JOB_CALLBACK_BROKER_URL?="s2-callback.semaphoretest.xyz"
ZEBRA_CALLBACK_TOKEN_KEYS?="testing"

CONTAINER_ENV_VARS= \
	-e CI=$(CI) \
	-e MIX_ENV=$(MIX_ENV) \
	-e START_JOB_DELETION_POLICY_MARKER=$(START_JOB_DELETION_POLICY_MARKER) \
	-e START_JOB_DELETION_POLICY_WORKER=$(START_JOB_DELETION_POLICY_WORKER) \
	-e START_PUBLIC_JOB_API=$(START_PUBLIC_JOB_API) \
	-e START_INTERNAL_JOB_API=$(START_INTERNAL_JOB_API) \
	-e START_INTERNAL_TASK_API=$(START_INTERNAL_TASK_API) \
	-e START_GRPC_HEALTH_CHECK=$(START_GRPC_HEALTH_CHECK) \
	-e START_JOB_REQUEST_FACTORY=$(START_JOB_REQUEST_FACTORY) \
	-e START_DISPATCHER_WORKER=$(START_DISPATCHER_WORKER) \
	-e START_TASK_FINISHER_WORKER=$(START_TASK_FINISHER_WORKER) \
	-e START_JOB_STARTED_CALLBACK_WORKER=$(START_JOB_STARTED_CALLBACK_WORKER) \
	-e START_JOB_FINISHED_CALLBACK_WORKER=$(START_JOB_STARTED_CALLBACK_WORKER) \
	-e START_JOB_TEARDOWN_CALLBACK_WORKER=$(START_JOB_TEARDOWN_CALLBACK_WORKER) \
	-e START_MONITOR=$(START_MONITOR) \
	-e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
	-e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
	-e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
	-e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
	-e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
	-e AMQP_URL=$(AMQP_URL) \
	-e JOB_CALLBACK_BROKER_URL=$(JOB_CALLBACK_BROKER_URL) \
	-e ZEBRA_CALLBACK_TOKEN_KEYS=$(ZEBRA_CALLBACK_TOKEN_KEYS)

internal.pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/protos/internal_api && mkdir -p lib/protos/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(RT_PROTOC_IMG_VSN) sh -c /home/protoc/code/scripts/internal_protos.sh
	rm -rf $(TMP_REPO_DIR)

public.pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:semaphoreci/api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(PUBLIC_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/protos/public_api && mkdir -p lib/protos/public_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(RT_PROTOC_IMG_VSN) sh -c /home/protoc/code/scripts/public_protos.sh
	rm -rf $(TMP_REPO_DIR)

pb.gen:
	$(MAKE) internal.pb.gen
	$(MAKE) public.pb.gen

db.gen.migration:
	docker compose run --rm -e MIX_ENV=dev app mix ecto.gen.migration $(NAME)

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	sem-service start rabbitmq 3.8
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif