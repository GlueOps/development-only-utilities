#!/bin/bash

set -e

service_account_id="svc-glueops-captain"
# Generate a random project name
PROJECT_NAME_PREFIX="dev-glueops-captain"
RANDOM_SUFFIX_LENGTH=5

# Generate a random string of lowercase letters
RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z' | fold -w ${RANDOM_SUFFIX_LENGTH} | head -n 1)

# Concatenate the prefix and the random string
PROJECT_NAME="${PROJECT_NAME_PREFIX}-${RANDOM_SUFFIX}"
project_id=$PROJECT_NAME

gcloud projects create $project_id && \
gcloud config set project $project_id && \
gcloud alpha billing projects link $project_id --billing-account=$(gcloud alpha billing accounts list --format=json | jq '.[]."name"'  | tr -d '"' | awk -F'/' '{ print $2}') && \
gcloud services enable cloudresourcemanager.googleapis.com compute.googleapis.com && \
gcloud iam service-accounts create $service_account_id \
  --description="$service_account_id" \
  --display-name="$service_account_id" && \
gcloud projects add-iam-policy-binding $project_id \
  --member="serviceAccount:$service_account_id@$project_id.iam.gserviceaccount.com" \
  --role="roles/owner" && \
rm -f delete-these-creds.json
gcloud iam service-accounts keys create delete-these-creds.json \
  --iam-account=$service_account_id@$project_id.iam.gserviceaccount.com

creds=$(cat delete-these-creds.json | jq -c . )
rm -f delete-these-creds.json

GREEN=$'\033[32m'
RESET=$'\033[0m'

echo ""
echo ""
echo ""
echo ""
echo ""


cat << EOF
${GREEN}Run the following in your codespace environment to create your .env for $project_id:${RESET}

cat <<ENV >> \$(pwd)/.env
export GOOGLE_CREDENTIALS='${creds}'
echo \\\$GOOGLE_CREDENTIALS > temp_key_pipe_creds &
gcloud auth activate-service-account --key-file=temp_key_pipe_creds
rm -f temp_key_pipe_creds
#gcloud container clusters get-credentials captain --region us-central1 --project $project_id

### This command below will destroy everything. It disables billing first and then deletes the project.
### gcloud alpha billing projects unlink $project_id && gcloud projects delete $project_id

ENV

${GREEN}In your terraform you will want to use this project_id:${RESET}

$project_id

EOF
