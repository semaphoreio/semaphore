export MIX_ENV?=dev

include ../Makefile

APP_NAME=secrethub
TMP_REPO_DIR=/tmp/internal_api
INTERNAL_API_BRANCH ?= master
PUBLIC_API_BRANCH ?= master
PROTOC_TAG=1.12.1-3.17.3-0.7.1

IN_DOCKER?="true"
POSTGRES_DB_NAME?="guard"
POSTGRES_DB_USER?="postgres"
POSTGRES_DB_PASSWORD?="the-cake-is-a-lie"
POSTGRES_DB_HOST?="0.0.0.0"
POSTGRES_DB_POOL_SIZE?="5"
AMQP_URL?="amqp://0.0.0.0:5672"
BASE_DOMAIN?="localhost"
LOG_LEVEL?=info
OPENID_KEYS_PATH?="priv/openid_keys_in_tests"
ENCRYPTOR_URL?="0.0.0.0:50052"
INTERNAL_API_URL_RBAC?="127.0.0.1:50051"
INTERNAL_API_URL_FEATURE?="127.0.0.1:50051"
INTERNAL_API_URL_PROJECT?="127.0.0.1:50051"

CONTAINER_ENV_VARS= \
  -e IN_DOCKER=$(IN_DOCKER) \
  -e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
  -e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
  -e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD) \
  -e POSTGRES_DB_HOST=$(POSTGRES_DB_HOST) \
  -e POSTGRES_DB_POOL_SIZE=$(POSTGRES_DB_POOL_SIZE) \
  -e AMQP_URL=$(AMQP_URL) \
  -e BASE_DOMAIN=$(BASE_DOMAIN) \
	-e OPENID_KEYS_PATH=$(OPENID_KEYS_PATH) \
	-e ENCRYPTOR_URL=$(ENCRYPTOR_URL) \
  -e CI=$(CI) \
  -e MIX_ENV=$(MIX_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL) \
  -e INTERNAL_API_URL_RBAC=$(INTERNAL_API_URL_RBAC) \
  -e INTERNAL_API_URL_FEATURE=$(INTERNAL_API_URL_FEATURE) \
  -e INTERNAL_API_URL_PROJECT=$(INTERNAL_API_URL_PROJECT)

pb.gen.internal:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	scripts/vagrant_sudo chown -R $$(id -u $${USER}):$$(id -g $${USER}) lib/internal_api
	rm -rf $(TMP_REPO_DIR)
	$(MAKE) pb.gen.format

pb.gen.public:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:semaphoreci/api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(PUBLIC_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/public_api && mkdir -p lib/public_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/public_protos.sh
	scripts/vagrant_sudo chown -R $$(id -u $${USER}):$$(id -g $${USER}) lib/public_api
	rm -rf $(TMP_REPO_DIR)
	$(MAKE) pb.gen.format

deps.check: build
	docker run --rm $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix deps.unlock --check-unused

db.gen.migration:
	docker run --rm $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix ecto.gen.migration $(NAME)

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	$(MAKE) encryptor.run
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	sem-service start rabbitmq 3.8
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif
