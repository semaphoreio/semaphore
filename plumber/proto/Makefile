.PHONY: console test

USER=dev
HOME_DIR=/home/dev
WORKDIR=$(HOME_DIR)/proto
RELATIVE_PB_OUTPUT_DIR=lib/internal_api
INTERACTIVE_SESSION=\
          -v $$PWD/home_dir:$(HOME_DIR) \
          -v $$PWD/..:$(WORKDIR) \
          -e HOME=$(HOME_DIR) \
          -e MIX_ENV=test \
          --workdir=$(WORKDIR)/proto \
          -it renderedtext/elixir-dev:1.6.5-v2 \

INTERNAL_API_BRANCH?=master
TMP_INTERNAL_REPO_DIR?=/tmp/internal_api
RELATIVE_INTERNAL_PB_OUTPUT_DIR=lib/internal_api
RT_PROTOC_IMG_VSN=1.6.6-3.3.0-0.5.4

pb.clone:
	rm -rf $(TMP_INTERNAL_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_INTERNAL_REPO_DIR) && (cd $(TMP_INTERNAL_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)

pb.gen: pb.clone
ifeq ($(shell whoami), vagrant)
	sudo rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
else
	rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
endif
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/include/google/protobuf/timestamp.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/include/google/rpc/status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/include/google/rpc/code.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/gofer.switch.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/gofer.dt.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/organization.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/paparazzo.snapshot.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/plumber.pipeline.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/plumber.admin.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/plumber_w_f.workflow.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/repo_proxy.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/repository.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/include/internal_api/response_status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/include/internal_api/status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/task.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/repository_integrator.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/user.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/projecthub.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/artifacthub.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/health.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/pre_flight_checks_hub.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/usage.proto
	rm -rf $(TMP_INTERNAL_REPO_DIR)

console:
	docker run $(INTERACTIVE_SESSION) /bin/bash

test:
	docker run --user=$(USER) $(INTERACTIVE_SESSION) \
          mix do local.hex --force, local.rebar --force, deps.get, test
