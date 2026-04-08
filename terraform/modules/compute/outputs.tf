################################################################################
# ALB
################################################################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB (for Route 53 alias records)."
  value       = aws_lb.this.zone_id
}

################################################################################
# ECS
################################################################################

output "ecs_cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "ecs_service_id" {
  description = "ID of the ECS service."
  value       = aws_ecs_service.this.id
}

################################################################################
# Cognito
################################################################################

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool."
  value       = aws_cognito_user_pool.this.id
}

output "cognito_client_id" {
  description = "ID of the Cognito User Pool Client."
  value       = aws_cognito_user_pool_client.this.id
}

################################################################################
# API Gateway
################################################################################

output "api_gateway_endpoint" {
  description = "Invoke URL of the API Gateway HTTP API."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

################################################################################
# CloudWatch
################################################################################

output "log_group_name" {
  description = "Name of the ECS CloudWatch log group."
  value       = aws_cloudwatch_log_group.ecs.name
}
