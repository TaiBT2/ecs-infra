# Observability Module

This module provisions the observability and compliance stack for the ECS infrastructure, including monitoring, logging, auditing, and threat detection.

## Components

- **CloudWatch** -- Dashboard with key metrics, alarms with SNS notifications, encrypted log groups
- **CloudTrail** -- Management and S3 data event logging with KMS encryption and log file validation
- **OpenSearch** (optional) -- VPC-deployed domain for log analytics with encryption at rest and in transit
- **GuardDuty** -- Threat detection with S3 protection and findings published to SNS via EventBridge
- **AWS Config** -- Configuration recorder with managed rules for encryption and VPC flow log compliance
- **X-Ray** -- Distributed tracing with configurable sampling rate and KMS encryption

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
