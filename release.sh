#!/bin/bash

git_organization="semaphoreio"
repo="${git_organization}/semaphore"

upload_asset() {
    if [ ! -f $2 ]; then
        echo "❌ File $2 does not exist, aborting..."
        exit 1
    fi

    asset=$(curl \
        --silent \
        -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: $(file -b --mime-type $2)" \
        --data-binary @$2 \
        "https://uploads.github.com/repos/${repo}/releases/$1/assets?name=$(basename $2)")
    if jq 'has("id")' <<< "$asset" | grep -q true; then
        echo "✅ Asset uploaded: $(basename $2)"
    else
        echo "❌ Asset upload failed: ${asset}, $(basename $2)"
        exit 1
    fi
}

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN is not set, aborting..."
    exit 1
fi

tag=$(git describe --exact-match --tags HEAD 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ This script must be run on a tagged commit, aborting..."
    exit 1
fi

#
# Creates a GitHub release,
# if one does not exist yet for the current tag.
#
echo "❕ Creating GitHub release for $tag"

echo "❕ Check for existing release..."
release=$(curl \
    --silent \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/${repo}/releases/tags/$tag)
if jq 'has("id")' <<< "$release" | grep -q true; then
    echo "❌ Release already exists, aborting..."
    exit 1
fi

echo "❕ Release does not exist yet, creating it..."
release=$(curl \
  --silent \
  -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${repo}/releases \
  -d '{"tag_name":"'$tag'"}')

if jq 'has("id")' <<< "$release" | grep -q true; then
    echo "✅ Release created: $release"
else
    echo "❌ Release creation failed, ${release}, aborting..."
    exit 1
fi

#
# Fetch assets from artifacts and upload them as assets for the release.
#
echo "❕ Fetching Helm chart from Semaphore artifact..."
package_name=$(sem-context get chart_package_name)
artifact pull workflow $package_name

release_id=$(jq -r '.id' <<< "$release")
echo "❕ Uploading release assets for release=${release_id}..."
upload_asset "${release_id}" $package_name
echo "✅ GitHub release created."

#
# Now, upload the Helm chart to GitHub Container Registry.
#
echo "❕ Uploading $package_name Helm chart to GitHub Container Registry..."
helm push $package_name oci://ghcr.io/${git_organization} &> /tmp/push-output.txt
cat /tmp/push-output.txt
echo "✅ Helm chart uploaded."

#
# Finally, sign Helm chart.
#
chart_name=$(echo "${package_name%.*}" | cut -d "-" -f1)
chart_version=$(echo "${package_name%.*}" | cut -d "-" -f2-)
chart_digest=$(cat /tmp/push-output.txt | grep "Digest: " | cut -d ":" -f3)
echo "❕ Signing Helm chart - name=${chart_name}, version=${chart_version}, digest=${chart_digest}..."

cosign sign -y \
    --identity-token $(cat /tmp/sigstore-token) \
    ghcr.io/${git_organization}/$chart_name@sha256:$chart_digest

echo "✅ Helm chart signed."
