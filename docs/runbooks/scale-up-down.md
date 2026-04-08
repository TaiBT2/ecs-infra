# Runbook: Tăng/Giảm tài nguyên (Scale Up/Down)

## Mục đích & khi nào dùng

Runbook này hướng dẫn mở rộng hoặc thu hẹp tài nguyên hệ thống. Sử dụng khi:

- Traffic tăng đột biến, cần thêm ECS tasks
- CPU/Memory sử dụng cao liên tục (>80%)
- Chuẩn bị cho sự kiện traffic cao (flash sale, marketing campaign)
- Giảm chi phí bằng cách thu hẹp tài nguyên không cần thiết
- RDS cần instance class lớn hơn do query performance giảm
- Cần thêm read replicas cho read-heavy workload

## Tiền điều kiện

- AWS CLI đã cấu hình với quyền ECS, RDS, Application Auto Scaling (`aws sts get-caller-identity`)
- Terraform đã cài đặt (cho thay đổi auto scaling policies)
- Hiểu về instance types và pricing
- Đối với RDS scaling: xác nhận maintenance window hoặc chấp nhận downtime ngắn

## Các bước chi tiết

### 1. Scale ECS Service

#### 1a. Scale thủ công (nhanh nhất)

```bash
# Kiểm tra trạng thái hiện tại
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount,cpu:deployments[0].networkConfiguration}' \
  --output table

# Tăng số lượng tasks (ví dụ: từ 3 lên 6)
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --desired-count 6

echo "Đang scale lên 6 tasks..."

# Chờ tasks mới sẵn sàng
aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service

echo "Scale hoàn tất!"
```

```bash
# Giảm số lượng tasks khi không cần nữa (ví dụ: về lại 3)
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --desired-count 3
```

#### 1b. Cập nhật Auto Scaling min/max qua Terraform

```bash
cd terraform/envs/prod

# Chỉnh sửa biến auto scaling trong terraform.tfvars
# ecs_min_tasks = 3  -> 6
# ecs_max_tasks = 10 -> 20
# Hoặc chỉnh trực tiếp trong module

terraform plan -target=module.compute.aws_appautoscaling_target.ecs_target \
  -out=scale.tfplan

terraform apply scale.tfplan
```

Hoặc cập nhật trực tiếp qua AWS CLI:

```bash
# Cập nhật auto scaling target (min/max capacity)
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/myapp-prod-cluster/myapp-prod-api-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 6 \
  --max-capacity 20

echo "Auto scaling min=6, max=20 đã được cập nhật."
```

#### 1c. Điều chỉnh Auto Scaling Policy

```bash
# Xem policies hiện tại
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/myapp-prod-cluster/myapp-prod-api-service \
  --output json

# Cập nhật target tracking policy (ví dụ: giảm CPU target để scale sớm hơn)
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

#### 2a. Thay đổi Instance Class (Vertical Scaling)

**Lưu ý**: Thay đổi instance class gây downtime ngắn (~5-10 phút cho Multi-AZ).

```bash
# Kiểm tra instance class hiện tại
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Class:DBInstanceClass,Storage:AllocatedStorage,IOPS:Iops,MultiAZ:MultiAZ}' \
  --output table

# Scale lên instance class lớn hơn
# Tùy chọn 1: Apply trong maintenance window (ít rủi ro)
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --db-instance-class db.r6g.xlarge \
  --apply-immediately false

echo "Thay đổi sẽ được áp dụng trong maintenance window tiếp theo."

# Tùy chọn 2: Apply ngay lập tức (gây downtime ngắn)
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --db-instance-class db.r6g.xlarge \
  --apply-immediately

echo "Đang apply thay đổi ngay. Sẽ có downtime ngắn (~5-10 phút)."
```

```bash
# Theo dõi tiến trình modification
watch -n 15 "aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Class:DBInstanceClass,PendingModifications:PendingModifiedValues}' \
  --output table"
```

#### 2b. Thêm Read Replica (Horizontal Read Scaling)

```bash
# Tạo read replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier myapp-prod-rds-read-1 \
  --source-db-instance-identifier myapp-prod-rds-main \
  --db-instance-class db.r6g.large \
  --availability-zone us-east-1b \
  --no-publicly-accessible

echo "Đang tạo read replica. Quá trình có thể mất 15-30 phút."

# Chờ replica sẵn sàng
aws rds wait db-instance-available \
  --db-instance-identifier myapp-prod-rds-read-1

echo "Read replica đã sẵn sàng!"

# Lấy endpoint của read replica
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-read-1 \
  --query 'DBInstances[0].Endpoint.{Address:Address,Port:Port}' \
  --output table
```

#### 2c. Tăng Storage

```bash
# Tăng storage (không gây downtime, nhưng không thể giảm lại)
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-rds-main \
  --allocated-storage 200 \
  --apply-immediately

echo "Đang tăng storage. Quá trình diễn ra online, không có downtime."
```

### 3. Pre-scaling cho Traffic Spikes dự kiến

Thực hiện **trước ít nhất 30 phút** khi biết trước traffic sẽ tăng.

```bash
# Bước 1: Scale ECS trước
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --desired-count 10

# Bước 2: Tăng auto scaling limits
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/myapp-prod-cluster/myapp-prod-api-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 10 \
  --max-capacity 30

# Bước 3: Chờ tất cả tasks ready
aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service

# Bước 4: Warm up CloudFront cache nếu cần
# curl -s https://<DOMAIN>/critical-page-1 > /dev/null
# curl -s https://<DOMAIN>/critical-page-2 > /dev/null

echo "Pre-scaling hoàn tất. Hệ thống sẵn sàng cho traffic cao."
```

**Sau sự kiện — scale down:**

```bash
# Quay về cấu hình bình thường
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

echo "Scale down hoàn tất."
```

## Verify

```bash
# Kiểm tra ECS service sau khi scale
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount,pending:pendingCount}' \
  --output table

# Kiểm tra tất cả tasks healthy
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --query 'TargetHealthDescriptions[].{target:Target.Id,health:TargetHealth.State}' \
  --output table

# Kiểm tra auto scaling target
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/myapp-prod-cluster/myapp-prod-api-service \
  --query 'ScalableTargets[0].{Min:MinCapacity,Max:MaxCapacity}' \
  --output table

# Kiểm tra RDS sau khi scale
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Class:DBInstanceClass,Storage:AllocatedStorage}' \
  --output table

# Kiểm tra application performance
curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" https://<DOMAIN>/api/health
```

## Rollback

- **ECS scale up**: Giảm desired count về giá trị cũ bằng `aws ecs update-service --desired-count <OLD_COUNT>`
- **RDS instance class**: Modify lại về instance class cũ (gây thêm downtime ngắn)
- **Read replica**: Xóa replica nếu không cần: `aws rds delete-db-instance --db-instance-identifier myapp-prod-rds-read-1 --skip-final-snapshot`
- **Auto scaling policy**: Restore policy cũ qua Terraform hoặc AWS CLI

## Escalation

| Điều kiện | Escalation đến |
|-----------|----------------|
| ECS tasks không thể start (resource limits) | DevOps Lead — kiểm tra Fargate quotas/limits |
| RDS modification bị stuck | DBA + AWS Support |
| Auto scaling không phản ứng kịp traffic | DevOps Lead — review scaling policy |
| Chi phí tăng đáng kể sau scaling | Engineering Manager + FinOps |
| Cần tăng AWS service quotas | DevOps Lead — mở Support case tại AWS |
