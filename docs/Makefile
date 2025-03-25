include ../Makefile

APP_NAME=docs-v2

dev:
	npm start

test:
	npm run lint

npm.build:
	npm run build

image.build:
	npm run clear
	npm run build
	docker build -t semaphore-docs:latest .

image.run:
	docker run -it -p 3000:80 semaphore-docs:latest

configure.gcloud:
	gcloud auth activate-service-account $(GCP_REGISTRY_WRITER_EMAIL) --key-file ~/gce-registry-writer-key.json
	gcloud --quiet auth configure-docker

build:
	docker build --cache-from $(IMAGE):latest -t $(IMAGE) . -f Dockerfile

test:
	docker run --rm -t -a stdout $(IMAGE) nginx -c /etc/nginx/nginx.conf -t

push:
	docker tag $(IMAGE):latest $(IMAGE):$(IMAGE_TAG)
	docker push $(IMAGE):$(IMAGE_TAG)
	docker push $(IMAGE):latest
