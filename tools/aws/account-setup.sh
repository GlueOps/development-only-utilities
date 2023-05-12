#!/bin/bash
##
### Variables
##
SUB_ACCOUNT_ID=$(aws organizations list-accounts --output json | jq -r --arg ACCOUNT_NAME "$ACCOUNT_NAME" '.Accounts[] | select(.Name==$ACCOUNT_NAME) | .Id')
sed -i 's/AWS_ACCOUNT_ID_TO_DESTROY/$SUB_ACCOUNT_ID/g' nuke.yaml
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
aws iam create-user --user-name $IAM_USER_NAME
#
### Attach AdministratorAccess policy to the IAM user
aws iam attach-user-policy --user-name $IAM_USER_NAME --policy-arn $IAM_POLICY_ARN
##
### Create access keys for the IAM user
userKeys=$(aws iam create-access-key --user-name $IAM_USER_NAME --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
accessKey=$(echo $userKeys | awk '{print $1}')
secretKey=$(echo $userKeys | awk '{print $2}')
##
echo "Access Key: $accessKey"
echo "Secret Key: $secretKey"
##
### Create IAM role with AdministratorAccess policy in the sub-account
assumeRolePolicyDocument='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"'arn:aws:iam::$SUB_ACCOUNT_ID:root'"},"Action":"sts:AssumeRole"}]}'
##
aws iam create-role --role-name $IAM_ROLE_NAME --assume-role-policy-document "$assumeRolePolicyDocument"
##
### Attach AdministratorAccess policy to the IAM role
#aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn $IAM_POLICY_ARN
##
echo "IAM Role: $IAM_ROLE_NAME created with AdministratorAccess policy."
##
ARN_OF_ROLE_CREATED=$(aws iam get-role --role-name $IAM_ROLE_NAME --query 'Role.Arn' --output text)
#
#
#
#
echo "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
echo "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
echo "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
echo "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
echo "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
##
echo "Run the following exports into your codespace environment (save them for future use):"
echo "\n\n"
echo "export AWS_ACCESS_KEY_ID=$accessKey"
echo "export AWS_SECRET_ACCESS_KEY=$secretKey"
echo "export AWS_DEFAULT_REGION=us-west-2"
#
echo "\n\n"
echo "Here is the role you will want to assume in terraform (save for future use):"
echo "$ARN_OF_ROLE_CREATED"
#
