#!/bin/bash
##
### Variables
##
set -e
echo -e "\n"
AWS_NUKE_VERSION=v3.60.0

[ "$(aws sts get-caller-identity --query Account --output text)" = "$(aws organizations describe-organization --query Organization.MasterAccountId --output text)" ] && echo -e "\e[32mCHECKS PASSED. PLEASE PROCEED\e[0m" || echo -e "\e[31mYOU MUST RUN THIS FROM THE ROOT ORG ACCOUNT. STOP IMMEDIATELY.\e[0m"


# Check if the environment variable is set
if [ -z "$AWS_ACCOUNT_NAME_TO_NUKE" ]; then
  # If not set, prompt for the account name
  echo -e "\n"
  echo -e "\e[31mPlease enter your AWS account name. This account will have ALL of its resources destroyed! It should start with glueops-captain (e.g. glueops-captain-laciudaddelgato):\e[0m"
  echo ""
  read -p "Account Name: " AWS_ACCOUNT_NAME_TO_NUKE
  echo -e "\n"
fi

# Now AWS_ACCOUNT_NAME_TO_NUKE will contain the value (either from the environment or user input)
echo "The AWS account name to nuke is: $AWS_ACCOUNT_NAME_TO_NUKE"

ACCOUNT_NAME=$AWS_ACCOUNT_NAME_TO_NUKE
echo -e "\n"
wget https://github.com/ekristen/aws-nuke/releases/download/$AWS_NUKE_VERSION/aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz && tar -xvf aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz && rm aws-nuke-$AWS_NUKE_VERSION-linux-amd64.tar.gz
SUB_ACCOUNT_ID=$(aws organizations list-accounts --output json | jq -r --arg ACCOUNT_NAME "$ACCOUNT_NAME" '.Accounts[] | select(.Name==$ACCOUNT_NAME) | .Id')

cat << 'EOF' > nuke.yaml
blocklist:
- "0123456789" # Keep listing any accounts you want to ensure do NOT get touched. If you did this properly and are using IAM credentials that only have access to your sub account then this is less important and could be left with this default/invalid value

accounts:
  AWS_ACCOUNT_ID_TO_DESTROY: # This `12345678910` account ID will have most, if not all of it's resources DESTROYED. This will allow you to redeploy the glueops stack cleanly using the same sub account.
    presets:
      - common #these presets basically say exclude certain things, these are things we want to keep so we can easily provision again into this account later
      - sso
  
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
  sso:
    filters:
      IAMSAMLProvider:
      - type: "regex"
        value: "AWSSSO_.*_DO_NOT_DELETE"
      IAMRole:
      - type: "glob"
        value: "AWSReservedSSO_*"
      IAMRolePolicyAttachment:
      - type: "glob"
        value: "AWSReservedSSO_*"


regions: #this regions list was last updated on October 11, 2025. https://aws-nuke.ekristen.dev/features/enabled-regions/
- global
- us-west-2
- us-east-1


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



echo -e "\n\e[33m[START] Multi-Region Access Point Cleanup Phase\e[0m"

# 0. Safety Check: Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "\e[31mError: 'jq' is not installed. MRAP cleanup requires jq. Skipping.\e[0m"
else
    # 1. List MRAPs
    # We use '|| true' to ensure the script doesn't die if the API call flakes or returns 404
    # We route this specifically to us-west-2 to ensure we hit a valid control plane endpoint
    MRAP_NAMES=$(aws s3control list-multi-region-access-points --account-id "$SUB_ACCOUNT_ID" --region us-west-2 --query 'AccessPoints[].Name' --output text || true)

    if [ -z "$MRAP_NAMES" ]; then
        echo "No Multi-Region Access Points found."
    else
        for mrap_name in $MRAP_NAMES; do
            echo -e "\n\e[34mProcessing MRAP: $mrap_name\e[0m"

            # 2. Get Configuration (Which buckets are in which regions?)
            # Returns an empty JSON array [] if it fails, to prevent jq errors
            REGIONAL_DATA=$(aws s3control get-multi-region-access-point --account-id "$SUB_ACCOUNT_ID" --region us-west-2 --name "$mrap_name" --query 'AccessPoint.Regions' --output json || echo "[]")

            # 3. Iterate through each region attached to the MRAP
            echo "$REGIONAL_DATA" | jq -c '.[]' | while read -r row; do
                bucket_name=$(echo "$row" | jq -r '.Bucket')
                region_id=$(echo "$row" | jq -r '.Region')
                
                echo "Targeting bucket: $bucket_name in $region_id"

                # 4. Loop to delete ALL Versions (Handles >1000 items pagination)
                while true; do
                    # Fetch batch of versions (suppress errors if bucket is already gone)
                    versions=$(aws s3api list-object-versions --bucket "$bucket_name" --region "$region_id" --max-items 1000 --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null || echo "")
                    
                    # Check if empty (jq returns null or empty list)
                    count=$(echo "$versions" | jq '.Objects | length' 2>/dev/null || echo "0")
                    
                    if [ "$count" == "0" ] || [ "$versions" == "" ] || [ "$count" == "null" ]; then
                        break
                    fi

                    echo "  - Deleting batch of $count versions..."
                    aws s3api delete-objects --bucket "$bucket_name" --region "$region_id" --delete "$versions" >/dev/null 2>&1 || true
                done

                # 5. Loop to delete ALL Delete Markers (Handles >1000 items pagination)
                while true; do
                    markers=$(aws s3api list-object-versions --bucket "$bucket_name" --region "$region_id" --max-items 1000 --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null || echo "")
                    
                    count=$(echo "$markers" | jq '.Objects | length' 2>/dev/null || echo "0")
                    
                    if [ "$count" == "0" ] || [ "$markers" == "" ] || [ "$count" == "null" ]; then
                        break
                    fi

                    echo "  - Deleting batch of $count markers..."
                    aws s3api delete-objects --bucket "$bucket_name" --region "$region_id" --delete "$markers" >/dev/null 2>&1 || true
                done

                # 6. Delete the now-empty Bucket
                # We use || true because aws-nuke might have already deleted it
                aws s3 rb "s3://$bucket_name" --force --region "$region_id" 2>/dev/null || echo "    Bucket $bucket_name already deleted or not found."
            done

            # 7. Delete the MRAP Global Routing
            echo "Deleting MRAP Global Endpoint: $mrap_name"
            aws s3control delete-multi-region-access-point --account-id "$SUB_ACCOUNT_ID" --region us-west-2 --details "Name=$mrap_name" || echo "Warning: Failed to delete MRAP $mrap_name (may already be gone)"
        done
    fi
fi

echo -e "\e[32m[DONE] Multi-Region cleanup phase complete.\e[0m"

# AWS Nuke

./aws-nuke nuke -c nuke.yaml --max-wait-retries 200 --no-dry-run --force --log-level debug --log-full-timestamp true --log-caller true || true
./aws-nuke nuke -c nuke.yaml --max-wait-retries 200 --no-dry-run --force --log-level debug --log-full-timestamp true --log-caller true

rm nuke.yaml
rm aws-nuke
