################################################################################
# Local Values
################################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"

  # Build a map keyed by AZ for subnet iteration
  az_map = { for idx, az in var.availability_zones : az => idx }

  # Determine how many NAT Gateways to create
  nat_keys = var.single_nat_gateway ? { (var.availability_zones[0]) = 0 } : local.az_map

  # Interface VPC endpoints to create
  interface_endpoints = {
    ecr_api        = "com.amazonaws.ap-southeast-1.ecr.api"
    ecr_dkr        = "com.amazonaws.ap-southeast-1.ecr.dkr"
    kms            = "com.amazonaws.ap-southeast-1.kms"
    secretsmanager = "com.amazonaws.ap-southeast-1.secretsmanager"
    logs           = "com.amazonaws.ap-southeast-1.logs"
    ssm            = "com.amazonaws.ap-southeast-1.ssm"
    ssmmessages    = "com.amazonaws.ap-southeast-1.ssmmessages"
    ec2messages    = "com.amazonaws.ap-southeast-1.ec2messages"
  }

  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

################################################################################
# Subnets - Public (ALB, NAT, IGW)
################################################################################

resource "aws_subnet" "public" {
  for_each = local.az_map

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[each.value]
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  })
}

################################################################################
# Subnets - App Private (ECS Fargate)
################################################################################

resource "aws_subnet" "app" {
  for_each = local.az_map

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.app_subnet_cidrs[each.value]
  availability_zone = each.key

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-${each.key}"
    Tier = "app"
  })
}

################################################################################
# Subnets - Data Private (RDS, ElastiCache)
################################################################################

resource "aws_subnet" "data" {
  for_each = local.az_map

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.data_subnet_cidrs[each.value]
  availability_zone = each.key

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-data-${each.key}"
    Tier = "data"
  })
}

################################################################################
# Elastic IPs for NAT Gateways
################################################################################

resource "aws_eip" "nat" {
  for_each = local.nat_keys

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# NAT Gateways
################################################################################

resource "aws_nat_gateway" "this" {
  for_each = local.nat_keys

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# Route Table - Public
################################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = local.az_map

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

################################################################################
# Route Tables - App Private (one per AZ when multi-NAT, shared when single)
################################################################################

resource "aws_route_table" "app" {
  for_each = local.az_map

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-rt-${each.key}"
    Tier = "app"
  })
}

resource "aws_route" "app_nat" {
  for_each = local.az_map

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[var.availability_zones[0]].id : aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "app" {
  for_each = local.az_map

  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

################################################################################
# Route Tables - Data Private
################################################################################

resource "aws_route_table" "data" {
  for_each = local.az_map

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-data-rt-${each.key}"
    Tier = "data"
  })
}

resource "aws_route" "data_nat" {
  for_each = local.az_map

  route_table_id         = aws_route_table.data[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[var.availability_zones[0]].id : aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "data" {
  for_each = local.az_map

  subnet_id      = aws_subnet.data[each.key].id
  route_table_id = aws_route_table.data[each.key].id
}

################################################################################
# VPC Flow Logs
################################################################################

resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = var.flow_log_cloudwatch_log_group_arn
  iam_role_arn         = var.flow_log_iam_role_arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-log"
  })
}

################################################################################
# VPC Endpoint - S3 Gateway
################################################################################

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.ap-southeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    [aws_route_table.public.id],
    [for rt in aws_route_table.app : rt.id],
    [for rt in aws_route_table.data : rt.id],
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-s3"
  })
}

################################################################################
# Security Group for Interface VPC Endpoints
################################################################################

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name        = "${local.name_prefix}-vpce-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count = var.enable_vpc_endpoints ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "HTTPS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = aws_vpc.this.cidr_block

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-sg-ingress"
  })
}

################################################################################
# VPC Interface Endpoints
################################################################################

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_vpc_endpoints ? local.interface_endpoints : {}

  vpc_id              = aws_vpc.this.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [for s in aws_subnet.app : s.id]
  security_group_ids = [aws_security_group.vpc_endpoints[0].id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-${each.key}"
  })
}
