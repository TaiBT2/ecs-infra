# Hướng dẫn bắt đầu

## Yêu cầu hệ thống

Trước khi bắt đầu, hãy đảm bảo máy của bạn đã cài đặt các công cụ sau:

| Công cụ    | Phiên bản tối thiểu | Mục đích                        |
| ---------- | -------------------- | ------------------------------- |
| Terraform  | >= 1.9               | Quản lý hạ tầng IaC            |
| AWS CLI    | v2                   | Tương tác với AWS               |
| tflint     | mới nhất             | Kiểm tra lỗi Terraform         |
| tfsec      | mới nhất             | Quét bảo mật Terraform         |
| checkov    | mới nhất             | Quét bảo mật và tuân thủ       |
| git        | >= 2.30              | Quản lý mã nguồn               |
| jq         | >= 1.6               | Xử lý JSON trên command line   |

## Clone repository

```bash
git clone git@github.com:<GITHUB_ORG>/<GITHUB_REPO>.git
cd infra-ecs
```

## Cài đặt công cụ

### macOS (Homebrew)

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install awscli
brew install tflint
brew install tfsec
brew install checkov
brew install jq
brew install git
```

### Ubuntu / Debian (apt)

```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# checkov
pip install checkov

# jq & git
sudo apt install -y jq git
```

### Windows (Chocolatey)

```powershell
choco install terraform
choco install awscli
choco install tflint
choco install tfsec
pip install checkov
choco install jq
choco install git
```

## Cấu hình AWS credentials

Chúng tôi ưu tiên sử dụng **AWS SSO** thay vì access key tĩnh.

```bash
# Cấu hình SSO profile
aws configure sso
# SSO session name: infra-ecs
# SSO start URL: https://<DOMAIN>.awsapps.com/start
# SSO Region: ap-southeast-1
# Chọn account và role phù hợp

# Đăng nhập SSO
aws sso login --profile dev

# Xác nhận
aws sts get-caller-identity --profile dev
```

Nếu không sử dụng SSO, cấu hình credentials truyền thống:

```bash
aws configure --profile dev
# Nhập AWS Access Key ID, Secret Access Key, Region, Output format
```

## Cần điền trước khi deploy

Trước khi deploy, bạn **bắt buộc** phải thay thế tất cả các placeholder trong codebase bằng giá trị thực tế. Danh sách đầy đủ các placeholder:

| Placeholder              | Mô tả                                          | Ví dụ                              |
| ------------------------ | ----------------------------------------------- | ---------------------------------- |
| `<ACCOUNT_ID_DEV>`      | AWS Account ID cho môi trường dev               | `123456789012`                     |
| `<ACCOUNT_ID_STAGING>`  | AWS Account ID cho môi trường staging           | `234567890123`                     |
| `<ACCOUNT_ID_PROD>`     | AWS Account ID cho môi trường production        | `345678901234`                     |
| `<DOMAIN>`              | Tên miền chính của dự án                        | `mycompany.com`                    |
| `<ALERT_EMAIL>`         | Email nhận cảnh báo từ hệ thống                 | `ops-team@mycompany.com`           |
| `<SLACK_WEBHOOK_URL>`   | Webhook URL Slack để gửi thông báo              | `https://hooks.slack.com/...`      |
| `<GITHUB_ORG>`          | Tên tổ chức GitHub                              | `my-org`                           |
| `<GITHUB_REPO>`         | Tên repository trên GitHub                      | `infra-ecs`                        |
| `<COST_CENTER>`         | Mã trung tâm chi phí cho tagging                | `engineering-platform`             |
| `<OWNER>`               | Người / team chịu trách nhiệm cho resource      | `platform-team`                    |

Sử dụng lệnh sau để tìm tất cả placeholder chưa được thay thế:

```bash
grep -r '<[A-Z_]*>' terraform/ .github/
```

> **Lưu ý:** Không commit giá trị thực của các placeholder nhạy cảm (account ID, webhook URL) vào repository. Sử dụng `terraform.tfvars` (đã nằm trong `.gitignore`) hoặc biến môi trường.

## Bootstrap state lần đầu

Khi deploy lần đầu tiên, bạn cần khởi tạo S3 backend để lưu trữ Terraform state:

```bash
./scripts/bootstrap.sh dev
```

Script này sẽ tạo:
- S3 bucket cho Terraform state
- DynamoDB table cho state locking
- Cấu hình encryption và versioning

## Deploy môi trường dev

Sau khi bootstrap xong, tiến hành deploy:

```bash
cd terraform/envs/dev

# Khởi tạo Terraform (tải providers và modules)
terraform init

# Xem trước thay đổi
terraform plan

# Áp dụng thay đổi (nhập "yes" khi được hỏi)
terraform apply
```

## Xác nhận deploy thành công

Sau khi `terraform apply` hoàn tất, kiểm tra kết quả:

### 1. Kiểm tra terraform output

```bash
terraform output
```

Bạn sẽ thấy các output như ALB DNS name, ECS cluster name, RDS endpoint, v.v.

### 2. Kiểm tra trên AWS Console

- **ECS**: Vào ECS Console > Clusters, xác nhận cluster đã được tạo và service đang chạy.
- **ALB**: Vào EC2 Console > Load Balancers, xác nhận ALB healthy.
- **RDS**: Vào RDS Console, xác nhận database instance ở trạng thái "Available".
- **VPC**: Vào VPC Console, xác nhận VPC, subnets, và security groups đã được tạo.

### 3. Kiểm tra health check

```bash
# Lấy ALB DNS từ terraform output
ALB_DNS=$(terraform output -raw alb_dns_name)

# Kiểm tra health endpoint
curl -s "http://${ALB_DNS}/health"
```

Nếu trả về status `200 OK`, deploy đã thành công.
