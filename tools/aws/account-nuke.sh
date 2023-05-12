#!/bin/bash
##
### Variables
##
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


##SUB_ACCOUNT_ID="<SubAccountID>"
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
export AWS_DEFAULT_REGION=us-west-2



./aws-nuke -c aws-nuke.yaml.tpl

rm nuke.yaml