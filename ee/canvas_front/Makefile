export MIX_ENV?=dev

include ../../Makefile

DOCKER_BUILD_PATH=.
APP_NAME?=canvas_front
SHELL := /bin/bash
PROTOC_TAG=1.18.3-3.20.1-0.14.1
TMP_REPO_DIR ?= /tmp/internal_api
INTERNAL_API_BRANCH?=master

#
# Environment variables required for application to run
#
CACHE_PREFIX=canvas_front/
CACHE_HOST=0.0.0.0
CACHE_PORT=6379
CACHE_POOL_SIZE=5
AMQP_URL=amqp://0.0.0.0:5672

CONTAINER_ENV_VARS = \
	-e CI=$(CI) \
	-e MIX_ENV=$(MIX_ENV) \
	-e AMQP_URL=$(AMQP_URL) \
	-e CACHE_PREFIX=$(CACHE_PREFIX) \
	-e CACHE_HOST=$(CACHE_HOST) \
	-e CACHE_PORT=$(CACHE_PORT) \
	-e CACHE_POOL_SIZE=$(CACHE_POOL_SIZE) \
	-e SECRET_KEY_BASE="keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure" \
	-e SESSION_SIGNING_SALT="keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure"

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifneq ($(CI),)
	sem-service start rabbitmq 3.8
endif

pb.gen.internal:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	scripts/vagrant_sudo chown -R $$(id -u $${USER}):$$(id -g $${USER}) lib/internal_api
	rm -rf $(TMP_REPO_DIR)

deps.check: build
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --no-deps -e MIX_ENV=dev app ash -c 'mix deps.unlock --check-unused'
else
	docker run --rm $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) ash -c 'mix deps.unlock --check-unused'
endif

overage.js: build
ifeq ($(CI),)
	-docker compose $(DOCKER_COMPOSE_OPTS) run --no-deps -e MIX_ENV=test --rm app ash -c "cd assets && npm run coverage"
else
	docker run --rm -v $(PWD)/out:/app/out $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) ash -c "cd assets && npm run coverage"
endif

compile.ts: build
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --no-deps -e MIX_ENV=test --rm app ash -c "set -o pipefail; cd assets && npm run tsc.check"
else
	docker run --rm -v $(PWD)/out:/app/out $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) ash -c "set -o pipefail; cd assets && npm run tsc.check"
endif

show.routes: build
	docker compose $(DOCKER_COMPOSE_OPTS) run -e MIX_ENV=test --rm app mix phx.routes

dev.server: build
	docker compose $(DOCKER_COMPOSE_OPTS) run --service-ports -e MIX_ENV=dev $(DOCKER_COMPOSE_RUN_OPTS) --rm app iex -S mix dev.server

