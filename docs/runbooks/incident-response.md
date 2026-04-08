# Runbook: Xử lý sự cố (Incident Response)

## Mục đích & khi nào dùng

Runbook này hướng dẫn quy trình phản ứng khi hệ thống MyApp gặp sự cố ảnh hưởng đến người dùng hoặc hạ tầng. Sử dụng khi:

- Nhận alert từ CloudWatch / PagerDuty / Slack
- Người dùng báo lỗi hàng loạt
- Monitoring dashboard cho thấy metric bất thường (error rate tăng, latency cao, service unhealthy)

## Tiền điều kiện

- Quyền truy cập AWS Console hoặc AWS CLI đã cấu hình (`aws sts get-caller-identity`)
- Quyền đọc CloudWatch Logs, X-Ray, ECS, RDS
- Tài khoản Slack với quyền tạo channel
- Quyền truy cập Zoom/Google Meet để tạo war room
- Danh sách liên hệ on-call team cập nhật

## Các bước chi tiết

### Bước 1: Đánh giá mức độ nghiêm trọng (Severity Matrix)

| Mức độ | Mô tả | Thời gian phản hồi | Escalation |
|--------|--------|---------------------|------------|
| **SEV1** | Hệ thống production sập hoàn toàn, mất dữ liệu, bảo mật bị xâm phạm | **15 phút** | VP Engineering + CTO ngay lập tức |
| **SEV2** | Chức năng chính bị ảnh hưởng nghiêm trọng, >50% người dùng bị ảnh hưởng | **30 phút** | Engineering Manager + Team Lead |
| **SEV3** | Chức năng phụ bị ảnh hưởng, <50% người dùng, có workaround | **2 giờ** | Team Lead |
| **SEV4** | Ảnh hưởng nhỏ, cosmetic issue, không ảnh hưởng chức năng chính | **1 ngày làm việc** | Xử lý trong sprint tiếp theo |

### Bước 2: Thiết lập War Room

**Tạo Slack channel:**

```bash
# Đặt tên channel theo format: #inc-YYYYMMDD-mô-tả-ngắn
# Ví dụ: #inc-20260408-api-timeout
```

- Mời các thành viên cần thiết vào channel
- Pin message đầu tiên với thông tin tóm tắt sự cố

**Tạo Zoom/Meet call (cho SEV1 & SEV2):**

- Tạo meeting room và chia sẻ link vào Slack channel
- Bật recording để phục vụ postmortem

**Phân công vai trò:**

| Vai trò | Trách nhiệm |
|---------|-------------|
| **Incident Commander (IC)** | Điều phối tổng thể, ra quyết định, quản lý timeline |
| **Tech Lead** | Điều tra kỹ thuật, đề xuất giải pháp, thực hiện fix |
| **Communications Lead** | Cập nhật stakeholder, status page, khách hàng |
| **Scribe** | Ghi chép timeline, các hành động đã thực hiện |

### Bước 3: Thông báo cho Stakeholders

**Template thông báo lần đầu:**

```
[SEV<N>] Sự cố: <Mô tả ngắn gọn>
Thời gian phát hiện: <YYYY-MM-DD HH:MM UTC>
Ảnh hưởng: <Mô tả ảnh hưởng đến người dùng>
Trạng thái: Đang điều tra
Incident Commander: <Tên>
War Room: <Link Slack channel>
Cập nhật tiếp theo: trong <N> phút
```

**Template cập nhật:**

```
[CẬP NHẬT] Sự cố: <Mô tả ngắn gọn>
Trạng thái: Đang xử lý / Đã xác định nguyên nhân / Đã khắc phục
Cập nhật: <Mô tả những gì đã làm>
Bước tiếp theo: <Kế hoạch tiếp theo>
Cập nhật tiếp theo: trong <N> phút
```

**Template kết thúc sự cố:**

```
[ĐÃ GIẢI QUYẾT] Sự cố: <Mô tả ngắn gọn>
Thời gian phát hiện: <YYYY-MM-DD HH:MM UTC>
Thời gian khắc phục: <YYYY-MM-DD HH:MM UTC>
Tổng thời gian: <N> phút
Nguyên nhân tóm tắt: <1-2 câu>
Postmortem sẽ được thực hiện: <YYYY-MM-DD>
```

### Bước 4: Điều tra (Investigation)

**4a. Kiểm tra tổng quan hệ thống:**

```bash
# Kiểm tra trạng thái ECS services
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[].{status:status,running:runningCount,desired:desiredCount,deployments:deployments[].{status:status,running:runningCount,desired:desiredCount,taskDef:taskDefinition}}' \
  --output table

# Kiểm tra health của ALB target groups
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --output table
```

**4b. Kiểm tra CloudWatch Metrics:**

```bash
# Kiểm tra error rate của ALB (5 phút gần nhất)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum

# Kiểm tra latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,p99

# Kiểm tra CPU/Memory ECS
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=myapp-prod-cluster Name=ServiceName,Value=myapp-prod-api-service \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,Maximum
```

**4c. Kiểm tra logs:**

```bash
# Xem logs gần nhất của ECS tasks
aws logs tail /ecs/myapp-prod-api --since 15m --follow

# Tìm kiếm lỗi cụ thể trong logs
aws logs filter-log-events \
  --log-group-name /ecs/myapp-prod-api \
  --start-time $(date -u -d '30 minutes ago' +%s)000 \
  --filter-pattern "ERROR" \
  --limit 50

# Tìm kiếm theo request ID
aws logs filter-log-events \
  --log-group-name /ecs/myapp-prod-api \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --filter-pattern "\"<REQUEST_ID>\""
```

