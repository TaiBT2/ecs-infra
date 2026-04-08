################################################################################
# General
################################################################################

variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "<OWNER>"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "<COST_CENTER>"
}

################################################################################
# Domain & DNS
################################################################################

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
  default     = "<DOMAIN>"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID (from global/route53 output)"
  type        = string
  default     = "<ZONE_ID>"
}

variable "alert_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = "<ALERT_EMAIL>"
}

################################################################################
# Networking
################################################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ (cost savings for non-prod)"
  type        = bool
  default     = false
}

################################################################################
# Container
################################################################################

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080
}

variable "container_image" {
  description = "Docker image URI for the application container"
  type        = string
  default     = "nginx:latest"
}

################################################################################
# RDS
################################################################################

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.xlarge"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = true
}

variable "rds_backup_retention" {
  description = "Number of days to retain RDS automated backups"
  type        = number
  default     = 30
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection for the RDS instance"
  type        = bool
  default     = true
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot when destroying the RDS instance"
  type        = bool
  default     = false
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB for the RDS instance"
  type        = number
  default     = 100
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage in GiB for RDS autoscaling"
  type        = number
  default     = 500
}

################################################################################
# ElastiCache Redis
################################################################################

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_clusters" {
  description = "Number of cache clusters (nodes) in the replication group"
  type        = number
  default     = 3
}

################################################################################
# ECS
################################################################################

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 4
}

variable "ecs_cpu" {
  description = "CPU units for the Fargate task"
  type        = number
  default     = 1024
}

variable "ecs_memory" {
  description = "Memory in MiB for the Fargate task"
  type        = number
  default     = 2048
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks for auto scaling"
  type        = number
  default     = 4
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks for auto scaling"
  type        = number
  default     = 12
}

################################################################################
# Observability
################################################################################

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 90
}

variable "enable_opensearch" {
  description = "Whether to create the OpenSearch domain for log analytics"
  type        = bool
  default     = true
}

################################################################################
# Backup
################################################################################

variable "backup_retention_days" {
  description = "Number of days to retain backups in the vault"
  type        = number
  default     = 30
}
