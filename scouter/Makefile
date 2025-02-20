export MIX_ENV?=dev

include ../Makefile

APP_NAME=scouter
INTERNAL_API_BRANCH?=master
PROTOC_TAG=1.16.2-otp-25-3.20.1-0.12.0
TMP_REPO_DIR?=/tmp/internal_api
DOCKERFILE?=Dockerfile

POSTGRES_DB_NAME=scouter
POSTGRES_DB_USER=postgres
POSTGRES_DB_PASSWORD=the-cake-is-a-lie

CONTAINER_ENV_VARS= \
	-e CI=$(CI) \
	-e MIX_ENV=$(MIX_ENV) \
	-e POSTGRES_DB_NAME=$(POSTGRES_DB_NAME) \
	-e POSTGRES_DB_USER=$(POSTGRES_DB_USER) \
	-e POSTGRES_DB_PASSWORD=$(POSTGRES_DB_PASSWORD)

pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	rm -rf $(TMP_REPO_DIR)

coverage:
	docker run --rm $(VOLUME_BIND) -e MIX_ENV=$(MIX_ENV) $(IMAGE):$(IMAGE_TAG) mix coveralls

test.ex.setup: export MIX_ENV=test
test.ex.setup: build
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
	docker run --network host $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif
