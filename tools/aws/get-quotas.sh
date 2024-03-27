#!/bin/zsh

setopt ERR_EXIT

# Prompt for service code, quota code, and AWS region
read -p "Enter the service code (e.g., 'ec2' for EC2): " SERVICE_CODE
read -p "Enter the quota code (e.g., 'L-1216C47A' for EC2 standard instances): " QUOTA_CODE
read -p "Enter the AWS region (e.g., 'us-west-2'): " AWS_REGION

# Role ARN to assume in each account is always OrganizationAccountAccessRole
ROLE_NAME="OrganizationAccountAccessRole"

# List all accounts in the organization and capture both ID and Name
ORG_ACCOUNTS=$(aws organizations list-accounts --query 'Accounts[*].[Id,Name]' --output text)

# Read each line containing account ID and Name
while read -r account_id account_name
do
    # Convert account name to lowercase and check if it contains "captain"
    if [[ "${account_name,,}" == *"captain"* ]]; then
        echo "Processing Account: $account_id ($account_name)"

        # Construct the role ARN for the current account
        ROLE_ARN="arn:aws:iam::$account_id:role/$ROLE_NAME"

        # Assume role in the account and capture the credentials
        CREDENTIALS=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name "session-$account_id")
        export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
        export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
        export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')

        # Set AWS Region
        export AWS_DEFAULT_REGION=$AWS_REGION

        # Get Quota Information
        echo "Quota Information for Account $account_id ($account_name):"
        aws service-quotas get-service-quota --service-code $SERVICE_CODE --quota-code $QUOTA_CODE --query 'Quota.{QuotaName:QuotaName,Value:Value}' --output table

        # Reset environment variables for the next iteration
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_DEFAULT_REGION
    fi
done <<< "$ORG_ACCOUNTS"
