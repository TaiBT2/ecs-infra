# Terraform Configuration

## Cấu trúc

- `modules/` — Các module tái sử dụng, không chứa giá trị env cụ thể
- `envs/` — Cấu hình riêng từng môi trường, gọi modules và truyền biến
- `global/` — Tài nguyên toàn cục, chỉ cần tạo một lần

## Modules

| Module | Mô tả |
|---|---|
| `networking` | VPC, subnets, NAT Gateway, IGW, route tables, VPC endpoints |
| `security` | KMS keys, Secrets Manager, IAM roles, Security Groups |
| `edge` | CloudFront distribution, WAF, ACM certificates, Route53 records |
| `compute` | ECS cluster, Fargate service, ALB, API Gateway, Cognito |
| `data` | RDS PostgreSQL, ElastiCache Redis, S3 buckets, AWS Backup |
| `observability` | CloudWatch alarms, OpenSearch, GuardDuty, AWS Config, CloudTrail |

## Quy trình deploy

```bash
# 1. Bootstrap state (chỉ lần đầu)
./scripts/bootstrap.sh dev

# 2. Init và apply
cd terraform/envs/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Quản lý state

- Backend: S3 + DynamoDB lock
- Mỗi env có state file riêng: `myapp-{env}-terraform-state/{env}/terraform.tfstate`
- KHÔNG sử dụng Terraform workspaces
