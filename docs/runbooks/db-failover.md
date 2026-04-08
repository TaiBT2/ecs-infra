# Runbook: Database Failover

## Purpose & When to Use

This runbook guides failover procedures for RDS PostgreSQL and ElastiCache Redis when:

- RDS primary instance encounters an issue or is unresponsive
- Need to fail over to the standby AZ due to AZ impairment
- Need to restore the database from a snapshot or point-in-time
- ElastiCache primary node encounters an issue
- Infrastructure maintenance requires a proactive failover

## Prerequisites

- AWS CLI configured with RDS, ElastiCache permissions (`aws sts get-caller-identity`)
- RDS instance running in Multi-AZ mode
- Know the DB instance identifier: `myapp-prod-rds-main`
- Know the ElastiCache replication group: `myapp-prod-redis`
- Application uses the RDS endpoint (no hardcoded IPs)
- Team has been notified about the planned failover (if not an emergency)

## Detailed Steps

### Option A: Manual RDS Multi-AZ Failover

Expected downtime: **60-120 seconds**.

**Step 1: Check current RDS status:**

```bash
# Check instance status and Multi-AZ
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,MultiAZ:MultiAZ,AZ:AvailabilityZone,SecondaryAZ:SecondaryAvailabilityZone,Endpoint:Endpoint.Address,Engine:Engine,Version:EngineVersion}' \
  --output table
```

**Step 2: Perform failover:**

```bash
# Force failover by rebooting with --force-failover
aws rds reboot-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --force-failover

echo "Failover has started. Instance will restart in 60-120 seconds."
```

**Step 3: Monitor failover progress:**

```bash
# Check status (repeat until status = available)
watch -n 10 "aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,AZ:AvailabilityZone}' \
  --output table"
```

**Step 4: Confirm the AZ has changed:**

```bash
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,PrimaryAZ:AvailabilityZone,SecondaryAZ:SecondaryAvailabilityZone}' \
  --output table
```

### Option B: Restore from Automated Snapshot

Use when a full database restore to a snapshot point-in-time is needed.

**Step 1: List available snapshots:**

```bash
# List the 10 most recent snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[0:10].{Snapshot:DBSnapshotIdentifier,Created:SnapshotCreateTime,Status:Status,Size:AllocatedStorage}' \
  --output table
```

**Step 2: Restore snapshot as a new instance:**

```bash
# Restore snapshot (creates a new instance, does NOT overwrite the old instance)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier myapp-prod-rds-restored \
  --db-snapshot-identifier <SNAPSHOT_ID> \
  --db-instance-class db.r6g.large \
  --db-subnet-group-name myapp-prod-db-subnet-group \
  --vpc-security-group-ids <SECURITY_GROUP_ID> \
  --multi-az \
  --no-publicly-accessible

echo "Restoring. The process may take 10-30 minutes depending on database size."
```

**Step 3: Wait for the new instance to be ready:**

```bash
aws rds wait db-instance-available \
  --db-instance-identifier myapp-prod-rds-restored

echo "Restored instance is ready!"
```

**Step 4: Update the endpoint in the application:**

```bash
# Get the new endpoint
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-restored \
  --query 'DBInstances[0].Endpoint.{Address:Address,Port:Port}' \
  --output table

# Update the secret in Secrets Manager
aws secretsmanager update-secret \
  --secret-id myapp-prod-rds-credentials \
  --secret-string '{"host":"<NEW_ENDPOINT>","port":5432,"username":"appuser","password":"<PASSWORD>","dbname":"myapp"}'

# Force a new ECS deployment to pick up the new secret
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --force-new-deployment
```

### Option C: Point-in-Time Recovery (PITR)

Use when a restore to an exact point in time is needed (e.g., before data was accidentally deleted).

**Step 1: Determine the restorable time range:**

```bash
# Check earliest and latest restorable time
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{EarliestRestore:EarliestRestorableTime,LatestRestore:LatestRestorableTime}' \
  --output table
```

**Step 2: Perform PITR:**

```bash
# Restore to a specific point in time (UTC)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier myapp-prod-rds-main \
  --target-db-instance-identifier myapp-prod-rds-pitr \
  --restore-time "2026-04-08T10:30:00Z" \
  --db-instance-class db.r6g.large \
  --db-subnet-group-name myapp-prod-db-subnet-group \
  --vpc-security-group-ids <SECURITY_GROUP_ID> \
  --multi-az \
  --no-publicly-accessible

echo "PITR restore in progress. The process may take 10-30 minutes."
```

**Step 3: Wait and switch endpoint (same as Option B, Steps 3-4)**

### Option D: ElastiCache Failover

**Step 1: Check ElastiCache status:**

```bash
aws elasticache describe-replication-groups \
  --replication-group-id myapp-prod-redis \
  --query 'ReplicationGroups[0].{Status:Status,Nodes:NodeGroups[0].NodeGroupMembers[].{Role:CurrentRole,AZ:PreferredAvailabilityZone,Endpoint:ReadEndpoint.Address}}' \
  --output json
```

**Step 2: Perform failover:**

```bash
# Fail over to a replica node in a different AZ
aws elasticache modify-replication-group \
  --replication-group-id myapp-prod-redis \
  --automatic-failover-enabled \
  --apply-immediately

# Or test failover manually
aws elasticache test-failover \
  --replication-group-id myapp-prod-redis \
  --node-group-id 0001
```

**Step 3: Monitor progress:**

```bash
watch -n 10 "aws elasticache describe-replication-groups \
  --replication-group-id myapp-prod-redis \
  --query 'ReplicationGroups[0].{Status:Status}' \
  --output text"
```

### Important Note: Connection Strings

- **ALWAYS** use the RDS endpoint DNS (e.g., `myapp-prod-rds-main.xxxx.us-east-1.rds.amazonaws.com`), **NEVER** hardcode IP addresses
- During Multi-AZ failover, the RDS endpoint DNS automatically points to the new standby instance — the application will reconnect automatically
- The ElastiCache primary endpoint also updates automatically after failover
- The application should have connection retry logic with exponential backoff

## Verification

```bash
# Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,AZ:AvailabilityZone}' \
  --output table

# Check connectivity from ECS tasks
# (Check logs for connection errors)
aws logs tail /ecs/myapp-prod-api --since 5m --filter-pattern "database"

# Check application health endpoint
curl -sf https://<DOMAIN>/api/health && echo "OK" || echo "FAIL"

# Check ECS tasks are running healthy
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount}'

# Check ElastiCache
aws elasticache describe-replication-groups \
  --replication-group-id myapp-prod-redis \
  --query 'ReplicationGroups[0].Status'
```

## Rollback

- **Multi-AZ failover**: Perform another failover to return to the original AZ (repeat Option A)
- **Snapshot restore / PITR**: The old instance still exists — switch the endpoint back to the old instance in Secrets Manager, then force an ECS deployment
- **ElastiCache failover**: Perform another failover or wait for automatic failover

```bash
# Delete the restored instance if no longer needed
aws rds delete-db-instance \
  --db-instance-identifier myapp-prod-rds-restored \
  --skip-final-snapshot
```

## Escalation

| Condition | Escalate to |
|-----------|-------------|
| RDS failover unsuccessful after 5 minutes | DBA + Senior DevOps |
| Application unable to reconnect after failover | Backend Team Lead + DevOps |
| Data inconsistency after restore | DBA + Engineering Manager |
| Both primary and standby RDS are unavailable | AWS Support (Urgent case) + CTO |
| ElastiCache cluster completely unresponsive | DevOps Lead + AWS Support |
