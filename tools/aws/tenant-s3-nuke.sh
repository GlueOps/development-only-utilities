#!/bin/bash

set -e

if command -v jq >/dev/null 2>&1; then
    echo "Success: jq is installed and found in PATH."
    jq --version
else
    echo "Error: jq is not installed or not found in PATH."
    echo "Please install jq to use scripts that require it."
    # Exit with status 1 (failure)
    exit 1
fi


echo -e "\n"


[ "$(aws sts get-caller-identity --query Account --output text)" = "$(aws organizations describe-organization --query Organization.MasterAccountId --output text)" ] || (echo -e "\e[31mTHIS IS NOT THE ROOT ACCOUNT STOP IMMEDIATELY.\e[0m" && exit 1)

echo -e "\n"
echo -e "\e[31mTHIS SCRIPT WILL DELETE ALL YOUR BACKUPS FOR YOUR TENANT. This includes but isn't limited to loki backups and vault backups.\e[0m"
echo "Please enter your captain domain example: nonprod.earth.onglueops.rocks :"
echo ""

# Check if the variable is undefined or empty
if [ -z "$CAPTAIN_DOMAIN_TO_NUKE" ]; then
    read -p "CAPTAIN_DOMAIN_TO_NUKE is undefined. Please enter the captain domain to nuke: " CAPTAIN_DOMAIN_TO_NUKE
fi

# Optional: If you want to confirm the value after prompt
echo "You entered: $CAPTAIN_DOMAIN_TO_NUKE"

CAPTAIN_DOMAIN=$CAPTAIN_DOMAIN_TO_NUKE
IFS='.' read -ra ADDR <<< "$CAPTAIN_DOMAIN"

# Assign each part to a specific variable
ENVIRONMENT_NAME=${ADDR[0]}
TENANT_NAME=${ADDR[1]}

ACCOUNT_NAME="tenant-$TENANT_NAME"
SUB_ACCOUNT_ID=$(aws organizations list-accounts --output json | jq -r --arg ACCOUNT_NAME "$ACCOUNT_NAME" '.Accounts[] | select(.Name==$ACCOUNT_NAME) | .Id')


### Assume role in the sub-account
assumeRole=$(aws sts assume-role --role-arn "arn:aws:iam::$SUB_ACCOUNT_ID:role/OrganizationAccountAccessRole" --role-session-name "SubAccountAccess")
##
### Extract credentials
sessionToken=$(echo $assumeRole | jq -r .Credentials.SessionToken)
accessKeyId=$(echo $assumeRole | jq -r .Credentials.AccessKeyId)
secretAccessKey=$(echo $assumeRole | jq -r .Credentials.SecretAccessKey)
expiration=$(echo $assumeRole | jq -r .Credentials.Expiration)
##
### Set AWS CLI environment variables for sub-account
export AWS_SESSION_TOKEN=$sessionToken
export AWS_ACCESS_KEY_ID=$accessKeyId
export AWS_SECRET_ACCESS_KEY=$secretAccessKey
export AWS_DEFAULT_REGION=us-west-2

# Function to safely remove a specific S3 prefix from a given bucket.
# It first checks if the bucket exists before attempting deletion.
# Arguments:
#   --bucket <bucket_name>: The S3 bucket name (e.g., "my-bucket")
#   --prefix <prefix>: The S3 prefix within the bucket (e.g., "path/to/clean")
safe_s3_rm_bucket_prefix() {

set -e

  local s3_bucket=""
  local s3_prefix=""

  # Parse named arguments
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --bucket)
        s3_bucket="$2"
        shift # Shift past argument name
        shift # Shift past argument value
        ;;
      --prefix)
        s3_prefix="$2"
        shift # Shift past argument name
        shift # Shift past argument value
        ;;
      *)
        echo "Error: Unknown parameter passed: $1"
        return 1
        ;;
    esac
  done

  # --- Input validation ---
  if [[ -z "$s3_bucket" ]]; then
    echo "Error: --bucket is required but not provided to safe_s3_rm_bucket_prefix function."
    return 1
  fi

  # Prefix can be empty if deleting the whole bucket content,
  # so we don't make --prefix strictly mandatory here,
  # but the user must pass it explicitly if they intend to use it.
  # if [[ -z "$s3_prefix" ]]; then
  #   echo "Error: --prefix is required but not provided to safe_s3_rm_bucket_prefix function."
  #   return 1
  # fi
  # --- End validation ---

  # Construct the full S3 path for the remove command
  # Handle the case where prefix is empty correctly for the path string
  local s3_path_to_delete="s3://$s3_bucket"
  if [[ -n "$s3_prefix" ]]; then
      s3_path_to_delete="${s3_path_to_delete}/$s3_prefix"
  fi


  echo "Processing S3 path: '$s3_path_to_delete'"
  echo "Checking if S3 bucket '$s3_bucket' exists..."

  # Use head-bucket to check for bucket existence.
  # Redirect stdout and stderr to /dev/null to prevent noise.
  # The 'if' checks the exit status of the command.
  if aws s3api head-bucket --bucket "$s3_bucket" >/dev/null 2>&1; then
    echo "Bucket '$s3_bucket' exists."

    # Now attempt to remove the specified path within the existing bucket
    echo "Attempting to delete objects under '$s3_path_to_delete' recursively..."

    # Execute the remove command
    # Note: aws s3 rm handles deleting an empty prefix or non-existent objects gracefully
    if aws s3 rm "$s3_path_to_delete" --recursive; then
      echo "aws s3 rm command for '$s3_path_to_delete' finished successfully (path may have been empty)."
      return 0 # Indicate success
    else
      echo "Error running aws s3 rm command for '$s3_path_to_delete'."
      return 1 # Indicate failure
    fi

  else
    # The head-bucket command failed, meaning the bucket does not exist or is inaccessible
    echo "Bucket '$s3_bucket' does not exist or is not accessible. Skipping deletion of path '$s3_prefix'."
    return 0 # Consider skipping deletion not an error for the function's purpose here
  fi
}

# legacy buckets
safe_s3_rm_bucket_prefix --bucket "glueops-$ACCOUNT_NAME-primary" --prefix "$CAPTAIN_DOMAIN"
safe_s3_rm_bucket_prefix --bucket "glueops-$ACCOUNT_NAME-replica" --prefix "$CAPTAIN_DOMAIN"



# Get list of all bucket names (global call)
aws s3api list-buckets --query "Buckets[].Name" --output json | jq -r '.[]' | while read -r bucket_name; do
    # 1. Get the bucket's region
    BUCKET_LOCATION=$(aws s3api get-bucket-location --bucket "$bucket_name" --output json)
    BUCKET_REGION=$(echo "$BUCKET_LOCATION" | jq -r '.LocationConstraint')

    TAG_INFO=$(aws resourcegroupstaggingapi get-resources \
                  --resource-arn-list "arn:aws:s3:::${bucket_name}" \
                  --region "$BUCKET_REGION" \
                  --output json)

    # 3. Check if the required tag exists using jq
    # Outputs "1" if the tag is found, empty otherwise
    HAS_REQUIRED_TAG=$(echo "$TAG_INFO" | jq -r --arg key "tenant_name" --arg value "$TENANT_NAME" \
                         '.ResourceTagMappingList[].Tags[] | select(.Key == $key and .Value == $value) | "1"' | head -n 1)
                         
    if [ "$HAS_REQUIRED_TAG" == "1" ]; then
        safe_s3_rm_bucket_prefix --bucket ${bucket_name} --prefix "$CAPTAIN_DOMAIN"
    fi
done
