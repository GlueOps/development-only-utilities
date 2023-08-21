#!/bin/bash
##
### Variables
##
set -e
echo -e "\n"
AWS_NUKE_VERSION=v2.24.1

[ "$(aws sts get-caller-identity --query Account --output text)" = "$(aws organizations describe-organization --query Organization.MasterAccountId --output text)" ] && echo -e "\e[32mTHIS IS THE ROOT ACCOUNT. PLEASE PROCEED\e[0m" || echo -e "\e[31mTHIS IS NOT THE ROOT ACCOUNT STOP IMMEDIATELY.\e[0m"
echo -e "\n"
echo "Please enter your AWS account name. It should start with glueops-captain (e.g. glueops-captain-laciudaddelgato):"
echo ""
read ACCOUNT_NAME
echo -e "\n"
echo "AWS Nuke Version: $AWS_NUKE_VERSION"
wget https://github.com/rebuy-de/aws-nuke/releases/download/$AWS_NUKE_VERSION/aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz && tar -xvf aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz && rm aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz && mv aws-nuke-$AWS_NUKE_VERSION-linux-amd64 aws-nuke
SUB_ACCOUNT_ID=$(aws organizations list-accounts --output json | jq -r --arg ACCOUNT_NAME "$ACCOUNT_NAME" '.Accounts[] | select(.Name==$ACCOUNT_NAME) | .Id')

cat << 'EOF' > nuke.yaml
account-blocklist:
- "0123456789" # Keep listing any accounts you want to ensure do NOT get touched. If you did this properly and are using IAM credentials that only have access to your sub account then this is less important and could be left with this default/invalid value

accounts:
  AWS_ACCOUNT_ID_TO_DESTROY: # This `12345678910` account ID will have most, if not all of it's resources DESTROYED. This will allow you to redeploy the glueops stack cleanly using the same sub account.
    presets:
      - common #these presets basically say exclude certain things, these are things we want to keep so we can easily provision again into this account later
  
presets:
  common:
    filters:
      IAMRole:
      - type: regex
        value: '.*OrganizationAccountAccessRole.*'
      IAMRolePolicyAttachment:
      - type: regex
        value: '.*OrganizationAccountAccessRole.*'
      OpsWorksUserProfile:
      - type: regex
        value: '.*OrganizationAccountAccessRole.*'



regions: #this regions list was last updated on April 2, 2022.
- global
- us-west-2

EOF


sed -i "s/AWS_ACCOUNT_ID_TO_DESTROY/${SUB_ACCOUNT_ID}/g" nuke.yaml


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


./aws-nuke -c nuke.yaml --no-dry-run --force

rm nuke.yaml
rm aws-nuke
