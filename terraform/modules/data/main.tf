locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(var.tags, {
    Module = "data"
  })
}

################################################################################
# RDS PostgreSQL – Password from Secrets Manager
################################################################################

data "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = var.rds_master_password_secret_arn
}

################################################################################
# RDS PostgreSQL – Subnet Group
################################################################################

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-db"
  description = "DB subnet group for ${local.name_prefix}"
  subnet_ids  = var.data_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db"
  })
}

################################################################################
# RDS PostgreSQL – Parameter Group
################################################################################

resource "aws_db_parameter_group" "this" {
  name        = "${local.name_prefix}-pg16"
  family      = "postgres16"
  description = "Parameter group for ${local.name_prefix} PostgreSQL 16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "all"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg16"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# RDS PostgreSQL – Instance
################################################################################

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.rds_instance_class

  db_name  = var.rds_db_name
  username = var.rds_master_username
  password = data.aws_secretsmanager_secret_version.rds_password.secret_string
  port     = 5432

  # Storage
  storage_type          = "gp3"
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage > 0 ? var.rds_max_allocated_storage : null

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_security_group_id]
  multi_az               = var.rds_multi_az
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.this.name

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Backups
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = 7

  # CloudWatch log exports
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Protection
  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_skip_final_snapshot ? null : "${local.name_prefix}-postgres-final"

  # Safety: do not apply changes immediately in production
  apply_immediately = false

  # Copy tags to snapshots
  copy_tags_to_snapshot = true

  tags = merge(local.common_tags, {
    Name   = "${local.name_prefix}-postgres"
    Backup = "true"
  })
}

################################################################################
# ElastiCache Redis – Subnet Group
################################################################################

resource "aws_elasticache_subnet_group" "this" {
  name        = "${local.name_prefix}-redis"
  description = "Subnet group for ${local.name_prefix} Redis"
  subnet_ids  = var.data_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis"
  })
}

################################################################################
# ElastiCache Redis – Parameter Group
################################################################################

resource "aws_elasticache_parameter_group" "this" {
  name        = "${local.name_prefix}-redis7"
  family      = "redis7"
  description = "Parameter group for ${local.name_prefix} Redis 7"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis7"
  })
}

################################################################################
# ElastiCache Redis – Replication Group
################################################################################

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis replication group for ${local.name_prefix}"

  node_type            = var.redis_node_type
  num_cache_clusters   = var.redis_num_cache_clusters
  parameter_group_name = aws_elasticache_parameter_group.this.name
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [var.redis_security_group_id]
  port                 = 6379

  engine_version = "7.0"

  # Encryption
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token != "" ? var.redis_auth_token : null

  # High availability
  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_automatic_failover_enabled

  # Snapshots
  snapshot_retention_limit = var.redis_snapshot_retention_limit
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:05:00-sun:06:00"

  # Safety
  apply_immediately = false

  tags = merge(local.common_tags, {
    Name   = "${local.name_prefix}-redis"
    Backup = "true"
  })
}

################################################################################
# S3 – Logs Bucket (created first as it receives access logs)
################################################################################

resource "aws_s3_bucket" "logs" {
  bucket        = "${local.name_prefix}-logs"
  force_destroy = var.s3_logs_force_destroy

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-logs"
  })
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "logs" {
  bucket = aws_s3_bucket.logs.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "self-access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

################################################################################
# S3 – App Assets Bucket
################################################################################

resource "aws_s3_bucket" "assets" {
  bucket        = "${local.name_prefix}-assets"
  force_destroy = var.s3_assets_force_destroy

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-assets"
  })
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "assets" {
  bucket = aws_s3_bucket.assets.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/${aws_s3_bucket.assets.id}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "noncurrent-version-cleanup"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

################################################################################
# AWS Backup – Vault
################################################################################

resource "aws_backup_vault" "this" {
  name        = "${local.name_prefix}-vault"
  kms_key_arn = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vault"
  })
}

################################################################################
# AWS Backup – Plan
################################################################################

resource "aws_backup_plan" "this" {
  name = "${local.name_prefix}-plan"

  rule {
    rule_name         = "${local.name_prefix}-daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_retention_days
    }

  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-plan"
  })
}

################################################################################
# AWS Backup – IAM Role
################################################################################

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${local.name_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backup-role"
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_s3" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
}

resource "aws_iam_role_policy_attachment" "backup_restores" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

################################################################################
# AWS Backup – Selection (tag-based for RDS and ElastiCache)
################################################################################

resource "aws_backup_selection" "this" {
  name         = "${local.name_prefix}-selection"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }
}
