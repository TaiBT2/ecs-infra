# MyApp System Architecture Overview

## 1. Overall Architecture (3-Tier Architecture)

The MyApp system is designed following a 3-tier architecture on AWS, using managed services to minimize operations and optimize scalability.

### Presentation Tier (Frontend)

- **CloudFront** distributes static content from **S3** (Single Page Application)
- **AWS WAF** integrates with CloudFront to protect against DDoS, SQL injection, XSS
- **Route 53** manages DNS and health checks
- **ACM (AWS Certificate Manager)** provides SSL/TLS certificates

### Application Tier (Backend)

- **Application Load Balancer (ALB)** distributes traffic to containers
- **ECS Fargate** runs API containers in private subnets (serverless, no EC2 management needed)
- **Amazon Cognito** authenticates users (if used)
- **API Gateway** (optional) for API management

### Data Tier (Database)

- **RDS PostgreSQL** (Multi-AZ) stores primary data, automatic failover
- **ElastiCache Redis** for caching and session management
- **S3** for long-term file/assets storage
- **AWS Backup** automatic scheduled backups

```
User
    │
    ▼
┌─────────────┐
│  Route 53   │  DNS resolution
└──────┬──────┘
       │
┌──────▼──────┐
│ CloudFront  │  CDN + WAF protection
│  + WAF      │
└──────┬──────┘
       │
       ├──────────────────┐
       │                  │
┌──────▼──────┐    ┌──────▼──────┐
│  S3 (SPA)   │    │    ALB      │  Load balancing
│  Frontend   │    └──────┬──────┘
└─────────────┘           │
                   ┌──────▼──────┐
                   │ ECS Fargate │  API containers
                   │ (Private)   │
                   └──────┬──────┘
                          │
              ┌───────────┼───────────┐
              │           │           │
       ┌──────▼──┐  ┌────▼─────┐  ┌──▼──────┐
       │   RDS   │  │ElastiCache│  │   S3    │
       │Postgres │  │  Redis   │  │ Assets  │
       │Multi-AZ │  └──────────┘  └─────────┘
       └─────────┘
```

## 2. Network Topology

### VPC Design

Each environment (dev, staging, prod) has a separate VPC, completely isolated.

| Component | CIDR (Prod) | Description |
|-----------|-------------|------------|
| VPC | 10.0.0.0/16 | 65,536 IPs |
| Public Subnet AZ-a | 10.0.1.0/24 | ALB, NAT Gateway |
| Public Subnet AZ-b | 10.0.2.0/24 | ALB, NAT Gateway |
| Private Subnet AZ-a | 10.0.10.0/24 | ECS Fargate tasks |
| Private Subnet AZ-b | 10.0.11.0/24 | ECS Fargate tasks |
| Data Subnet AZ-a | 10.0.20.0/24 | RDS, ElastiCache |
| Data Subnet AZ-b | 10.0.21.0/24 | RDS standby, ElastiCache replica |

### Network Connectivity

```
                    Internet
                        │
                 ┌──────▼──────┐
                 │ Internet GW │
                 └──────┬──────┘
                        │
          ┌─────────────┼─────────────┐
          │                           │
   ┌──────▼──────┐             ┌──────▼──────┐
   │Public Subnet│             │Public Subnet│
   │    AZ-a     │             │    AZ-b     │
   │ - ALB       │             │ - ALB       │
   │ - NAT GW    │             │ - NAT GW    │
   └──────┬──────┘             └──────┬──────┘
          │                           │
   ┌──────▼──────┐             ┌──────▼──────┐
   │Private Sub  │             │Private Sub  │
   │    AZ-a     │             │    AZ-b     │
   │ - ECS Tasks │             │ - ECS Tasks │
   └──────┬──────┘             └──────┬──────┘
          │                           │
   ┌──────▼──────┐             ┌──────▼──────┐
   │ Data Subnet │             │ Data Subnet │
   │    AZ-a     │             │    AZ-b     │
   │ - RDS Pri   │             │ - RDS Stby  │
   │ - Redis Pri │             │ - Redis Rep │
   └─────────────┘             └─────────────┘
```

