export MIX_ENV ?= dev

include ../Makefile

APP_NAME=$(shell grep 'app:' mix.exs | cut -d ':' -f3 | cut -d ',' -f1)
PROTOC_TAG=1.12.1-3.17.3-0.7.1
TMP_REPO_DIR=/tmp/internal_api

INTERNAL_API_BRANCH ?= master
PUBLIC_API_BRANCH ?= master

test.ex.setup: export MIX_ENV=test
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
	git clone git@github.com:semaphoreci/api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(PUBLIC_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/public_api && mkdir -p lib/public_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/public_protos.sh
	rm -rf $(TMP_REPO_DIR)
	$(MAKE) format
