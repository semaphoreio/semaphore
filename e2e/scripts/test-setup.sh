#
# This scripts connects to the Kubernetes cluster based on the environment type,
# and exports environment variables required for the tests to run.
#

if [[ "$CLOUD_TEST_ENVIRONMENT_TYPE" == "gke" ]]; then
    artifact pull project "environments/${CLOUD_TEST_ENV_PREFIX}/terraform.tfstate" -d terraform.tfstate
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    gcloud container clusters get-credentials ${CLUSTER_NAME} --region us-east4 --project ${GOOGLE_PROJECT_NAME}
    export SEMAPHORE_API_TOKEN=$(kubectl get secret semaphore-authentication -o jsonpath='{.data.ROOT_USER_TOKEN}' | base64 -d)
    export SEMAPHORE_USER_PASSWORD=$(kubectl get secret semaphore-authentication -o jsonpath='{.data.ROOT_USER_PASSWORD}' | base64 -d)
elif [[ "$CLOUD_TEST_ENVIRONMENT_TYPE" == "single-vm" ]]; then
    artifact pull project "environments/${CLOUD_TEST_ENV_PREFIX}/private-ssh-key" -d private-ssh-key
    artifact pull project "environments/${CLOUD_TEST_ENV_PREFIX}/private-ssh-key.pub" -d private-ssh-key.pub
    chmod 400 private-ssh-key
    export SEMAPHORE_API_TOKEN=$(gcloud compute ssh --ssh-key-file private-ssh-key test-${CLOUD_TEST_ENV_PREFIX} --command "kubectl get secret semaphore-authentication -o jsonpath='{.data.ROOT_USER_TOKEN}' | base64 -d")
    export SEMAPHORE_USER_PASSWORD=$(gcloud compute ssh --ssh-key-file private-ssh-key test-${CLOUD_TEST_ENV_PREFIX} --command "kubectl get secret semaphore-authentication -o jsonpath='{.data.ROOT_USER_PASSWORD}' | base64 -d")
else
    echo "Unknown environment type: ${CLOUD_TEST_ENVIRONMENT_TYPE}"
    exit 1
fi
