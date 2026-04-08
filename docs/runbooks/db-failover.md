# Runbook: Chuyển đổi dự phòng Database (DB Failover)

## Mục đích & khi nào dùng

Runbook này hướng dẫn chuyển đổi dự phòng (failover) cho RDS PostgreSQL và ElastiCache Redis khi:

- RDS primary instance gặp sự cố hoặc không phản hồi
- Cần failover sang standby AZ do AZ bị ảnh hưởng
- Cần restore database từ snapshot hoặc point-in-time
- ElastiCache primary node gặp sự cố
- Bảo trì hạ tầng yêu cầu failover chủ động

## Tiền điều kiện

- AWS CLI đã cấu hình với quyền RDS, ElastiCache (`aws sts get-caller-identity`)
- RDS instance đang chạy ở chế độ Multi-AZ
- Biết DB instance identifier: `myapp-prod-rds-main`
- Biết ElastiCache replication group: `myapp-prod-redis`
- Application sử dụng RDS endpoint (không hardcode IP)
- Đã thông báo cho team về planned failover (nếu không phải emergency)

## Các bước chi tiết

### Phương án A: Manual RDS Multi-AZ Failover

Thời gian downtime dự kiến: **60-120 giây**.

**Bước 1: Kiểm tra trạng thái hiện tại của RDS:**

```bash
# Kiểm tra instance status và Multi-AZ
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,MultiAZ:MultiAZ,AZ:AvailabilityZone,SecondaryAZ:SecondaryAvailabilityZone,Endpoint:Endpoint.Address,Engine:Engine,Version:EngineVersion}' \
  --output table
```

**Bước 2: Thực hiện failover:**

```bash
# Force failover bằng cách reboot với --force-failover
aws rds reboot-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --force-failover

echo "Failover đã bắt đầu. Instance sẽ khởi động lại trong 60-120 giây."
```

**Bước 3: Theo dõi tiến trình failover:**

```bash
# Kiểm tra trạng thái (lặp lại cho đến khi status = available)
watch -n 10 "aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,AZ:AvailabilityZone}' \
  --output table"
```

**Bước 4: Xác nhận AZ đã thay đổi:**

```bash
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,PrimaryAZ:AvailabilityZone,SecondaryAZ:SecondaryAvailabilityZone}' \
  --output table
```

### Phương án B: Restore từ Automated Snapshot

Sử dụng khi cần restore toàn bộ database về thời điểm snapshot.

**Bước 1: Liệt kê snapshots có sẵn:**

```bash
# Liệt kê 10 snapshot gần nhất
aws rds describe-db-snapshots \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[0:10].{Snapshot:DBSnapshotIdentifier,Created:SnapshotCreateTime,Status:Status,Size:AllocatedStorage}' \
  --output table
```

**Bước 2: Restore snapshot thành instance mới:**

```bash
# Restore snapshot (tạo instance mới, KHÔNG ghi đè instance cũ)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier myapp-prod-rds-restored \
  --db-snapshot-identifier <SNAPSHOT_ID> \
  --db-instance-class db.r6g.large \
  --db-subnet-group-name myapp-prod-db-subnet-group \
  --vpc-security-group-ids <SECURITY_GROUP_ID> \
  --multi-az \
  --no-publicly-accessible

echo "Đang restore. Quá trình có thể mất 10-30 phút tùy kích thước database."
```

**Bước 3: Chờ instance mới sẵn sàng:**

```bash
aws rds wait db-instance-available \
  --db-instance-identifier myapp-prod-rds-restored

echo "Instance restored đã sẵn sàng!"
```

**Bước 4: Cập nhật endpoint trong application:**

```bash
# Lấy endpoint mới
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-restored \
  --query 'DBInstances[0].Endpoint.{Address:Address,Port:Port}' \
  --output table

# Cập nhật secret trong Secrets Manager
aws secretsmanager update-secret \
  --secret-id myapp-prod-rds-credentials \
  --secret-string '{"host":"<NEW_ENDPOINT>","port":5432,"username":"appuser","password":"<PASSWORD>","dbname":"myapp"}'

# Force ECS deployment mới để lấy secret mới
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --force-new-deployment
```

### Phương án C: Point-in-Time Recovery (PITR)

Sử dụng khi cần restore về thời điểm chính xác (ví dụ: trước khi dữ liệu bị xóa nhầm).

