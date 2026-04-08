# Runbook: Incident Response

## Purpose & When to Use

This runbook guides the response process when the MyApp system encounters incidents affecting users or infrastructure. Use when:

- Receiving alerts from CloudWatch / PagerDuty / Slack
- Users report widespread errors
- Monitoring dashboard shows abnormal metrics (increased error rate, high latency, unhealthy service)

## Prerequisites

- Access to AWS Console or AWS CLI configured (`aws sts get-caller-identity`)
- Read access to CloudWatch Logs, X-Ray, ECS, RDS
- Slack account with channel creation permissions
- Access to Zoom/Google Meet for creating a war room
- Up-to-date on-call team contact list

## Detailed Steps

### Step 1: Assess Severity (Severity Matrix)

| Severity | Description | Response Time | Escalation |
|----------|-------------|---------------|------------|
| **SEV1** | Production system completely down, data loss, security breach | **15 minutes** | VP Engineering + CTO immediately |
| **SEV2** | Core functionality severely impacted, >50% of users affected | **30 minutes** | Engineering Manager + Team Lead |
| **SEV3** | Non-core functionality impacted, <50% of users, workaround available | **2 hours** | Team Lead |
| **SEV4** | Minor impact, cosmetic issue, core functionality unaffected | **1 business day** | Handle in next sprint |

### Step 2: Set Up War Room

**Create Slack channel:**

```bash
# Name the channel using the format: #inc-YYYYMMDD-short-description
# Example: #inc-20260408-api-timeout
```

- Invite necessary team members to the channel
- Pin the first message with a summary of the incident

**Create Zoom/Meet call (for SEV1 & SEV2):**

- Create a meeting room and share the link in the Slack channel
- Enable recording for postmortem purposes

**Assign roles:**

| Role | Responsibility |
|------|----------------|
| **Incident Commander (IC)** | Overall coordination, decision-making, timeline management |
| **Tech Lead** | Technical investigation, propose solutions, implement fix |
| **Communications Lead** | Update stakeholders, status page, customers |
| **Scribe** | Record timeline, actions taken |

### Step 3: Notify Stakeholders

**Initial notification template:**

```
[SEV<N>] Incident: <Short description>
Time detected: <YYYY-MM-DD HH:MM UTC>
Impact: <Description of user impact>
Status: Investigating
Incident Commander: <Name>
War Room: <Slack channel link>
Next update: in <N> minutes
```

**Update template:**

```
[UPDATE] Incident: <Short description>
Status: In progress / Root cause identified / Resolved
Update: <Description of what was done>
Next steps: <Plan going forward>
Next update: in <N> minutes
```

**Incident closure template:**

```
[RESOLVED] Incident: <Short description>
Time detected: <YYYY-MM-DD HH:MM UTC>
Time resolved: <YYYY-MM-DD HH:MM UTC>
Total duration: <N> minutes
Root cause summary: <1-2 sentences>
Postmortem scheduled for: <YYYY-MM-DD>
```

### Step 4: Investigation

**4a. Check overall system status:**

```bash
# Check ECS services status
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[].{status:status,running:runningCount,desired:desiredCount,deployments:deployments[].{status:status,running:runningCount,desired:desiredCount,taskDef:taskDefinition}}' \
  --output table

# Check ALB target groups health
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --output table
```

**4b. Check CloudWatch Metrics:**

```bash
# Check ALB error rate (last 5 minutes)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum

# Check latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,p99

# Check ECS CPU/Memory
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=myapp-prod-cluster Name=ServiceName,Value=myapp-prod-api-service \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,Maximum
```

**4c. Check logs:**

```bash
# View recent ECS task logs
aws logs tail /ecs/myapp-prod-api --since 15m --follow

# Search for specific errors in logs
aws logs filter-log-events \
  --log-group-name /ecs/myapp-prod-api \
  --start-time $(date -u -d '30 minutes ago' +%s)000 \
  --filter-pattern "ERROR" \
  --limit 50

# Search by request ID
aws logs filter-log-events \
  --log-group-name /ecs/myapp-prod-api \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --filter-pattern "\"<REQUEST_ID>\""
```

