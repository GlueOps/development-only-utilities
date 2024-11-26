#!/bin/bash


if [ -z "$TAG" ]; then
  echo ""
  echo "TAG environment variable is required"
  echo "e.g. export TAG=v1.0.0"
  echo ""
  exit 1
fi

# Replace these variables with your repository details
owner="GlueOps"
repo="codespaces"

if [ -f "$TAG.qcow2" ]; then
  echo "File $TAG.qcow2.tar already exists. Skipping download."
  echo "Cleaning up any files"
  rm -rf $TAG.qcow2.tar*
else
  # Capture the start time
  start_time=$(date +%s)

  # Get the release ID for the specified tag
  release_id=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/tags/$TAG" | jq -r '.id')

  # Get the asset download URLs
  asset_urls=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/$release_id/assets" | jq -r '.[].browser_download_url')

  # Download each asset in parallel
  for url in $asset_urls; do
    echo "Downloading $url"
    curl -L -O "$url" &
  done

  # Wait for all background jobs to complete
  wait

  # Calculate and display elapsed time
  end_time=$(date +%s)
  elapsed_time=$((end_time - start_time))
  echo "Total time taken: $elapsed_time seconds"


  cat $TAG.qcow2.tar.part_* > $TAG.qcow2.tar
  tar -xvf $TAG.qcow2.tar
  echo "Deleting downloaded .tar files"
  rm -rf $TAG.qcow2.tar*
fi
