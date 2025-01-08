#!/bin/bash

set -e

if [ -z "$VM_NAME" ] || [ -z "$TAG" ]; then
  echo ""
  [ -z "$VM_NAME" ] && echo "VM_NAME environment variable is required" && echo "e.g. export VM_NAME=dinosaur-cat" && echo ""
  [ -z "$TAG" ] && echo "TAG environment variable is required" && echo "e.g. export TAG=v1.0.0" && echo ""
  exit 1
fi

# Replace these variables with your repository details
owner="GlueOps"
repo="codespaces"

DOWNLOAD_DIR="/opt/qcow2-image-cache"
mkdir -p "${DOWNLOAD_DIR}"

if [[ -f "${DOWNLOAD_DIR}/${TAG}.qcow2" ]]; then
  echo "Image: ${TAG}.qcow2 exists in ${DOWNLOAD_DIR}. Skipping ${asset_url}"
else
  LOCKFILE="/tmp/qcow2-image-download.lock"
  # Acquire an exclusive lock on file descriptor 200
  exec 200>"${LOCKFILE}"
  flock -x 200
  echo "Image: ${TAG}.qcow2 does not exist in ${DOWNLOAD_DIR}."

  start_time=$(date +%s)
  
  # Get the release ID for the specified tag
  release_id=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/tags/$TAG" | jq -r '.id')
  
  # Get the asset download URLs
  asset_urls=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/$release_id/assets" | jq -r '.[].browser_download_url')
  
  # Download each asset in parallel
  for url in $asset_urls; do
    filename=$(basename "$url")
    echo "Downloading $url"
    mkdir -p "/tmp/$VM_NAME"
    curl -L -o "/tmp/$VM_NAME/$filename" "$url" &
  done
  
  # Wait for all background jobs to complete
  wait

  # Calculate and display elapsed time
  end_time=$(date +%s)
  elapsed_time=$((end_time - start_time))
  echo "Total time taken: $elapsed_time seconds"
  
  
  cat /tmp/$VM_NAME/*.qcow2.tar.part_* > /tmp/$VM_NAME/$VM_NAME.qcow2.tar
  tar -xvf /tmp/$VM_NAME/$VM_NAME.qcow2.tar -C /tmp/$VM_NAME

  mv /tmp/$VM_NAME/*.qcow2 /opt/qcow2-image-cache/$TAG.qcow2
  rm -rf /tmp/$VM_NAME/
  rm -rf /tmp/$VM_NAME/*.qcow2.tar.*

  # Release the lock
  flock -u 200
  
fi

  echo "resizing /var/lib/libvirt/images/$VM_NAME.qcow2"
  cp ${DOWNLOAD_DIR}/${TAG}.qcow2 /var/lib/libvirt/images/$VM_NAME.qcow2
  qemu-img resize /var/lib/libvirt/images/$VM_NAME.qcow2 120G

  echo "Finished resizing"
  



