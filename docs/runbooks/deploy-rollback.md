# Runbook: Deploy Rollback

## Purpose & When to Use

This runbook guides the deployment rollback process when a new version causes errors or incidents. Use when:

- A new deployment causes increased error rate or latency
- Health checks continuously fail after deployment
- A critical bug is discovered in the new version
- Need to revert to the previous stable version as quickly as possible

## Prerequisites

- AWS CLI configured with appropriate ECS, IAM permissions (`aws sts get-caller-identity`)
- Know the cluster name and service name to roll back
- Terraform installed (if Terraform state rollback is needed)
- Git access to the `infra-ecs` repository

## Detailed Steps

### Option A: Rollback ECS Task Definition

The fastest option — only rolls back the container/task definition without changing infrastructure.

**Step 1: Identify the current and previous task definitions:**

```bash
# Get the current task definition of the service
CURRENT_TASK_DEF=$(aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].taskDefinition' \
  --output text)

echo "Current task definition: $CURRENT_TASK_DEF"

# Get the current revision number
CURRENT_REVISION=$(echo $CURRENT_TASK_DEF | grep -o '[0-9]*$')
echo "Current revision: $CURRENT_REVISION"

# Calculate the previous revision
PREVIOUS_REVISION=$((CURRENT_REVISION - 1))
TASK_DEF_FAMILY=$(echo $CURRENT_TASK_DEF | sed "s/:${CURRENT_REVISION}$//")
PREVIOUS_TASK_DEF="${TASK_DEF_FAMILY}:${PREVIOUS_REVISION}"
echo "Previous task definition: $PREVIOUS_TASK_DEF"
```

**Step 2: Verify the previous task definition exists and is valid:**

```bash
# Check the previous task definition
aws ecs describe-task-definition \
  --task-definition $PREVIOUS_TASK_DEF \
  --query 'taskDefinition.{family:family,revision:revision,status:status,image:containerDefinitions[0].image}' \
  --output table
```

**Step 3: Roll back the service to the previous task definition:**

```bash
# Update the service to use the old task definition
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --task-definition $PREVIOUS_TASK_DEF \
  --force-new-deployment \
  --output json

echo "Rollback started. Waiting for deployment to stabilize..."
```

**Step 4: Wait for deployment to stabilize:**

```bash
# Wait for service to become stable (timeout 10 minutes)
aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service

echo "Service has stabilized!"
```

**Step 5: Check deployment status:**

```bash
# Confirm only 1 ACTIVE deployment (PRIMARY)
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].deployments[].{status:status,taskDef:taskDefinition,running:runningCount,desired:desiredCount,rollout:rolloutState}' \
  --output table
```

### Option B: Rollback Terraform State

Use when infrastructure changes need to be rolled back (VPC, RDS, ALB, etc.).

**Step 1: Check current Terraform state:**

```bash
cd terraform/envs/prod

# Pull current state
terraform state pull > /tmp/terraform-state-backup-$(date +%Y%m%d%H%M%S).json
echo "State backed up at /tmp/terraform-state-backup-*.json"

# View resources in state
terraform state list
```

**Step 2: Plan to check changes:**

```bash
# Check what Terraform will change compared to the current state
terraform plan -out=rollback.tfplan

# Review the plan carefully before applying
```

**Step 3a: Rollback specific resources (targeted):**

```bash
# If only 1-2 specific resources need to be rolled back
# Example: rollback only the ECS service
terraform plan -target=module.compute.aws_ecs_service.api -out=rollback.tfplan
terraform apply rollback.tfplan
```

**Step 3b: Full rollback via git revert:**

```bash
# Find the commit that caused the issue
git log --oneline -10

# Revert that commit
git revert <COMMIT_HASH> --no-edit

# Review changes
git diff HEAD~1

# Push and wait for CI/CD to apply
git push origin main

# OR apply manually if CI/CD is not working
cd terraform/envs/prod
terraform init
terraform plan -out=rollback.tfplan
terraform apply rollback.tfplan
```

**Step 3c: Full state rollback (emergency situation):**

```bash
# WARNING: Only use when other options are not effective
# Make sure you backed up the current state in Step 1

# Find the state file backup on S3 (if versioning is enabled)
aws s3api list-object-versions \
  --bucket myapp-terraform-state \
  --prefix prod/terraform.tfstate \
  --query 'Versions[0:5].{VersionId:VersionId,Modified:LastModified,Size:Size}' \
  --output table

# Restore a specific state version
aws s3api get-object \
  --bucket myapp-terraform-state \
  --key prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  /tmp/restored-state.json

# Push restored state
terraform state push /tmp/restored-state.json

# Plan and apply
terraform plan -out=rollback.tfplan
terraform apply rollback.tfplan
```

## Verification

```bash
# Check ECS service is healthy
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount,taskDef:taskDefinition}'

# Check ALB targets
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --query 'TargetHealthDescriptions[].{id:Target.Id,health:TargetHealth.State}'

# Check application endpoint
curl -sf https://<DOMAIN>/api/health && echo "OK" || echo "FAIL"

# Check that error rate has decreased
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum

# Check logs for no new errors
aws logs tail /ecs/myapp-prod-api --since 5m --filter-pattern "ERROR"
```

## Rollback

If the rollback itself causes issues:

1. **ECS**: Revert to the most recent working task definition by repeating Option A with a different revision
2. **Terraform**: Restore state from S3 versioned backup (Step 3c of Option B)
3. If neither works, escalate immediately

## Escalation

| Condition | Escalate to |
|-----------|-------------|
| ECS rollback unsuccessful after 15 minutes | Team Lead + Senior DevOps |
| Terraform state is corrupt or has significant drift | Senior DevOps + Infrastructure Lead |
| Rollback affects data integrity | DBA + Engineering Manager |
| Unclear which revision is safe to roll back to | Team Lead — check deployment history and release notes |
| AWS Support needed | Open a case at https://console.aws.amazon.com/support |
