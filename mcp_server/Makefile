include ../Makefile

APP_NAME=mcp_server
APP_ENV=prod

INTERNAL_API_BRANCH?=master
TMP_REPO_DIR ?= /tmp/internal_api
INTERNAL_API_MODULES?=include/internal_api/status,include/internal_api/response_status,plumber_w_f.workflow,plumber.pipeline,server_farm.job,loghub,loghub2,user,repository_integrator,rbac,organization,projecthub,feature,artifacthub
PROTOC_IMAGE?=golang:1.24-alpine

.PHONY: tidy test test.setup lint pb.gen dev.run

tidy:
	go mod tidy

test.setup:
	@true

test:
	go test ./...

lint:
	go vet ./...

pb.gen:
	rm -rf $(TMP_REPO_DIR)
	mkdir -p $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	docker run --rm \
		-v $(PWD):/app \
		-v $(TMP_REPO_DIR):/tmp/internal_api \
		-w /app \
		$(PROTOC_IMAGE) \
		sh -c 'apk add --no-cache bash protobuf && \
		go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.2 && \
		go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1 && \
		bash script/internal_api/gen.sh "$(INTERNAL_API_MODULES)" $(INTERNAL_API_BRANCH) /tmp/internal_api'
	rm -rf $(TMP_REPO_DIR)

dev.run:
	@if command -v air >/dev/null 2>&1; then \
		echo "Starting MCP server with air (hot reload)"; \
		air -c .air.dev.toml; \
	else \
		echo "air not found, falling back to go run"; \
		MCP_USE_STUBS=true go run ./cmd/mcp_server -http :3001; \
	fi
