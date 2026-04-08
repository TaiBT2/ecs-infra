# Runbook: Tối ưu chi phí (Cost Optimization)

## Mục đích & khi nào dùng

Runbook này hướng dẫn các hoạt động tối ưu chi phí AWS. Sử dụng khi:

- Review chi phí hàng tháng (thực hiện đều đặn vào đầu mỗi tháng)
- Chi phí tăng bất thường so với tháng trước
- Chuẩn bị báo cáo chi phí cho quản lý
- Muốn tìm tài nguyên lãng phí hoặc chưa tối ưu
- Đánh giá Reserved Instances hoặc Savings Plans
- Cần giảm chi phí theo yêu cầu của ban lãnh đạo

## Tiền điều kiện

- AWS CLI đã cấu hình với quyền Cost Explorer, EC2, RDS, S3, CloudWatch (`aws sts get-caller-identity`)
- Quyền `ce:GetCostAndUsage`, `ce:GetRightsizingRecommendation`
- Cost Explorer đã được kích hoạt trong AWS Account
- Tags đã được enforce: `Project`, `Environment`, `CostCenter`
- Truy cập AWS Console để xem các dashboard trực quan

## Các bước chi tiết

### 1. Review Cost Explorer hàng tháng

**Bước 1: Xem tổng chi phí tháng hiện tại và so sánh:**

```bash
# Chi phí tháng hiện tại
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --output json

# Chi phí tháng trước
LAST_MONTH_START=$(date -u -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d)
LAST_MONTH_END=$(date -u +%Y-%m-01)
aws ce get-cost-and-usage \
  --time-period Start=$LAST_MONTH_START,End=$LAST_MONTH_END \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --output json
```

