# Tổng quan kiến trúc hệ thống MyApp

## 1. Kiến trúc tổng thể (3-Tier Architecture)

Hệ thống MyApp được thiết kế theo kiến trúc 3 tầng trên AWS, sử dụng các managed services để giảm thiểu vận hành và tối ưu khả năng mở rộng.

### Tầng Presentation (Frontend)

- **CloudFront** phân phối nội dung tĩnh từ **S3** (Single Page Application)
- **AWS WAF** tích hợp với CloudFront để bảo vệ chống DDoS, SQL injection, XSS
- **Route 53** quản lý DNS và health check
- **ACM (AWS Certificate Manager)** cung cấp SSL/TLS certificate

### Tầng Application (Backend)

- **Application Load Balancer (ALB)** phân phối traffic đến các container
- **ECS Fargate** chạy API containers trong private subnets (serverless, không cần quản lý EC2)
- **Amazon Cognito** xác thực người dùng (nếu sử dụng)
- **API Gateway** (tùy chọn) cho API management

### Tầng Data (Database)

- **RDS PostgreSQL** (Multi-AZ) lưu trữ dữ liệu chính, tự động failover
- **ElastiCache Redis** cho caching và session management
- **S3** cho lưu trữ file/assets dài hạn
- **AWS Backup** tự động backup theo schedule

```
Người dùng
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

## 2. Network Topology (Mô hình mạng)

### VPC Design

Mỗi environment (dev, staging, prod) có VPC riêng biệt, cách ly hoàn toàn.

| Thành phần | CIDR (Prod) | Mô tả |
|-----------|-------------|--------|
| VPC | 10.0.0.0/16 | 65,536 IPs |
| Public Subnet AZ-a | 10.0.1.0/24 | ALB, NAT Gateway |
| Public Subnet AZ-b | 10.0.2.0/24 | ALB, NAT Gateway |
| Private Subnet AZ-a | 10.0.10.0/24 | ECS Fargate tasks |
| Private Subnet AZ-b | 10.0.11.0/24 | ECS Fargate tasks |
| Data Subnet AZ-a | 10.0.20.0/24 | RDS, ElastiCache |
| Data Subnet AZ-b | 10.0.21.0/24 | RDS standby, ElastiCache replica |

### Kết nối mạng

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

Sử dụng VPC Endpoints để truy cập AWS services mà không cần đi qua NAT Gateway, tiết kiệm chi phí và tăng bảo mật:

| Endpoint | Loại | Mục đích |
|----------|------|----------|
| S3 | Gateway | Truy cập S3 từ private subnets |
| DynamoDB | Gateway | Terraform state locking |
| ECR (api + dkr) | Interface | Pull container images |
| CloudWatch Logs | Interface | Push logs từ ECS tasks |
| Secrets Manager | Interface | Lấy credentials từ ECS tasks |
| SSM | Interface | Parameter Store access |

### NAT Gateway

- Production: 1 NAT Gateway mỗi AZ (high availability)
- Dev/Staging: 1 NAT Gateway dùng chung (tiết kiệm chi phí)
- Cho phép ECS tasks trong private subnets truy cập internet (pull images, external APIs)

## 3. Mô hình bảo mật (Security Model)

### Mã hóa (Encryption)

| Tầng | Encryption at Rest | Encryption in Transit |
|------|-------------------|----------------------|
| S3 | AES-256 (SSE-S3) hoặc KMS | HTTPS (TLS 1.2+) |
| RDS | KMS managed key | SSL/TLS enforced |
| ElastiCache | KMS managed key | TLS enabled |
| ECS (EFS nếu có) | KMS managed key | TLS |
| Secrets Manager | KMS managed key | HTTPS |
| CloudWatch Logs | KMS managed key | HTTPS |

- **KMS**: Sử dụng Customer Managed Key (CMK) riêng cho mỗi environment
- **Certificate**: ACM cung cấp, tự động renew, gắn vào CloudFront và ALB

### IAM (Identity and Access Management)

**Nguyên tắc Least Privilege:**

| Role | Quyền | Mục đích |
|------|--------|----------|
| ECS Task Role | S3 read/write, Secrets Manager read, CloudWatch write | Application runtime |
| ECS Execution Role | ECR pull, CloudWatch Logs create, Secrets Manager read | Task startup |
| GitHub Actions OIDC | Terraform state S3, specific resource creation | CI/CD deployment |
| Developer Role | Read-only production, full access dev | Day-to-day development |
| Admin Role | Full access with MFA required | Emergency operations |

- Sử dụng **OIDC Federation** cho GitHub Actions (không dùng long-lived access keys)
- **MFA** bắt buộc cho tất cả IAM users
- **Service Control Policies (SCP)** để giới hạn actions ở organization level

### Network Isolation (Cách ly mạng)

**Security Groups:**

| Security Group | Inbound | Outbound | Gắn với |
|---------------|---------|----------|---------|
| ALB SG | 443 từ CloudFront IPs | ECS SG:8080 | Application Load Balancer |
| ECS SG | 8080 từ ALB SG | 443 Internet (qua NAT), Data SG | ECS Fargate tasks |
| RDS SG | 5432 từ ECS SG | Deny all | RDS PostgreSQL |
| Redis SG | 6379 từ ECS SG | Deny all | ElastiCache Redis |

**Network ACLs:**
- Public subnets: Cho phép 80/443 inbound, ephemeral ports outbound
- Private subnets: Chỉ cho phép traffic từ public subnets và VPC CIDR
- Data subnets: Chỉ cho phép traffic từ private subnets (ports cụ thể)

### Bảo mật bổ sung

- **AWS GuardDuty**: Phát hiện threats tự động
- **AWS Config**: Theo dõi compliance của tài nguyên
- **CloudTrail**: Audit log tất cả API calls
- **WAF Rules**: Rate limiting, IP reputation, managed rule groups (OWASP Top 10)

## 4. Luồng dữ liệu (Data Flow)

### Request Lifecycle: Từ người dùng đến database và trở lại

```
1. Người dùng truy cập https://myapp.com
        │
        ▼
