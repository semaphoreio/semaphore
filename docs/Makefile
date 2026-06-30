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

#
# Node image used to run the docs dev server in a container.
# Matches the builder stage in Dockerfile so deps resolve identically.
#
DOCS_NODE_IMAGE?=node:25.1
DOCS_PORT?=3000

#
# Run the Docusaurus live-reload dev server inside a throwaway container.
# - source is bind-mounted so edits to docs/ hot-reload in the browser
# - node_modules lives in an anonymous volume, so nothing is installed on the host
# - --host 0.0.0.0 exposes the server through the published port
# - --poll makes file-watching work across the macOS bind mount
#
# Open http://localhost:$(DOCS_PORT) once it has compiled.
#
dev.server:
	docker run --rm -it \
		--name semaphore-docs \
		-v $(PWD):/app \
		-v /app/node_modules \
		-w /app \
		-p $(DOCS_PORT):3000 \
		$(DOCS_NODE_IMAGE) \
		bash -c "npm install && npm start -- --host 0.0.0.0 --poll 1000"