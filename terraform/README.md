# Terraform Configuration

## Structure

- `modules/` — Reusable modules, does not contain env-specific values
- `envs/` — Per-environment configuration, calls modules and passes variables
- `global/` — Global resources, only need to be created once

## Modules

| Module | Description |
|---|---|
| `networking` | VPC, subnets, NAT Gateway, IGW, route tables, VPC endpoints |
| `security` | KMS keys, Secrets Manager, IAM roles, Security Groups |
| `edge` | CloudFront distribution, WAF, ACM certificates, Route53 records |
| `compute` | ECS cluster, Fargate service, ALB, API Gateway, Cognito |
| `data` | RDS PostgreSQL, ElastiCache Redis, S3 buckets, AWS Backup |
| `observability` | CloudWatch alarms, OpenSearch, GuardDuty, AWS Config, CloudTrail |

## Deploy Process

```bash
# 1. Bootstrap state (first time only)
./scripts/bootstrap.sh dev

# 2. Init and apply
cd terraform/envs/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## State Management

- Backend: S3 + DynamoDB lock
- Each env has its own state file: `myapp-{env}-terraform-state/{env}/terraform.tfstate`
- DO NOT use Terraform workspaces