2. Route 53 resolve DNS → CloudFront distribution
        │
        ▼
3. CloudFront kiểm tra:
   ├─ Nếu là static asset (JS/CSS/images) → Trả về từ S3 origin (cache hit)
   └─ Nếu là API request (/api/*) → Forward đến ALB origin
        │
        ▼
4. WAF kiểm tra request:
   ├─ Rate limit check
   ├─ SQL injection / XSS detection
   ├─ IP reputation check
   └─ Nếu hợp lệ → Forward
        │
        ▼
5. ALB nhận request:
   ├─ Health check target groups
   ├─ Route theo path rules
   └─ Distribute đến healthy ECS task (round-robin)
        │
        ▼
6. ECS Fargate task xử lý request:
   ├─ Kiểm tra cache (ElastiCache Redis)
   │   ├─ Cache HIT → Trả kết quả ngay
   │   └─ Cache MISS → Tiếp tục
   ├─ Lấy credentials từ Secrets Manager (cached in memory)
   ├─ Query RDS PostgreSQL
   ├─ Xử lý business logic
   ├─ Cập nhật cache nếu cần
   └─ Trả response
        │
        ▼
7. Response đi ngược lại:
   ECS → ALB → CloudFront (cache nếu cacheable) → Người dùng
```

### Luồng dữ liệu nội bộ

| Luồng | Mô tả | Protocol |
|-------|--------|----------|
| ECS → RDS | Read/write dữ liệu chính | PostgreSQL (TCP 5432, TLS) |
| ECS → Redis | Cache read/write, session | Redis (TCP 6379, TLS) |
| ECS → S3 | Upload/download files | HTTPS qua VPC Endpoint |
| ECS → Secrets Manager | Lấy credentials lúc startup | HTTPS qua VPC Endpoint |
| ECS → CloudWatch | Push logs và metrics | HTTPS qua VPC Endpoint |

## 5. Mô hình triển khai (Deployment Model)

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
│ 6. terraform plan │  Plan cho affected envs
│ 7. Comment lên PR │
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

### Chiến lược triển khai

| Thành phần | Chiến lược | Mô tả |
|-----------|------------|--------|
| ECS Service | Rolling update | Thay thế tasks từng nhóm, zero-downtime |
| RDS | Blue/Green hoặc in-place | Tùy loại thay đổi |
| Infrastructure | Terraform apply | Idempotent, state-managed |
| Frontend (S3) | S3 sync + CloudFront invalidation | Cập nhật tức thì |

### Environment Promotion

| Môi trường | Trigger | Approval | Mục đích |
|-----------|---------|----------|----------|
| **dev** | Push to `main` | Tự động | Phát triển, integration testing |
| **staging** | Tag `rc-*` | 1 reviewer | Pre-production, UAT |
| **prod** | Tag `v*.*.*` | 2 reviewers | Production |

### Drift Detection

- Chạy tự động lúc **02:00 UTC hàng ngày**
- So sánh Terraform state với actual infrastructure
- Gửi alert qua Slack nếu phát hiện drift
- Team on-call review và reconcile drift trong ngày làm việc tiếp theo

### Rollback

- **ECS**: Cập nhật service về task definition revision trước đó (xem [runbooks/deploy-rollback.md](../runbooks/deploy-rollback.md))
- **Terraform**: Revert git commit và re-apply, hoặc restore state từ S3 versioned backup
- **Frontend**: Redeploy version cũ từ git tag sang S3

## Tham khảo

- [Runbooks vận hành](../runbooks/) — Hướng dẫn xử lý các tình huống vận hành
- [Onboarding](../onboarding/) — Hướng dẫn bắt đầu cho thành viên mới
- [Terraform Modules](../../terraform/modules/) — Source code các module
