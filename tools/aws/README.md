# Example Usage

## Setup AWS Account

- Login to AWS (Root/Master Organization)
- Open [CloudShell](https://us-east-1.console.aws.amazon.com/cloudshell/home?region=us-west-2)

```bash
bash <(curl -s https://raw.githubusercontent.com/GlueOps/development-only-utilities/main/tools/aws/account-setup.sh)
```

## Nuke/Destroy AWS Account (CLOUD SHELL)

- Login to AWS (Root/Master Organization)
- Open [CloudShell](https://us-east-1.console.aws.amazon.com/cloudshell/home?region=us-west-2)

```bash
bash <(curl -s https://raw.githubusercontent.com/GlueOps/development-only-utilities/main/tools/aws/account-nuke.sh)
```

## Get EKS Kube Config (GitHub Codespace)

- You must have the AWS Sub Account credentials set in your environment

```bash
aws eks update-kubeconfig --region us-west-2 --name captain-cluster
```

## Get Quotas (CLOUD SHELL)

- Login to AWS (Root/Master Organization)
- Open [CloudShell](https://us-east-1.console.aws.amazon.com/cloudshell/home?region=us-west-2)

```bash
bash <(curl -s https://raw.githubusercontent.com/GlueOps/development-only-utilities/main/tools/aws/get-quotas.sh)
```

## Delete tenant data from S3

- Login to AWS (Root/Master Organization)
- Open [CloudShell](https://us-east-1.console.aws.amazon.com/cloudshell/home?region=us-west-2)

```bash
 bash <(curl -s https://raw.githubusercontent.com/GlueOps/development-only-utilities/main/tools/main/tenant-s3-nuke.sh)
```

## Create Chisel Exit Nodes using lightsail

- Login to AWS (Root/Master Organization)
- Assume role into desginated AWS Sub account for lightsail
- Select AWS Region to deploy exit nodes into
- Go to Lightsail page and launch cloud shell and run:

```bash
 bash <(curl -s https://raw.githubusercontent.com/GlueOps/development-only-utilities/main/tools/aws/lightsail.sh)
```
