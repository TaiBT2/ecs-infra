output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "role_arns" {
  description = "Map of environment name to GitHub Actions IAM role ARN"
  value       = { for env, role in aws_iam_role.github_actions : env => role.arn }
}
