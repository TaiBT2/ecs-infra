# Quản lý quyền truy cập AWS

## Request SSO access

Để được cấp quyền truy cập AWS, bạn cần:

1. Liên hệ **Team Lead** hoặc **IT Admin** để yêu cầu thêm tài khoản vào AWS IAM Identity Center (SSO).
2. Cung cấp thông tin:
   - Email công ty
   - Team / dự án
   - Môi trường cần truy cập (dev / staging / prod)
   - Mức quyền cần thiết (ReadOnly, PowerUser, Admin)
3. Sau khi được phê duyệt, bạn sẽ nhận email mời từ AWS SSO. Làm theo hướng dẫn trong email để kích hoạt tài khoản.

> **Lưu ý:** Quyền truy cập production yêu cầu phê duyệt từ Engineering Manager trở lên.

## Configure AWS SSO

Sau khi có tài khoản SSO, cấu hình trên máy local:

```bash
aws configure sso
```

Nhập các thông tin sau khi được hỏi:

```
SSO session name (Recommended): infra-ecs
SSO start URL [None]: https://<DOMAIN>.awsapps.com/start
SSO region [None]: ap-southeast-1
SSO registration scopes [sso:account:access]:
```

Trình duyệt sẽ mở để bạn xác thực. Sau khi xác thực, chọn account và role phù hợp.

Cấu hình sẽ được lưu vào `~/.aws/config`. Ví dụ profile được tạo:

```ini
[profile dev]
sso_session = infra-ecs
sso_account_id = 123456789012
sso_role_name = PowerUserAccess
region = ap-southeast-1
output = json

[sso-session infra-ecs]
sso_start_url = https://<DOMAIN>.awsapps.com/start
sso_region = ap-southeast-1
sso_registration_scopes = sso:account:access
```

Đăng nhập hàng ngày:

```bash
aws sso login --profile dev
```

## Assume role cho môi trường cụ thể

Trong một số trường hợp, bạn cần assume role để truy cập tài nguyên ở môi trường khác:

```bash
# Assume role cho môi trường staging
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT_ID_STAGING>:role/InfraDeployRole \
  --role-session-name my-session \
  --duration-seconds 3600 \
  --profile dev

# Export credentials từ output
export AWS_ACCESS_KEY_ID="<AccessKeyId>"
export AWS_SECRET_ACCESS_KEY="<SecretAccessKey>"
export AWS_SESSION_TOKEN="<SessionToken>"

# Xác nhận
aws sts get-caller-identity
```

Hoặc cấu hình profile với source_profile:

```ini
[profile staging]
role_arn = arn:aws:iam::<ACCOUNT_ID_STAGING>:role/InfraDeployRole
source_profile = dev
region = ap-southeast-1
```

Sau đó sử dụng trực tiếp:

```bash
aws ecs list-clusters --profile staging
```

## MFA setup và cách sử dụng

### Thiết lập MFA

1. Đăng nhập vào AWS SSO portal: `https://<DOMAIN>.awsapps.com/start`
2. Vào **MFA devices** > **Register device**.
3. Chọn loại MFA:
   - **Authenticator app** (khuyến nghị): Google Authenticator, Authy, 1Password
   - **Security key**: YubiKey, Titan Key
4. Quét QR code bằng ứng dụng authenticator và nhập mã xác nhận.

### Sử dụng MFA

MFA được yêu cầu tự động khi đăng nhập SSO. Nếu sử dụng IAM role trực tiếp (không qua SSO):

```bash
aws sts get-session-token \
  --serial-number arn:aws:iam::<ACCOUNT_ID>:mfa/<username> \
  --token-code <mã-6-số-từ-app> \
  --duration-seconds 3600
```

> **Bắt buộc:** Tất cả tài khoản phải bật MFA. Tài khoản không có MFA sẽ bị vô hiệu hóa sau 7 ngày.

## Connect to RDS via SSM port forwarding

Để kết nối an toàn tới RDS mà không cần mở public access, sử dụng AWS Systems Manager Session Manager.

### Cài đặt Session Manager plugin

**macOS:**

```bash
brew install --cask session-manager-plugin
```

