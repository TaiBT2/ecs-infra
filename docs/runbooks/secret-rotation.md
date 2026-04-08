# Runbook: Xoay vòng Secret (Secret Rotation)

## Mục đích & khi nào dùng

Runbook này hướng dẫn quy trình xoay vòng (rotate) credentials và secrets. Sử dụng khi:

- Rotation định kỳ theo policy (mỗi 90 ngày)
- Nghi ngờ credentials bị lộ hoặc bị xâm phạm
- Nhân viên có quyền truy cập rời khỏi tổ chức
- Audit yêu cầu rotate credentials
- Sau một sự cố bảo mật

## Tiền điều kiện

- AWS CLI đã cấu hình với quyền Secrets Manager, RDS, ECS (`aws sts get-caller-identity`)
- Quyền `secretsmanager:RotateSecret`, `secretsmanager:DescribeSecret`, `secretsmanager:UpdateSecret`
- Quyền `ecs:UpdateService` để force deployment
- Biết secret ARN/name cần rotate
- Hiểu rằng rotation sẽ gây ra brief connection reset cho ECS tasks

## Các bước chi tiết

### Phương án A: Rotate RDS Password qua Secrets Manager (Automatic)

Phương án ưu tiên — sử dụng Lambda rotation function đã cấu hình.

**Bước 1: Kiểm tra trạng thái secret hiện tại:**

```bash
# Xem thông tin secret
aws secretsmanager describe-secret \
  --secret-id myapp-prod-rds-credentials \
  --query '{Name:Name,RotationEnabled:RotationEnabled,LastRotated:LastRotatedDate,NextRotation:NextRotationDate,RotationLambda:RotationRules}' \
  --output table

# Kiểm tra giá trị hiện tại (chỉ để xác nhận format, KHÔNG log ra)
aws secretsmanager get-secret-value \
  --secret-id myapp-prod-rds-credentials \
  --query 'SecretString' \
  --output text | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Host: {d[\"host\"]}, User: {d[\"username\"]}, DB: {d[\"dbname\"]}')"
```

**Bước 2: Kích hoạt rotation:**

```bash
# Trigger rotation
aws secretsmanager rotate-secret \
  --secret-id myapp-prod-rds-credentials

echo "Rotation đã bắt đầu. Lambda function sẽ thực hiện các bước rotation."
```

**Bước 3: Theo dõi tiến trình rotation:**

```bash
# Kiểm tra trạng thái rotation (lặp lại cho đến khi hoàn tất)
aws secretsmanager describe-secret \
  --secret-id myapp-prod-rds-credentials \
  --query '{LastRotated:LastRotatedDate,Versions:VersionIdsToStages}' \
  --output json

# Kiểm tra CloudWatch Logs của rotation Lambda
aws logs tail /aws/lambda/myapp-prod-secret-rotation --since 5m
```

**Bước 4: Xác nhận secret mới hoạt động:**

```bash
# Kiểm tra staging label đã được chuyển
aws secretsmanager describe-secret \
  --secret-id myapp-prod-rds-credentials \
  --query 'VersionIdsToStages' \
  --output json

# Secret mới phải có label AWSCURRENT, secret cũ có label AWSPREVIOUS
```

**Bước 5: Force ECS deployment để lấy credentials mới:**

```bash
# ECS tasks cần restart để lấy secret mới từ Secrets Manager
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --force-new-deployment

echo "Đang triển khai ECS tasks mới với credentials mới..."

# Chờ deployment ổn định
aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service

echo "Deployment hoàn tất!"
```

**Bước 6: Kiểm tra tasks mới healthy:**

```bash
# Kiểm tra tất cả tasks đang chạy
aws ecs list-tasks \
  --cluster myapp-prod-cluster \
  --service-name myapp-prod-api-service \
  --desired-status RUNNING \
  --output text

# Kiểm tra không có tasks STOPPED gần đây (do lỗi credentials)
aws ecs list-tasks \
  --cluster myapp-prod-cluster \
  --service-name myapp-prod-api-service \
  --desired-status STOPPED \
  --output text

# Nếu có stopped tasks, kiểm tra lý do
aws ecs describe-tasks \
  --cluster myapp-prod-cluster \
  --tasks <TASK_ARN> \
  --query 'tasks[].{status:lastStatus,reason:stoppedReason,container:containers[0].{status:lastStatus,reason:reason,exitCode:exitCode}}' \
  --output json
```

### Phương án B: Manual Rotation (Fallback)

Sử dụng khi automatic rotation Lambda gặp lỗi hoặc chưa được cấu hình.

