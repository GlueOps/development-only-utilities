#!/bin/bash


# Save the current AWS environment variables

ORIGINAL_AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN
ORIGINAL_AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
ORIGINAL_AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

### Function to display the credentials
display_credentials() {
    GREEN=$'\033[32m'
    RESET=$'\033[0m'
    
cat << EOF
${GREEN}Run the following in your codespace environment to create your .env for $ACCOUNT_NAME:${RESET}

cat <<ENV >> \$(pwd)/.env
export AWS_ACCESS_KEY_ID=${accessKey}
export AWS_SECRET_ACCESS_KEY=${secretKey}
export AWS_DEFAULT_REGION=us-west-2
#aws eks update-kubeconfig --region us-west-2 --name captain-cluster --role-arn ${ARN_OF_ROLE_CREATED}
ENV

${GREEN}Here is the iam_role_to_assume that you will need to specify in your terraform module for $ACCOUNT_NAME:${RESET}

${ARN_OF_ROLE_CREATED}
EOF
}

### Function to create credentials for an account
create_credentials_for_account() {
    echo -e "\n"
    ROOT_ACCOUNT_ID=$(aws organizations describe-organization --query Organization.MasterAccountId --output text)
    CURRENT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

    if [ "$CURRENT_ACCOUNT_ID" != "$ROOT_ACCOUNT_ID" ]; then
        echo -e "\e[31mTHIS IS NOT THE ROOT ACCOUNT. EXITING.\n\n\e[0m"
        exit 1
    fi

    echo -e "\n"
    echo "Please enter your AWS account name. It should start with glueops-captain (e.g. glueops-captain-laciudaddelgato):"
    echo ""
    read ACCOUNT_NAME
    SUB_ACCOUNT_ID=$(aws organizations list-accounts --output json | jq -r --arg ACCOUNT_NAME "$ACCOUNT_NAME" '.Accounts[] | select(.Name==$ACCOUNT_NAME) | .Id')
    IAM_USER_NAME="dev-deployment-svc-account"
    IAM_ROLE_NAME="glueops-captain-role"
    IAM_POLICY_ARN="arn:aws:iam::aws:policy/AdministratorAccess"

    assumeRole=$(aws sts assume-role --role-arn "arn:aws:iam::$SUB_ACCOUNT_ID:role/OrganizationAccountAccessRole" --role-session-name "SubAccountAccess")
    sessionToken=$(echo $assumeRole | jq -r .Credentials.SessionToken)
    accessKeyId=$(echo $assumeRole | jq -r .Credentials.AccessKeyId)
    secretAccessKey=$(echo $assumeRole | jq -r .Credentials.SecretAccessKey)

    export AWS_SESSION_TOKEN=$sessionToken
    export AWS_ACCESS_KEY_ID=$accessKeyId
    export AWS_SECRET_ACCESS_KEY=$secretAccessKey

    aws iam create-user --user-name $IAM_USER_NAME > /dev/null
    aws iam attach-user-policy --user-name $IAM_USER_NAME --policy-arn $IAM_POLICY_ARN

    userKeys=$(aws iam create-access-key --user-name $IAM_USER_NAME --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
    accessKey=$(echo $userKeys | awk '{print $1}')
    secretKey=$(echo $userKeys | awk '{print $2}')

    assumeRolePolicyDocument='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"'arn:aws:iam::$SUB_ACCOUNT_ID:root'"},"Action":"sts:AssumeRole"}]}'
    aws iam create-role --role-name $IAM_ROLE_NAME --assume-role-policy-document "$assumeRolePolicyDocument" > /dev/null
    aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn $IAM_POLICY_ARN

    ARN_OF_ROLE_CREATED=$(aws iam get-role --role-name $IAM_ROLE_NAME --query 'Role.Arn' --output text)

    # Display the credentials based on the format
    display_credentials $1
}

set -e

# Call function for first account with 'first' format
create_credentials_for_account first

export AWS_SESSION_TOKEN=$ORIGINAL_AWS_SESSION_TOKEN
export AWS_ACCESS_KEY_ID=$ORIGINAL_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$ORIGINAL_AWS_SECRET_ACCESS_KEY