### VPC Endpoints

VPC Endpoints are used to access AWS services without going through the NAT Gateway, saving costs and improving security:

| Endpoint | Type | Purpose |
|----------|------|---------|
| S3 | Gateway | Access S3 from private subnets |
| DynamoDB | Gateway | Terraform state locking |
| ECR (api + dkr) | Interface | Pull container images |
| CloudWatch Logs | Interface | Push logs from ECS tasks |
| Secrets Manager | Interface | Retrieve credentials from ECS tasks |
| SSM | Interface | Parameter Store access |

### NAT Gateway

- Production: 1 NAT Gateway per AZ (high availability)
- Dev/Staging: 1 shared NAT Gateway (cost savings)
- Allows ECS tasks in private subnets to access the internet (pull images, external APIs)

## 3. Security Model

### Encryption

| Tier | Encryption at Rest | Encryption in Transit |
|------|-------------------|----------------------|
| S3 | AES-256 (SSE-S3) or KMS | HTTPS (TLS 1.2+) |
| RDS | KMS managed key | SSL/TLS enforced |
| ElastiCache | KMS managed key | TLS enabled |
| ECS (EFS if applicable) | KMS managed key | TLS |
| Secrets Manager | KMS managed key | HTTPS |
| CloudWatch Logs | KMS managed key | HTTPS |

- **KMS**: Uses a separate Customer Managed Key (CMK) for each environment
- **Certificate**: Provided by ACM, auto-renewed, attached to CloudFront and ALB

### IAM (Identity and Access Management)

**Least Privilege Principle:**

| Role | Permissions | Purpose |
|------|------------|---------|
| ECS Task Role | S3 read/write, Secrets Manager read, CloudWatch write | Application runtime |
| ECS Execution Role | ECR pull, CloudWatch Logs create, Secrets Manager read | Task startup |
| GitHub Actions OIDC | Terraform state S3, specific resource creation | CI/CD deployment |
| Developer Role | Read-only production, full access dev | Day-to-day development |
| Admin Role | Full access with MFA required | Emergency operations |

- Uses **OIDC Federation** for GitHub Actions (no long-lived access keys)
- **MFA** required for all IAM users
- **Service Control Policies (SCP)** to restrict actions at the organization level

### Network Isolation

**Security Groups:**

| Security Group | Inbound | Outbound | Attached to |
|---------------|---------|----------|-------------|
| ALB SG | 443 from CloudFront IPs | ECS SG:8080 | Application Load Balancer |
| ECS SG | 8080 from ALB SG | 443 Internet (via NAT), Data SG | ECS Fargate tasks |
| RDS SG | 5432 from ECS SG | Deny all | RDS PostgreSQL |
| Redis SG | 6379 from ECS SG | Deny all | ElastiCache Redis |

**Network ACLs:**
- Public subnets: Allow 80/443 inbound, ephemeral ports outbound
- Private subnets: Only allow traffic from public subnets and VPC CIDR
- Data subnets: Only allow traffic from private subnets (specific ports)

### Additional Security

- **AWS GuardDuty**: Automatic threat detection
- **AWS Config**: Track resource compliance
- **CloudTrail**: Audit log for all API calls
- **WAF Rules**: Rate limiting, IP reputation, managed rule groups (OWASP Top 10)

## 4. Data Flow

### Request Lifecycle: From user to database and back

