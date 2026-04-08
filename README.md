# MyApp Infrastructure

Dự án Infrastructure-as-Code cho ứng dụng web 3-tier trên AWS, sử dụng Terraform và GitHub Actions.

## Kiến trúc tổng quan

```
                    ┌─────────────┐
                    │  Route 53   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ CloudFront  │
                    │  + WAF      │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
       ┌──────▼──────┐          ┌──────▼──────┐
       │  S3 (SPA)   │          │    ALB      │
       └─────────────┘          └──────┬──────┘
                                       │
                          ┌────────────┴────────────┐
                          │    ECS Fargate           │
                          │    (Private Subnet)      │
                          └────────────┬────────────┘
                                       │
                          ┌────────────┴────────────┐
                          │                         │
                   ┌──────▼──────┐          ┌──────▼──────┐
                   │ RDS Postgres│          │ ElastiCache  │
                   │ (Multi-AZ)  │          │ (Redis)      │
                   └─────────────┘          └─────────────┘
```

## Cấu trúc dự án

```
terraform/
├── modules/          # Reusable modules
│   ├── networking/   # VPC, subnets, NAT, IGW, VPC endpoints
│   ├── security/     # KMS, Secrets Manager, IAM, Security Groups
│   ├── edge/         # CloudFront, WAF, ACM, Route53
│   ├── compute/      # ECS Fargate, ALB, API Gateway, Cognito
│   ├── data/         # RDS, ElastiCache, S3, AWS Backup
│   └── observability/# CloudWatch, OpenSearch, GuardDuty, Config
├── envs/             # Per-environment configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
└── global/           # One-time global resources
    ├── backend/      # S3 state bucket + DynamoDB lock
    ├── iam/          # GitHub OIDC provider
    └── route53/      # Public hosted zone
```

## Môi trường

| Môi trường | Mục đích | Auto-deploy | Approval |
|---|---|---|---|
| dev | Phát triển, testing | Push to main | Không |
| staging | Pre-production | Tag `rc-*` | 1 reviewer |
| prod | Production | Tag `v*.*.*` | 2 reviewers |

## Bắt đầu nhanh

1. **Cài đặt công cụ**: Xem [docs/onboarding/getting-started.md](docs/onboarding/getting-started.md)
2. **Bootstrap state**: `./scripts/bootstrap.sh dev`
3. **Deploy dev**: `cd terraform/envs/dev && terraform init && terraform apply`

## Quy ước đặt tên

- Pattern: `{project}-{env}-{resource}` (ví dụ: `myapp-prod-rds-main`)
- Tags bắt buộc: `Project`, `Environment`, `Owner`, `CostCenter`, `ManagedBy=terraform`

## CI/CD Workflows

| Workflow | Trigger | Mô tả |
|---|---|---|
| `terraform-plan` | Pull Request | Plan tất cả env bị ảnh hưởng, comment lên PR |
| `terraform-apply` | Push to main | Auto-apply dev |
| `terraform-promote` | Tag `rc-*` / `v*.*.*` | Deploy staging/prod với approval |
| `terraform-destroy` | Manual | Destroy dev/staging |
| `drift-detection` | Cron (02:00 UTC) | Phát hiện drift, alert Slack |
| `security-scan` | Pull Request | tflint, tfsec, checkov, trivy |
| `docs` | Push to main | Auto-generate terraform-docs |

## Tài liệu

- [Kiến trúc tổng quan](docs/architecture/overview.md)
- [Runbooks vận hành](docs/runbooks/)
- [Onboarding](docs/onboarding/getting-started.md)

## Placeholders cần thay thế

Tìm và thay thế các placeholder sau trước khi deploy:

| Placeholder | Mô tả |
|---|---|
| `<ACCOUNT_ID_DEV>` | AWS Account ID cho env dev |
| `<ACCOUNT_ID_STAGING>` | AWS Account ID cho env staging |
| `<ACCOUNT_ID_PROD>` | AWS Account ID cho env prod |
| `<DOMAIN>` | Domain chính (ví dụ: `myapp.com`) |
| `<ALERT_EMAIL>` | Email nhận alert |
| `<SLACK_WEBHOOK_URL>` | Slack webhook cho drift alert |
| `<GITHUB_ORG>` | GitHub organization name |
| `<GITHUB_REPO>` | GitHub repository name |
| `<COST_CENTER>` | Mã cost center |
| `<OWNER>` | Team/người sở hữu |
