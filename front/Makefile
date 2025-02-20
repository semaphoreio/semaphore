export MIX_ENV?=dev

include ../Makefile

APP_NAME?=project_page
SHELL := /bin/bash
PROTOC_TAG=1.6.6-3.3.0-0.5.4
TMP_REPO_DIR ?= /tmp/internal_api
INTERNAL_API_BRANCH?=master
PUBLIC_API_BRANCH ?= master
APP_DESIGN_BRANCH ?= master

#
# Environment variables required for application to run
#
CACHE_PREFIX=front/
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
	-e WORKFLOW_TEMPLATES_YAMLS_PATH="/app/workflow_templates/saas" \
	-e SEED_SELF_HOSTED_AGENTS=true \
	-e SEED_PROJECTS="initializing_failed,zebra,guard,errored,test_results,test_results_debug,after_pipeline,bitbucket" \
	-e SEED_CLOUD_MACHINES=true \
	-e SECRET_KEY_BASE="keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure" \
	-e SESSION_SIGNING_SALT="keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure"


CONTAINER_CE_ENV_VARS =\
	 -e CE_ROLES=true \
	 -e SEED_CLOUD_MACHINES=false \
	 -e SEED_SELF_HOSTED_AGENTS=true \
	 -e SEED_CE_FEATURES=true \
	 -e SEED_PROJECTS="simple_project,multi_block_project,scheduled_project" \
	 -e HIDE_PROMOTIONS=true \
	 -e WORKFLOW_TEMPLATES_YAMLS_PATH="/app/workflow_templates/ce" \
	 -e EXCLUDE_STUBS="GoferMock" \
	 -e SECRET_KEY_BASE="keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure" \
	 -e SESSION_SIGNING_SALT="keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure"

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifneq ($(CI),)
	sem-service start rabbitmq 3.8
	sem-service start redis 5.0
endif

pb.gen: pb.gen.internal pb.gen.public
	$(MAKE) format

pb.gen.internal:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	scripts/vagrant_sudo chown -R $$(id -u $${USER}):$$(id -g $${USER}) lib/internal_api
	rm -rf $(TMP_REPO_DIR)

pb.gen.public:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:semaphoreci/api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(PUBLIC_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/public_api && mkdir -p lib/public_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/public_protos.sh
	scripts/vagrant_sudo chown -R $$(id -u $${USER}):$$(id -g $${USER}) lib/public_api
	rm -rf $(TMP_REPO_DIR)

workflow.templates.gen:
	@echo "Generating workflow templates"
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/app-design.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(APP_DESIGN_BRANCH) && make check.templates && cd -)
	./scripts/generate-workflow-templates.sh $(TMP_REPO_DIR)
	rm -rf $(TMP_REPO_DIR)

deps.check: build
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --no-deps -e MIX_ENV=dev app ash -c 'mix deps.unlock --check-unused'
else
	docker run --rm $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) ash -c 'mix deps.unlock --check-unused'
endif

lint.js: build
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --no-deps -e MIX_ENV=dev app ash -c 'cd assets && npm run lint.junit'
else
	docker run --rm -v $(PWD)/out:/app/out $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) ash -c 'cd assets && npm run lint.junit'
endif

test.js: build
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --no-deps -e MIX_ENV=test --rm app ash -c "cd assets && npm test"
else
	docker run --rm -v $(PWD)/out:/app/out $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) ash -c "cd assets && npm test"
endif

coverage.js: build
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

dev.ce.server: build
	DOCKER_COMPOSE_RUN_OPTS="--service-ports $(CONTAINER_CE_ENV_VARS)" $(MAKE) dev.server

console.ce.bash:
	DOCKER_COMPOSE_RUN_OPTS="--service-ports $(CONTAINER_CE_ENV_VARS)" $(MAKE) console.bash
