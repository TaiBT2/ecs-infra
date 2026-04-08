environment = "dev"
vpc_cidr    = "10.0.0.0/16"

# RDS
rds_instance_class        = "db.t4g.small"
rds_multi_az              = false
rds_backup_retention      = 7
rds_deletion_protection   = false
rds_skip_final_snapshot   = true
rds_allocated_storage     = 20
rds_max_allocated_storage = 50

# ElastiCache
redis_node_type    = "cache.t4g.small"
redis_num_clusters = 1

# ECS
ecs_desired_count = 1
ecs_cpu           = 256
ecs_memory        = 512
ecs_min_capacity  = 1
ecs_max_capacity  = 2

# Networking
single_nat_gateway = true

# Observability
log_retention_days = 7
enable_opensearch  = false

# Backup
backup_retention_days = 7
