#!/bin/bash
set -euo pipefail

#
# Download required artifacts for terraform
#
artifact pull project "environments/${CLOUD_TEST_ENV_PREFIX}/terraform.tfstate" -d terraform.tfstate || true
artifact pull project "certs/${CLOUD_TEST_ENV_PREFIX}/${CLOUD_TEST_ENV_PREFIX}.key" -d cert.key || { echo "Failed to pull certificate key file; please generate certificates"; exit 1; }
artifact pull project "certs/${CLOUD_TEST_ENV_PREFIX}/${CLOUD_TEST_ENV_PREFIX}.fullchain.cer" -d cert.fullchain.cer || { echo "Failed to pull certificate key file; please generate certificates"; exit 1; }

#
# If we are using GKE, we don't need to create a SSH key
#
if [[ "$CLOUD_TEST_ENVIRONMENT_TYPE" == "gke" ]]; then
  exit 0
fi

if [[ "${CLOUD_TEST_ENVIRONMENT_TYPE}" == "single-vm" ]]; then
  path="/tmp/ssh-key"
  artifact pull project environments/${CLOUD_TEST_ENV_PREFIX}/private-ssh-key -d "$path" || true

  if [ ! -f "$path" ]; then
    echo "SSH key not found, creating one"
    ssh-keygen -b 2048 -t rsa -m PEM -N "" -f "$path"
    artifact push project "$path" -d environments/${CLOUD_TEST_ENV_PREFIX}/private-ssh-key
    artifact push project "$path.pub" -d environments/${CLOUD_TEST_ENV_PREFIX}/private-ssh-key.pub
    exit 0
  else
    echo "SSH key found, downloading public key"
    artifact pull project environments/${CLOUD_TEST_ENV_PREFIX}/private-ssh-key.pub -d "$path.pub"
    exit 0
  fi
fi

#
# Unknown environment type
#
echo "Unknown environment type: ${CLOUD_TEST_ENVIRONMENT_TYPE}"
exit 1
