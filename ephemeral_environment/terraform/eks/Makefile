-include ../../Makefile

export AWS_REGION ?= us-east-1

auth:
	aws configure set aws_access_key_id ${AWS_SA_ACCESS_KEY_ID}
	aws configure set aws_secret_access_key ${AWS_SA_SECRET_ACCESS_KEY}
	aws configure set region ${AWS_REGION}
	aws configure set output json

terraform.plan:
	terraform plan \
		-var="aws_region=${AWS_REGION}" \
		-var="cluster_name=${CLOUD_TEST_ENV_PREFIX}" \
		-var="domain=${DOMAIN}" \
		-var="route53_zone_id=${ZONE_ID}" \

terraform.apply:
	terraform apply \
		-var="aws_region=${AWS_REGION}" \
		-var="cluster_name=${CLOUD_TEST_ENV_PREFIX}" \
		-var="domain=${DOMAIN}" \
		-var="route53_zone_id=${ZONE_ID}" \
		-auto-approve

terraform.destroy:
	terraform destroy \
		-var="aws_region=${AWS_REGION}" \
		-var="cluster_name=${CLOUD_TEST_ENV_PREFIX}" \
		-var="domain=${DOMAIN}" \
		-var="route53_zone_id=${ZONE_ID}" \
		-input=false \
		-auto-approve
