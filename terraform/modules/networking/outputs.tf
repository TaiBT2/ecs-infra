################################################################################
# VPC
################################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

################################################################################
# Subnets
################################################################################

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "app_subnet_ids" {
  description = "List of app-tier private subnet IDs"
  value       = [for s in aws_subnet.app : s.id]
}

output "data_subnet_ids" {
  description = "List of data-tier private subnet IDs"
  value       = [for s in aws_subnet.data : s.id]
}

################################################################################
# NAT Gateway
################################################################################

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = [for ng in aws_nat_gateway.this : ng.id]
}

################################################################################
# VPC Endpoints
################################################################################

output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC interface endpoints"
  value       = try(aws_security_group.vpc_endpoints[0].id, null)
}
