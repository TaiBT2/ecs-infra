# Networking Module

Terraform module that provisions the core networking infrastructure for a 3-tier AWS architecture in `ap-southeast-1`. It creates a VPC with public, application, and data subnets across multiple availability zones, along with NAT Gateways, an Internet Gateway, route tables, VPC Flow Logs, and VPC endpoints for AWS services.

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
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.app_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.data_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_ingress_rule.vpc_endpoints_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_subnet_cidrs"></a> [app\_subnet\_cidrs](#input\_app\_subnet\_cidrs) | CIDR blocks for app-tier private subnets (ECS Fargate). Must match the number of availability\_zones. | `list(string)` | <pre>[<br/>  "10.0.16.0/22",<br/>  "10.0.20.0/22",<br/>  "10.0.24.0/22"<br/>]</pre> | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones to use (e.g. ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]) | `list(string)` | <pre>[<br/>  "ap-southeast-1a",<br/>  "ap-southeast-1b",<br/>  "ap-southeast-1c"<br/>]</pre> | no |
| <a name="input_data_subnet_cidrs"></a> [data\_subnet\_cidrs](#input\_data\_subnet\_cidrs) | CIDR blocks for data-tier private subnets (RDS, ElastiCache). Must match the number of availability\_zones. | `list(string)` | <pre>[<br/>  "10.0.32.0/22",<br/>  "10.0.36.0/22",<br/>  "10.0.40.0/22"<br/>]</pre> | no |
| <a name="input_enable_vpc_endpoints"></a> [enable\_vpc\_endpoints](#input\_enable\_vpc\_endpoints) | Whether to create VPC endpoints | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment | `string` | n/a | yes |
| <a name="input_flow_log_cloudwatch_log_group_arn"></a> [flow\_log\_cloudwatch\_log\_group\_arn](#input\_flow\_log\_cloudwatch\_log\_group\_arn) | ARN of the CloudWatch Log Group for VPC Flow Logs | `string` | n/a | yes |
| <a name="input_flow_log_iam_role_arn"></a> [flow\_log\_iam\_role\_arn](#input\_flow\_log\_iam\_role\_arn) | ARN of the IAM role that allows VPC Flow Logs to publish to CloudWatch | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name used in resource naming | `string` | n/a | yes |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | CIDR blocks for public subnets (ALB, NAT, IGW). Must match the number of availability\_zones. | `list(string)` | <pre>[<br/>  "10.0.0.0/22",<br/>  "10.0.4.0/22",<br/>  "10.0.8.0/22"<br/>]</pre> | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use a single NAT Gateway instead of one per AZ (cost savings for non-prod) | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_subnet_ids"></a> [app\_subnet\_ids](#output\_app\_subnet\_ids) | List of app-tier private subnet IDs |
| <a name="output_data_subnet_ids"></a> [data\_subnet\_ids](#output\_data\_subnet\_ids) | List of data-tier private subnet IDs |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | List of NAT Gateway IDs |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of public subnet IDs |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | CIDR block of the VPC |
| <a name="output_vpc_endpoint_sg_id"></a> [vpc\_endpoint\_sg\_id](#output\_vpc\_endpoint\_sg\_id) | Security group ID for VPC interface endpoints |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
<!-- END_TF_DOCS -->
