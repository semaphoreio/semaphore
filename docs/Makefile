include ../Makefile

APP_NAME=docs-v2
APP_ENV?=dev

npm.dev:
	npm start

npm.lint:
	npm run lint

npm.build:
	npm run build

lint:
	docker run --rm -t -a stdout $(IMAGE):$(IMAGE_TAG) npm run lint

test:
	docker run --rm -t -a stdout $(IMAGE):$(IMAGE_TAG) nginx -c /etc/nginx/nginx.conf -t

