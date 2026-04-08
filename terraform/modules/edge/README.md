# Edge Module

Terraform module that provisions the edge-layer infrastructure including CloudFront distribution with S3 SPA hosting and ALB API origin, regional WAF v2 for ALB protection, ACM certificates for TLS termination, and Route53 DNS records. The module expects CloudFront-specific resources (WAF Web ACL and ACM certificate) to be provisioned separately in `us-east-1` and passed in as variables.

<!-- BEGIN_TF_DOCS --><!-- END_TF_DOCS -->
