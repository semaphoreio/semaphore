#!/bin/bash
set -euo pipefail

IP=$1
DOMAIN=$2
PACKAGE_NAME=$3

echo "Using IP: $IP"
echo "Using DOMAIN: $DOMAIN"
echo "Installing chart: $PACKAGE_NAME"

# Install k3s and helm
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh
helm plugin install https://github.com/databus23/helm-diff --version 3.9.13 || true

# Install ambassador CRDs
kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml
kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system

#
# Create the GitHub app secret.
# Here, we assume this file was previously copied into the VM.
#
kubectl apply -f github-app-secret.yaml
kubectl apply -f bitbucket-app-secret.yaml
kubectl apply -f gitlab-app-secret.yaml

args=(
  "--set"
  "global.domain.ip=${IP}"
  "--set"
  "global.domain.name=${DOMAIN}"
  "--set"
  "ingress.className=traefik"
  "--set"
  "ingress.ssl.type=custom"
  "--set"
  "ingress.ssl.crt=$(cat cert.fullchain.cer | base64 -w 0)"
  "--set"
  "ingress.ssl.key=$(cat cert.key | base64 -w 0)"
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
)

#
# Generate diff of chart being applied
#
helm diff upgrade semaphore $PACKAGE_NAME --allow-unreleased "${args[@]}"

#
# Install chart
# Here, we assume the cert.fullchain.cer and cert.key files were previously copied into the VM
#
helm upgrade --install --debug semaphore $PACKAGE_NAME --timeout 20m "${args[@]}"
