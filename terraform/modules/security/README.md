# Security Module

Manages KMS encryption keys, Secrets Manager secrets, IAM roles for ECS, and security groups for the application stack.

## Overview

This module provisions:

- **KMS keys** for general-purpose encryption (RDS, S3, EBS), Secrets Manager, and CloudWatch Logs, each with an alias following `{project}-{env}-{purpose}`.
- **Secrets Manager** secret containing an auto-generated RDS master password (with a rotation configuration placeholder).
- **IAM roles** for ECS task execution (ECR pull, Secrets Manager read, CloudWatch Logs) and ECS task (X-Ray, CloudWatch Logs, Secrets Manager read).
- **Security groups** for ALB, ECS, RDS, ElastiCache, and VPC endpoints with least-privilege ingress/egress rules.

## Usage

```hcl
module "security" {
  source = "../../modules/security"

  project     = "myapp"
  environment = "prod"
  vpc_id      = module.networking.vpc_id
  vpc_cidr_block = module.networking.vpc_cidr_block

  container_port      = 8080
  ecr_repository_arns = [module.ecr.repository_arn]

  tags = {
    Team = "platform"
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
