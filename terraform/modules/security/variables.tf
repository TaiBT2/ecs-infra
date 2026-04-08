########################################
# General
########################################

variable "project" {
  description = "Project name used in resource naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project must be lowercase alphanumeric with hyphens, 2-21 chars, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Map of tags applied to all resources."
  type        = map(string)
  default     = {}
}

########################################
# Networking
########################################

variable "vpc_id" {
  description = "ID of the VPC where security groups are created."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (vpc-xxxx)."
  }
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC, used to scope VPC endpoint security group ingress."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "vpc_cidr_block must be a valid CIDR notation."
  }
}

variable "container_port" {
  description = "Port the ECS container listens on (used in ECS security group ingress from ALB)."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

########################################
# KMS
########################################

variable "kms_deletion_window_in_days" {
  description = "Number of days before a KMS key is permanently deleted after scheduling."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "enable_kms_key_rotation" {
  description = "Whether automatic annual rotation is enabled for KMS keys."
  type        = bool
  default     = true
}

########################################
# Secrets Manager
########################################

variable "rds_master_username" {
  description = "Master username stored alongside the generated RDS password in Secrets Manager."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.rds_master_username))
    error_message = "rds_master_username must start with a letter and contain only alphanumerics/underscores (max 63 chars)."
  }
}

variable "rds_password_length" {
  description = "Length of the randomly generated RDS master password."
  type        = number
  default     = 32

  validation {
    condition     = var.rds_password_length >= 16 && var.rds_password_length <= 128
    error_message = "rds_password_length must be between 16 and 128."
  }
}

########################################
# IAM
########################################

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs the ECS execution role is allowed to pull from. Use [\"*\"] to allow all."
  type        = list(string)
  default     = ["*"]
}

variable "ssm_parameter_arns" {
  description = "List of SSM Parameter Store ARNs the ECS task role may read. Empty list disables access."
  type        = list(string)
  default     = []
}
