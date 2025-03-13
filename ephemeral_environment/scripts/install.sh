#!/bin/bash
set -euo pipefail

#
# Download required artifacts for installation
#
artifact pull project "environments/${CLOUD_TEST_ENV_PREFIX}/terraform.tfstate" -d terraform.tfstate
artifact pull project "certs/${CLOUD_TEST_ENV_PREFIX}/${CLOUD_TEST_ENV_PREFIX}.key" -d cert.key
artifact pull project "certs/${CLOUD_TEST_ENV_PREFIX}/${CLOUD_TEST_ENV_PREFIX}.fullchain.cer" -d cert.fullchain.cer
package_name=$(sem-context get chart_package_name)
artifact pull workflow $package_name

export CLUSTER_NAME=$(terraform output -raw cluster_name)
export IP=$(terraform output -raw external_ip_address)
export STATIC_IP_NAME=$(terraform output external_ip_name)
export CERT_NAME=$(terraform output ssl_cert_name)
export DOMAIN="${CLOUD_TEST_ENV_PREFIX}.test.sonprem.com"
export GITHUB_APP_PRIVATE_KEY_PATH=/home/semaphore/github_app_private_key

echo "Using IP: $IP"
echo "Using DOMAIN: $DOMAIN"

# Base args

# Set default edition to ce if not specified
SEMAPHORE_EDITION=${SEMAPHORE_EDITION:-ce}

args=(
  "--set"
  "global.rootUser.githubLogin=on-prem-tester"
  "--set"
  "global.githubApp.secretName=github-app"
  "--set"
  "global.bitbucketApp.secretName=bitbucket-app"
  "--set"
  "global.gitlabApp.secretName=gitlab-app"
  "--set"
  "global.telemetry.cron=* * * * *"
  "--set"
  "global.telemetry.endpoint=https://telemetry.sxmoon.com/ingest"
  "--set"
  "global.domain.name=${DOMAIN}"
  "--set"
  "ingress.ssl.certName=${CERT_NAME}"
  "--set"
  "global.edition=${SEMAPHORE_EDITION}"
)

# Provider-specific base args

if [ "$CLOUD_TEST_ENVIRONMENT_TYPE" = "eks" ]; then
  args+=(
    "--set"
    "ingress.className=alb"
    "--set"
    "ingress.ssl.type=alb"
  )
else
  args+=(
    "--set"
    "global.domain.ip=${IP}"
    "--set"
    "ingress.staticIpName=${STATIC_IP_NAME}"
    "--set"
    "ingress.ssl.type=google"
  )
fi

#
# Create Github app secret
#
cat > github-app-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: github-app
data:
  GITHUB_APPLICATION_NAME: $(echo -n $GITHUB_APP_NAME | base64)
  GITHUB_APPLICATION_ID: $(echo -n $GITHUB_APP_ID | base64)
  GITHUB_APPLICATION_CLIENT_ID: $(echo -n $GITHUB_OAUTH_CLIENT_ID | base64)
  GITHUB_APPLICATION_CLIENT_SECRET: $(echo -n $GITHUB_OAUTH_CLIENT_SECRET | base64)
  GITHUB_APPLICATION_PRIVATE_KEY: $(cat $GITHUB_APP_PRIVATE_KEY_PATH | base64 -w 0)
EOF

cat > bitbucket-app-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: bitbucket-app
data:
  BITBUCKET_APPLICATION_CLIENT_ID: $(echo -n $BITBUCKET_OAUTH_CLIENT_ID | base64 -w 0)
  BITBUCKET_APPLICATION_CLIENT_SECRET: $(echo -n $BITBUCKET_OAUTH_CLIENT_SECRET | base64 -w 0)
EOF

cat > gitlab-app-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-app
data:
  GITLAB_APPLICATION_CLIENT_ID: $(echo -n $GITLAB_OAUTH_CLIENT_ID | base64 -w 0)
  GITLAB_APPLICATION_CLIENT_SECRET: $(echo -n $GITLAB_OAUTH_CLIENT_SECRET | base64 -w 0)
EOF

if [[ "$CLOUD_TEST_ENVIRONMENT_TYPE" == "single-vm" ]]; then

  echo "Installing chart in VM"

  #
  # Download the private SSH key for the key
  # we attached to the instance, so we can copy files into it, and execute commands
  #
  artifact pull project "environments/${CLOUD_TEST_ENV_PREFIX}/private-ssh-key" -d private-ssh-key
  artifact pull project "environments/${CLOUD_TEST_ENV_PREFIX}/private-ssh-key.pub" -d private-ssh-key.pub
  chmod 400 private-ssh-key

  #
  # Copy necessary files into VM and execute install script
  #

  files=(
    "$package_name"
    "cert.fullchain.cer"
    "cert.key"
    "github-app-secret.yaml"
    "bitbucket-app-secret.yaml"
    "gitlab-app-secret.yaml"
    "vm-install.sh"
  )

  for file in "${files[@]}"; do
    gcloud compute scp --ssh-key-file private-ssh-key "$file" "test-${CLOUD_TEST_ENV_PREFIX}:~/$file"
  done

  #
  # Execute installation script on the vm
  #
  gcloud compute ssh \
    --ssh-key-file private-ssh-key test-${CLOUD_TEST_ENV_PREFIX} \
    --command "SEMAPHORE_EDITION=${SEMAPHORE_EDITION} bash ~/vm-install.sh ${IP} ${DOMAIN} ${package_name}"

elif [[ "$CLOUD_TEST_ENVIRONMENT_TYPE" =~ ^(gke|eks)$ ]]; then
  if [[ "$CLOUD_TEST_ENVIRONMENT_TYPE" == "gke" ]]; then
    gcloud container clusters get-credentials ${CLUSTER_NAME} --region us-east4 --project ${GOOGLE_PROJECT_NAME}
  else
    aws eks update-kubeconfig --name ${CLUSTER_NAME} --region us-east-1
  fi

  echo "Installing chart in ${CLUSTER_NAME} cluster"

  #
  # Install ambassador CRDs and create the GitHub app secret
  #
  kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml
  kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system
  kubectl apply -f github-app-secret.yaml
  kubectl apply -f bitbucket-app-secret.yaml
  kubectl apply -f gitlab-app-secret.yaml

  #
  # Generate diff of chart being applied
  #
  helm plugin install https://github.com/databus23/helm-diff --version 3.9.13
  helm diff upgrade semaphore $package_name --allow-unreleased "${args[@]}"

  #
  # Install chart
  #
  helm upgrade --install --debug semaphore $package_name --timeout 20m "${args[@]}"
fi
