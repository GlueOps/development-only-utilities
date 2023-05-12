# Example Usage

## Setup AWS Account

```bash
export ACCOUNT_NAME=glueops-captain-sandiego && export GLUEOPS_LATEST_DEV_ONLY_UTILS_SHA=$(curl -s https://api.github.com/repos/glueops/development-only-utilities/commits/aws | jq -r '.sha'); curl https://raw.githubusercontent.com/GlueOps/development-only-utilities/${GLUEOPS_LATEST_DEV_ONLY_UTILS_SHA}/tools/aws/account-setup.sh | bash
```

## Nuke/Destroy AWS Account

```bash
export ACCOUNT_NAME=glueops-captain-sandiego && export GLUEOPS_LATEST_DEV_ONLY_UTILS_SHA=$(curl -s https://api.github.com/repos/glueops/development-only-utilities/commits/aws | jq -r '.sha'); curl https://raw.githubusercontent.com/GlueOps/development-only-utilities/${GLUEOPS_LATEST_DEV_ONLY_UTILS_SHA}/tools/aws/account-nuke.sh | bash
```
