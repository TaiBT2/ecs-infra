# Data Module

This module provisions the data-tier infrastructure for the ECS platform:

- **RDS PostgreSQL 16** -- Primary relational database with encryption, Performance Insights, and automated backups
- **ElastiCache Redis 7** -- In-memory cache/session store with encryption at rest and in transit
- **S3 Buckets** -- App assets bucket (versioned, KMS-encrypted) and logs bucket (lifecycle tiering to IA/Glacier)
- **AWS Backup** -- Centralized backup vault, plan, and tag-based selection for RDS and ElastiCache

## Usage

```hcl
module "data" {
  source = "./modules/data"

  project     = "myapp"
  environment = "prod"

  data_subnet_ids = module.networking.data_subnet_ids
  kms_key_arn     = module.security.kms_key_arn

  # RDS
  rds_instance_class            = "db.r6g.large"
  rds_allocated_storage         = 100
  rds_max_allocated_storage     = 500
  rds_multi_az                  = true
  rds_deletion_protection       = true
  rds_skip_final_snapshot       = false
  rds_master_password_secret_arn = module.security.rds_password_secret_arn
  rds_security_group_id         = module.security.rds_sg_id

  # Redis
  redis_node_type                = "cache.r7g.large"
  redis_num_cache_clusters       = 2
  redis_automatic_failover_enabled = true
  redis_security_group_id        = module.security.redis_sg_id

  tags = local.common_tags
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
