# Getting Started Guide

## System Requirements

Before getting started, make sure your machine has the following tools installed:

| Tool       | Minimum Version      | Purpose                         |
| ---------- | -------------------- | ------------------------------- |
| Terraform  | >= 1.9               | IaC infrastructure management   |
| AWS CLI    | v2                   | Interact with AWS               |
| tflint     | latest               | Terraform error checking        |
| tfsec      | latest               | Terraform security scanning     |
| checkov    | latest               | Security and compliance scanning|
| git        | >= 2.30              | Source code management          |
| jq         | >= 1.6               | JSON processing on command line |

## Clone repository

```bash
git clone git@github.com:<GITHUB_ORG>/<GITHUB_REPO>.git
cd infra-ecs
```

## Install tools

### macOS (Homebrew)

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install awscli
brew install tflint
brew install tfsec
brew install checkov
brew install jq
brew install git
```

### Ubuntu / Debian (apt)

```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# checkov
pip install checkov

# jq & git
sudo apt install -y jq git
```

### Windows (Chocolatey)

```powershell
choco install terraform
choco install awscli
choco install tflint
choco install tfsec
pip install checkov
choco install jq
choco install git
```

## Configure AWS credentials

We recommend using **AWS SSO** instead of static access keys.

```bash
# Configure SSO profile
aws configure sso
# SSO session name: infra-ecs
# SSO start URL: https://<DOMAIN>.awsapps.com/start
# SSO Region: ap-southeast-1
# Select the appropriate account and role

# Log in via SSO
aws sso login --profile dev

# Verify
aws sts get-caller-identity --profile dev
```

If not using SSO, configure credentials the traditional way:

```bash
aws configure --profile dev
# Enter AWS Access Key ID, Secret Access Key, Region, Output format
```

## Required values before deploying

Before deploying, you **must** replace all placeholders in the codebase with actual values. Full list of placeholders:

| Placeholder              | Description                                     | Example                            |
| ------------------------ | ----------------------------------------------- | ---------------------------------- |
| `<ACCOUNT_ID_DEV>`      | AWS Account ID for the dev environment          | `123456789012`                     |
| `<ACCOUNT_ID_STAGING>`  | AWS Account ID for the staging environment      | `234567890123`                     |
| `<ACCOUNT_ID_PROD>`     | AWS Account ID for the production environment   | `345678901234`                     |
| `<DOMAIN>`              | Main domain name of the project                 | `mycompany.com`                    |
| `<ALERT_EMAIL>`         | Email to receive system alerts                  | `ops-team@mycompany.com`           |
| `<SLACK_WEBHOOK_URL>`   | Slack Webhook URL for sending notifications     | `https://hooks.slack.com/...`      |
| `<GITHUB_ORG>`          | GitHub organization name                        | `my-org`                           |
| `<GITHUB_REPO>`         | GitHub repository name                          | `infra-ecs`                        |
| `<COST_CENTER>`         | Cost center code for tagging                    | `engineering-platform`             |
| `<OWNER>`               | Person / team responsible for the resource      | `platform-team`                    |

Use the following command to find all unreplaced placeholders:

```bash
grep -r '<[A-Z_]*>' terraform/ .github/
```

> **Note:** Do not commit actual values of sensitive placeholders (account ID, webhook URL) into the repository. Use `terraform.tfvars` (already in `.gitignore`) or environment variables.

## First-time state bootstrap

When deploying for the first time, you need to initialize the S3 backend to store Terraform state:

```bash
./scripts/bootstrap.sh dev
```

This script will create:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- Encryption and versioning configuration

## Deploy the dev environment

After bootstrap is complete, proceed with deployment:

```bash
cd terraform/envs/dev

# Initialize Terraform (download providers and modules)
terraform init

# Preview changes
terraform plan

# Apply changes (type "yes" when prompted)
terraform apply
```

## Verify successful deployment

After `terraform apply` completes, verify the results:

### 1. Check terraform output

```bash
terraform output
```

You should see outputs such as ALB DNS name, ECS cluster name, RDS endpoint, etc.

### 2. Verify on AWS Console

- **ECS**: Go to ECS Console > Clusters, confirm the cluster has been created and the service is running.
- **ALB**: Go to EC2 Console > Load Balancers, confirm the ALB is healthy.
- **RDS**: Go to RDS Console, confirm the database instance is in "Available" status.
- **VPC**: Go to VPC Console, confirm the VPC, subnets, and security groups have been created.

### 3. Check health check

```bash
# Get ALB DNS from terraform output
ALB_DNS=$(terraform output -raw alb_dns_name)

# Check health endpoint
curl -s "http://${ALB_DNS}/health"
```

If it returns status `200 OK`, the deployment was successful.
