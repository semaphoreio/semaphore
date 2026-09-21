export MIX_ENV?=dev

include ../Makefile

DOCKER_BUILD_PATH=..
APP_NAME=auth
INTERNAL_API_BRANCH?=master
TMP_REPO_DIR?=/tmp/internal_api
RELATIVE_INTERNAL_PB_OUTPUT_DIR=lib/internal_api
RT_PROTOC_IMG_VSN=1.16.2-otp-26-3.20.1-0.12.0

#
# Environment variables
#
LOG_LEVEL?=info
LOAD_BALANCER_IP?="127.0.0.1"
BASE_DOMAIN?="semaphoretest.test"
COOKIE_NAME?="_s2_something_"
INTERNAL_API_URL_AUTHENTICATION?=localhost:50051
INTERNAL_API_URL_ORGANIZATION?=localhost:50051
INTERNAL_API_URL_RBAC?=localhost:50051
INTERNAL_API_URL_FEATURE?=localhost:50051

CONTAINER_ENV_VARS= \
	-e MIX_ENV=$(MIX_ENV) \
	-e LOG_LEVEL=$(LOG_LEVEL) \
	-e CI=$(CI) \
	-e LOAD_BALANCER_IP=$(LOAD_BALANCER_IP) \
	-e BASE_DOMAIN=$(BASE_DOMAIN) \
	-e COOKIE_NAME=$(COOKIE_NAME) \
	-e INTERNAL_API_URL_AUTHENTICATION=$(INTERNAL_API_URL_AUTHENTICATION) \
	-e INTERNAL_API_URL_ORGANIZATION=$(INTERNAL_API_URL_ORGANIZATION) \
	-e INTERNAL_API_URL_RBAC=$(INTERNAL_API_URL_RBAC) \
	-e INTERNAL_API_URL_FEATURE=$(INTERNAL_API_URL_FEATURE)

compile:
	mkdir -p deps _build
	docker run -v $(PWD)/deps:/app/deps -v $(PWD)/_build:/app/_build -e MIX_ENV=$(MIX_ENV) $(IMAGE):$(IMAGE_TAG) mix do deps.get, deps.compile

pb.clone:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)

pb.gen: pb.clone
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(RT_PROTOC_IMG_VSN) sh -c /home/protoc/code/scripts/internal_protos.sh
	scripts/vagrant_sudo chown -R $$(id -u $${USER}):$$(id -g $${USER}) lib/internal_api
	rm -rf $(TMP_REPO_DIR)
