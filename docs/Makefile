include ../Makefile

APP_NAME=docs-v2
APP_ENV?=prod

npm.dev:
	npm start

npm.lint:
	npm run lint

npm.build:
	npm run build

lint:
	docker run --rm -t -a stdout $(IMAGE):dev npm run lint

test:
	docker run --rm -t -a stdout $(IMAGE) nginx -c /etc/nginx/nginx.conf -t

