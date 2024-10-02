import boto3

# Set the role name that you want to list for each account
ROLE_NAME = "OrganizationAccountAccessRole"

# Initialize AWS Organizations client
org_client = boto3.client('organizations')

def list_accounts():
    """Fetch all active accounts in the organization"""
    accounts = []
    paginator = org_client.get_paginator('list_accounts')
    for page in paginator.paginate():
        accounts.extend(page['Accounts'])
    return accounts

def main():
    # List all accounts in the organization
    accounts = list_accounts()

    # Iterate over each account and print details for active accounts only
    for account in accounts:
        account_name = account['Name']
        account_id = account['Id']
        account_status = account['Status']

        # Print only if account is active
        if account_status == "ACTIVE":
            print(f"[{account_name}]")
            print(f"role_name = {ROLE_NAME}")
            print(f"aws_account_id = {account_id}")
            print("\n")

if __name__ == "__main__":
    main()
