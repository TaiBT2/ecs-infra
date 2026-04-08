########################################
# Data Sources
########################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name

  kms_keys = {
    general         = "General-purpose encryption (RDS, S3, EBS, SNS, SQS)"
    secrets         = "Secrets Manager encryption"
    cloudwatch-logs = "CloudWatch Logs encryption"
  }

  common_tags = merge(var.tags, {
    Module = "security"
  })
}

########################################
# KMS Keys
########################################

resource "aws_kms_key" "this" {
  for_each = local.kms_keys

  description             = "${local.name_prefix} – ${each.value}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = var.enable_kms_key_rotation
  policy                  = data.aws_iam_policy_document.kms[each.key].json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}"
  })
}

resource "aws_kms_alias" "this" {
  for_each = local.kms_keys

  name          = "alias/${local.name_prefix}-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}

# KMS key policies — allow account root full access and service principals where needed.
data "aws_iam_policy_document" "kms" {
  for_each = local.kms_keys

  # Allow root account full management
  statement {
    sid       = "AllowRootAccount"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  # CloudWatch Logs service principal (only for cloudwatch-logs key)
  dynamic "statement" {
    for_each = each.key == "cloudwatch-logs" ? [1] : []
    content {
      sid    = "AllowCloudWatchLogs"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = ["logs.${local.region}.amazonaws.com"]
      }

      condition {
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
      }
    }
  }
}

########################################
# Secrets Manager – RDS master password
########################################

resource "random_password" "rds_master" {
  length           = var.rds_password_length
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|:,.<>?"
}

resource "aws_secretsmanager_secret" "rds_master" {
  name        = "${local.name_prefix}/rds/master-password"
  description = "RDS master credentials for ${local.name_prefix}"
  kms_key_id  = aws_kms_key.this["secrets"].arn

  # Rotation configuration placeholder – uncomment and configure a Lambda ARN when ready.
  # rotation_rules {
  #   automatically_after_days = 30
  # }
  # rotation_lambda_arn = var.rotation_lambda_arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-master-password"
  })
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id
  secret_string = jsonencode({
    username = var.rds_master_username
    password = random_password.rds_master.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

########################################
# IAM – ECS Task Execution Role
########################################

data "aws_iam_policy_document" "ecs_execution_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-execution"
  })
}

data "aws_iam_policy_document" "ecs_execution" {
  # ECR pull
  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = var.ecr_repository_arns
  }

  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
  }

  # Secrets Manager – read secrets required at container start
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.rds_master.arn,
    ]
  }

  # KMS decrypt for secrets
  statement {
    sid    = "KMSDecryptSecrets"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      aws_kms_key.this["secrets"].arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_execution" {
  name   = "${local.name_prefix}-ecs-execution"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution.json
}

########################################
# IAM – ECS Task Role
########################################

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-task"
  })
}

data "aws_iam_policy_document" "ecs_task" {
  # CloudWatch Logs – application-level logging
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
  }

  # X-Ray daemon
  statement {
    sid    = "XRay"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
    ]
    resources = ["*"]
  }

  # Secrets Manager – runtime reads
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.rds_master.arn,
    ]
  }

  # KMS decrypt for secrets
  statement {
    sid    = "KMSDecryptSecrets"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      aws_kms_key.this["secrets"].arn,
    ]
  }

  # Optional SSM Parameter Store access
  dynamic "statement" {
    for_each = length(var.ssm_parameter_arns) > 0 ? [1] : []
    content {
      sid    = "SSMParameterRead"
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
      ]
      resources = var.ssm_parameter_arns
    }
  }
}

resource "aws_iam_role_policy" "ecs_task" {
  name   = "${local.name_prefix}-ecs-task"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task.json
}

########################################
# Security Groups
########################################

# --- ALB ---
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "ALB – allow HTTPS from the internet"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-https-in"
  })
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward traffic to ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.ecs.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-to-ecs"
  })
}

# --- ECS ---
resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs"
  description = "ECS tasks – allow traffic from ALB"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Container port from ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.alb.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-from-alb"
  })
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "PostgreSQL to RDS"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-to-rds"
  })
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_elasticache" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Redis to ElastiCache"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.elasticache.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-to-elasticache"
  })
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_vpce" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "HTTPS to VPC endpoints"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.vpc_endpoint.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-to-vpce"
  })
}

# --- RDS ---
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds"
  description = "RDS – allow PostgreSQL from ECS"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ecs.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-from-ecs"
  })
}

# --- ElastiCache ---
resource "aws_security_group" "elasticache" {
  name        = "${local.name_prefix}-elasticache"
  description = "ElastiCache – allow Redis from ECS"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-elasticache"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_from_ecs" {
  security_group_id            = aws_security_group.elasticache.id
  description                  = "Redis from ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.ecs.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-elasticache-from-ecs"
  })
}

# --- VPC Endpoints ---
resource "aws_security_group" "vpc_endpoint" {
  name        = "${local.name_prefix}-vpce"
  description = "VPC Endpoints – allow HTTPS from VPC CIDR"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_https" {
  security_group_id = aws_security_group.vpc_endpoint.id
  description       = "HTTPS from VPC CIDR"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr_block

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-https-in"
  })
}
