#!/usr/bin/env python3

import boto3
import sys
import os
import operator
import urllib.parse # Import urllib.parse for URL encoding
from botocore.exceptions import NoCredentialsError, PartialCredentialsError, NoRegionError, ClientError

print("Fetching IAM resources with 'Name' tag, sorting, and including Console URLs...")
print("")

# --- Configuration ---
# Get region from environment variable or use a default
region = os.environ.get("AWS_DEFAULT_REGION")
if not region:
    region = os.environ.get("AWS_REGION")
if not region:
    region = "us-east-1" # Or set your preferred default region
    print(f"Warning: AWS_DEFAULT_REGION or AWS_REGION environment variable not set. Using default region: {region}", file=sys.stderr)

# Define header names and their order
COLUMN_ORDER = ['type', 'tag_name', 'aws_name', 'arn', 'console_url']
HEADER_NAMES = {
    'type': 'Type',
    'tag_name': 'Name (from Tag)',
    'aws_name': 'AWS Name',
    'arn': 'ARN',
    'console_url': 'Console URL'
}

# --- Helper Functions ---

def get_iam_client(region_name):
    """Initializes and returns an IAM boto3 client."""
    try:
        return boto3.client('iam', region_name=region_name)
    except (NoCredentialsError, PartialCredentialsError):
        print("Error: AWS credentials not found. Configure your credentials.", file=sys.stderr)
        sys.exit(1)
    except NoRegionError:
        print(f"Error: Region not specified. Please set AWS_REGION or use --region.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred creating IAM client: {e}", file=sys.stderr)
        sys.exit(1)


def get_tag_value(tags, key_name="Name"):
    """Finds a specific tag value in a list of tags."""
    if not tags:
        return ""
    for tag in tags:
        if tag.get('Key') == key_name:
            return tag.get('Value', "")
    return ""

def build_console_url(resource_type, region, resource_identifier):
    """Constructs the AWS console URL for a resource."""
    base_url = f"https://{region}.console.aws.amazon.com/iam/home#"
    if resource_type == 'user':
        # Users use the user name in the URL
        return f"{base_url}/users/{resource_identifier}"
    elif resource_type == 'role':
        # Roles use the role name in the URL
        return f"{base_url}/roles/{resource_identifier}"
    elif resource_type == 'policy':
         # Policies use the encoded ARN in the URL /details/ path
         # The resource_identifier passed for policies is the ARN
         policy_arn = resource_identifier
         encoded_arn = urllib.parse.quote(policy_arn, safe='') # URL encode the ARN
         return f"{base_url}/policies/details/{encoded_arn}"
         # Optional: add "?section=permissions" if you want that specific tab open by default
         # return f"{base_url}/policies/details/{encoded_arn}?section=permissions"
    return "" # Unknown type


# --- Main Logic (Same fetching part as before) ---

iam_client = get_iam_client(region)
all_resources = []

# --- Fetch IAM Users with Pagination ---
print("Fetching IAM Users...")
try:
    paginator = iam_client.get_paginator('list_users')
    for page in paginator.paginate():
        for user in page.get('Users', []):
            user_name = user.get('UserName')
            user_arn = user.get('Arn')

            tag_name = ""
            try:
                tag_response = iam_client.list_user_tags(UserName=user_name)
                tag_name = get_tag_value(tag_response.get('Tags'))
            except ClientError as e:
                 pass # Suppress like bash

            if tag_name:
                # Pass user_name as identifier
                console_url = build_console_url('user', region, user_name)
                all_resources.append({
                    "aws_name": user_name,
                    "tag_name": tag_name,
                    "type": "user",
                    "arn": user_arn,
                    "console_url": console_url
                })
except ClientError as e:
    print(f"Error fetching IAM users: {e}", file=sys.stderr)
except Exception as e:
    print(f"An unexpected error occurred while fetching users: {e}", file=sys.stderr)

print("Finished fetching IAM Users.")
print("")


