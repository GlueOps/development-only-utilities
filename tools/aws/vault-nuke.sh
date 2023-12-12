#!/bin/bash

set -e
echo -e "\n"

[ "$(aws sts get-caller-identity --query Account --output text)" = "$(aws organizations describe-organization --query Organization.MasterAccountId --output text)" ] && echo -e "\e[32mTHIS IS THE ROOT ACCOUNT. PLEASE PROCEED\e[0m" || echo -e "\e[31mTHIS IS NOT THE ROOT ACCOUNT STOP IMMEDIATELY.\e[0m"
echo -e "\n"
echo "This script will delete your vault backups/data"
echo "Please enter your captain domain example: nonprod.earth.onglueops.rocks :"
echo ""
read CAPTAIN_DOMAIN
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

aws s3 rm s3://glueops-$TENANT_NAME-primary/$CAPTAIN_DOMAIN --recursive
