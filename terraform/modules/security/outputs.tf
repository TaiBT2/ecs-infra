########################################
# KMS
########################################

output "kms_key_arns" {
  description = "Map of KMS key purpose to ARN."
  value       = { for k, v in aws_kms_key.this : k => v.arn }
}

output "kms_key_ids" {
  description = "Map of KMS key purpose to key ID."
  value       = { for k, v in aws_kms_key.this : k => v.key_id }
}

########################################
# Secrets Manager
########################################

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the RDS master credentials."
  value       = aws_secretsmanager_secret.rds_master.arn
}

output "rds_secret_name" {
  description = "Name of the Secrets Manager secret holding the RDS master credentials."
  value       = aws_secretsmanager_secret.rds_master.name
}

########################################
# IAM
########################################

output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role."
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_execution_role_name" {
  description = "Name of the ECS task execution IAM role."
  value       = aws_iam_role.ecs_execution.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task IAM role."
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  description = "Name of the ECS task IAM role."
  value       = aws_iam_role.ecs_task.name
}

########################################
# Security Groups
########################################

output "alb_sg_id" {
  description = "Security group ID for the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "ecs_sg_id" {
  description = "Security group ID for ECS tasks."
  value       = aws_security_group.ecs.id
}

output "rds_sg_id" {
  description = "Security group ID for RDS instances."
  value       = aws_security_group.rds.id
}

output "elasticache_sg_id" {
  description = "Security group ID for ElastiCache clusters."
  value       = aws_security_group.elasticache.id
}

output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC interface endpoints."
  value       = aws_security_group.vpc_endpoint.id
}