```
1. User accesses https://myapp.com
        │
        ▼
2. Route 53 resolves DNS → CloudFront distribution
        │
        ▼
3. CloudFront checks:
   ├─ If static asset (JS/CSS/images) → Return from S3 origin (cache hit)
   └─ If API request (/api/*) → Forward to ALB origin
        │
        ▼
4. WAF checks request:
   ├─ Rate limit check
   ├─ SQL injection / XSS detection
   ├─ IP reputation check
   └─ If valid → Forward
        │
        ▼
5. ALB receives request:
   ├─ Health check target groups
   ├─ Route by path rules
   └─ Distribute to healthy ECS task (round-robin)
        │
        ▼
6. ECS Fargate task processes request:
   ├─ Check cache (ElastiCache Redis)
   │   ├─ Cache HIT → Return result immediately
   │   └─ Cache MISS → Continue
   ├─ Retrieve credentials from Secrets Manager (cached in memory)
   ├─ Query RDS PostgreSQL
   ├─ Process business logic
   ├─ Update cache if needed
   └─ Return response
        │
        ▼
7. Response travels back:
   ECS → ALB → CloudFront (cache if cacheable) → User
```

### Internal Data Flow

| Flow | Description | Protocol |
|------|------------|----------|
| ECS → RDS | Read/write primary data | PostgreSQL (TCP 5432, TLS) |
| ECS → Redis | Cache read/write, session | Redis (TCP 6379, TLS) |
| ECS → S3 | Upload/download files | HTTPS via VPC Endpoint |
| ECS → Secrets Manager | Retrieve credentials at startup | HTTPS via VPC Endpoint |
| ECS → CloudWatch | Push logs and metrics | HTTPS via VPC Endpoint |

## 5. Deployment Model

### CI/CD Pipeline Flow

```
Developer push code
        │
        ▼
┌───────────────────┐
│   GitHub Actions  │
│   Trigger: PR     │
├───────────────────┤
│ 1. terraform fmt  │
│ 2. tflint         │  Linting & Formatting
│ 3. tfsec          │
│ 4. checkov        │  Security scanning
│ 5. trivy          │
│ 6. terraform plan │  Plan for affected envs
│ 7. Comment on PR  │
└───────┬───────────┘
        │ PR approved & merged
        ▼
┌───────────────────┐
│   Push to main    │
├───────────────────┤
│ terraform apply   │  Auto-apply DEV
│ (dev environment) │
└───────┬───────────┘
        │ Tag rc-*
        ▼
┌───────────────────┐
│  Promote Staging  │
├───────────────────┤
│ 1 reviewer approve│
│ terraform apply   │  Apply STAGING
│ (staging env)     │
└───────┬───────────┘
        │ Tag v*.*.*
        ▼
┌───────────────────┐
│  Promote Prod     │
├───────────────────┤
│ 2 reviewers       │
│ approve           │  Apply PRODUCTION
│ terraform apply   │
│ (prod env)        │
└───────────────────┘
```

### Deployment Strategy

| Component | Strategy | Description |
|-----------|----------|------------|
| ECS Service | Rolling update | Replace tasks in groups, zero-downtime |
| RDS | Blue/Green or in-place | Depends on the type of change |
| Infrastructure | Terraform apply | Idempotent, state-managed |
| Frontend (S3) | S3 sync + CloudFront invalidation | Instant update |

### Environment Promotion

| Environment | Trigger | Approval | Purpose |
|-------------|---------|----------|---------|
| **dev** | Push to `main` | Automatic | Development, integration testing |
| **staging** | Tag `rc-*` | 1 reviewer | Pre-production, UAT |
| **prod** | Tag `v*.*.*` | 2 reviewers | Production |

### Drift Detection

- Runs automatically at **02:00 UTC daily**
- Compares Terraform state with actual infrastructure
- Sends alert via Slack if drift is detected
- On-call team reviews and reconciles drift on the next business day

### Rollback

- **ECS**: Update service to previous task definition revision (see [runbooks/deploy-rollback.md](../runbooks/deploy-rollback.md))
- **Terraform**: Revert git commit and re-apply, or restore state from S3 versioned backup
- **Frontend**: Redeploy old version from git tag to S3

## References

- [Operations Runbooks](../runbooks/) — Guides for handling operational scenarios
- [Onboarding](../onboarding/) — Getting started guide for new team members
- [Terraform Modules](../../terraform/modules/) — Module source code
