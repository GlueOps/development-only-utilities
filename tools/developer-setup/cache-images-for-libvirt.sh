#!/bin/bash

set -euo pipefail

OWNER="glueops"
REPO="codespaces"
PER_PAGE=1

DOWNLOAD_DIR="/opt/qcow2-image-cache"
mkdir -p "${DOWNLOAD_DIR}"

echo "Checking for new releases..."

# Fetch the latest releases in JSON form (no authentication needed).
releases_json="$(
  curl -sSf \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER}/${REPO}/releases?per_page=${PER_PAGE}"
)"

# Extract only the desired asset download URLs using jq.
# We're selecting only non-prerelease releases, then among their assets,
# only those with names containing "qcow2.tar".
asset_urls="$(
  echo "${releases_json}" | jq -r '
    .[]
    | select(.prerelease == false)
    | .assets[]
    | select(.name | contains("qcow2.tar"))
    | .browser_download_url
  '
)"

# Iterate over each URL (one per line).
for asset_url in ${asset_urls}; do
  filename="${asset_url##*/}"
  filename="${asset_url##*/}"
  image_name="${filename%%.qcow2.tar*}.qcow2"
  if [[ -f "${DOWNLOAD_DIR}/${image_name}" ]]; then
    echo "Image: ${image_name} exists in ${DOWNLOAD_DIR}. Skipping ${asset_url}"
    continue
  else
    echo "Image: ${image_name} does not exist in ${DOWNLOAD_DIR}."
  fi

  echo "Downloading ${filename}..."
  curl -sSfL -o "${DOWNLOAD_DIR}/${filename}" "${asset_url}"
  echo "Downloaded ${filename}"
done


release_tags="$(
  echo "${releases_json}" | jq -r '
    .[]
    | select(.prerelease == false)
    | .tag_name
  '
)"

# Loop over each non-prerelease release tag.
for release_tag in ${release_tags}; do
    if [[ -f "${DOWNLOAD_DIR}/${release_tag}.qcow2" ]]; then
      echo "Not extracting: ${release_tag}.qcow2 as it exists in: ${DOWNLOAD_DIR}."
      continue
  else
    echo "Image: ${release_tag}.qcow2 does not exist in ${DOWNLOAD_DIR} and will be extracted..."
    cat ${DOWNLOAD_DIR}/${release_tag}.qcow2.tar.part_* > ${DOWNLOAD_DIR}/${release_tag}.qcow2.tar
    tar -xvf ${DOWNLOAD_DIR}/${release_tag}.qcow2.tar -C ${DOWNLOAD_DIR}
    echo "Extracted ${release_tag}.qcow2"
  fi
done


rm -rf "${DOWNLOAD_DIR}"/*.qcow2.*

# Clean up images that haven't been modified in the last 30 days.
# Use -mmin for minutes (e.g., 35 days * 24 hours/day * 60 minutes/hour = 93600 minutes)
find "${DOWNLOAD_DIR}" -name "*.qcow2" -type f -mmin +93600 -exec rm -f {} \;
echo "Cleaned up images not modified in the last 65 days."
echo "Finished caching recent qcow2 images"
