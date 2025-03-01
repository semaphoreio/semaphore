export MIX_ENV?=dev

include ../../Makefile

DOCKER_BUILD_PATH=../..
OUT_VOLUME=$(PWD)/out:/app/api/out
INTERNAL_API_BRANCH?=master
TMP_INTERNAL_REPO_DIR?=/tmp/internal_api
RELATIVE_INTERNAL_PB_OUTPUT_DIR=lib/internal_api
RT_PROTOC_IMG_VSN=1.15.4-3.20.1-0.12.0
APP_NAME=plumber-public

CHECK_DEPS_EXTRA_OPTS=-w util,feature_provider

PROTOC_TAG=1.6.6-3.3.0-0.5.4
API_VERSION=v1alpha

IN_DOCKER?="true"
LOGHUB_API_URL?=127.0.0.1:50052
LOGHUB2_API_URL?=127.0.0.1:50052
INTERNAL_API_URL_RBAC?=127.0.0.1:50052
REPO_PROXY_URL?=127.0.0.1:50052
USER_API_URL?=127.0.0.1:50052
GOFER_GRPC_URL?=127.0.0.1:50052
PERIODIC_SCHEDULER_URL?=127.0.0.1:50052
PPL_GRPC_URL?=127.0.0.1:50052
WF_GRPC_URL?=127.0.0.1:50052
SELF_HOSTED_HUB_URL?=127.0.0.1:50052
SECRETHUB_GRPC_URL?=127.0.0.1:50052
FEATURE_GRPC_URL?=127.0.0.1:50052
JOBS_API_URL?=127.0.0.1:50052
PROJECT_API_GRPC_URL?=127.0.0.1:50052
ARTIFACTS_HUB_URL?=127.0.0.1:50052
PROJECTHUB_API_GRPC_URL?=127.0.0.1:50052
LOG_LEVEL?=debug
API_VERSION?=v1alpha
ON_PREM?="false"

CONTAINER_ENV_VARS= \
  -e IN_DOCKER=$(IN_DOCKER) \
  -e MIX_ENV=$(MIX_ENV) \
  -e CI=$(CI) \
  -e LOGHUB_API_URL=$(LOGHUB_API_URL) \
  -e LOGHUB2_API_URL=$(LOGHUB2_API_URL) \
  -e INTERNAL_API_URL_RBAC=$(INTERNAL_API_URL_RBAC) \
  -e REPO_PROXY_URL=$(REPO_PROXY_URL) \
  -e USER_API_URL=$(USER_API_URL) \
  -e GOFER_GRPC_URL=$(GOFER_GRPC_URL) \
  -e PERIODIC_SCHEDULER_URL=$(PERIODIC_SCHEDULER_URL) \
  -e PPL_GRPC_URL=$(PPL_GRPC_URL) \
  -e WF_GRPC_URL=$(WF_GRPC_URL) \
  -e SELF_HOSTED_HUB_URL=$(SELF_HOSTED_HUB_URL) \
  -e SECRETHUB_GRPC_URL=$(SECRETHUB_GRPC_URL) \
  -e FEATURE_GRPC_URL=$(FEATURE_GRPC_URL) \
  -e JOBS_API_URL=$(JOBS_API_URL) \
  -e PROJECT_API_GRPC_URL=$(PROJECT_API_GRPC_URL) \
  -e ARTIFACTS_HUB_URL=$(ARTIFACTS_HUB_URL) \
  -e PROJECTHUB_API_GRPC_URL=$(PROJECTHUB_API_GRPC_URL) \
  -e LOG_LEVEL=$(LOG_LEVEL) \
  -e API_VERSION=$(API_VERSION) \
  -e ON_PREM=$(ON_PREM)

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
# Localy we use database supplied by docker-compose
	docker compose $(DOCKER_COMPOSE_OPTS) run -e MIX_ENV=$(MIX_ENV) --build app mix do deps.get, test $(FILE)
else
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) sh
endif

pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	rm -rf $(TMP_REPO_DIR)
