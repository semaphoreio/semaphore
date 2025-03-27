-include ../../Makefile

export AWS_REGION ?= us-east-1

auth:
	aws configure set aws_access_key_id ${AWS_SA_ACCESS_KEY_ID}
	aws configure set aws_secret_access_key ${AWS_SA_SECRET_ACCESS_KEY}
	aws configure set region ${AWS_REGION}
	aws configure set output json

terraform.plan:
	terraform plan \
		-var="project_name=${GOOGLE_PROJECT_NAME}" \
		-var="branch=${CLOUD_TEST_ENV_PREFIX}" \
		-var="path_to_private_key=./cert.key" \
		-var="path_to_fullchain_cer=./cert.fullchain.cer" \

terraform.apply:
	terraform apply \
		-var="project_name=${GOOGLE_PROJECT_NAME}" \
		-var="branch=${CLOUD_TEST_ENV_PREFIX}" \
		-var="path_to_private_key=./cert.key" \
		-var="path_to_fullchain_cer=./cert.fullchain.cer" \
		-auto-approve

terraform.destroy:
	terraform destroy \
		-var="project_name=${GOOGLE_PROJECT_NAME}" \
		-var="branch=${CLOUD_TEST_ENV_PREFIX}" \
		-var="path_to_private_key=./cert.key" \
		-var="path_to_fullchain_cer=./cert.fullchain.cer" \
		-input=false \
		-auto-approve
