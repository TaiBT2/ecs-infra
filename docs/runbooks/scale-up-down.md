# Runbook: Scale Up/Down Resources

## Purpose & When to Use

This runbook guides scaling system resources up or down. Use when:

- Traffic spikes unexpectedly, requiring additional ECS tasks
- CPU/Memory usage is consistently high (>80%)
- Preparing for an expected high-traffic event (flash sale, marketing campaign)
- Reducing costs by scaling down unnecessary resources
- RDS needs a larger instance class due to degraded query performance
- Additional read replicas are needed for read-heavy workloads

## Prerequisites

- AWS CLI configured with ECS, RDS, Application Auto Scaling permissions (`aws sts get-caller-identity`)
- Terraform installed (for auto scaling policy changes)
- Understanding of instance types and pricing
- For RDS scaling: confirm maintenance window or accept brief downtime

## Detailed Steps

### 1. Scale ECS Service

#### 1a. Manual scaling (fastest)

```bash
# Check current status
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount,cpu:deployments[0].networkConfiguration}' \
  --output table

# Increase the number of tasks (e.g., from 3 to 6)
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --desired-count 6

echo "Scaling up to 6 tasks..."

# Wait for new tasks to be ready
aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service

echo "Scaling complete!"
```

```bash
# Decrease the number of tasks when no longer needed (e.g., back to 3)
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --desired-count 3
```

#### 1b. Update Auto Scaling min/max via Terraform

```bash
cd terraform/envs/prod

# Edit auto scaling variables in terraform.tfvars
# ecs_min_tasks = 3  -> 6
# ecs_max_tasks = 10 -> 20
# Or edit directly in the module

terraform plan -target=module.compute.aws_appautoscaling_target.ecs_target \
  -out=scale.tfplan

terraform apply scale.tfplan
```

Or update directly via AWS CLI:

```bash
# Update auto scaling target (min/max capacity)
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/myapp-prod-cluster/myapp-prod-api-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 6 \
  --max-capacity 20

echo "Auto scaling min=6, max=20 has been updated."
```

#### 1c. Adjust Auto Scaling Policy

```bash
# View current policies
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/myapp-prod-cluster/myapp-prod-api-service \
  --output json

# Update target tracking policy (e.g., lower CPU target to scale sooner)
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/myapp-prod-cluster/myapp-prod-api-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name myapp-prod-cpu-target-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 60.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleInCooldown": 300,
    "ScaleOutCooldown": 60
  }'
```

### 2. Scale RDS

#### 2a. Change Instance Class (Vertical Scaling)

**Note**: Changing instance class causes brief downtime (~5-10 minutes for Multi-AZ).

```bash
# Check current instance class
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Class:DBInstanceClass,Storage:AllocatedStorage,IOPS:Iops,MultiAZ:MultiAZ}' \
  --output table

# Scale up to a larger instance class
# Option 1: Apply during maintenance window (lower risk)
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --db-instance-class db.r6g.xlarge \
  --apply-immediately false

echo "Change will be applied during the next maintenance window."

# Option 2: Apply immediately (causes brief downtime)
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --db-instance-class db.r6g.xlarge \
  --apply-immediately

echo "Applying change now. There will be brief downtime (~5-10 minutes)."
```

```bash
# Monitor modification progress
watch -n 15 "aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Class:DBInstanceClass,PendingModifications:PendingModifiedValues}' \
  --output table"
```

#### 2b. Add Read Replica (Horizontal Read Scaling)

```bash
# Create a read replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier myapp-prod-rds-read-1 \
  --source-db-instance-identifier myapp-prod-rds-main \
  --db-instance-class db.r6g.large \
  --availability-zone us-east-1b \
  --no-publicly-accessible

echo "Creating read replica. The process may take 15-30 minutes."

# Wait for the replica to be ready
aws rds wait db-instance-available \
  --db-instance-identifier myapp-prod-rds-read-1

echo "Read replica is ready!"

# Get the read replica endpoint
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-read-1 \
  --query 'DBInstances[0].Endpoint.{Address:Address,Port:Port}' \
  --output table
```

#### 2c. Increase Storage

```bash
# Increase storage (no downtime, but cannot be reduced afterward)
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --allocated-storage 200 \
  --apply-immediately

echo "Increasing storage. The process runs online with no downtime."
```

### 3. Pre-scaling for Expected Traffic Spikes

Perform **at least 30 minutes before** the expected traffic increase.

```bash
# Step 1: Scale ECS first
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --desired-count 10

# Step 2: Increase auto scaling limits
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/myapp-prod-cluster/myapp-prod-api-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 10 \
  --max-capacity 30

# Step 3: Wait for all tasks to be ready
aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service

# Step 4: Warm up CloudFront cache if needed
# curl -s https://<DOMAIN>/critical-page-1 > /dev/null
# curl -s https://<DOMAIN>/critical-page-2 > /dev/null

echo "Pre-scaling complete. System is ready for high traffic."
```

**After the event — scale down:**

```bash
# Return to normal configuration
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/myapp-prod-cluster/myapp-prod-api-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 3 \
  --max-capacity 10

aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --desired-count 3

echo "Scale down complete."
```

## Verification

```bash
# Check ECS service after scaling
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount,pending:pendingCount}' \
  --output table

# Check all tasks are healthy
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --query 'TargetHealthDescriptions[].{target:Target.Id,health:TargetHealth.State}' \
  --output table

# Check auto scaling target
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/myapp-prod-cluster/myapp-prod-api-service \
  --query 'ScalableTargets[0].{Min:MinCapacity,Max:MaxCapacity}' \
  --output table

# Check RDS after scaling
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Class:DBInstanceClass,Storage:AllocatedStorage}' \
  --output table

# Check application performance
curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" https://<DOMAIN>/api/health
```

## Rollback

- **ECS scale up**: Reduce desired count to the previous value with `aws ecs update-service --desired-count <OLD_COUNT>`
- **RDS instance class**: Modify back to the previous instance class (causes additional brief downtime)
- **Read replica**: Delete the replica if not needed: `aws rds delete-db-instance --db-instance-identifier myapp-prod-rds-read-1 --skip-final-snapshot`
- **Auto scaling policy**: Restore the previous policy via Terraform or AWS CLI

## Escalation

| Condition | Escalate to |
|-----------|-------------|
| ECS tasks unable to start (resource limits) | DevOps Lead — check Fargate quotas/limits |
| RDS modification is stuck | DBA + AWS Support |
| Auto scaling not responding fast enough to traffic | DevOps Lead — review scaling policy |
| Costs increase significantly after scaling | Engineering Manager + FinOps |
| Need to increase AWS service quotas | DevOps Lead — open a Support case at AWS |