**Bước 2: Chi phí theo dịch vụ (top 10):**

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d),End=$(date -u +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json | python3 -c "
import sys, json
data = json.load(sys.stdin)
groups = data['ResultsByTime'][0]['Groups']
sorted_groups = sorted(groups, key=lambda x: float(x['Metrics']['BlendedCost']['Amount']), reverse=True)
print(f'{'Dịch vụ':<50} {'Chi phí (USD)':>12}')
print('-' * 64)
for g in sorted_groups[:10]:
    name = g['Keys'][0]
    cost = float(g['Metrics']['BlendedCost']['Amount'])
    print(f'{name:<50} {cost:>12.2f}')
"
```

**Bước 3: Chi phí theo environment:**

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d),End=$(date -u +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment \
  --output json
```

### 2. Phát hiện tài nguyên lãng phí

**2a. Elastic IPs không sử dụng:**

```bash
# Tìm EIPs không gắn với instance nào
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].{IP:PublicIp,AllocationId:AllocationId}' \
  --output table

# Giải phóng EIP không dùng (tiết kiệm ~$3.65/tháng mỗi EIP)
# aws ec2 release-address --allocation-id <ALLOCATION_ID>
```

**2b. EBS Volumes không gắn:**

```bash
# Tìm volumes không attached
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[].{VolumeId:VolumeId,Size:Size,Type:VolumeType,Created:CreateTime}' \
  --output table

# Xóa volume không cần (sau khi snapshot nếu cần)
# aws ec2 create-snapshot --volume-id <VOLUME_ID> --description "Backup before delete"
# aws ec2 delete-volume --volume-id <VOLUME_ID>
```

**2c. Snapshots cũ:**

```bash
# Tìm snapshots cũ hơn 90 ngày
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[?StartTime<='$(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%S)'].{SnapshotId:SnapshotId,Size:VolumeSize,Created:StartTime,Description:Description}" \
  --output table

# Xóa snapshot cũ (sau khi xác nhận không cần)
# aws ec2 delete-snapshot --snapshot-id <SNAPSHOT_ID>
```

**2d. Load Balancers không có targets:**

```bash
# Kiểm tra ALBs có target groups rỗng
for tg_arn in $(aws elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' --output text); do
  health=$(aws elbv2 describe-target-health --target-group-arn $tg_arn --query 'TargetHealthDescriptions' --output text)
  if [ -z "$health" ]; then
    echo "Target Group rỗng: $tg_arn"
  fi
done
```

### 3. RDS Rightsizing với Performance Insights

```bash
# Kiểm tra CPU utilization trung bình của RDS (30 ngày)
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod-rds-main \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum \
  --output json

# Kiểm tra freeable memory
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeableMemory \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod-rds-main \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Minimum \
  --output json

# Kiểm tra database connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod-rds-main \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum \
  --output json
```

**Khuyến nghị rightsizing:**
- CPU trung bình < 20% liên tục 30 ngày: xem xét giảm instance class
- Freeable memory > 50% liên tục: có thể dùng instance class nhỏ hơn
- Connections max < 50% max_connections: instance có thể quá lớn

### 4. ECS Rightsizing với Container Insights

```bash
# Kiểm tra CPU utilization của ECS service (30 ngày)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=myapp-prod-cluster Name=ServiceName,Value=myapp-prod-api-service \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum \
  --output json

# Kiểm tra Memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ClusterName,Value=myapp-prod-cluster Name=ServiceName,Value=myapp-prod-api-service \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum \
  --output json
```

**Khuyến nghị rightsizing ECS:**
- CPU trung bình < 30%: giảm task CPU allocation
- Memory trung bình < 40%: giảm task memory allocation
- Cập nhật task definition trong Terraform sau khi xác nhận

### 5. Reserved Instances / Savings Plans

```bash
# Xem RI recommendations
aws ce get-reservation-purchase-recommendation \
  --service "Amazon Relational Database Service" \
  --term-in-years ONE_YEAR \
  --payment-option ALL_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS \
  --output json

# Xem Savings Plans recommendations
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option ALL_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS \
  --output json

# Kiểm tra Savings Plans coverage hiện tại
aws ce get-savings-plans-coverage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d),End=$(date -u +%Y-%m-01) \
  --granularity MONTHLY \
  --output json
```

**Checklist đánh giá:**
- [ ] RDS: Nếu chạy > 12 tháng, mua RI (tiết kiệm 30-60%)
- [ ] ECS Fargate: Compute Savings Plans (tiết kiệm 20-30%)
- [ ] So sánh 1-year vs 3-year, No Upfront vs All Upfront

### 6. S3 Lifecycle Policies

```bash
# Liệt kê tất cả S3 buckets và storage size
for bucket in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  size=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/S3 \
    --metric-name BucketSizeBytes \
    --dimensions Name=BucketName,Value=$bucket Name=StorageType,Value=StandardStorage \
    --start-time $(date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 86400 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text 2>/dev/null)
  if [ "$size" != "None" ] && [ -n "$size" ]; then
    size_gb=$(echo "scale=2; $size / 1073741824" | bc)
    echo "Bucket: $bucket - Size: ${size_gb} GB"
  fi
done

# Kiểm tra lifecycle policies hiện tại
aws s3api get-bucket-lifecycle-configuration \
  --bucket myapp-prod-assets 2>/dev/null || echo "Chưa có lifecycle policy"
```

**Lifecycle policy khuyến nghị:**

```json
{
  "Rules": [
    {
      "ID": "TransitionToIA",
      "Status": "Enabled",
      "Transitions": [
        {"Days": 30, "StorageClass": "STANDARD_IA"},
        {"Days": 90, "StorageClass": "GLACIER"},
        {"Days": 365, "StorageClass": "DEEP_ARCHIVE"}
      ],
      "Filter": {"Prefix": "logs/"}
    },
    {
      "ID": "DeleteOldLogs",
      "Status": "Enabled",
      "Expiration": {"Days": 730},
      "Filter": {"Prefix": "logs/"}
    }
  ]
}
```

### 7. NAT Gateway Cost Optimization

NAT Gateway là một trong những chi phí ẩn lớn nhất (~$32/tháng + $0.045/GB data processed).

```bash
# Kiểm tra NAT Gateway data processed
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=<NAT_GW_ID> \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Sum \
  --output json
```

**Chiến lược tối ưu:**
- Sử dụng **VPC Endpoints** cho S3, DynamoDB, ECR, CloudWatch, Secrets Manager (giảm traffic qua NAT)
- Kiểm tra Terraform module `networking` đã cấu hình VPC endpoints chưa
- Dev environment: có thể dùng 1 NAT Gateway thay vì 1 per AZ
- Xem xét NAT Instance (t3.micro) cho dev nếu traffic thấp

### 8. Dev Environment Scheduling

Tắt tài nguyên dev ngoài giờ làm việc (tiết kiệm ~65% chi phí dev).

```bash
# Scale down ECS dev service (tối/cuối tuần)
aws ecs update-service \
  --cluster myapp-dev-cluster \
  --service myapp-dev-api-service \
  --desired-count 0

# Scale up lại sáng hôm sau
aws ecs update-service \
  --cluster myapp-dev-cluster \
  --service myapp-dev-api-service \
  --desired-count 1

# Stop RDS dev instance (nếu không cần)
aws rds stop-db-instance \
  --db-instance-identifier myapp-dev-rds-main
# Lưu ý: RDS tự động start lại sau 7 ngày

# Start RDS dev instance
aws rds start-db-instance \
  --db-instance-identifier myapp-dev-rds-main
```

**Tự động hóa với EventBridge + Lambda hoặc cron trong CI/CD:**

```bash
# Ví dụ: Tạo EventBridge rule để stop dev lúc 20:00 UTC hàng ngày
aws events put-rule \
  --name "stop-dev-environment" \
  --schedule-expression "cron(0 20 ? * MON-FRI *)" \
  --state ENABLED

# Tạo rule start dev lúc 07:00 UTC hàng ngày
aws events put-rule \
  --name "start-dev-environment" \
  --schedule-expression "cron(0 7 ? * MON-FRI *)" \
  --state ENABLED
```

## Verify

```bash
# Xác nhận chi phí trend đang giảm (so sánh 2 tháng gần nhất)
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01) -2 months" +%Y-%m-%d),End=$(date -u +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --output json

# Kiểm tra không có EIPs, volumes lãng phí
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]' --output text
aws ec2 describe-volumes --filters Name=status,Values=available --output text

# Kiểm tra S3 lifecycle policies đã active
aws s3api get-bucket-lifecycle-configuration --bucket myapp-prod-assets

# Xác nhận dev environment đang tắt ngoài giờ
aws ecs describe-services \
  --cluster myapp-dev-cluster \
  --services myapp-dev-api-service \
  --query 'services[0].{running:runningCount,desired:desiredCount}'
```

## Rollback

- **Rightsizing RDS/ECS**: Scale lại lên nếu performance bị ảnh hưởng (xem [scale-up-down.md](scale-up-down.md))
- **S3 Lifecycle**: Xóa hoặc disable lifecycle rule: `aws s3api delete-bucket-lifecycle --bucket <BUCKET>`
- **Dev scheduling**: Start lại dev resources nếu team cần: `aws ecs update-service --desired-count 1`
- **Savings Plans/RI**: Không thể hủy sau khi mua — đánh giá kỹ trước khi commit

## Escalation

| Điều kiện | Escalation đến |
|-----------|----------------|
| Chi phí tăng > 20% so với tháng trước không rõ nguyên nhân | Engineering Manager + FinOps |
| Cần mua Reserved Instances / Savings Plans | Engineering Manager + Finance (cần approval) |
| Rightsizing gây performance degradation | Team Lead + DevOps Lead |
| Phát hiện tài nguyên không có tag (không xác định được owner) | DevOps Lead — enforce tagging policy |
| Cần tăng AWS service quotas để tối ưu | DevOps Lead — mở AWS Support case |
