################################################################################
# RDS PostgreSQL
################################################################################

output "rds_endpoint" {
  description = "Connection endpoint for the RDS PostgreSQL instance"
  value       = aws_db_instance.this.endpoint
}

output "rds_arn" {
  description = "ARN of the RDS PostgreSQL instance"
  value       = aws_db_instance.this.arn
}

output "rds_identifier" {
  description = "Identifier of the RDS PostgreSQL instance"
  value       = aws_db_instance.this.identifier
}

################################################################################
# ElastiCache Redis
################################################################################

output "elasticache_endpoint" {
  description = "Configuration endpoint for the ElastiCache Redis replication group"
  value       = aws_elasticache_replication_group.this.configuration_endpoint_address
}

output "elasticache_primary_endpoint" {
  description = "Primary endpoint address for the ElastiCache Redis replication group"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

################################################################################
# S3
################################################################################

output "s3_assets_bucket" {
  description = "Name of the S3 assets bucket"
  value       = aws_s3_bucket.assets.id
}

output "s3_assets_bucket_arn" {
  description = "ARN of the S3 assets bucket"
  value       = aws_s3_bucket.assets.arn
}

output "s3_logs_bucket" {
  description = "Name of the S3 logs bucket"
  value       = aws_s3_bucket.logs.id
}

################################################################################
# AWS Backup
################################################################################

output "backup_vault_arn" {
  description = "ARN of the AWS Backup vault"
  value       = aws_backup_vault.this.arn
}
