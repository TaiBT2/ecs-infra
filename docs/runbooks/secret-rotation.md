# Runbook: Secret Rotation

## Purpose & When to Use

This runbook guides the process for rotating credentials and secrets. Use when:

- Scheduled rotation per policy (every 90 days)
- Credentials are suspected to be leaked or compromised
- An employee with access leaves the organization
- An audit requires credential rotation
- After a security incident

## Prerequisites

- AWS CLI configured with Secrets Manager, RDS, ECS permissions (`aws sts get-caller-identity`)
- Permissions: `secretsmanager:RotateSecret`, `secretsmanager:DescribeSecret`, `secretsmanager:UpdateSecret`
- Permission: `ecs:UpdateService` to force deployment
- Know the secret ARN/name to rotate
- Understand that rotation will cause a brief connection reset for ECS tasks

## Detailed Steps

### Option A: Rotate RDS Password via Secrets Manager (Automatic)

Preferred option — uses the pre-configured Lambda rotation function.

**Step 1: Check current secret status:**

```bash
# View secret information
aws secretsmanager describe-secret \
  --secret-id myapp-prod-rds-credentials \
  --query '{Name:Name,RotationEnabled:RotationEnabled,LastRotated:LastRotatedDate,NextRotation:NextRotationDate,RotationLambda:RotationRules}' \
  --output table

# Check current value (only to confirm format, do NOT log it)
aws secretsmanager get-secret-value \
  --secret-id myapp-prod-rds-credentials \
  --query 'SecretString' \
  --output text | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Host: {d[\"host\"]}, User: {d[\"username\"]}, DB: {d[\"dbname\"]}')"
```

**Step 2: Trigger rotation:**

```bash
# Trigger rotation
aws secretsmanager rotate-secret \
  --secret-id myapp-prod-rds-credentials

echo "Rotation has started. The Lambda function will perform the rotation steps."
```

**Step 3: Monitor rotation progress:**

```bash
# Check rotation status (repeat until complete)
aws secretsmanager describe-secret \
  --secret-id myapp-prod-rds-credentials \
  --query '{LastRotated:LastRotatedDate,Versions:VersionIdsToStages}' \
  --output json

# Check CloudWatch Logs of the rotation Lambda
aws logs tail /aws/lambda/myapp-prod-secret-rotation --since 5m
```

**Step 4: Confirm the new secret is working:**

```bash
# Check that the staging label has been transferred
aws secretsmanager describe-secret \
  --secret-id myapp-prod-rds-credentials \
  --query 'VersionIdsToStages' \
  --output json

# The new secret should have the AWSCURRENT label, the old secret should have AWSPREVIOUS
```

**Step 5: Force ECS deployment to pick up new credentials:**

```bash
# ECS tasks need to restart to pick up the new secret from Secrets Manager
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --force-new-deployment

echo "Deploying new ECS tasks with new credentials..."

# Wait for deployment to stabilize
aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service

echo "Deployment complete!"
```

**Step 6: Check that new tasks are healthy:**

```bash
# Check all running tasks
aws ecs list-tasks \
  --cluster myapp-prod-cluster \
  --service-name myapp-prod-api-service \
  --desired-status RUNNING \
  --output text

# Check for no recently STOPPED tasks (due to credential errors)
aws ecs list-tasks \
  --cluster myapp-prod-cluster \
  --service-name myapp-prod-api-service \
  --desired-status STOPPED \
  --output text

# If there are stopped tasks, check the reason
aws ecs describe-tasks \
  --cluster myapp-prod-cluster \
  --tasks <TASK_ARN> \
  --query 'tasks[].{status:lastStatus,reason:stoppedReason,container:containers[0].{status:lastStatus,reason:reason,exitCode:exitCode}}' \
  --output json
```

### Option B: Manual Rotation (Fallback)

Use when the automatic rotation Lambda fails or has not been configured.

**Step 1: Generate a new password:**

```bash
# Generate a strong random password (32 characters)
NEW_PASSWORD=$(aws secretsmanager get-random-password \
  --password-length 32 \
  --exclude-punctuation \
  --output text)

echo "New password has been generated (not displayed for security reasons)"
```

**Step 2: Update the password on RDS:**

