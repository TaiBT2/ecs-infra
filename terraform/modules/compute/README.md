# Compute Module

This module provisions the compute layer for ECS Fargate workloads, including:

- **ALB** -- Application Load Balancer with HTTPS termination, HTTP-to-HTTPS redirect, and access logging.
- **ECS** -- Fargate cluster, task definition, and service with deployment circuit breaker and Container Insights.
- **Auto Scaling** -- Target-tracking policies on CPU and memory utilisation.
- **API Gateway** -- HTTP API with VPC Link integration to the ALB and access logging.
- **Cognito** -- User Pool with mandatory TOTP MFA, strict password policy, and a pre-configured client.

## Usage

```hcl
module "compute" {
  source = "./modules/compute"

  project     = "myapp"
  environment = "prod"

  vpc_id                 = module.networking.vpc_id
  public_subnet_ids      = module.networking.public_subnet_ids
  app_private_subnet_ids = module.networking.app_private_subnet_ids

  alb_security_group_id  = module.security.alb_sg_id
  ecs_security_group_id  = module.security.ecs_sg_id
  acm_certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
  alb_access_logs_bucket = "my-alb-logs-bucket"

  container_image        = "123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:latest"
  task_execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn           = module.security.ecs_task_role_arn

  tags = {
    Team = "platform"
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