# --- Fetch IAM Roles with Pagination ---
print("Fetching IAM Roles...")
try:
    paginator = iam_client.get_paginator('list_roles')
    for page in paginator.paginate():
        for role in page.get('Roles', []):
            role_name = role.get('RoleName')
            role_arn = role.get('Arn')

            tag_name = ""
            try:
                tag_response = iam_client.list_role_tags(RoleName=role_name)
                tag_name = get_tag_value(tag_response.get('Tags'))
            except ClientError as e:
                 pass # Suppress like bash

            if tag_name:
                # Pass role_name as identifier
                console_url = build_console_url('role', region, role_name)
                all_resources.append({
                    "aws_name": role_name,
                    "tag_name": tag_name,
                    "type": "role",
                    "arn": role_arn,
                    "console_url": console_url
                })
except ClientError as e:
    print(f"Error fetching IAM roles: {e}", file=sys.stderr)
except Exception as e:
    print(f"An unexpected error occurred while fetching roles: {e}", file=sys.stderr)


print("Finished fetching IAM Roles.")
print("")


# --- Fetch IAM Policies (Customer Managed) with Pagination ---
print("Fetching IAM Policies (Customer Managed)...")
try:
    paginator = iam_client.get_paginator('list_policies')
    for page in paginator.paginate(Scope='Local'):
        for policy in page.get('Policies', []):
            policy_name = policy.get('PolicyName')
            policy_arn = policy.get('Arn')

            tag_name = ""
            try:
                tag_response = iam_client.list_policy_tags(PolicyArn=policy_arn)
                tag_name = get_tag_value(tag_response.get('Tags'))
            except ClientError as e:
                 pass # Suppress like bash

            if tag_name:
                 # Pass policy_arn as identifier for building the URL
                 console_url = build_console_url('policy', region, policy_arn)
                 all_resources.append({
                     "aws_name": policy_name,
                     "tag_name": tag_name,
                     "type": "policy",
                     "arn": policy_arn,
                     "console_url": console_url
                 })
except ClientError as e:
    print(f"Error fetching IAM policies: {e}", file=sys.stderr)
except Exception as e:
    print(f"An unexpected error occurred while fetching policies: {e}", file=sys.stderr)

print("Finished fetching IAM Policies.")
print("")

# --- Sort and Print Results ---

# Sort the collected resources
# Sort primarily by 'type', and secondarily by 'tag_name'
all_resources.sort(key=operator.itemgetter('type', 'tag_name'))


# Calculate maximum width for each column based on data and headers
max_widths = {col: len(HEADER_NAMES[col]) for col in COLUMN_ORDER}

for resource in all_resources:
    for col in COLUMN_ORDER:
        # Use str() in case a field is unexpectedly not a string
        max_widths[col] = max(max_widths[col], len(str(resource.get(col, ''))))

# Add padding to widths for readability
padding = 2
padded_widths = {col: max_widths[col] + padding for col in COLUMN_ORDER}


# Print header
header_parts = []
separator_parts = []
for i, col_key in enumerate(COLUMN_ORDER):
    header_text = HEADER_NAMES[col_key]
    if i < len(COLUMN_ORDER) - 1: # Apply padding to all columns except the last one
        header_parts.append(f"{header_text:<{padded_widths[col_key]}}")
        separator_parts.append("-" * padded_widths[col_key])
    else: # Last column (Console URL)
        header_parts.append(header_text)
        # Separator for the last column - match header width or minimum 10
        separator_parts.append("-" * max(len(header_text), 10))


print(" | ".join(header_parts))
print("-|-".join(separator_parts))

# Print sorted data
for resource in all_resources:
    row_parts = []
    for i, col_key in enumerate(COLUMN_ORDER):
        value = str(resource.get(col_key, '')) # Ensure value is a string

        if i < len(COLUMN_ORDER) - 1: # Apply padding to all columns except the last one
             # Use calculated padded width
            row_parts.append(f"{value:<{padded_widths[col_key]}}")
        else: # Last column (Console URL)
            row_parts.append(value) # No padding needed, just print the value

    print(" | ".join(row_parts))


print("")
print(f"Done. Found {len(all_resources)} resources with the 'Name' tag.")
