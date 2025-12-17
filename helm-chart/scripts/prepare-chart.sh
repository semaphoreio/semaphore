#!/bin/bash

chart_version=$1

if [[ -z "${chart_version}" ]]; then
  if [[ -n "${SEMAPHORE_GIT_TAG_NAME}" ]]; then
    #
    # If SEMAPHORE_GIT_TAG_NAME is set, we know this is a stable release.
    # since this is running on a tag pipeline on Semaphore,
    # so we just use the tag name for the version.
    #
    chart_version=$SEMAPHORE_GIT_TAG_NAME
    echo "Stable release - ${chart_version}"
  else
    #
    # Otherwise, this is an unstable release.
    # Here, we bump the current version a minor version,
    # and use the '-unstable' suffix and the git SHA.
    #
    current_version=$(git tag | sort --version-sort | tail -n 1)
    next=$(echo $current_version | cut -c 2- | awk -F '.' '{ print "v" $1 "." $2 + 1 ".0" }')
    chart_version="${next}-unstable-$(git rev-parse HEAD | cut -c 1-8)"
    echo "Unstable release - ${chart_version}"
  fi
else
  echo "Manually created release: ${chart_version}"
fi

applications=(
  "APIv1alpha"
  "APIv2"
  "ArtifactHub"
  "Audit"
  "Auth"
  "Badge"
  "Bootstrapper"
  "BranchHub"
  "Dashboardhub"
  "Encryptor"
  "Front"
  "GithubNotifier"
  "Gofer"
  "Guard"
  "HooksProcessor"
  "HooksReceiver"
  "Keycloak image"
  "Keycloak setup"
  "PeriodicScheduler"
  "Loghub2"
  "GithubHooks"
  "MCP Server"
  "Notifications"
  "Plumber"
  "ProjectHub"
  "ProjectHub REST API"
  "PreFlightChecks"
  "RBAC CE"
  "RBAC EE"
  "PublicApiGateway"
  "Repohub"
  "RepositoryHub"
  "Scouter"
  "SecretHub"
  "Self Hosted Hub"
  "Statsd"
  "Velocity"
  "Zebra"
)

#
# Some applications do not have a Helm chart,
# since they are used as sidecar containers.
#
sidecars=(
  "Encryptor"
  "Statsd"
)

echo "> Preparing Helm chart for release..."
echo "> version=${chart_version}"
echo "> Generating Chart.yaml..."
cp Chart.yaml.in Chart.yaml.tmp
yq -i ".version = \"${chart_version}\"" Chart.yaml.tmp
yq -i "(.dependencies.[] | select(.name != \"emissary-ingress\" and .name != \"controller\") | .version) |= \"${chart_version}\"" Chart.yaml.tmp
mv Chart.yaml.tmp Chart.yaml

echo "> Generating values.yaml..."
cp values.yaml.in values.yaml.tmp

#
# Update the encryptor sidecar image tag
#
encryptor_image_tag=$(git rev-list -1 HEAD -- ../encryptor)
yq -i ".global.sidecarEncryptor.imageTag = \"${encryptor_image_tag}\"" values.yaml.tmp
echo "> Encryptor sidecar image tag: ${encryptor_image_tag}"

#
# Update the statsd sidecar image tag
#
statsd_image_tag=$(git rev-list -1 HEAD -- ../statsd)
yq -i ".global.statsd.imageTag = \"${statsd_image_tag}\"" values.yaml.tmp
echo "> Statsd sidecar image tag: ${statsd_image_tag}"

for application in "${applications[@]}"; do
  echo ">> Updating ${application}..."

  #
  # If this is an application used as a sidecar,
  # there's no need to generate any chart for it.
  #
  if printf '%s\n' "${sidecars[@]}" | grep -Fxq -- "${application}"; then
    echo ">>> ${application} is used as a sidecar - skipping chart generation for it..."
    continue
  fi

  path=$(jq -r ".services[\"${application}\"][][\"path\"]" ../.semaphore/services.json)
  component=$(jq -r ".services[\"${application}\"][][\"component\"]" ../.semaphore/services.json)

  p="../${path}/helm/Chart.yaml"
  cp "${p}.in" "${p}.tmp"
  yq -i ".version = \"${chart_version}\"" "${p}.tmp"
  mv "${p}.tmp" "${p}"

  image_tag=$(git rev-list -1 HEAD -- "../${path}")
  echo ">>> ${application} image tag: ${image_tag}"
  yq -i ".${component}.imageTag = \"${image_tag}\"" values.yaml.tmp
done

mv values.yaml.tmp values.yaml
echo "> Helm chart generated."
