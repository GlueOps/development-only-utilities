# Example Usage

## Setup AWS Account

- Login to AWS (Root/Master Organization)
- Open [CloudShell](https://us-east-1.console.aws.amazon.com/cloudshell/home?region=us-west-2)

```bash
bash <(curl -s https://raw.githubusercontent.com/GlueOps/development-only-utilities/aws/tools/aws/account-nuke.sh)
```

## Nuke/Destroy AWS Account (CLOUD SHELL)

- Login to AWS (Root/Master Organization)
- Open [CloudShell](https://us-east-1.console.aws.amazon.com/cloudshell/home?region=us-west-2)

```bash
bash <(curl -s https://raw.githubusercontent.com/GlueOps/development-only-utilities/aws/tools/aws/account-nuke.sh)
```

## Get EKS Kube Config (GitHub Codespace)

- You must have the AWS Sub Account credentials set in your environment

```bash
aws eks update-kubeconfig --region us-west-2 --name captain-cluster
```
