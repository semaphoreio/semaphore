.PHONY: build dev test image.build image.run

BRANCH=$(shell echo "$(SEMAPHORE_GIT_BRANCH)" | sed 's/[^a-z]//g')
IMAGE="us.gcr.io/semaphore2-prod/docs-v2"
IMAGE_TAG="$(BRANCH)-$(SEMAPHORE_WORKFLOW_ID)-sha-$(SEMAPHORE_GIT_SHA)"

dev:
	npm start

test:
	npm run lint

build:
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

nginx.build: build
	docker build --cache-from $(IMAGE):latest -t $(IMAGE) . -f Dockerfile

nginx.test:
	docker run --rm -t -a stdout $(IMAGE) nginx -c /etc/nginx/nginx.conf -t

nginx.push:
	docker tag $(IMAGE):latest $(IMAGE):$(IMAGE_TAG)
	docker push $(IMAGE):$(IMAGE_TAG)
	docker push $(IMAGE):latest
