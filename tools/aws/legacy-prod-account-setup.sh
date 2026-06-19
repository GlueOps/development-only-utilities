#!/bin/bash
set -euo pipefail

###############################################################################
# Creates a deployment service account in the CURRENT AWS account.
#
# Run this while authenticated to the target account with Admin access.
# It does NOT assume into another account and does NOT touch AWS Organizations.
#
# It creates:
#   - IAM user: captain-deployment-svc-account  (plus a long-lived access key)
#   - IAM role: glueops-captain-role            (assumable by this account)
#   Both are granted AdministratorAccess.
#
# If either the user or the role already exists, the script exits immediately
# without making any changes.
###############################################################################

IAM_USER_NAME="captain-deployment-svc-account"
IAM_ROLE_NAME="glueops-captain-role"
IAM_POLICY_ARN="arn:aws:iam::aws:policy/AdministratorAccess"

GREEN=$'\033[32m'
RED=$'\033[31m'
RESET=$'\033[0m'

# --- Confirm we're authenticated and capture the current account ID ----------
if ! ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo -e "${RED}Could not determine the current AWS account. Are your credentials set?${RESET}"
    exit 1
fi

echo -e "\nOperating in account: ${GREEN}${ACCOUNT_ID}${RESET}\n"

# --- Exit immediately if the user or role already exists ---------------------
if aws iam get-user --user-name "$IAM_USER_NAME" >/dev/null 2>&1; then
    echo -e "${RED}User '$IAM_USER_NAME' already exists. Exiting.${RESET}"
    exit 1
fi

if aws iam get-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1; then
    echo -e "${RED}Role '$IAM_ROLE_NAME' already exists. Exiting.${RESET}"
    exit 1
fi

# --- IAM user ----------------------------------------------------------------
echo "Creating user '$IAM_USER_NAME'..."
aws iam create-user --user-name "$IAM_USER_NAME" >/dev/null
aws iam attach-user-policy --user-name "$IAM_USER_NAME" --policy-arn "$IAM_POLICY_ARN"

echo "Creating an access key for '$IAM_USER_NAME'..."
userKeys=$(aws iam create-access-key --user-name "$IAM_USER_NAME" \
    --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
accessKey=$(echo "$userKeys" | awk '{print $1}')
secretKey=$(echo "$userKeys" | awk '{print $2}')

# --- IAM role ----------------------------------------------------------------
# Trust policy lets principals in THIS account assume the role.
assumeRolePolicyDocument=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::${ACCOUNT_ID}:root" },
      "Action": "sts:AssumeRole"
    }
  ]
}
JSON
)

echo "Creating role '$IAM_ROLE_NAME'..."
aws iam create-role --role-name "$IAM_ROLE_NAME" \
    --assume-role-policy-document "$assumeRolePolicyDocument" >/dev/null
aws iam attach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn "$IAM_POLICY_ARN"

ARN_OF_ROLE_CREATED=$(aws iam get-role --role-name "$IAM_ROLE_NAME" --query 'Role.Arn' --output text)

# --- Output ------------------------------------------------------------------
cat <<EOF

export AWS_ACCESS_KEY_ID=${accessKey}
export AWS_SECRET_ACCESS_KEY=${secretKey}
export AWS_DEFAULT_REGION=us-west-2
#aws eks update-kubeconfig --region us-west-2 --name captain-cluster --role-arn ${ARN_OF_ROLE_CREATED}
EOF
