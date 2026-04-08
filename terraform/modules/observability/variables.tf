################################################################################
# General
################################################################################

variable "project" {
  description = "Project name used in resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "Project must start with a letter, contain only lowercase alphanumeric characters and hyphens, and be 2-21 characters long."
  }
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Networking (for OpenSearch VPC deployment)
################################################################################

variable "vpc_id" {
  description = "VPC ID for OpenSearch domain deployment"
  type        = string
}

variable "data_subnet_ids" {
  description = "Subnet IDs for OpenSearch VPC deployment (data/private subnets)"
  type        = list(string)
}

################################################################################
# KMS
################################################################################

variable "kms_key_arn" {
  description = "KMS key ARN used for encryption of CloudWatch Logs, CloudTrail, OpenSearch, and X-Ray"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN."
  }
}

################################################################################
# CloudWatch
################################################################################

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications via SNS"
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alarm_email))
    error_message = "alarm_email must be a valid email address."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

################################################################################
# ECS references (for alarms / dashboard)
################################################################################

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster to monitor"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service to monitor"
  type        = string
}

################################################################################
# RDS references (for alarms / dashboard)
################################################################################

variable "rds_instance_id" {
  description = "RDS instance identifier to monitor"
  type        = string
}

################################################################################
# ALB references (for alarms / dashboard)
################################################################################

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (the part after loadbalancer/)"
  type        = string
}

variable "alb_target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group"
  type        = string
}

################################################################################
# OpenSearch (optional)
################################################################################

variable "enable_opensearch" {
  description = "Whether to create the OpenSearch domain for log analytics"
  type        = bool
  default     = false
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch data nodes"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch data nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.opensearch_instance_count >= 1 && var.opensearch_instance_count <= 10
    error_message = "opensearch_instance_count must be between 1 and 10."
  }
}

variable "opensearch_volume_size" {
  description = "EBS volume size in GB for each OpenSearch node"
  type        = number
  default     = 20

  validation {
    condition     = var.opensearch_volume_size >= 10 && var.opensearch_volume_size <= 1000
    error_message = "opensearch_volume_size must be between 10 and 1000 GB."
  }
}

variable "opensearch_engine_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "OpenSearch_2.11"
}

################################################################################
# X-Ray
################################################################################

variable "xray_sampling_rate" {
  description = "X-Ray sampling rate (0.0 to 1.0). Defaults to 0.05 (5%) for dev, recommend higher for prod."
  type        = number
  default     = 0.05

  validation {
    condition     = var.xray_sampling_rate >= 0 && var.xray_sampling_rate <= 1
    error_message = "xray_sampling_rate must be between 0.0 and 1.0."
  }
}
