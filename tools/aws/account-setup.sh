#!/bin/bash
##
### Variables
##
set -e
echo -e "\n"
[ "$(aws sts get-caller-identity --query Account --output text)" = "$(aws organizations describe-organization --query Organization.MasterAccountId --output text)" ] && echo -e "\e[32mTHIS IS THE ROOT ACCOUNT. PLEASE PROCEED\e[0m" || echo -e "\e[31mTHIS IS NOT THE ROOT ACCOUNT STOP IMMEDIATELY.\e[0m"
echo -e "\n"
echo "Please enter your AWS account name. It should start with glueops-captain (e.g. glueops-captain-laciudaddelgato):"
echo ""
read ACCOUNT_NAME
echo -e "\n"
SUB_ACCOUNT_ID=$(aws organizations list-accounts --output json | jq -r --arg ACCOUNT_NAME "$ACCOUNT_NAME" '.Accounts[] | select(.Name==$ACCOUNT_NAME) | .Id')
IAM_USER_NAME="dev-deployment-svc-account"
IAM_ROLE_NAME="captain-role"
IAM_POLICY_ARN="arn:aws:iam::aws:policy/AdministratorAccess"
##
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
##
### Create IAM user in the sub-account
aws iam create-user --user-name $IAM_USER_NAME > /dev/null
#
### Attach AdministratorAccess policy to the IAM user
aws iam attach-user-policy --user-name $IAM_USER_NAME --policy-arn $IAM_POLICY_ARN
##
### Create access keys for the IAM user
userKeys=$(aws iam create-access-key --user-name $IAM_USER_NAME --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
accessKey=$(echo $userKeys | awk '{print $1}')
secretKey=$(echo $userKeys | awk '{print $2}')
##
### Create IAM role with AdministratorAccess policy in the sub-account
assumeRolePolicyDocument='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"'arn:aws:iam::$SUB_ACCOUNT_ID:root'"},"Action":"sts:AssumeRole"}]}'
##
aws iam create-role --role-name $IAM_ROLE_NAME --assume-role-policy-document "$assumeRolePolicyDocument" > /dev/null
##
### Attach AdministratorAccess policy to the IAM role
#aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn $IAM_POLICY_ARN
##
ARN_OF_ROLE_CREATED=$(aws iam get-role --role-name $IAM_ROLE_NAME --query 'Role.Arn' --output text)
#
#
#
#
echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
##
echo "Run the following in your codespace environment:"
echo -e "\n\n"
GREEN=$'\033[32m'
RESET=$'\033[0m'

cat << EOF
${GREEN}Run the following in your codespace environment:${RESET}

cat <<ENV >> \$(pwd)/.env
export AWS_ACCESS_KEY_ID=${accessKey}
export AWS_SECRET_ACCESS_KEY=${secretKey}
export AWS_DEFAULT_REGION=us-west-2
ENV

${GREEN}Here is the role you will want to specify in your terraform module:${RESET}

${ARN_OF_ROLE_CREATED}
EOF
