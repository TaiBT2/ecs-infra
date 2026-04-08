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
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.70 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.70 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_apigatewayv2_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_apigatewayv2_vpc_link.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_vpc_link) | resource |
| [aws_appautoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.api_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cognito_user_pool.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ARN of the ACM certificate for the HTTPS listener. | `string` | n/a | yes |
| <a name="input_alb_access_logs_bucket"></a> [alb\_access\_logs\_bucket](#input\_alb\_access\_logs\_bucket) | S3 bucket name for ALB access logs. | `string` | n/a | yes |
| <a name="input_alb_access_logs_prefix"></a> [alb\_access\_logs\_prefix](#input\_alb\_access\_logs\_prefix) | S3 key prefix for ALB access logs. | `string` | `"alb-logs"` | no |
| <a name="input_alb_deletion_protection"></a> [alb\_deletion\_protection](#input\_alb\_deletion\_protection) | Enable deletion protection on the ALB. | `bool` | `true` | no |
| <a name="input_alb_idle_timeout"></a> [alb\_idle\_timeout](#input\_alb\_idle\_timeout) | Idle timeout in seconds for the ALB. | `number` | `60` | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | Security group ID for the Application Load Balancer. | `string` | n/a | yes |
| <a name="input_api_gateway_log_retention_in_days"></a> [api\_gateway\_log\_retention\_in\_days](#input\_api\_gateway\_log\_retention\_in\_days) | Number of days to retain API Gateway access logs. | `number` | `30` | no |
| <a name="input_app_private_subnet_ids"></a> [app\_private\_subnet\_ids](#input\_app\_private\_subnet\_ids) | List of private subnet IDs for ECS tasks. | `list(string)` | n/a | yes |
| <a name="input_autoscaling_max_capacity"></a> [autoscaling\_max\_capacity](#input\_autoscaling\_max\_capacity) | Maximum number of ECS tasks for auto scaling. | `number` | `10` | no |
| <a name="input_autoscaling_min_capacity"></a> [autoscaling\_min\_capacity](#input\_autoscaling\_min\_capacity) | Minimum number of ECS tasks for auto scaling. | `number` | `1` | no |
| <a name="input_cognito_allowed_oauth_flows"></a> [cognito\_allowed\_oauth\_flows](#input\_cognito\_allowed\_oauth\_flows) | Allowed OAuth flows for the Cognito client. | `list(string)` | <pre>[<br/>  "code"<br/>]</pre> | no |
| <a name="input_cognito_allowed_oauth_scopes"></a> [cognito\_allowed\_oauth\_scopes](#input\_cognito\_allowed\_oauth\_scopes) | Allowed OAuth scopes for the Cognito client. | `list(string)` | <pre>[<br/>  "openid",<br/>  "email",<br/>  "profile"<br/>]</pre> | no |
| <a name="input_cognito_callback_urls"></a> [cognito\_callback\_urls](#input\_cognito\_callback\_urls) | List of allowed callback URLs for the Cognito User Pool Client. | `list(string)` | <pre>[<br/>  "https://localhost/callback"<br/>]</pre> | no |
| <a name="input_cognito_email_verification_message"></a> [cognito\_email\_verification\_message](#input\_cognito\_email\_verification\_message) | Email verification message template. Must contain {####}. | `string` | `"Your verification code is {####}"` | no |
| <a name="input_cognito_email_verification_subject"></a> [cognito\_email\_verification\_subject](#input\_cognito\_email\_verification\_subject) | Subject line for verification emails. | `string` | `"Your Verification Code"` | no |
| <a name="input_cognito_logout_urls"></a> [cognito\_logout\_urls](#input\_cognito\_logout\_urls) | List of allowed logout URLs for the Cognito User Pool Client. | `list(string)` | <pre>[<br/>  "https://localhost/logout"<br/>]</pre> | no |
| <a name="input_container_environment"></a> [container\_environment](#input\_container\_environment) | List of environment variable maps ({name, value}) for the container. | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Docker image URI for the application container. | `string` | n/a | yes |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Port the container listens on. | `number` | `8080` | no |
| <a name="input_container_secrets"></a> [container\_secrets](#input\_container\_secrets) | List of secret maps ({name, valueFrom}) sourced from Secrets Manager ARNs. | <pre>list(object({<br/>    name      = string<br/>    valueFrom = string<br/>  }))</pre> | `[]` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | CPU units for the Fargate task (256, 512, 1024, 2048, 4096). | `number` | `512` | no |
| <a name="input_cpu_target_value"></a> [cpu\_target\_value](#input\_cpu\_target\_value) | Target CPU utilisation percentage for auto scaling. | `number` | `70` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired number of ECS tasks. | `number` | `2` | no |
| <a name="input_ecs_security_group_id"></a> [ecs\_security\_group\_id](#input\_ecs\_security\_group\_id) | Security group ID for ECS tasks. | `string` | n/a | yes |
| <a name="input_enable_service_connect"></a> [enable\_service\_connect](#input\_enable\_service\_connect) | Enable ECS Service Connect. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. dev, staging, prod). | `string` | n/a | yes |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | Health check interval in seconds. | `number` | `30` | no |
| <a name="input_health_check_matcher"></a> [health\_check\_matcher](#input\_health\_check\_matcher) | HTTP status codes to match for a healthy response. | `string` | `"200"` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Health check path for the ALB target group. | `string` | `"/health"` | no |
| <a name="input_health_check_timeout"></a> [health\_check\_timeout](#input\_health\_check\_timeout) | Health check timeout in seconds. | `number` | `5` | no |
| <a name="input_healthy_threshold"></a> [healthy\_threshold](#input\_healthy\_threshold) | Number of consecutive successes before considering target healthy. | `number` | `3` | no |
| <a name="input_log_kms_key_id"></a> [log\_kms\_key\_id](#input\_log\_kms\_key\_id) | KMS key ARN for encrypting CloudWatch log group. | `string` | `null` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Number of days to retain ECS container logs. | `number` | `30` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory in MiB for the Fargate task. | `number` | `1024` | no |
| <a name="input_memory_target_value"></a> [memory\_target\_value](#input\_memory\_target\_value) | Target memory utilisation percentage for auto scaling. | `number` | `70` | no |
| <a name="input_project"></a> [project](#input\_project) | Project name used for resource naming. | `string` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | List of public subnet IDs for the ALB. | `list(string)` | n/a | yes |
| <a name="input_scale_in_cooldown"></a> [scale\_in\_cooldown](#input\_scale\_in\_cooldown) | Cooldown period in seconds after a scale-in activity. | `number` | `300` | no |
| <a name="input_scale_out_cooldown"></a> [scale\_out\_cooldown](#input\_scale\_out\_cooldown) | Cooldown period in seconds after a scale-out activity. | `number` | `60` | no |
| <a name="input_service_connect_namespace"></a> [service\_connect\_namespace](#input\_service\_connect\_namespace) | Cloud Map namespace ARN for Service Connect. Required when enable\_service\_connect is true. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags applied to all resources. | `map(string)` | `{}` | no |
| <a name="input_task_execution_role_arn"></a> [task\_execution\_role\_arn](#input\_task\_execution\_role\_arn) | ARN of the ECS task execution IAM role. | `string` | n/a | yes |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | ARN of the ECS task IAM role. | `string` | n/a | yes |
| <a name="input_unhealthy_threshold"></a> [unhealthy\_threshold](#input\_unhealthy\_threshold) | Number of consecutive failures before considering target unhealthy. | `number` | `3` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where resources are deployed. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer. |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer. |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Canonical hosted zone ID of the ALB (for Route 53 alias records). |
| <a name="output_api_gateway_endpoint"></a> [api\_gateway\_endpoint](#output\_api\_gateway\_endpoint) | Invoke URL of the API Gateway HTTP API. |
| <a name="output_cognito_client_id"></a> [cognito\_client\_id](#output\_cognito\_client\_id) | ID of the Cognito User Pool Client. |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | ID of the Cognito User Pool. |
| <a name="output_ecs_cluster_id"></a> [ecs\_cluster\_id](#output\_ecs\_cluster\_id) | ID of the ECS cluster. |
| <a name="output_ecs_service_id"></a> [ecs\_service\_id](#output\_ecs\_service\_id) | ID of the ECS service. |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | Name of the ECS service. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the ECS CloudWatch log group. |
<!-- END_TF_DOCS -->
