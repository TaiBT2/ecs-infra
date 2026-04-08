################################################################################
# General
################################################################################

variable "project" {
  description = "Project name used for resource naming."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "Project name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Map of tags applied to all resources."
  type        = map(string)
  default     = {}
}

################################################################################
# Networking
################################################################################

variable "vpc_id" {
  description = "VPC ID where resources are deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public subnets are required for the ALB."
  }
}

variable "app_private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks."
  type        = list(string)

  validation {
    condition     = length(var.app_private_subnet_ids) >= 2
    error_message = "At least two private subnets are required for ECS tasks."
  }
}

################################################################################
# ALB
################################################################################

variable "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:", var.acm_certificate_arn))
    error_message = "Must be a valid ACM certificate ARN."
  }
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs."
  type        = string
}

variable "alb_access_logs_prefix" {
  description = "S3 key prefix for ALB access logs."
  type        = string
  default     = "alb-logs"
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on the ALB."
  type        = bool
  default     = true
}

variable "alb_idle_timeout" {
  description = "Idle timeout in seconds for the ALB."
  type        = number
  default     = 60
}

variable "health_check_path" {
  description = "Health check path for the ALB target group."
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds."
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds."
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Number of consecutive successes before considering target healthy."
  type        = number
  default     = 3
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failures before considering target unhealthy."
  type        = number
  default     = 3
}

variable "health_check_matcher" {
  description = "HTTP status codes to match for a healthy response."
  type        = string
  default     = "200"
}

################################################################################
# ECS
################################################################################

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks."
  type        = string
}

variable "task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role."
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task IAM role."
  type        = string
}

variable "container_image" {
  description = "Docker image URI for the application container."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "cpu" {
  description = "CPU units for the Fargate task (256, 512, 1024, 2048, 4096)."
  type        = number
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Memory in MiB for the Fargate task."
  type        = number
  default     = 1024

  validation {
    condition     = var.memory >= 512
    error_message = "Memory must be at least 512 MiB."
  }
}

variable "desired_count" {
  description = "Desired number of ECS tasks."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 0
    error_message = "Desired count must be non-negative."
  }
}

variable "container_environment" {
  description = "List of environment variable maps ({name, value}) for the container."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "container_secrets" {
  description = "List of secret maps ({name, valueFrom}) sourced from Secrets Manager ARNs."
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "enable_service_connect" {
  description = "Enable ECS Service Connect."
  type        = bool
  default     = false
}

variable "service_connect_namespace" {
  description = "Cloud Map namespace ARN for Service Connect. Required when enable_service_connect is true."
  type        = string
  default     = ""
}

################################################################################
# CloudWatch Logs
################################################################################

variable "log_retention_in_days" {
  description = "Number of days to retain ECS container logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention value."
  }
}

variable "log_kms_key_id" {
  description = "KMS key ARN for encrypting CloudWatch log group."
  type        = string
  default     = null
}

################################################################################
# Auto Scaling
################################################################################

variable "autoscaling_min_capacity" {
  description = "Minimum number of ECS tasks for auto scaling."
  type        = number
  default     = 1

  validation {
    condition     = var.autoscaling_min_capacity >= 1
    error_message = "Minimum capacity must be at least 1."
  }
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of ECS tasks for auto scaling."
  type        = number
  default     = 10

  validation {
    condition     = var.autoscaling_max_capacity >= 1
    error_message = "Maximum capacity must be at least 1."
  }
}

variable "cpu_target_value" {
  description = "Target CPU utilisation percentage for auto scaling."
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 1 and 100."
  }
}

variable "memory_target_value" {
  description = "Target memory utilisation percentage for auto scaling."
  type        = number
  default     = 70

  validation {
    condition     = var.memory_target_value > 0 && var.memory_target_value <= 100
    error_message = "Memory target value must be between 1 and 100."
  }
}

variable "scale_in_cooldown" {
  description = "Cooldown period in seconds after a scale-in activity."
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period in seconds after a scale-out activity."
  type        = number
  default     = 60
}

################################################################################
# API Gateway
################################################################################

variable "api_gateway_log_retention_in_days" {
  description = "Number of days to retain API Gateway access logs."
  type        = number
  default     = 30
}

################################################################################
# Cognito
################################################################################

variable "cognito_email_verification_message" {
  description = "Email verification message template. Must contain {####}."
  type        = string
  default     = "Your verification code is {####}"
}

variable "cognito_email_verification_subject" {
  description = "Subject line for verification emails."
  type        = string
  default     = "Your Verification Code"
}

variable "cognito_callback_urls" {
  description = "List of allowed callback URLs for the Cognito User Pool Client."
  type        = list(string)
  default     = ["https://localhost/callback"]
}

variable "cognito_logout_urls" {
  description = "List of allowed logout URLs for the Cognito User Pool Client."
  type        = list(string)
  default     = ["https://localhost/logout"]
}

variable "cognito_allowed_oauth_flows" {
  description = "Allowed OAuth flows for the Cognito client."
  type        = list(string)
  default     = ["code"]
}

variable "cognito_allowed_oauth_scopes" {
  description = "Allowed OAuth scopes for the Cognito client."
  type        = list(string)
  default     = ["openid", "email", "profile"]
}
