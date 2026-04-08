# Runbook: Cost Optimization

## Purpose & When to Use

This runbook guides AWS cost optimization activities. Use when:

- Monthly cost review (performed regularly at the beginning of each month)
- Costs have increased unexpectedly compared to the previous month
- Preparing a cost report for management
- Looking for wasted or unoptimized resources
- Evaluating Reserved Instances or Savings Plans
- Need to reduce costs as requested by leadership

## Prerequisites

- AWS CLI configured with Cost Explorer, EC2, RDS, S3, CloudWatch permissions (`aws sts get-caller-identity`)
- Permissions: `ce:GetCostAndUsage`, `ce:GetRightsizingRecommendation`
- Cost Explorer has been enabled in the AWS Account
- Tags have been enforced: `Project`, `Environment`, `CostCenter`
- Access to AWS Console for visual dashboards

## Detailed Steps

### 1. Monthly Cost Explorer Review

**Step 1: View current month total cost and compare:**

```bash
# Current month cost
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --output json

# Previous month cost
LAST_MONTH_START=$(date -u -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d)
LAST_MONTH_END=$(date -u +%Y-%m-01)
aws ce get-cost-and-usage \
  --time-period Start=$LAST_MONTH_START,End=$LAST_MONTH_END \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --output json
```

**Step 2: Cost by service (top 10):**

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d),End=$(date -u +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json | python3 -c "
import sys, json
data = json.load(sys.stdin)
groups = data['ResultsByTime'][0]['Groups']
sorted_groups = sorted(groups, key=lambda x: float(x['Metrics']['BlendedCost']['Amount']), reverse=True)
print(f'{'Service':<50} {'Cost (USD)':>12}')
print('-' * 64)
for g in sorted_groups[:10]:
    name = g['Keys'][0]
    cost = float(g['Metrics']['BlendedCost']['Amount'])
    print(f'{name:<50} {cost:>12.2f}')
"
```

**Step 3: Cost by environment:**

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d),End=$(date -u +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment \
  --output json
```

### 2. Detect Wasted Resources

**2a. Unused Elastic IPs:**

```bash
# Find EIPs not attached to any instance
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].{IP:PublicIp,AllocationId:AllocationId}' \
  --output table

# Release unused EIPs (saves ~$3.65/month per EIP)
# aws ec2 release-address --allocation-id <ALLOCATION_ID>
```

**2b. Unattached EBS Volumes:**

```bash
# Find unattached volumes
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[].{VolumeId:VolumeId,Size:Size,Type:VolumeType,Created:CreateTime}' \
  --output table

# Delete unneeded volumes (snapshot first if needed)
# aws ec2 create-snapshot --volume-id <VOLUME_ID> --description "Backup before delete"
# aws ec2 delete-volume --volume-id <VOLUME_ID>
```

**2c. Old Snapshots:**

```bash
# Find snapshots older than 90 days
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[?StartTime<='$(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%S)'].{SnapshotId:SnapshotId,Size:VolumeSize,Created:StartTime,Description:Description}" \
  --output table

# Delete old snapshots (after confirming they are not needed)
# aws ec2 delete-snapshot --snapshot-id <SNAPSHOT_ID>
```

**2d. Load Balancers with no targets:**

```bash
# Check ALBs with empty target groups
for tg_arn in $(aws elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' --output text); do
  health=$(aws elbv2 describe-target-health --target-group-arn $tg_arn --query 'TargetHealthDescriptions' --output text)
  if [ -z "$health" ]; then
    echo "Empty Target Group: $tg_arn"
  fi
done
```

### 3. RDS Rightsizing with Performance Insights

```bash
# Check average RDS CPU utilization (30 days)
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod-rds-main \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum \
  --output json

# Check freeable memory
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeableMemory \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod-rds-main \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Minimum \
  --output json

# Check database connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod-rds-main \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum \
  --output json
```

**Rightsizing recommendations:**
- Average CPU < 20% consistently for 30 days: consider downgrading instance class
- Freeable memory > 50% consistently: a smaller instance class may be sufficient
- Max connections < 50% of max_connections: instance may be oversized

### 4. ECS Rightsizing with Container Insights

```bash
# Check ECS service CPU utilization (30 days)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=myapp-prod-cluster Name=ServiceName,Value=myapp-prod-api-service \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum \
  --output json

# Check Memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ClusterName,Value=myapp-prod-cluster Name=ServiceName,Value=myapp-prod-api-service \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum \
  --output json
```

**ECS rightsizing recommendations:**
- Average CPU < 30%: reduce task CPU allocation
- Average memory < 40%: reduce task memory allocation
- Update the task definition in Terraform after confirming

### 5. Reserved Instances / Savings Plans

```bash
# View RI recommendations
aws ce get-reservation-purchase-recommendation \
  --service "Amazon Relational Database Service" \
  --term-in-years ONE_YEAR \
  --payment-option ALL_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS \
  --output json

# View Savings Plans recommendations
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option ALL_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS \
  --output json

# Check current Savings Plans coverage
aws ce get-savings-plans-coverage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d),End=$(date -u +%Y-%m-01) \
  --granularity MONTHLY \
  --output json
```

**Evaluation checklist:**
- [ ] RDS: If running > 12 months, purchase RI (saves 30-60%)
- [ ] ECS Fargate: Compute Savings Plans (saves 20-30%)
- [ ] Compare 1-year vs 3-year, No Upfront vs All Upfront

### 6. S3 Lifecycle Policies

```bash
# List all S3 buckets and storage size
for bucket in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  size=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/S3 \
    --metric-name BucketSizeBytes \
    --dimensions Name=BucketName,Value=$bucket Name=StorageType,Value=StandardStorage \
    --start-time $(date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 86400 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text 2>/dev/null)
  if [ "$size" != "None" ] && [ -n "$size" ]; then
    size_gb=$(echo "scale=2; $size / 1073741824" | bc)
    echo "Bucket: $bucket - Size: ${size_gb} GB"
  fi
done

# Check current lifecycle policies
aws s3api get-bucket-lifecycle-configuration \
  --bucket myapp-prod-assets 2>/dev/null || echo "No lifecycle policy configured"
```

**Recommended lifecycle policy:**

```json
{
  "Rules": [
    {
      "ID": "TransitionToIA",
      "Status": "Enabled",
      "Transitions": [
        {"Days": 30, "StorageClass": "STANDARD_IA"},
        {"Days": 90, "StorageClass": "GLACIER"},
        {"Days": 365, "StorageClass": "DEEP_ARCHIVE"}
      ],
      "Filter": {"Prefix": "logs/"}
    },
    {
      "ID": "DeleteOldLogs",
      "Status": "Enabled",
      "Expiration": {"Days": 730},
      "Filter": {"Prefix": "logs/"}
    }
  ]
}
```

### 7. NAT Gateway Cost Optimization

NAT Gateway is one of the largest hidden costs (~$32/month + $0.045/GB data processed).

```bash
# Check NAT Gateway data processed
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=<NAT_GW_ID> \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Sum \
  --output json
```

**Optimization strategies:**
- Use **VPC Endpoints** for S3, DynamoDB, ECR, CloudWatch, Secrets Manager (reduces traffic through NAT)
- Check whether the Terraform `networking` module has VPC endpoints configured
- Dev environment: can use 1 NAT Gateway instead of 1 per AZ
- Consider a NAT Instance (t3.micro) for dev if traffic is low

### 8. Dev Environment Scheduling

Shut down dev resources outside working hours (saves ~65% of dev costs).

```bash
# Scale down ECS dev service (evenings/weekends)
aws ecs update-service \
  --cluster myapp-dev-cluster \
  --service myapp-dev-api-service \
  --desired-count 0

# Scale back up the next morning
aws ecs update-service \
  --cluster myapp-dev-cluster \
  --service myapp-dev-api-service \
  --desired-count 1

# Stop RDS dev instance (if not needed)
aws rds stop-db-instance \
  --db-instance-identifier myapp-dev-rds-main
# Note: RDS automatically restarts after 7 days

# Start RDS dev instance
aws rds start-db-instance \
  --db-instance-identifier myapp-dev-rds-main
```

**Automate with EventBridge + Lambda or cron in CI/CD:**

```bash
# Example: Create an EventBridge rule to stop dev at 20:00 UTC daily
aws events put-rule \
  --name "stop-dev-environment" \
  --schedule-expression "cron(0 20 ? * MON-FRI *)" \
  --state ENABLED

# Create a rule to start dev at 07:00 UTC daily
aws events put-rule \
  --name "start-dev-environment" \
  --schedule-expression "cron(0 7 ? * MON-FRI *)" \
  --state ENABLED
```

## Verification

```bash
# Confirm cost trend is decreasing (compare last 2 months)
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01) -2 months" +%Y-%m-%d),End=$(date -u +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --output json

# Check for no wasted EIPs or volumes
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]' --output text
aws ec2 describe-volumes --filters Name=status,Values=available --output text

# Check S3 lifecycle policies are active
aws s3api get-bucket-lifecycle-configuration --bucket myapp-prod-assets

# Confirm dev environment is shut down outside working hours
aws ecs describe-services \
  --cluster myapp-dev-cluster \
  --services myapp-dev-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount}'
```

## Rollback

- **Rightsizing RDS/ECS**: Scale back up if performance is affected (see [scale-up-down.md](scale-up-down.md))
- **S3 Lifecycle**: Delete or disable the lifecycle rule: `aws s3api delete-bucket-lifecycle --bucket <BUCKET>`
- **Dev scheduling**: Start dev resources again if the team needs them: `aws ecs update-service --desired-count 1`
- **Savings Plans/RI**: Cannot be canceled after purchase — evaluate carefully before committing

## Escalation

| Condition | Escalate to |
|-----------|-------------|
| Costs increased > 20% compared to the previous month with no clear cause | Engineering Manager + FinOps |
| Need to purchase Reserved Instances / Savings Plans | Engineering Manager + Finance (approval required) |
| Rightsizing causes performance degradation | Team Lead + DevOps Lead |
| Resources found without tags (owner cannot be identified) | DevOps Lead — enforce tagging policy |
| Need to increase AWS service quotas for optimization | DevOps Lead — open an AWS Support case |
