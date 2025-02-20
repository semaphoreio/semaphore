#!/bin/sh

set -euo pipefail

echo "Waiting for Keycloak to be ready..."
until curl -s http://keycloak:9000/health | grep -q "\"status\": \"UP\""; do echo waiting for keycloak; sleep 5; done;
echo "Keycloak is ready. Running Terraform..."

echo "Initializing terraform state"
terraform init -migrate-state -backend-config="namespace=${KUBERNETES_NAMESPACE:-default}"

echo "Applying terraform state"
terraform apply -auto-approve