**Bước 1: Tạo password mới:**

```bash
# Tạo password ngẫu nhiên mạnh (32 ký tự)
NEW_PASSWORD=$(aws secretsmanager get-random-password \
  --password-length 32 \
  --exclude-punctuation \
  --output text)

echo "Password mới đã được tạo (không hiển thị vì lý do bảo mật)"
```

**Bước 2: Cập nhật password trên RDS:**

```bash
# Thay đổi master password trên RDS
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately

echo "Đang cập nhật password trên RDS. Có thể mất vài giây."
```

**Bước 3: Cập nhật secret trong Secrets Manager:**

```bash
# Lấy secret hiện tại
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id myapp-prod-rds-credentials \
  --query 'SecretString' \
  --output text)

# Cập nhật password trong secret
UPDATED_SECRET=$(echo $CURRENT_SECRET | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['password'] = '$NEW_PASSWORD'
print(json.dumps(d))
")

aws secretsmanager update-secret \
  --secret-id myapp-prod-rds-credentials \
  --secret-string "$UPDATED_SECRET"

echo "Secret đã được cập nhật trong Secrets Manager."
```

**Bước 4: Force ECS deployment (giống Phương án A, Bước 5-6)**

### Phương án C: Emergency Password Reset

Sử dụng khi credentials bị xâm phạm và cần thay đổi ngay lập tức.

**Bước 1: Thay đổi password RDS ngay lập tức:**

```bash
# Tạo password mới
EMERGENCY_PASSWORD=$(aws secretsmanager get-random-password \
  --password-length 32 \
  --exclude-punctuation \
  --output text)

# Đổi password RDS ngay lập tức
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --master-user-password "$EMERGENCY_PASSWORD" \
  --apply-immediately

echo "!!! PASSWORD ĐÃ THAY ĐỔI - Application sẽ mất kết nối cho đến khi secret được cập nhật !!!"
```

**Bước 2: Cập nhật secret ngay lập tức:**

```bash
# Lấy và cập nhật secret
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

**Bước 3: Force ECS deployment ngay lập tức:**

```bash
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service
```

**Bước 4: Revoke tất cả sessions cũ trên RDS (nếu cần):**

```bash
# Kết nối vào RDS và kill tất cả connections cũ
# (yêu cầu psql client hoặc bastion host)
# SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'appuser' AND pid <> pg_backend_pid();
```

**Bước 5: Kiểm tra CloudTrail để xác định nguồn xâm phạm:**

```bash
# Tìm access bất thường đến secret trong 24h qua
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=myapp-prod-rds-credentials \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --query 'Events[].{Time:EventTime,Name:EventName,User:Username,Source:EventSource}' \
  --output table
```

## Verify

```bash
# Kiểm tra secret đã được rotate
aws secretsmanager describe-secret \
  --secret-id myapp-prod-rds-credentials \
  --query '{LastRotated:LastRotatedDate,Versions:VersionIdsToStages}' \
  --output json

# Kiểm tra ECS tasks mới đang chạy healthy
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount,deployments:deployments[].{status:status,running:runningCount}}'

# Kiểm tra không có lỗi kết nối database trong logs
aws logs tail /ecs/myapp-prod-api --since 5m --filter-pattern "connection refused"
aws logs tail /ecs/myapp-prod-api --since 5m --filter-pattern "authentication failed"

# Kiểm tra application health
curl -sf https://<DOMAIN>/api/health && echo "OK" || echo "FAIL"
```

## Rollback

Nếu rotation gây lỗi kết nối:

```bash
# Quay về password cũ (Secrets Manager giữ version AWSPREVIOUS)
aws secretsmanager update-secret-version-stage \
  --secret-id myapp-prod-rds-credentials \
  --version-stage AWSCURRENT \
  --move-to-version-id <PREVIOUS_VERSION_ID> \
  --remove-from-version-id <CURRENT_VERSION_ID>

# Nếu cần, reset RDS password về giá trị cũ
# (Lấy từ AWSPREVIOUS version)
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

| Điều kiện | Escalation đến |
|-----------|----------------|
| Rotation Lambda liên tục fail | Senior DevOps + Security Team |
| Nghi ngờ credentials bị lộ ra bên ngoài | Security Team + CISO ngay lập tức |
| Không thể kết nối RDS sau rotation | DBA + DevOps Lead |
| Application downtime > 5 phút do rotation | Team Lead + Engineering Manager |
| Cần rotate credentials cho nhiều service cùng lúc | DevOps Lead — lập kế hoạch rotation window |
