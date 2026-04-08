environment = "staging"
vpc_cidr    = "10.1.0.0/16"

# RDS
rds_instance_class        = "db.t4g.medium"
rds_multi_az              = true
rds_backup_retention      = 14
rds_deletion_protection   = true
rds_skip_final_snapshot   = false
rds_allocated_storage     = 50
rds_max_allocated_storage = 100

# ElastiCache
redis_node_type    = "cache.t4g.medium"
redis_num_clusters = 2

# ECS
ecs_desired_count = 2
ecs_cpu           = 512
ecs_memory        = 1024
ecs_min_capacity  = 2
ecs_max_capacity  = 4

# Networking
single_nat_gateway = true

# Observability
log_retention_days = 30
enable_opensearch  = false

# Backup
backup_retention_days = 14