**Ubuntu / Debian:**

```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

**Windows:**

```powershell
choco install session-manager-plugin
```

Xác nhận cài đặt:

```bash
session-manager-plugin --version
```

### Kết nối tới database

Sử dụng script có sẵn trong repository:

```bash
./scripts/db-connect.sh dev
```

Script sẽ tự động:
1. Tìm bastion instance hoặc ECS task phù hợp.
2. Thiết lập SSM port forwarding từ localhost:5432 tới RDS endpoint.
3. In ra thông tin kết nối.

### Kết nối với psql

Sau khi port forwarding đã chạy (giữ terminal mở), mở terminal mới:

```bash
psql -h localhost -p 5432 -U myapp -d myapp
```

Nhập password khi được hỏi. Password được lưu trong AWS Secrets Manager - lấy bằng lệnh:

```bash
aws secretsmanager get-secret-value \
  --secret-id myapp/dev/db-password \
  --query 'SecretString' \
  --output text \
  --profile dev
```

## Access ECS containers

Để truy cập shell bên trong container ECS đang chạy (tương tự `docker exec`):

```bash
# Liệt kê các task đang chạy
aws ecs list-tasks \
  --cluster myapp-dev \
  --service-name myapp-api-dev \
  --profile dev

# Execute command vào container
aws ecs execute-command \
  --cluster myapp-dev \
  --task <task-id> \
  --container myapp-api \
  --command "/bin/sh" \
  --interactive \
  --profile dev
```

> **Lưu ý:** ECS Exec phải được bật trong task definition (`enableExecuteCommand = true`). Cấu hình này đã có sẵn trong Terraform code.

## View logs

### CloudWatch Logs

Xem logs real-time từ ECS service:

```bash
# Xem logs mới nhất (tail)
aws logs tail /ecs/myapp-dev --follow --profile dev

# Xem logs trong khoảng thời gian cụ thể
aws logs tail /ecs/myapp-dev \
  --since 1h \
  --profile dev

# Lọc logs theo pattern
aws logs filter-log-events \
  --log-group-name /ecs/myapp-dev \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s000) \
  --profile dev
```

### Logs từ các service khác

```bash
# ALB access logs (nếu bật)
aws s3 ls s3://myapp-dev-alb-logs/ --profile dev

# RDS logs
aws rds describe-db-log-files \
  --db-instance-identifier myapp-dev \
  --profile dev
```

## Security policies

Các quy tắc bảo mật **bắt buộc** phải tuân thủ khi làm việc với AWS:

### Không sử dụng IAM Users

- **Luôn sử dụng IAM Roles** thông qua SSO hoặc assume-role.
- Không tạo IAM user với access key tĩnh.
- Ngoại lệ duy nhất: service account cho CI/CD (được quản lý bởi Terraform).

### Sử dụng Roles

- Mỗi môi trường (dev, staging, prod) có role riêng với quyền phù hợp.
- Không chia sẻ role giữa các môi trường.
- Sử dụng `source_profile` hoặc SSO để chuyển đổi giữa các môi trường.

### Nguyên tắc quyền tối thiểu (Least Privilege)

- Chỉ yêu cầu quyền cần thiết cho công việc.
- Quyền ReadOnly là đủ cho hầu hết tác vụ hàng ngày (xem logs, debug).
- Quyền PowerUser / Admin chỉ cần khi deploy hoặc thay đổi infrastructure.
- Review quyền định kỳ mỗi quý.

### Không sử dụng long-term credentials

- Không lưu access key / secret key trong file, code, hoặc biến môi trường lâu dài.
- Session token từ SSO / assume-role tự động hết hạn (mặc định 1 giờ).
- Nếu phát hiện credentials bị lộ, **báo cáo ngay lập tức** cho team security và rotate credentials.

### Quy tắc bổ sung

- Không mở security group với `0.0.0.0/0` cho port nào ngoài 80/443.
- Không tắt encryption cho bất kỳ resource nào (S3, RDS, EBS).
- Không tạo public S3 bucket.
- Mọi thay đổi infrastructure phải qua Pull Request và được review.
