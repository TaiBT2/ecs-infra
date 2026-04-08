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
# VPC
################################################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }

  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "VPC CIDR prefix length must be between /16 and /24."
  }
}

################################################################################
# Subnets
################################################################################

variable "availability_zones" {
  description = "List of availability zones to use (e.g. [\"ap-southeast-1a\", \"ap-southeast-1b\", \"ap-southeast-1c\"])"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (ALB, NAT, IGW). Must match the number of availability_zones."
  type        = list(string)
  default     = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All public subnet CIDRs must be valid CIDR blocks."
  }
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks for app-tier private subnets (ECS Fargate). Must match the number of availability_zones."
  type        = list(string)
  default     = ["10.0.16.0/22", "10.0.20.0/22", "10.0.24.0/22"]

  validation {
    condition     = alltrue([for cidr in var.app_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All app subnet CIDRs must be valid CIDR blocks."
  }
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks for data-tier private subnets (RDS, ElastiCache). Must match the number of availability_zones."
  type        = list(string)
  default     = ["10.0.32.0/22", "10.0.36.0/22", "10.0.40.0/22"]

  validation {
    condition     = alltrue([for cidr in var.data_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All data subnet CIDRs must be valid CIDR blocks."
  }
}

################################################################################
# NAT Gateway
################################################################################

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ (cost savings for non-prod)"
  type        = bool
  default     = true
}

################################################################################
# VPC Flow Logs
################################################################################

variable "flow_log_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for VPC Flow Logs"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:logs:", var.flow_log_cloudwatch_log_group_arn))
    error_message = "flow_log_cloudwatch_log_group_arn must be a valid CloudWatch Logs ARN."
  }
}

variable "flow_log_iam_role_arn" {
  description = "ARN of the IAM role that allows VPC Flow Logs to publish to CloudWatch"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::", var.flow_log_iam_role_arn))
    error_message = "flow_log_iam_role_arn must be a valid IAM role ARN."
  }
}

################################################################################
# VPC Endpoints
################################################################################

variable "enable_vpc_endpoints" {
  description = "Whether to create VPC endpoints"
  type        = bool
  default     = true
}