**4d. Kiểm tra X-Ray traces (nếu có):**

```bash
# Tìm traces có lỗi trong 15 phút gần nhất
aws xray get-trace-summaries \
  --start-time $(date -u -d '15 minutes ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression 'service("myapp-api") AND fault = true' \
  --output json

# Lấy chi tiết trace
aws xray batch-get-traces \
  --trace-ids <TRACE_ID>
```

**4e. Kiểm tra RDS:**

```bash
# Kiểm tra trạng thái RDS
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-rds-main \
  --query 'DBInstances[].{Status:DBInstanceStatus,AZ:AvailabilityZone,CPU:PerformanceInsightsEnabled,Storage:AllocatedStorage}' \
  --output table

# Kiểm tra connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod-rds-main \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,Maximum
```

**4f. Kiểm tra ElastiCache:**

```bash
# Kiểm tra trạng thái Redis cluster
aws elasticache describe-replication-groups \
  --replication-group-id myapp-prod-redis \
  --query 'ReplicationGroups[].{Status:Status,Nodes:NodeGroups[].{Status:Status,Primary:PrimaryEndpoint}}' \
  --output json
```

### Bước 5: Khắc phục & Ghi chép

- Thực hiện fix dựa trên nguyên nhân đã xác định
- Mỗi hành động phải được ghi lại trong Slack channel với timestamp
- Tham khảo các runbook khác nếu cần: [deploy-rollback.md](deploy-rollback.md), [db-failover.md](db-failover.md), [scale-up-down.md](scale-up-down.md)

## Verify

```bash
# Xác nhận ECS service healthy
aws ecs describe-services \
  --cluster myapp-prod-cluster \
  --services myapp-prod-api-service \
  --query 'services[].{running:runningCount,desired:desiredCount,status:status}'

# Xác nhận ALB targets healthy
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --query 'TargetHealthDescriptions[].{target:Target.Id,health:TargetHealth.State}'

# Xác nhận error rate trở về bình thường
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum

# Kiểm tra endpoint chính
curl -s -o /dev/null -w "%{http_code}" https://<DOMAIN>/api/health
```

## Rollback

Nếu fix gây ra vấn đề mới:

1. Rollback ngay về trạng thái trước khi fix (xem [deploy-rollback.md](deploy-rollback.md))
2. Thông báo trong war room
3. Quay lại bước điều tra

## Escalation

| Điều kiện | Escalation đến |
|-----------|----------------|
| Không thể xác định nguyên nhân trong 30 phút (SEV1) | CTO, AWS Support (Business/Enterprise) |
| Không thể xác định nguyên nhân trong 1 giờ (SEV2) | VP Engineering |
| Nghi ngờ bảo mật bị xâm phạm | Security Team + CISO ngay lập tức |
| Ảnh hưởng đến dữ liệu khách hàng | Legal + Compliance Team |
| Cần AWS Support | Mở case tại https://console.aws.amazon.com/support — chọn Severity phù hợp |

---

## Postmortem Template

Thực hiện postmortem trong vòng **48 giờ** sau khi sự cố được giải quyết (bắt buộc cho SEV1 & SEV2).

```markdown
# Postmortem: <Tên sự cố>

**Ngày sự cố:** YYYY-MM-DD
**Mức độ:** SEV<N>
**Incident Commander:** <Tên>
**Người viết postmortem:** <Tên>

## Tóm tắt
<1-2 câu mô tả sự cố và ảnh hưởng>

## Ảnh hưởng
- Thời gian downtime: <N> phút
- Số người dùng bị ảnh hưởng: <N>
- Doanh thu bị ảnh hưởng: <ước tính>
- SLA bị vi phạm: Có / Không

## Timeline (UTC)
| Thời gian | Sự kiện |
|-----------|---------|
| HH:MM | Alert được kích hoạt |
| HH:MM | Incident Commander tiếp nhận |
| HH:MM | War room được thiết lập |
| HH:MM | Nguyên nhân được xác định |
| HH:MM | Fix được triển khai |
| HH:MM | Hệ thống phục hồi hoàn toàn |
| HH:MM | Sự cố được đóng |

## Nguyên nhân gốc (Root Cause)
<Mô tả chi tiết nguyên nhân gốc>

## Nguyên nhân kích hoạt (Trigger)
<Hành động hoặc sự kiện nào đã kích hoạt sự cố>

## Phát hiện (Detection)
<Sự cố được phát hiện như thế nào — alert, người dùng báo, kiểm tra thủ công>

## Các hành động đã thực hiện
1. <Hành động 1>
2. <Hành động 2>
...

## Điều gì đã hoạt động tốt
- <Điểm tốt 1>
- <Điểm tốt 2>

## Điều gì cần cải thiện
- <Điểm cải thiện 1>
- <Điểm cải thiện 2>

## Action Items
| # | Hành động | Người phụ trách | Hạn chót | Trạng thái |
|---|-----------|-----------------|----------|------------|
| 1 | <Action item> | <Tên> | YYYY-MM-DD | TODO |
| 2 | <Action item> | <Tên> | YYYY-MM-DD | TODO |

## Bài học kinh nghiệm
<Những bài học rút ra từ sự cố>
```
