# Thiết lập môi trường phát triển local

## Pre-commit hooks setup

Pre-commit hooks giúp tự động kiểm tra code trước mỗi lần commit, đảm bảo chất lượng và bảo mật.

### Cài đặt pre-commit

```bash
pip install pre-commit
```

### Cấu hình .pre-commit-config.yaml

Tạo hoặc cập nhật file `.pre-commit-config.yaml` ở thư mục gốc của repository:

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-tf
    rev: v1.96.1
    hooks:
      - id: terraform_fmt
        name: Terraform fmt
        description: Tự động format code Terraform

      - id: terraform_tflint
        name: Terraform tflint
        description: Kiểm tra lỗi và best practices

      - id: terraform_tfsec
        name: Terraform tfsec
        description: Quét lỗ hổng bảo mật

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        name: Detect secrets
        description: Phát hiện secrets bị commit nhầm
        args: ["--baseline", ".secrets.baseline"]
```

### Kích hoạt pre-commit

```bash
# Cài đặt hooks vào git
pre-commit install

# Chạy thử trên toàn bộ repository
pre-commit run --all-files
```

## IDE setup

### VSCode

#### Extensions cần thiết

Cài đặt các extension sau từ VS Code Marketplace:

- **HashiCorp Terraform** (`hashicorp.terraform`) - Syntax highlighting, auto-completion, go-to-definition cho Terraform
- **AWS Toolkit** (`amazonwebservices.aws-toolkit-vscode`) - Tích hợp AWS services trực tiếp trong IDE

#### Cấu hình settings.json

Thêm các cấu hình sau vào `.vscode/settings.json` của workspace:

```json
{
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true,
    "editor.formatOnSaveMode": "file"
  },
  "[terraform-vars]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  },
  "terraform.experimentalFeatures.validateOnSave": true,
  "terraform.languageServer.enable": true,
  "files.associations": {
    "*.tfvars": "terraform-vars",
    "*.tfbackend": "terraform"
  }
}
```

### JetBrains (IntelliJ / GoLand)

1. Vào **Settings > Plugins > Marketplace**.
2. Tìm và cài đặt plugin **Terraform and HCL** (by JetBrains).
3. Bật auto-format: **Settings > Tools > Terraform > Format on save**.

## Terraform fmt: auto-format on save

`terraform fmt` đảm bảo code luôn nhất quán theo chuẩn của HashiCorp.

```bash
# Format toàn bộ project
terraform fmt -recursive

# Kiểm tra xem file nào chưa được format (không thay đổi file)
terraform fmt -check -recursive
```

Nếu bạn đã cấu hình IDE theo hướng dẫn ở trên, file sẽ được tự động format mỗi khi lưu.

## Linting: tflint với project config

tflint kiểm tra lỗi cú pháp, best practices, và quy tắc riêng của AWS provider.

```bash
# Khởi tạo tflint (tải plugins)
tflint --init

# Chạy lint trong thư mục hiện tại
tflint

# Chạy lint đệ quy cho toàn bộ project
find terraform/ -name '*.tf' -exec dirname {} \; | sort -u | while read dir; do
  echo "=== Linting: $dir ==="
  tflint --chdir="$dir"
done
```

File cấu hình `.tflint.hcl` ở thư mục gốc đã được thiết lập sẵn với các rules phù hợp cho dự án.

## Security scanning locally

### tfsec

Quét các vấn đề bảo mật trong code Terraform:

```bash
# Quét toàn bộ project
tfsec terraform/

# Quét với output dạng JSON
tfsec terraform/ --format json

# Bỏ qua rule cụ thể (chỉ khi có lý do chính đáng)
tfsec terraform/ --exclude aws-vpc-no-public-ingress
```

### checkov

Kiểm tra tuân thủ và bảo mật toàn diện:

```bash
# Quét toàn bộ thư mục terraform
checkov -d terraform/

# Quét với framework cụ thể
checkov -d terraform/ --framework terraform

# Xuất báo cáo dạng JUnit XML (hữu ích cho CI)
checkov -d terraform/ -o junitxml > checkov-report.xml
```

> **Mẹo:** Chạy cả `tfsec` và `checkov` trước khi tạo PR. CI pipeline cũng sẽ chạy lại các công cụ này, nhưng phát hiện sớm giúp tiết kiệm thời gian.

## Git workflow

### Quy ước đặt tên branch

```
<type>/<ticket-id>-<mô-tả-ngắn>
```

Ví dụ:
- `feat/INFRA-123-add-redis-cluster`
- `fix/INFRA-456-fix-alb-health-check`
- `chore/INFRA-789-update-terraform-version`

Các type phổ biến:
| Type      | Mục đích                              |
| --------- | ------------------------------------- |
| `feat`    | Tính năng mới hoặc resource mới      |
| `fix`     | Sửa lỗi                              |
| `chore`   | Cập nhật dependencies, refactor nhỏ  |
| `docs`    | Cập nhật tài liệu                    |
| `security`| Sửa lỗi bảo mật                     |

### Quy ước commit message

Sử dụng [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <mô tả ngắn>

<body - tùy chọn>

<footer - tùy chọn>
```

Ví dụ:

```
feat(ecs): add auto-scaling policy for API service

- Add target tracking scaling policy based on CPU utilization
- Configure scale-in cooldown to 300s
- Add CloudWatch alarms for scaling events

Refs: INFRA-123
```

### PR template

Khi tạo Pull Request, đảm bảo bao gồm:

1. **Mô tả thay đổi**: Giải thích rõ ràng thay đổi gì và tại sao.
2. **Terraform plan output**: Đính kèm output của `terraform plan` cho môi trường liên quan.
3. **Checklist**:
   - [ ] `terraform fmt` đã chạy
   - [ ] `tflint` không có lỗi
   - [ ] `tfsec` / `checkov` không có finding mới
   - [ ] Đã cập nhật tài liệu (nếu cần)
   - [ ] Đã test trên môi trường dev (nếu applicable)
4. **Reviewer**: Tag ít nhất 1 người trong team platform.
