################################################################################
# Networking
################################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "app_subnet_ids" {
  description = "List of app-tier private subnet IDs"
  value       = module.networking.app_subnet_ids
}

output "data_subnet_ids" {
  description = "List of data-tier private subnet IDs"
  value       = module.networking.data_subnet_ids
}

################################################################################
# Security
################################################################################

output "kms_key_arns" {
  description = "Map of KMS key purpose to ARN"
  value       = module.security.kms_key_arns
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = module.security.ecs_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = module.security.ecs_task_role_arn
}

################################################################################
# Data
################################################################################

output "rds_endpoint" {
  description = "Connection endpoint for the RDS PostgreSQL instance"
  value       = module.data.rds_endpoint
}

output "rds_identifier" {
  description = "Identifier of the RDS PostgreSQL instance"
  value       = module.data.rds_identifier
}

output "elasticache_endpoint" {
  description = "Primary endpoint for the ElastiCache Redis replication group"
  value       = module.data.elasticache_primary_endpoint
}

output "s3_assets_bucket" {
  description = "Name of the S3 assets bucket"
  value       = module.data.s3_assets_bucket
}

################################################################################
# Compute
################################################################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.compute.alb_arn
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.compute.ecs_cluster_id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.compute.ecs_service_name
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.compute.cognito_user_pool_id
}

output "cognito_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = module.compute.cognito_client_id
}

output "api_gateway_endpoint" {
  description = "Invoke URL of the API Gateway HTTP API"
  value       = module.compute.api_gateway_endpoint
}

################################################################################
# Edge
################################################################################

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.edge.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.edge.cloudfront_domain_name
}

output "spa_bucket_name" {
  description = "Name of the S3 bucket for SPA static hosting"
  value       = module.edge.spa_bucket_name
}

output "acm_certificate_arn" {
  description = "ARN of the regional ACM certificate"
  value       = module.edge.acm_certificate_arn
}

################################################################################
# Observability
################################################################################

output "sns_topic_arn" {
  description = "ARN of the SNS alarm notification topic"
  value       = module.observability.sns_topic_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.observability.dashboard_name
}

output "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch domain (empty if disabled)"
  value       = module.observability.opensearch_endpoint
}
