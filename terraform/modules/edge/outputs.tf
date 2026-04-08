################################################################################
# CloudFront
################################################################################

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

################################################################################
# S3 SPA Bucket
################################################################################

output "spa_bucket_name" {
  description = "Name of the S3 bucket used for SPA static hosting"
  value       = aws_s3_bucket.spa.id
}

output "spa_bucket_arn" {
  description = "ARN of the S3 bucket used for SPA static hosting"
  value       = aws_s3_bucket.spa.arn
}

################################################################################
# WAF
################################################################################

output "waf_web_acl_arn" {
  description = "ARN of the regional WAF Web ACL (for ALB association)"
  value       = aws_wafv2_web_acl.regional.arn
}

################################################################################
# ACM
################################################################################

output "acm_certificate_arn" {
  description = "ARN of the regional ACM certificate (for ALB)"
  value       = try(aws_acm_certificate.regional[0].arn, null)
}

################################################################################
# Route53
################################################################################

output "route53_records" {
  description = "Map of Route53 record names to their FQDNs"
  value = merge(
    {
      cloudfront = aws_route53_record.cloudfront.fqdn
    },
    var.api_subdomain != "" && var.alb_dns_name != "" ? {
      api = aws_route53_record.api[0].fqdn
    } : {}
  )
}
