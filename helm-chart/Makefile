include ../Makefile

helm.create:
	./scripts/prepare-chart.sh $(VERSION)
	helm dependency build
	helm package .

helm.cleanup:
	rm -rf charts/
	rm -rf Chart.yaml
	rm -rf Chart.lock
	rm -rf values.yaml
	rm -rf *.tgz

helm.dep.build:
	helm dependency build

# Local testing

# Docker image name for helm testing
DOCKER_IMAGE := semaphore-helm-test

# Build the Docker image for helm testing
docker.build:
	docker build -t $(DOCKER_IMAGE) .

# Test CE version of helm chart
helm.test.ce: docker.build
	docker run --rm -v $(PWD)/..:/workspace \
		-w /workspace/helm-chart \
		$(DOCKER_IMAGE) -c "make helm.cleanup && \
		./scripts/prepare-chart.sh v0.0.0 && \
		helm dependency build && \
		helm template . \
			--set global.edition=ce \
			--set global.domain.name=test.semaphore.local \
			--set global.domain.ip=127.0.0.1 \
			--set ingress.ssl.type=custom \
			--set ingress.ssl.secretName=tls-test-secret"

# Test EE version of helm chart
helm.test.ee: docker.build
	docker run --rm -v $(PWD)/..:/workspace \
		-w /workspace/helm-chart \
		$(DOCKER_IMAGE) -c "make helm.cleanup && \
		./scripts/prepare-chart.sh v0.0.0 && \
		helm dependency build && \
		helm template . --debug \
			--set global.edition=ee \
			--set global.domain.name=test.semaphore.local \
			--set global.domain.ip=127.0.0.1 \
			--set ingress.ssl.type=custom \
			--set ingress.ssl.secretName=tls-test-secret"

# Test both CE and EE versions
helm.test.all: helm.test.ce helm.test.ee

helm.shell: docker.build
	docker run -it --rm -v $(PWD)/..:/workspace \
		-w /workspace/helm-chart \
		$(DOCKER_IMAGE) -c "bash"
