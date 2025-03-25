include ../Makefile

APP_NAME=docs-v2
APP_ENV=prod

npm.dev:
	npm start

npm.test:
	npm run lint

npm.build:
	npm run build

test:
	docker run --rm -t -a stdout $(IMAGE) nginx -c /etc/nginx/nginx.conf -t

