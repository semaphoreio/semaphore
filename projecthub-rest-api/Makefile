export MIX_ENV?=dev

include ../Makefile

APP_NAME=projecthub-rest-api

TMP_REPO_DIR?=/tmp/internal_api
INTERNAL_API_BRANCH ?=master
PROTOC_TAG=1.6.6-3.3.0-0.5.4

CHECK_DEPS_EXTRA_OPTS=-w uuid

pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	rm -rf $(TMP_REPO_DIR)
