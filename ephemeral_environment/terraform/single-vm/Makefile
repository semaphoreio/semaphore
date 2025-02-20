-include ../../Makefile

export GOOGLE_APPLICATION_CREDENTIALS ?= /home/semaphore/creds.json

auth:
	gcloud config set project ${GOOGLE_PROJECT_NAME} --quiet
	gcloud auth login --cred-file=${GOOGLE_APPLICATION_CREDENTIALS}

terraform.plan:
	terraform plan \
		-var="project_name=${GOOGLE_PROJECT_NAME}" \
		-var="branch=${CLOUD_TEST_ENV_PREFIX}" \
		-var="public_ssh_key_path=/tmp/ssh-key.pub" 

terraform.apply:
	terraform apply \
		-var="project_name=${GOOGLE_PROJECT_NAME}" \
		-var="branch=${CLOUD_TEST_ENV_PREFIX}" \
		-var="public_ssh_key_path=/tmp/ssh-key.pub" \
		-auto-approve

terraform.destroy:
	terraform destroy \
		-var="project_name=${GOOGLE_PROJECT_NAME}" \
		-var="branch=${CLOUD_TEST_ENV_PREFIX}" \
		-var="public_ssh_key_path=/tmp/ssh-key.pub" \
		-input=false \
		-auto-approve
