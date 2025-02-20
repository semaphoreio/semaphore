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
