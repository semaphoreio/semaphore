export MIX_ENV?=dev

include ../Makefile

DOCKER_BUILD_PATH=..
APP_NAME?=project_page
SHELL := /bin/bash
PROTOC_TAG=1.6.6-3.3.0-0.5.4
TMP_REPO_DIR ?= /tmp/internal_api
INTERNAL_API_BRANCH?=master
PUBLIC_API_BRANCH ?= master
APP_DESIGN_BRANCH ?= master

#
# Schema validator
#
SCHEMA_YAML_DIR=$(PWD)/../plumber/spec/priv
SCHEMA_YAML_FILE=v1.0
NODE_DOCKER_IMAGE=node:20
YQ_DOCKER_IMAGE=mikefarah/yq
SCHEMA_VALIDATOR_OUTPUT_DIR=$(PWD)/assets/js/workflow_editor/models/

#
# Environment variables required for application to run
#
CACHE_PREFIX=front/
CACHE_HOST=0.0.0.0
CACHE_PORT=6379
CACHE_POOL_SIZE=5
AMQP_URL=amqp://0.0.0.0:5672

#
# Internal API URLs
#
INTERNAL_API_URLS = \
	-e INTERNAL_API_URL_ARTIFACTHUB=127.0.0.1:50052 \
	-e INTERNAL_API_URL_AUDIT=127.0.0.1:50052 \
	-e INTERNAL_API_URL_AUTHENTICATION=127.0.0.1:50051 \
	-e INTERNAL_API_URL_BILLING=127.0.0.1:50052 \
	-e INTERNAL_API_URL_BRANCH=127.0.0.1:50052 \
	-e INTERNAL_API_URL_DASHBOARDHUB=127.0.0.1:50052 \
	-e INTERNAL_API_URL_FEATURE=127.0.0.1:50052 \
	-e INTERNAL_API_URL_GUARD=127.0.0.1:50052 \
	-e INTERNAL_API_URL_USER=127.0.0.1:50052 \
	-e INTERNAL_API_URL_HOOKS=127.0.0.1:50052 \
	-e INTERNAL_API_URL_INSTANCE_CONFIG=127.0.0.1:50052 \
	-e INTERNAL_API_URL_JOB=127.0.0.1:50052 \
	-e INTERNAL_API_URL_LOGHUB2=127.0.0.1:50051 \
	-e INTERNAL_API_URL_NOTIFICATION=127.0.0.1:50052 \
	-e INTERNAL_API_URL_OKTA=127.0.0.1:50052 \
	-e INTERNAL_API_URL_ORGANIZATION=127.0.0.1:50052 \
	-e INTERNAL_API_URL_SCHEDULER=127.0.0.1:50052 \
	-e INTERNAL_API_URL_PERMISSION_PATROL=127.0.0.1:50052 \
	-e INTERNAL_API_URL_PLUMBER=127.0.0.1:50052 \
	-e INTERNAL_API_URL_PFC=127.0.0.1:50052 \
	-e INTERNAL_API_URL_PROJECT=127.0.0.1:50052 \
	-e INTERNAL_API_URL_RBAC=127.0.0.1:50052 \
	-e INTERNAL_API_URL_REPO_PROXY=127.0.0.1:50051 \
	-e INTERNAL_API_URL_REPOHUB=127.0.0.1:50052 \
	-e INTERNAL_API_URL_REPOSITORY_INTEGRATOR=127.0.0.1:50052 \
	-e INTERNAL_API_URL_REPOSITORY=127.0.0.1:50052 \
	-e INTERNAL_API_URL_SCOUTER=127.0.0.1:50052 \
	-e INTERNAL_API_URL_SECRETHUB=127.0.0.1:50052 \
	-e INTERNAL_API_URL_SELFHOSTEDHUB=127.0.0.1:50052 \
	-e INTERNAL_API_URL_SUPERJERRY=127.0.0.1:50051 \
	-e INTERNAL_API_URL_TASK=127.0.0.1:50052 \
	-e INTERNAL_API_URL_VELOCITY=127.0.0.1:50052 \
	-e INTERNAL_API_URL_LICENSE=127.0.0.1:50052 \
	-e INTERNAL_API_URL_GOFER=127.0.0.1:50052 \
	-e INTERNAL_API_URL_GROUPS=127.0.0.1:50052 \
	-e INTERNAL_API_URL_LOGHUB=127.0.0.1:50051

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
	-e SESSION_SIGNING_SALT="keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure" \
	$(INTERNAL_API_URLS)


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
	 -e SESSION_SIGNING_SALT="keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure" \
	 $(INTERNAL_API_URLS)

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

#
# Schema validator generation
#
schema.validator.gen:
	# Convert YAML to JSON
	docker run --rm -v $(SCHEMA_YAML_DIR):/app -w /app $(YQ_DOCKER_IMAGE) e 'del(.["$$schema"]) | del(.version)' -o=json $(SCHEMA_YAML_FILE).yml > $(SCHEMA_YAML_FILE).json

	# Install ajv-cli and compile JSON schema
	docker run --rm -v $(PWD):/app -w /app $(NODE_DOCKER_IMAGE) \
		sh -c "\
			npm install -g ajv-cli && \
			ajv compile -s $(SCHEMA_YAML_FILE).json -o pipeline_schema_validator.js --all-errors && \
			echo '// This is a generated file using make schema.validator.gen' > temp.js && \
			echo '// This is a pre-compiled schema validator using Ajv.' >> temp.js && \
			echo '// It is included to prevent Eval errors in the browser,' >> temp.js && \
			echo '// as Ajv requires schema compilation.' >> temp.js && \
			echo '// Reference: https://ajv.js.org/standalone.html' >> temp.js && \
			cat pipeline_schema_validator.js >> temp.js"
	mv temp.js pipeline_schema_validator.js
	mv pipeline_schema_validator.js $(SCHEMA_VALIDATOR_OUTPUT_DIR)
	rm -f $(SCHEMA_YAML_FILE).json

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

workflow.templates.check:
	@echo "📦 Checking templates..."
	./scripts/check-templates.sh workflow_templates/saas_new 
	./scripts/check-templates.sh workflow_templates/ce_new
