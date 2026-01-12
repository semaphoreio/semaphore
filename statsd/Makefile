include ../Makefile

APP_NAME=statsd
APP_ENV=prod

test.js: build
	docker run --rm -v $(PWD)/test:/app/test $(IMAGE):$(IMAGE_TAG) sh -c "npm test"

test: test.js
