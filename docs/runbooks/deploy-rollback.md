# Runbook: Rollback Triển khai (Deploy Rollback)

## Mục đích & khi nào dùng

Runbook này hướng dẫn rollback deployment khi phiên bản mới gây ra lỗi hoặc sự cố. Sử dụng khi:

- Deployment mới gây tăng error rate hoặc latency
- Health check liên tục fail sau deployment
- Phát hiện bug nghiêm trọng trong phiên bản mới
- Cần quay về phiên bản ổn định trước đó nhanh nhất

## Tiền điều kiện

- AWS CLI đã cấu hình với quyền ECS, IAM phù hợp (`aws sts get-caller-identity`)
- Biết cluster name và service name cần rollback
- Terraform đã cài đặt (nếu cần rollback Terraform state)
- Git access vào repository `infra-ecs`

## Các bước chi tiết

### Phương án A: Rollback ECS Task Definition

Phương án nhanh nhất — chỉ rollback container/task definition mà không thay đổi infrastructure.

**Bước 1: Xác định task definition hiện tại và trước đó:**

```bash
# Lấy task definition hiện tại của service
CURRENT_TASK_DEF=$(aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].taskDefinition' \
  --output text)

echo "Task definition hiện tại: $CURRENT_TASK_DEF"

# Lấy revision number hiện tại
CURRENT_REVISION=$(echo $CURRENT_TASK_DEF | grep -o '[0-9]*$')
echo "Revision hiện tại: $CURRENT_REVISION"

# Tính revision trước đó
PREVIOUS_REVISION=$((CURRENT_REVISION - 1))
TASK_DEF_FAMILY=$(echo $CURRENT_TASK_DEF | sed "s/:${CURRENT_REVISION}$//")
PREVIOUS_TASK_DEF="${TASK_DEF_FAMILY}:${PREVIOUS_REVISION}"
echo "Task definition trước đó: $PREVIOUS_TASK_DEF"
```

**Bước 2: Xác nhận task definition trước đó tồn tại và hợp lệ:**

```bash
# Kiểm tra task definition trước đó
aws ecs describe-task-definition \
  --task-definition $PREVIOUS_TASK_DEF \
  --query 'taskDefinition.{family:family,revision:revision,status:status,image:containerDefinitions[0].image}' \
  --output table
```

**Bước 3: Rollback service về task definition trước đó:**

```bash
# Cập nhật service để dùng task definition cũ
aws ecs update-service \
  --cluster myapp-prod-cluster \
  --service myapp-prod-api-service \
  --task-definition $PREVIOUS_TASK_DEF \
  --force-new-deployment \
  --output json

echo "Đã bắt đầu rollback. Đang chờ deployment ổn định..."
```

**Bước 4: Chờ deployment ổn định:**

```bash
# Chờ service stable (timeout 10 phút)
aws ecs wait services-stable \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service

echo "Service đã ổn định!"
```

**Bước 5: Kiểm tra trạng thái deployment:**

```bash
# Xác nhận chỉ có 1 deployment ACTIVE (PRIMARY)
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].deployments[].{status:status,taskDef:taskDefinition,running:runningCount,desired:desiredCount,rollout:rolloutState}' \
  --output table
```

### Phương án B: Rollback Terraform State

Sử dụng khi cần rollback thay đổi infrastructure (VPC, RDS, ALB, v.v.).

**Bước 1: Kiểm tra trạng thái Terraform hiện tại:**

```bash
cd terraform/envs/prod

# Pull state hiện tại
terraform state pull > /tmp/terraform-state-backup-$(date +%Y%m%d%H%M%S).json
echo "Đã backup state tại /tmp/terraform-state-backup-*.json"

# Xem các resources trong state
terraform state list
```

**Bước 2: Plan để kiểm tra thay đổi:**

```bash
# Kiểm tra Terraform sẽ thay đổi gì so với state hiện tại
terraform plan -out=rollback.tfplan

# Review plan cẩn thận trước khi apply
```

**Bước 3a: Rollback resource cụ thể (targeted):**

```bash
# Nếu chỉ cần rollback 1-2 resources cụ thể
# Ví dụ: rollback chỉ ECS service
terraform plan -target=module.compute.aws_ecs_service.api -out=rollback.tfplan
terraform apply rollback.tfplan
```

**Bước 3b: Rollback toàn bộ bằng git revert:**

```bash
# Tìm commit gây lỗi
git log --oneline -10

# Revert commit đó
git revert <COMMIT_HASH> --no-edit

# Review changes
git diff HEAD~1

# Push và chờ CI/CD apply
git push origin main

# HOẶC apply thủ công nếu CI/CD không hoạt động
cd terraform/envs/prod
terraform init
terraform plan -out=rollback.tfplan
terraform apply rollback.tfplan
```

**Bước 3c: Rollback hoàn toàn về state cũ (tình huống khẩn cấp):**

```bash
# CHÚ Ý: Chỉ dùng khi các phương án khác không hiệu quả
# Đảm bảo đã backup state hiện tại ở Bước 1

# Tìm state file backup trên S3 (nếu có versioning)
aws s3api list-object-versions \
  --bucket myapp-terraform-state \
  --prefix prod/terraform.tfstate \
  --query 'Versions[0:5].{VersionId:VersionId,Modified:LastModified,Size:Size}' \
  --output table

# Restore state version cụ thể
aws s3api get-object \
  --bucket myapp-terraform-state \
  --key prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  /tmp/restored-state.json

# Push restored state
terraform state push /tmp/restored-state.json

# Plan và apply
terraform plan -out=rollback.tfplan
terraform apply rollback.tfplan
```

## Verify

```bash
# Kiểm tra ECS service healthy
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount,taskDef:taskDefinition}'

# Kiểm tra ALB targets
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --query 'TargetHealthDescriptions[].{id:Target.Id,health:TargetHealth.State}'

# Kiểm tra application endpoint
curl -sf https://<DOMAIN>/api/health && echo "OK" || echo "FAIL"

# Kiểm tra error rate đã giảm
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum

# Kiểm tra logs không còn lỗi mới
aws logs tail /ecs/myapp-prod-api --since 5m --filter-pattern "ERROR"
```

## Rollback

Nếu rollback bản thân gây ra vấn đề:

1. **ECS**: Quay lại task definition gần nhất hoạt động tốt bằng cách lặp lại Phương án A với revision khác
2. **Terraform**: Restore state từ S3 versioned backup (Bước 3c của Phương án B)
3. Nếu cả hai không hiệu quả, escalate ngay

## Escalation

| Điều kiện | Escalation đến |
|-----------|----------------|
| Rollback ECS không thành công sau 15 phút | Team Lead + Senior DevOps |
| Terraform state bị corrupt hoặc drift nghiêm trọng | Senior DevOps + Infrastructure Lead |
| Rollback gây ảnh hưởng đến data integrity | DBA + Engineering Manager |
| Không rõ revision nào an toàn để rollback | Team Lead — kiểm tra deployment history và release notes |
| Cần AWS Support | Mở case tại https://console.aws.amazon.com/support |
