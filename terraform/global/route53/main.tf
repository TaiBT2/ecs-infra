################################################################################
# Route 53 — Public Hosted Zone
################################################################################

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(var.tags, {
    Name = var.domain_name
  })
}
