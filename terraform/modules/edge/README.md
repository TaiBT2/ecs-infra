# Edge Module

Terraform module that provisions the edge-layer infrastructure including CloudFront distribution with S3 SPA hosting and ALB API origin, regional WAF v2 for ALB protection, ACM certificates for TLS termination, and Route53 DNS records. The module expects CloudFront-specific resources (WAF Web ACL and ACM certificate) to be provisioned separately in `us-east-1` and passed in as variables.

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
| [aws_acm_certificate.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_control.spa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_route53_record.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.spa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.spa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.spa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.spa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.spa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_wafv2_web_acl.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_cloudfront_cache_policy.managed_caching_disabled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_cache_policy.managed_caching_optimized](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_origin_request_policy.managed_all_viewer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_origin_request_policy) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_arn"></a> [alb\_arn](#input\_alb\_arn) | ARN of the ALB to associate with the regional WAF Web ACL | `string` | `""` | no |
| <a name="input_alb_dns_name"></a> [alb\_dns\_name](#input\_alb\_dns\_name) | DNS name of the ALB to use as CloudFront origin for /api/* requests | `string` | n/a | yes |
| <a name="input_alb_zone_id"></a> [alb\_zone\_id](#input\_alb\_zone\_id) | Route53 hosted zone ID of the ALB (required when api\_subdomain is set) | `string` | `""` | no |
| <a name="input_api_subdomain"></a> [api\_subdomain](#input\_api\_subdomain) | Subdomain for the API endpoint (e.g. 'api' creates api.example.com). Leave empty to skip API DNS record. | `string` | `""` | no |
| <a name="input_cloudfront_acm_certificate_arn"></a> [cloudfront\_acm\_certificate\_arn](#input\_cloudfront\_acm\_certificate\_arn) | ARN of the ACM certificate in us-east-1 for CloudFront viewer certificate | `string` | n/a | yes |
| <a name="input_cloudfront_aliases"></a> [cloudfront\_aliases](#input\_cloudfront\_aliases) | List of CNAMEs (alternate domain names) for the CloudFront distribution | `list(string)` | `[]` | no |
| <a name="input_cloudfront_log_bucket"></a> [cloudfront\_log\_bucket](#input\_cloudfront\_log\_bucket) | Domain name of the S3 bucket for CloudFront access logs (e.g. my-logs-bucket.s3.amazonaws.com) | `string` | `""` | no |
| <a name="input_cloudfront_log_prefix"></a> [cloudfront\_log\_prefix](#input\_cloudfront\_log\_prefix) | Prefix for CloudFront access log keys in the logging bucket | `string` | `"cloudfront/"` | no |
| <a name="input_cloudfront_price_class"></a> [cloudfront\_price\_class](#input\_cloudfront\_price\_class) | CloudFront price class (PriceClass\_100, PriceClass\_200, or PriceClass\_All) | `string` | `"PriceClass_200"` | no |
| <a name="input_cloudfront_waf_acl_arn"></a> [cloudfront\_waf\_acl\_arn](#input\_cloudfront\_waf\_acl\_arn) | ARN of the WAF Web ACL (CLOUDFRONT scope, us-east-1) to associate with the CloudFront distribution | `string` | `""` | no |
| <a name="input_create_regional_certificate"></a> [create\_regional\_certificate](#input\_create\_regional\_certificate) | Whether to create a regional ACM certificate for ALB | `bool` | `true` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Primary domain name for the application (e.g. example.com) | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name used in resource naming | `string` | n/a | yes |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 hosted zone ID for DNS record creation | `string` | n/a | yes |
| <a name="input_spa_kms_key_arn"></a> [spa\_kms\_key\_arn](#input\_spa\_kms\_key\_arn) | ARN of the KMS key used for S3 SPA bucket encryption | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_waf_rate_limit"></a> [waf\_rate\_limit](#input\_waf\_rate\_limit) | Maximum number of requests allowed from a single IP in a 5-minute period (regional WAF) | `number` | `2000` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | ARN of the regional ACM certificate (for ALB) |
| <a name="output_cloudfront_distribution_id"></a> [cloudfront\_distribution\_id](#output\_cloudfront\_distribution\_id) | ID of the CloudFront distribution |
| <a name="output_cloudfront_domain_name"></a> [cloudfront\_domain\_name](#output\_cloudfront\_domain\_name) | Domain name of the CloudFront distribution |
| <a name="output_route53_records"></a> [route53\_records](#output\_route53\_records) | Map of Route53 record names to their FQDNs |
| <a name="output_spa_bucket_arn"></a> [spa\_bucket\_arn](#output\_spa\_bucket\_arn) | ARN of the S3 bucket used for SPA static hosting |
| <a name="output_spa_bucket_name"></a> [spa\_bucket\_name](#output\_spa\_bucket\_name) | Name of the S3 bucket used for SPA static hosting |
| <a name="output_waf_web_acl_arn"></a> [waf\_web\_acl\_arn](#output\_waf\_web\_acl\_arn) | ARN of the regional WAF Web ACL (for ALB association) |
<!-- END_TF_DOCS -->
