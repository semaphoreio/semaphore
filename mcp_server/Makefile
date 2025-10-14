include ../Makefile

APP_NAME=mcp_server
APP_ENV=prod

.PHONY: tidy test test.setup lint

tidy:
	go mod tidy

test.setup:
	@true

test:
	go test ./...

lint:
	go vet ./...