```bash
# Change the master password on RDS
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately

echo "Updating password on RDS. This may take a few seconds."
```

**Step 3: Update the secret in Secrets Manager:**

```bash
# Get the current secret
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id myapp-prod-rds-credentials \
  --query 'SecretString' \
  --output text)

# Update the password in the secret
UPDATED_SECRET=$(echo $CURRENT_SECRET | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['password'] = '$NEW_PASSWORD'
print(json.dumps(d))
")

aws secretsmanager update-secret \
  --secret-id myapp-prod-rds-credentials \
  --secret-string "$UPDATED_SECRET"

echo "Secret has been updated in Secrets Manager."
```

**Step 4: Force ECS deployment (same as Option A, Steps 5-6)**

### Option C: Emergency Password Reset

Use when credentials have been compromised and need to be changed immediately.

**Step 1: Change RDS password immediately:**

```bash
# Generate a new password
EMERGENCY_PASSWORD=$(aws secretsmanager get-random-password \
  --password-length 32 \
  --exclude-punctuation \
  --output text)

# Change RDS password immediately
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --master-user-password "$EMERGENCY_PASSWORD" \
  --apply-immediately

echo "!!! PASSWORD HAS BEEN CHANGED - Application will lose connectivity until the secret is updated !!!"
```

**Step 2: Update the secret immediately:**

```bash
# Get and update the secret
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id myapp-prod-rds-credentials \
  --query 'SecretString' \
  --output text)

UPDATED_SECRET=$(echo $CURRENT_SECRET | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['password'] = '$EMERGENCY_PASSWORD'
print(json.dumps(d))
")

aws secretsmanager update-secret \
  --secret-id myapp-prod-rds-credentials \
  --secret-string "$UPDATED_SECRET"
```

**Step 3: Force ECS deployment immediately:**

```bash
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service
```

**Step 4: Revoke all old sessions on RDS (if needed):**

```bash
# Connect to RDS and kill all old connections
# (requires psql client or bastion host)
# SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'appuser' AND pid <> pg_backend_pid();
```

**Step 5: Check CloudTrail to identify the source of compromise:**

```bash
# Find abnormal access to the secret in the last 24 hours
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=myapp-prod-rds-credentials \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --query 'Events[].{Time:EventTime,Name:EventName,User:Username,Source:EventSource}' \
  --output table
```

## Verification

```bash
# Check that the secret has been rotated
aws secretsmanager describe-secret \
  --secret-id myapp-prod-rds-credentials \
  --query '{LastRotated:LastRotatedDate,Versions:VersionIdsToStages}' \
  --output json

# Check that new ECS tasks are running healthy
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount,deployments:deployments[].{status:status,running:runningCount}}'

# Check for no database connection errors in logs
aws logs tail /ecs/myapp-prod-api --since 5m --filter-pattern "connection refused"
aws logs tail /ecs/myapp-prod-api --since 5m --filter-pattern "authentication failed"

# Check application health
curl -sf https://<DOMAIN>/api/health && echo "OK" || echo "FAIL"
```

## Rollback

If rotation causes connection errors:

```bash
# Revert to the old password (Secrets Manager keeps the AWSPREVIOUS version)
aws secretsmanager update-secret-version-stage \
  --secret-id myapp-prod-rds-credentials \
  --version-stage AWSCURRENT \
  --move-to-version-id <PREVIOUS_VERSION_ID> \
  --remove-from-version-id <CURRENT_VERSION_ID>

# If needed, reset the RDS password to the old value
# (Retrieve from the AWSPREVIOUS version)
OLD_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id myapp-prod-rds-credentials \
  --version-stage AWSPREVIOUS \
  --query 'SecretString' \
  --output text | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --master-user-password "$OLD_PASSWORD" \
  --apply-immediately

# Force ECS deployment
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --force-new-deployment
```

## Escalation

| Condition | Escalate to |
|-----------|-------------|
| Rotation Lambda continuously fails | Senior DevOps + Security Team |
| Credentials suspected to be leaked externally | Security Team + CISO immediately |
| Unable to connect to RDS after rotation | DBA + DevOps Lead |
| Application downtime > 5 minutes due to rotation | Team Lead + Engineering Manager |
| Need to rotate credentials for multiple services simultaneously | DevOps Lead — plan a rotation window |
