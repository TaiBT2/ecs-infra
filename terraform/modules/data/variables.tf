################################################################################
# General
################################################################################

variable "project" {
  description = "Project name used in resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Networking
################################################################################

variable "data_subnet_ids" {
  description = "List of subnet IDs for the data tier (RDS, ElastiCache)"
  type        = list(string)

  validation {
    condition     = length(var.data_subnet_ids) >= 2
    error_message = "At least 2 data subnet IDs are required for high availability."
  }
}

################################################################################
# KMS
################################################################################

variable "kms_key_arn" {
  description = "ARN of the KMS key for encrypting RDS, ElastiCache, S3, and Backup vault"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN."
  }
}

################################################################################
# RDS PostgreSQL
################################################################################

variable "rds_instance_class" {
  description = "RDS instance class (e.g. db.t4g.micro for dev, db.r6g.large for prod)"
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = can(regex("^db\\.", var.rds_instance_class))
    error_message = "rds_instance_class must start with 'db.' (e.g. db.t4g.micro)."
  }
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB for the RDS instance"
  type        = number
  default     = 20

  validation {
    condition     = var.rds_allocated_storage >= 20 && var.rds_allocated_storage <= 65536
    error_message = "rds_allocated_storage must be between 20 and 65536 GiB."
  }
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage in GiB for RDS autoscaling (0 to disable)"
  type        = number
  default     = 100

  validation {
    condition     = var.rds_max_allocated_storage == 0 || var.rds_max_allocated_storage >= 20
    error_message = "rds_max_allocated_storage must be 0 (disabled) or at least 20 GiB."
  }
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection for the RDS instance"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain automated RDS backups"
  type        = number
  default     = 7

  validation {
    condition     = var.rds_backup_retention_period >= 1 && var.rds_backup_retention_period <= 35
    error_message = "rds_backup_retention_period must be between 1 and 35 days."
  }
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot when destroying the RDS instance (true for dev)"
  type        = bool
  default     = true
}

variable "rds_db_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "app"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.rds_db_name))
    error_message = "rds_db_name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "rds_master_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "postgres"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.rds_master_username))
    error_message = "rds_master_username must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "rds_master_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master password"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:", var.rds_master_password_secret_arn))
    error_message = "rds_master_password_secret_arn must be a valid Secrets Manager ARN."
  }
}

variable "rds_security_group_id" {
  description = "Security group ID for the RDS instance"
  type        = string

  validation {
    condition     = can(regex("^sg-", var.rds_security_group_id))
    error_message = "rds_security_group_id must be a valid security group ID."
  }
}

################################################################################
# ElastiCache Redis
################################################################################

variable "redis_node_type" {
  description = "ElastiCache node type (e.g. cache.t4g.micro for dev, cache.r7g.large for prod)"
  type        = string
  default     = "cache.t4g.micro"

  validation {
    condition     = can(regex("^cache\\.", var.redis_node_type))
    error_message = "redis_node_type must start with 'cache.' (e.g. cache.t4g.micro)."
  }
}

variable "redis_num_cache_clusters" {
  description = "Number of cache clusters (nodes) in the replication group"
  type        = number
  default     = 1

  validation {
    condition     = var.redis_num_cache_clusters >= 1 && var.redis_num_cache_clusters <= 6
    error_message = "redis_num_cache_clusters must be between 1 and 6."
  }
}

variable "redis_automatic_failover_enabled" {
  description = "Enable automatic failover for the Redis replication group (requires num_cache_clusters >= 2)"
  type        = bool
  default     = false
}

variable "redis_auth_token" {
  description = "Auth token (password) for Redis in-transit encryption. Leave empty to disable."
  type        = string
  default     = ""
  sensitive   = true
}

variable "redis_security_group_id" {
  description = "Security group ID for the ElastiCache Redis cluster"
  type        = string

  validation {
    condition     = can(regex("^sg-", var.redis_security_group_id))
    error_message = "redis_security_group_id must be a valid security group ID."
  }
}

variable "redis_snapshot_retention_limit" {
  description = "Number of days to retain Redis snapshots (0 to disable)"
  type        = number
  default     = 7

  validation {
    condition     = var.redis_snapshot_retention_limit >= 0 && var.redis_snapshot_retention_limit <= 35
    error_message = "redis_snapshot_retention_limit must be between 0 and 35."
  }
}

################################################################################
# S3
################################################################################

variable "s3_assets_force_destroy" {
  description = "Allow force destruction of the assets S3 bucket (true for dev)"
  type        = bool
  default     = false
}

variable "s3_logs_force_destroy" {
  description = "Allow force destruction of the logs S3 bucket (true for dev)"
  type        = bool
  default     = false
}

################################################################################
# AWS Backup
################################################################################

variable "backup_schedule" {
  description = "Cron expression for the AWS Backup schedule (UTC)"
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups in the vault"
  type        = number
  default     = 35

  validation {
    condition     = var.backup_retention_days >= 1
    error_message = "backup_retention_days must be at least 1."
  }
}
