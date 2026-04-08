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
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.70 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.70 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_backup_plan.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_elasticache_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group) | resource |
| [aws_elasticache_replication_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_iam_role.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.backup_restores](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.backup_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_logging.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_public_access_block.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.assets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_iam_policy_document.backup_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_secretsmanager_secret_version.rds_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Number of days to retain backups in the vault | `number` | `35` | no |
| <a name="input_backup_schedule"></a> [backup\_schedule](#input\_backup\_schedule) | Cron expression for the AWS Backup schedule (UTC) | `string` | `"cron(0 3 * * ? *)"` | no |
| <a name="input_data_subnet_ids"></a> [data\_subnet\_ids](#input\_data\_subnet\_ids) | List of subnet IDs for the data tier (RDS, ElastiCache) | `list(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the KMS key for encrypting RDS, ElastiCache, S3, and Backup vault | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name used in resource naming | `string` | n/a | yes |
| <a name="input_rds_allocated_storage"></a> [rds\_allocated\_storage](#input\_rds\_allocated\_storage) | Allocated storage in GiB for the RDS instance | `number` | `20` | no |
| <a name="input_rds_backup_retention_period"></a> [rds\_backup\_retention\_period](#input\_rds\_backup\_retention\_period) | Number of days to retain automated RDS backups | `number` | `7` | no |
| <a name="input_rds_db_name"></a> [rds\_db\_name](#input\_rds\_db\_name) | Name of the default database to create | `string` | `"app"` | no |
| <a name="input_rds_deletion_protection"></a> [rds\_deletion\_protection](#input\_rds\_deletion\_protection) | Enable deletion protection for the RDS instance | `bool` | `false` | no |
| <a name="input_rds_instance_class"></a> [rds\_instance\_class](#input\_rds\_instance\_class) | RDS instance class (e.g. db.t4g.micro for dev, db.r6g.large for prod) | `string` | `"db.t4g.micro"` | no |
| <a name="input_rds_master_password_secret_arn"></a> [rds\_master\_password\_secret\_arn](#input\_rds\_master\_password\_secret\_arn) | ARN of the Secrets Manager secret containing the RDS master password | `string` | n/a | yes |
| <a name="input_rds_master_username"></a> [rds\_master\_username](#input\_rds\_master\_username) | Master username for the RDS instance | `string` | `"postgres"` | no |
| <a name="input_rds_max_allocated_storage"></a> [rds\_max\_allocated\_storage](#input\_rds\_max\_allocated\_storage) | Maximum storage in GiB for RDS autoscaling (0 to disable) | `number` | `100` | no |
| <a name="input_rds_multi_az"></a> [rds\_multi\_az](#input\_rds\_multi\_az) | Enable Multi-AZ deployment for RDS | `bool` | `false` | no |
| <a name="input_rds_security_group_id"></a> [rds\_security\_group\_id](#input\_rds\_security\_group\_id) | Security group ID for the RDS instance | `string` | n/a | yes |
| <a name="input_rds_skip_final_snapshot"></a> [rds\_skip\_final\_snapshot](#input\_rds\_skip\_final\_snapshot) | Skip final snapshot when destroying the RDS instance (true for dev) | `bool` | `true` | no |
| <a name="input_redis_auth_token"></a> [redis\_auth\_token](#input\_redis\_auth\_token) | Auth token (password) for Redis in-transit encryption. Leave empty to disable. | `string` | `""` | no |
| <a name="input_redis_automatic_failover_enabled"></a> [redis\_automatic\_failover\_enabled](#input\_redis\_automatic\_failover\_enabled) | Enable automatic failover for the Redis replication group (requires num\_cache\_clusters >= 2) | `bool` | `false` | no |
| <a name="input_redis_node_type"></a> [redis\_node\_type](#input\_redis\_node\_type) | ElastiCache node type (e.g. cache.t4g.micro for dev, cache.r7g.large for prod) | `string` | `"cache.t4g.micro"` | no |
| <a name="input_redis_num_cache_clusters"></a> [redis\_num\_cache\_clusters](#input\_redis\_num\_cache\_clusters) | Number of cache clusters (nodes) in the replication group | `number` | `1` | no |
| <a name="input_redis_security_group_id"></a> [redis\_security\_group\_id](#input\_redis\_security\_group\_id) | Security group ID for the ElastiCache Redis cluster | `string` | n/a | yes |
| <a name="input_redis_snapshot_retention_limit"></a> [redis\_snapshot\_retention\_limit](#input\_redis\_snapshot\_retention\_limit) | Number of days to retain Redis snapshots (0 to disable) | `number` | `7` | no |
| <a name="input_s3_assets_force_destroy"></a> [s3\_assets\_force\_destroy](#input\_s3\_assets\_force\_destroy) | Allow force destruction of the assets S3 bucket (true for dev) | `bool` | `false` | no |
| <a name="input_s3_logs_force_destroy"></a> [s3\_logs\_force\_destroy](#input\_s3\_logs\_force\_destroy) | Allow force destruction of the logs S3 bucket (true for dev) | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backup_vault_arn"></a> [backup\_vault\_arn](#output\_backup\_vault\_arn) | ARN of the AWS Backup vault |
| <a name="output_elasticache_endpoint"></a> [elasticache\_endpoint](#output\_elasticache\_endpoint) | Configuration endpoint for the ElastiCache Redis replication group |
| <a name="output_elasticache_primary_endpoint"></a> [elasticache\_primary\_endpoint](#output\_elasticache\_primary\_endpoint) | Primary endpoint address for the ElastiCache Redis replication group |
| <a name="output_rds_arn"></a> [rds\_arn](#output\_rds\_arn) | ARN of the RDS PostgreSQL instance |
| <a name="output_rds_endpoint"></a> [rds\_endpoint](#output\_rds\_endpoint) | Connection endpoint for the RDS PostgreSQL instance |
| <a name="output_rds_identifier"></a> [rds\_identifier](#output\_rds\_identifier) | Identifier of the RDS PostgreSQL instance |
| <a name="output_s3_assets_bucket"></a> [s3\_assets\_bucket](#output\_s3\_assets\_bucket) | Name of the S3 assets bucket |
| <a name="output_s3_assets_bucket_arn"></a> [s3\_assets\_bucket\_arn](#output\_s3\_assets\_bucket\_arn) | ARN of the S3 assets bucket |
| <a name="output_s3_logs_bucket"></a> [s3\_logs\_bucket](#output\_s3\_logs\_bucket) | Name of the S3 logs bucket |
<!-- END_TF_DOCS -->
