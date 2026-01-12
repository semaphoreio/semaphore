include ../Makefile

APP_NAME=statsd
APP_ENV=prod

test.js: build
	mkdir -p out
	docker run --rm -v $(PWD)/test:/app/test -v $(PWD)/out:/app/out $(IMAGE):$(IMAGE_TAG) sh -c "npm test"

test: test.js
