################################################################################
# General
################################################################################

variable "project" {
  description = "Project name used in resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Domain & DNS
################################################################################

variable "domain_name" {
  description = "Primary domain name for the application (e.g. example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.domain_name))
    error_message = "domain_name must be a valid domain name."
  }
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS record creation"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))
    error_message = "route53_zone_id must be a valid Route53 hosted zone ID."
  }
}

variable "api_subdomain" {
  description = "Subdomain for the API endpoint (e.g. 'api' creates api.example.com). Leave empty to skip API DNS record."
  type        = string
  default     = ""
}

################################################################################
# ALB
################################################################################

variable "alb_dns_name" {
  description = "DNS name of the ALB to use as CloudFront origin for /api/* requests"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate with the regional WAF Web ACL"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "Route53 hosted zone ID of the ALB (required when api_subdomain is set)"
  type        = string
  default     = ""
}

################################################################################
# S3 SPA Bucket
################################################################################

variable "spa_kms_key_arn" {
  description = "ARN of the KMS key used for S3 SPA bucket encryption"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:", var.spa_kms_key_arn))
    error_message = "spa_kms_key_arn must be a valid KMS key ARN."
  }
}

################################################################################
# CloudFront
################################################################################

variable "cloudfront_aliases" {
  description = "List of CNAMEs (alternate domain names) for the CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "cloudfront_acm_certificate_arn" {
  description = "ARN of the ACM certificate in us-east-1 for CloudFront viewer certificate"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:us-east-1:", var.cloudfront_acm_certificate_arn))
    error_message = "cloudfront_acm_certificate_arn must be an ACM certificate ARN in us-east-1."
  }
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, or PriceClass_All)"
  type        = string
  default     = "PriceClass_200"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "cloudfront_log_bucket" {
  description = "Domain name of the S3 bucket for CloudFront access logs (e.g. my-logs-bucket.s3.amazonaws.com)"
  type        = string
  default     = ""
}

variable "cloudfront_log_prefix" {
  description = "Prefix for CloudFront access log keys in the logging bucket"
  type        = string
  default     = "cloudfront/"
}

variable "cloudfront_waf_acl_arn" {
  description = "ARN of the WAF Web ACL (CLOUDFRONT scope, us-east-1) to associate with the CloudFront distribution"
  type        = string
  default     = ""
}

################################################################################
# WAF (Regional - for ALB)
################################################################################

variable "waf_rate_limit" {
  description = "Maximum number of requests allowed from a single IP in a 5-minute period (regional WAF)"
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100
    error_message = "waf_rate_limit must be at least 100."
  }
}

################################################################################
# ACM (Regional - for ALB)
################################################################################

variable "create_regional_certificate" {
  description = "Whether to create a regional ACM certificate for ALB"
  type        = bool
  default     = true
}
