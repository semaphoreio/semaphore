#!/bin/sh

set -euo pipefail

echo "Waiting for Keycloak to be ready..."
until curl -s http://keycloak:9000/health | grep -q "\"status\": \"UP\""; do echo waiting for keycloak; sleep 5; done;
echo "Keycloak is ready. Running Terraform..."

echo "Initializing terraform state"
terraform init -migrate-state -backend-config="namespace=${KUBERNETES_NAMESPACE:-default}"

if terraform providers | grep -q "mrparkers/keycloak"; then
  echo "Moving state from the archived mrparkers/keycloak provider"
  terraform state replace-provider -auto-approve mrparkers/keycloak keycloak/keycloak
fi

echo "Applying terraform state"
terraform apply -auto-approve
