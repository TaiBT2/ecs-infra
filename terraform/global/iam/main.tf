################################################################################
# GitHub OIDC Provider
################################################################################

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = merge(var.tags, {
    Name = "${var.project}-github-oidc"
  })
}

################################################################################
# IAM Roles — GitHub Actions Deploy (per environment)
################################################################################

resource "aws_iam_role" "github_actions" {
  for_each = var.environments

  name = "${var.project}-${each.key}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:${each.value.sub_filter}"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project}-${each.key}-github-actions"
    Environment = each.key
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  for_each = var.environments

  role       = aws_iam_role.github_actions[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

  # NOTE: In production, scope this down to least-privilege policies.
}
