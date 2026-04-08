environment = "prod"
vpc_cidr    = "10.2.0.0/16"

# RDS
rds_instance_class        = "db.r6g.xlarge"
rds_multi_az              = true
rds_backup_retention      = 30
rds_deletion_protection   = true
rds_skip_final_snapshot   = false
rds_allocated_storage     = 100
rds_max_allocated_storage = 500

# ElastiCache
redis_node_type    = "cache.r6g.large"
redis_num_clusters = 3

# ECS
ecs_desired_count = 4
ecs_cpu           = 1024
ecs_memory        = 2048
ecs_min_capacity  = 4
ecs_max_capacity  = 12

# Networking
single_nat_gateway = false # per-AZ NAT

# Observability
log_retention_days = 90
enable_opensearch  = true

# Backup
backup_retention_days = 30
