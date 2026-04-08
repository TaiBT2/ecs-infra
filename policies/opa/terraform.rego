package main

import input

# Required tags that must be present on all taggable resources
required_tags := {"Project", "Environment", "Owner", "CostCenter", "ManagedBy"}

# Deny resources missing required tags
deny[msg] {
  resource := input.resource_changes[_]
  resource.change.actions[_] != "delete"

  tags := object.get(resource.change.after, "tags", {})
  tags != null

  missing := required_tags - {key | tags[key]}
  count(missing) > 0

  msg := sprintf(
    "Resource '%s' (type: %s) is missing required tags: %v",
    [resource.address, resource.type, missing]
  )
}

# Deny resources with null tags (no tags at all)
deny[msg] {
  resource := input.resource_changes[_]
  resource.change.actions[_] != "delete"

  tags := object.get(resource.change.after, "tags", null)
  tags == null

  # Only check resources that support tags
  supports_tags(resource.type)

  msg := sprintf(
    "Resource '%s' (type: %s) has no tags defined. Required tags: %v",
    [resource.address, resource.type, required_tags]
  )
}

# Deny S3 buckets without encryption configuration
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  resource.change.actions[_] != "delete"

  not has_s3_encryption(resource.address)

  msg := sprintf(
    "S3 bucket '%s' must have server-side encryption configured",
    [resource.address]
  )
}

has_s3_encryption(bucket_address) {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_server_side_encryption_configuration"
  contains(resource.address, bucket_address)
}

has_s3_encryption(bucket_address) {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  resource.address == bucket_address
  resource.change.after.server_side_encryption_configuration != null
}

# Deny security groups that allow 0.0.0.0/0 ingress on non-443 ports
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group"
  resource.change.actions[_] != "delete"

  ingress := resource.change.after.ingress[_]
  cidr := ingress.cidr_blocks[_]
  cidr == "0.0.0.0/0"

  ingress.from_port != 443
  ingress.to_port != 443

  msg := sprintf(
    "Security group '%s' allows ingress from 0.0.0.0/0 on port(s) %d-%d. Only port 443 is allowed for public access",
    [resource.address, ingress.from_port, ingress.to_port]
  )
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group_rule"
  resource.change.actions[_] != "delete"
  resource.change.after.type == "ingress"

  cidr := resource.change.after.cidr_blocks[_]
  cidr == "0.0.0.0/0"

  resource.change.after.from_port != 443
  resource.change.after.to_port != 443

  msg := sprintf(
    "Security group rule '%s' allows ingress from 0.0.0.0/0 on port(s) %d-%d. Only port 443 is allowed for public access",
    [resource.address, resource.change.after.from_port, resource.change.after.to_port]
  )
}

# Helper: common resource types that support tags
supports_tags(type) {
  taggable_types := {
    "aws_instance",
    "aws_s3_bucket",
    "aws_vpc",
    "aws_subnet",
    "aws_security_group",
    "aws_lb",
    "aws_ecs_cluster",
    "aws_ecs_service",
    "aws_ecs_task_definition",
    "aws_rds_cluster",
    "aws_db_instance",
    "aws_elasticache_cluster",
    "aws_lambda_function",
    "aws_iam_role",
    "aws_cloudwatch_log_group",
    "aws_secretsmanager_secret",
    "aws_kms_key",
    "aws_ecr_repository",
    "aws_sns_topic",
    "aws_sqs_queue",
  }
  taggable_types[type]
}
