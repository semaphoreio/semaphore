export MIX_ENV?=dev

include ../Makefile

DOCKER_BUILD_PATH=..
APP_NAME=$(shell grep 'app:' mix.exs | cut -d ':' -f3 | cut -d ',' -f1)
DOCKERFILE_ALPINE_VERSION=$(shell sed -n 's/^ARG ALPINE_VERSION=//p' Dockerfile | tr -d '"')
INTERNAL_API_BRANCH?=master
TMP_INTERNAL_REPO_DIR?=/tmp/internal_api
RELATIVE_INTERNAL_PB_OUTPUT_DIR=lib/internal_api
RT_PROTOC_IMG_VSN=1.18.1-3.20.1-0.13.0

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),true)
	sem-service start rabbitmq 3.8
endif

pb.clone:
	rm -rf $(TMP_INTERNAL_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_INTERNAL_REPO_DIR) && (cd $(TMP_INTERNAL_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)

ifeq ($(shell whoami), vagrant)
	sudo rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
else
	rm -rf $(RELATIVE_INTERNAL_PB_OUTPUT_DIR) && mkdir -p $(RELATIVE_INTERNAL_PB_OUTPUT_DIR)
endif
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/internal_api/status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/rpc/code.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/rpc/status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/internal_api/response_status.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/protobuf/timestamp.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/protobuf/empty.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/include/google/protobuf/any.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/plumber_w_f.workflow.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/user.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/projecthub.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/plumber.pipeline.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/repo_proxy.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/organization.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/github_notifier.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/repository_integrator.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/repository.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/velocity.proto
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_INTERNAL_REPO_DIR):/home/protoc/source renderedtext/protoc:$(RT_PROTOC_IMG_VSN) protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:$(RELATIVE_INTERNAL_PB_OUTPUT_DIR) --plugin=/root/.mix/escripts/protoc-gen-elixir \
		/home/protoc/source/feature.proto

# Guard for the musl/Alpine BEAM signal-stack bug (erlang/otp#11248).
# Production facts (GKE c3-standard-8, amx_tile): AT_MINSIGSTKSZ=11952;
# musl's SIGSTKSZ is a static 8192, and OTP 27..29.0.4 size their
# alternate signal stack with it. musl >= 1.2.6 validates sigaltstack
# against the dynamic kernel minimum (sysconf(_SC_MINSIGSTKSZ)) and
# rejects the undersized stack -> BEAM aborts at startup (the July 2026
# production incident, Alpine 3.24 = musl 1.2.6). musl < 1.2.6 only
# checks the static 2048 -> boots, with the stack still undersized.
#
# The check passes when either:
#   1. the release boots under an LD_PRELOAD shim faking a strict kernel
#      with AT_MINSIGSTKSZ=SIGSTK_KERNEL_MIN (fixed OTP with
#      erlang/otp#11249, OTP <= 26, or interpreter builds), or
#   2. the runtime image's musl is < 1.2.6 (matches production-observed
#      behavior on Alpine <= 3.23; warns about the undersized stack).
# It fails when the runtime would abort at startup: unfixed OTP >= 27
# on musl >= 1.2.6.
SIGSTK_KERNEL_MIN?=11952
check.beam.sigstk: BUILD_ENV=prod
check.beam.sigstk:
	mkdir -p out/sigstk
	docker run --rm -v $(PWD)/test/sigstk:/src -v $(PWD)/out/sigstk:/o alpine:$(DOCKERFILE_ALPINE_VERSION) \
		sh -c 'apk add --no-cache gcc musl-dev >/dev/null && gcc -shared -fPIC -DSIGSTK_KERNEL_MIN=$(SIGSTK_KERNEL_MIN) /src/shim.c -o /o/shim.so -ldl'
	@if docker run --rm -v $(PWD)/out/sigstk:/o -e LD_PRELOAD=/o/shim.so $(IMAGE):$(IMAGE_TAG) \
		sh -c 'ERL=$$(ls -d /app/erts-*/bin/erl|head -1); BOOT=$$(ls /app/releases/*/start_clean.boot|head -1|sed "s/\.boot$$//"); $$ERL -boot $$BOOT -boot_var RELEASE_LIB /app/lib -noshell -eval "halt()."'; then \
		echo "sigstk guard: PASS - release sizes its signal stack for AT_MINSIGSTKSZ=$(SIGSTK_KERNEL_MIN)"; \
	else \
		MUSL=$$(docker run --rm $(IMAGE):$(IMAGE_TAG) sh -c 'ld=$$(ls /lib/ld-musl-*.so.1|head -1); $$ld --version 2>&1 | sed -n "s/^Version //p"' | head -1); \
		echo "sigstk guard: release requests SIGSTKSZ=8192 < AT_MINSIGSTKSZ=$(SIGSTK_KERNEL_MIN) (erlang/otp#11248); runtime musl=$$MUSL"; \
		if [ -n "$$MUSL" ] && [ "$$(printf '%s\n' "$$MUSL" 1.2.6 | sort -V | head -1)" = "$$MUSL" ] && [ "$$MUSL" != "1.2.6" ]; then \
			echo "sigstk guard: PASS (musl < 1.2.6 does not enforce the dynamic minimum; NOTE: signal stack remains undersized on AVX-512/AMX nodes)"; \
		else \
			echo "sigstk guard: FAIL - musl >= 1.2.6 enforces the dynamic minimum via sigaltstack; BEAM will abort at startup on AVX-512/AMX nodes (e.g. GKE c3). Use Alpine <= 3.23 (musl 1.2.5) or an OTP containing erlang/otp#11249"; \
			exit 1; \
		fi; \
	fi
