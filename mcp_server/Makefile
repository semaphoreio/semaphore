include ../Makefile

APP_NAME=mcp_server
APP_ENV=prod

.PHONY: tidy test build

tidy:
	go mod tidy

test:
	go test ./...

build: tidy
	docker build \
		--build-arg GO_VERSION=1.23.8 \
		--build-arg ALPINE_VERSION=3.20 \
		-t $(APP_NAME)/$(BRANCH) .