**Bước 1: Xác định khoảng thời gian có thể restore:**

```bash
# Kiểm tra earliest và latest restorable time
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{EarliestRestore:EarliestRestorableTime,LatestRestore:LatestRestorableTime}' \
  --output table
```

**Bước 2: Thực hiện PITR:**

```bash
# Restore về thời điểm cụ thể (UTC)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier myapp-prod-rds-main \
  --target-db-instance-identifier myapp-prod-rds-pitr \
  --restore-time "2026-04-08T10:30:00Z" \
  --db-instance-class db.r6g.large \
  --db-subnet-group-name myapp-prod-db-subnet-group \
  --vpc-security-group-ids <SECURITY_GROUP_ID> \
  --multi-az \
  --no-publicly-accessible

echo "Đang restore PITR. Quá trình có thể mất 10-30 phút."
```

**Bước 3: Chờ và chuyển đổi endpoint (tương tự Phương án B, Bước 3-4)**

### Phương án D: ElastiCache Failover

**Bước 1: Kiểm tra trạng thái ElastiCache:**

```bash
aws elasticache describe-replication-groups \
  --replication-group-id myapp-prod-redis \
  --query 'ReplicationGroups[0].{Status:Status,Nodes:NodeGroups[0].NodeGroupMembers[].{Role:CurrentRole,AZ:PreferredAvailabilityZone,Endpoint:ReadEndpoint.Address}}' \
  --output json
```

**Bước 2: Thực hiện failover:**

```bash
# Failover sang replica node ở AZ khác
aws elasticache modify-replication-group \
  --replication-group-id myapp-prod-redis \
  --automatic-failover-enabled \
  --apply-immediately

# Hoặc test failover thủ công
aws elasticache test-failover \
  --replication-group-id myapp-prod-redis \
  --node-group-id 0001
```

**Bước 3: Theo dõi tiến trình:**

```bash
watch -n 10 "aws elasticache describe-replication-groups \
  --replication-group-id myapp-prod-redis \
  --query 'ReplicationGroups[0].{Status:Status}' \
  --output text"
```

### Lưu ý quan trọng: Connection String

- **LUÔN** sử dụng RDS endpoint DNS (ví dụ: `myapp-prod-rds-main.xxxx.us-east-1.rds.amazonaws.com`), **KHÔNG BAO GIỜ** hardcode IP address
- Khi failover Multi-AZ, RDS endpoint DNS tự động trỏ sang standby instance mới — application sẽ tự reconnect
- ElastiCache primary endpoint cũng tự động cập nhật sau failover
- Application nên có connection retry logic với exponential backoff

## Verify

```bash
# Kiểm tra RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,AZ:AvailabilityZone}' \
  --output table

# Kiểm tra connectivity từ ECS tasks
# (Kiểm tra logs xem có connection error không)
aws logs tail /ecs/myapp-prod-api --since 5m --filter-pattern "database"

# Kiểm tra application health endpoint
curl -sf https://<DOMAIN>/api/health && echo "OK" || echo "FAIL"

# Kiểm tra ECS tasks đang chạy healthy
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount}'

# Kiểm tra ElastiCache
aws elasticache describe-replication-groups \
  --replication-group-id myapp-prod-redis \
  --query 'ReplicationGroups[0].Status'
```

## Rollback

- **Multi-AZ failover**: Thực hiện failover lần nữa để quay về AZ cũ (lặp lại Phương án A)
- **Snapshot restore / PITR**: Instance cũ vẫn còn — chuyển endpoint trở lại instance cũ trong Secrets Manager, rồi force ECS deployment
- **ElastiCache failover**: Thực hiện failover lần nữa hoặc chờ automatic failover

```bash
# Xóa instance restored nếu không cần nữa
aws rds delete-db-instance \
  --db-instance-identifier myapp-prod-rds-restored \
  --skip-final-snapshot
```

## Escalation

| Điều kiện | Escalation đến |
|-----------|----------------|
| RDS failover không thành công sau 5 phút | DBA + Senior DevOps |
| Application không thể reconnect sau failover | Backend Team Lead + DevOps |
| Data inconsistency sau restore | DBA + Engineering Manager |
| Cả primary và standby RDS đều không available | AWS Support (Urgent case) + CTO |
| ElastiCache cluster hoàn toàn không phản hồi | DevOps Lead + AWS Support |
