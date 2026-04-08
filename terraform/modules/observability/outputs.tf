################################################################################
# SNS
################################################################################

output "sns_topic_arn" {
  description = "ARN of the SNS topic used for alarm notifications"
  value       = aws_sns_topic.alarms.arn
}

################################################################################
# CloudTrail
################################################################################

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.main.arn
}

################################################################################
# CloudWatch
################################################################################

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

################################################################################
# GuardDuty
################################################################################

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

################################################################################
# AWS Config
################################################################################

output "config_recorder_id" {
  description = "ID of the AWS Config configuration recorder"
  value       = aws_config_configuration_recorder.main.id
}

################################################################################
# OpenSearch
################################################################################

output "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch domain (empty string if disabled)"
  value       = var.enable_opensearch ? aws_opensearch_domain.main[0].endpoint : ""
}
