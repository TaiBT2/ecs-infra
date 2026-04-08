locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
  name_prefix = "${var.project}-${var.environment}"
}

################################################################################
# VPC Flow Log prerequisites (avoids circular dependency networking <-> observability)
################################################################################

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/${local.name_prefix}-flow-logs"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

resource "aws_iam_role" "flow_log" {
  name = "${local.name_prefix}-vpc-flow-log"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${local.name_prefix}-vpc-flow-log"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_log.arn}:*"
    }]
  })
}

################################################################################
# Networking
################################################################################

module "networking" {
  source = "../../modules/networking"

  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr

  single_nat_gateway = var.single_nat_gateway

  flow_log_cloudwatch_log_group_arn = aws_cloudwatch_log_group.flow_log.arn
  flow_log_iam_role_arn             = aws_iam_role.flow_log.arn

  tags = local.tags
}

################################################################################
# Security
################################################################################

module "security" {
  source = "../../modules/security"

  project     = var.project
  environment = var.environment

  vpc_id         = module.networking.vpc_id
  vpc_cidr_block = module.networking.vpc_cidr
  container_port = var.container_port

  tags = local.tags
}

################################################################################
# Data
################################################################################

module "data" {
  source = "../../modules/data"

  project     = var.project
  environment = var.environment

  data_subnet_ids = module.networking.data_subnet_ids
  kms_key_arn     = module.security.kms_key_arns["data"]

  # RDS
  rds_instance_class             = var.rds_instance_class
  rds_allocated_storage          = var.rds_allocated_storage
  rds_max_allocated_storage      = var.rds_max_allocated_storage
  rds_multi_az                   = var.rds_multi_az
  rds_deletion_protection        = var.rds_deletion_protection
  rds_backup_retention_period    = var.rds_backup_retention
  rds_skip_final_snapshot        = var.rds_skip_final_snapshot
  rds_master_password_secret_arn = module.security.rds_secret_arn
  rds_security_group_id          = module.security.rds_sg_id

  # ElastiCache Redis
  redis_node_type                  = var.redis_node_type
  redis_num_cache_clusters         = var.redis_num_clusters
  redis_automatic_failover_enabled = var.redis_num_clusters > 1 ? true : false
  redis_security_group_id          = module.security.elasticache_sg_id

  # Backup
  backup_retention_days = var.backup_retention_days

  tags = local.tags
}

################################################################################
# Compute
################################################################################

module "compute" {
  source = "../../modules/compute"

  project     = var.project
  environment = var.environment

  vpc_id                 = module.networking.vpc_id
  public_subnet_ids      = module.networking.public_subnet_ids
  app_private_subnet_ids = module.networking.app_subnet_ids

  # ALB
  alb_security_group_id   = module.security.alb_sg_id
  acm_certificate_arn     = module.edge.acm_certificate_arn
  alb_access_logs_bucket  = module.data.s3_logs_bucket
  alb_deletion_protection = var.rds_deletion_protection

  # ECS
  ecs_security_group_id   = module.security.ecs_sg_id
  task_execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn           = module.security.ecs_task_role_arn
  container_image         = var.container_image
  container_port          = var.container_port
  cpu                     = var.ecs_cpu
  memory                  = var.ecs_memory
  desired_count           = var.ecs_desired_count
  log_retention_in_days   = var.log_retention_days

  # Auto Scaling
  autoscaling_min_capacity = var.ecs_min_capacity
  autoscaling_max_capacity = var.ecs_max_capacity

  # Secrets wiring
  container_secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = module.security.rds_secret_arn
    }
  ]

  # Environment variables
  container_environment = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "DB_HOST"
      value = module.data.rds_endpoint
    },
    {
      name  = "REDIS_HOST"
      value = module.data.elasticache_primary_endpoint
    }
  ]

  tags = local.tags
}

################################################################################
# Edge
################################################################################

module "edge" {
  source = "../../modules/edge"

  project     = var.project
  environment = var.environment

  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id
  api_subdomain   = "api"

  alb_dns_name = module.compute.alb_dns_name
  alb_arn      = module.compute.alb_arn
  alb_zone_id  = module.compute.alb_zone_id

  spa_kms_key_arn                = module.security.kms_key_arns["data"]
  cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/PLACEHOLDER"
  cloudfront_log_bucket          = "${module.data.s3_logs_bucket}.s3.amazonaws.com"

  tags = local.tags
}

################################################################################
# Observability
################################################################################

module "observability" {
  source = "../../modules/observability"

  project     = var.project
  environment = var.environment

  vpc_id          = module.networking.vpc_id
  data_subnet_ids = module.networking.data_subnet_ids
  kms_key_arn     = module.security.kms_key_arns["data"]

  alarm_email        = var.alert_email
  log_retention_days = var.log_retention_days

  # ECS references
  ecs_cluster_name = module.compute.ecs_cluster_id
  ecs_service_name = module.compute.ecs_service_name

  # RDS references
  rds_instance_id = module.data.rds_identifier

  # ALB references
  alb_arn_suffix              = regex("loadbalancer/(.*)", module.compute.alb_arn)[0]
  alb_target_group_arn_suffix = ""

  # OpenSearch
  enable_opensearch = var.enable_opensearch

  tags = local.tags
}