**4d. Check X-Ray traces (if available):**

```bash
# Find traces with errors in the last 15 minutes
aws xray get-trace-summaries \
  --start-time $(date -u -d '15 minutes ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression 'service("myapp-api") AND fault = true' \
  --output json

# Get trace details
aws xray batch-get-traces \
  --trace-ids <TRACE_ID>
```

**4e. Check RDS:**

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[].{Status:DBInstanceStatus,AZ:AvailabilityZone,CPU:PerformanceInsightsEnabled,Storage:AllocatedStorage}' \
  --output table

# Check connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod-rds-main \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,Maximum
```

**4f. Check ElastiCache:**

```bash
# Check Redis cluster status
aws elasticache describe-replication-groups \
  --replication-group-id myapp-prod-redis \
  --query 'ReplicationGroups[].{Status:Status,Nodes:NodeGroups[].{Status:Status,Primary:PrimaryEndpoint}}' \
  --output json
```

### Step 5: Remediation & Documentation

- Implement fix based on the identified root cause
- Every action must be logged in the Slack channel with a timestamp
- Refer to other runbooks as needed: [deploy-rollback.md](deploy-rollback.md), [db-failover.md](db-failover.md), [scale-up-down.md](scale-up-down.md)

## Verification

```bash
# Confirm ECS service is healthy
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[].{running:runningCount,desired:desiredCount,status:status}'

# Confirm ALB targets are healthy
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --query 'TargetHealthDescriptions[].{target:Target.Id,health:TargetHealth.State}'

# Confirm error rate has returned to normal
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum

# Check main endpoint
curl -s -o /dev/null -w "%{http_code}" https://<DOMAIN>/api/health
```

## Rollback

If the fix causes new issues:

1. Rollback immediately to the state before the fix (see [deploy-rollback.md](deploy-rollback.md))
2. Notify the war room
3. Return to the investigation step

## Escalation

| Condition | Escalate to |
|-----------|-------------|
| Unable to identify root cause within 30 minutes (SEV1) | CTO, AWS Support (Business/Enterprise) |
| Unable to identify root cause within 1 hour (SEV2) | VP Engineering |
| Suspected security breach | Security Team + CISO immediately |
| Customer data affected | Legal + Compliance Team |
| AWS Support needed | Open a case at https://console.aws.amazon.com/support — select appropriate Severity |

---

## Postmortem Template

Conduct a postmortem within **48 hours** after the incident is resolved (mandatory for SEV1 & SEV2).

```markdown
# Postmortem: <Incident Name>

**Incident date:** YYYY-MM-DD
**Severity:** SEV<N>
**Incident Commander:** <Name>
**Postmortem author:** <Name>

## Summary
<1-2 sentences describing the incident and its impact>

## Impact
- Downtime duration: <N> minutes
- Number of affected users: <N>
- Revenue impact: <estimate>
- SLA violated: Yes / No

## Timeline (UTC)
| Time | Event |
|------|-------|
| HH:MM | Alert triggered |
| HH:MM | Incident Commander engaged |
| HH:MM | War room established |
| HH:MM | Root cause identified |
| HH:MM | Fix deployed |
| HH:MM | System fully recovered |
| HH:MM | Incident closed |

## Root Cause
<Detailed description of the root cause>

## Trigger
<What action or event triggered the incident>

## Detection
<How the incident was detected — alert, user report, manual check>

## Actions Taken
1. <Action 1>
2. <Action 2>
...

## What Went Well
- <Positive point 1>
- <Positive point 2>

## What Needs Improvement
- <Improvement point 1>
- <Improvement point 2>

## Action Items
| # | Action | Owner | Deadline | Status |
|---|--------|-------|----------|--------|
| 1 | <Action item> | <Name> | YYYY-MM-DD | TODO |
| 2 | <Action item> | <Name> | YYYY-MM-DD | TODO |

## Lessons Learned
<Key takeaways from the incident>
```
