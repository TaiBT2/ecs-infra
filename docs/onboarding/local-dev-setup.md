# Local Development Environment Setup

## Pre-commit hooks setup

Pre-commit hooks automatically check code before each commit, ensuring quality and security.

### Install pre-commit

```bash
pip install pre-commit
```

### Configure .pre-commit-config.yaml

Create or update the `.pre-commit-config.yaml` file in the root directory of the repository:

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-tf
    rev: v1.96.1
    hooks:
      - id: terraform_fmt
        name: Terraform fmt
        description: Auto-format Terraform code

      - id: terraform_tflint
        name: Terraform tflint
        description: Check for errors and best practices

      - id: terraform_tfsec
        name: Terraform tfsec
        description: Scan for security vulnerabilities

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        name: Detect secrets
        description: Detect accidentally committed secrets
        args: ["--baseline", ".secrets.baseline"]
```

### Activate pre-commit

```bash
# Install hooks into git
pre-commit install

# Run a test on the entire repository
pre-commit run --all-files
```

## IDE setup

### VSCode

#### Required extensions

Install the following extensions from the VS Code Marketplace:

- **HashiCorp Terraform** (`hashicorp.terraform`) - Syntax highlighting, auto-completion, go-to-definition for Terraform
- **AWS Toolkit** (`amazonwebservices.aws-toolkit-vscode`) - AWS services integration directly in the IDE

#### Configure settings.json

Add the following configuration to your workspace's `.vscode/settings.json`:

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

1. Go to **Settings > Plugins > Marketplace**.
2. Search for and install the **Terraform and HCL** plugin (by JetBrains).
3. Enable auto-format: **Settings > Tools > Terraform > Format on save**.

## Terraform fmt: auto-format on save

`terraform fmt` ensures code is always consistent with HashiCorp's standard.

```bash
# Format the entire project
terraform fmt -recursive

# Check which files are not yet formatted (does not modify files)
terraform fmt -check -recursive
```

If you have configured your IDE following the instructions above, files will be automatically formatted every time you save.

## Linting: tflint with project config

tflint checks for syntax errors, best practices, and AWS provider-specific rules.

```bash
# Initialize tflint (download plugins)
tflint --init

# Run lint in the current directory
tflint

# Run lint recursively for the entire project
find terraform/ -name '*.tf' -exec dirname {} \; | sort -u | while read dir; do
  echo "=== Linting: $dir ==="
  tflint --chdir="$dir"
done
```

The `.tflint.hcl` configuration file in the root directory has been pre-configured with rules appropriate for the project.

## Security scanning locally

### tfsec

Scan for security issues in Terraform code:

```bash
# Scan the entire project
tfsec terraform/

# Scan with JSON output
tfsec terraform/ --format json

# Skip a specific rule (only when there is a valid reason)
tfsec terraform/ --exclude aws-vpc-no-public-ingress
```

### checkov

Comprehensive compliance and security checking:

```bash
# Scan the entire terraform directory
checkov -d terraform/

# Scan with a specific framework
checkov -d terraform/ --framework terraform

# Export report in JUnit XML format (useful for CI)
checkov -d terraform/ -o junitxml > checkov-report.xml
```

> **Tip:** Run both `tfsec` and `checkov` before creating a PR. The CI pipeline will also run these tools, but catching issues early saves time.

## Git workflow

### Branch naming convention

```
<type>/<ticket-id>-<short-description>
```

Examples:
- `feat/INFRA-123-add-redis-cluster`
- `fix/INFRA-456-fix-alb-health-check`
- `chore/INFRA-789-update-terraform-version`

Common types:
| Type      | Purpose                               |
| --------- | ------------------------------------- |
| `feat`    | New feature or new resource           |
| `fix`     | Bug fix                               |
| `chore`   | Update dependencies, minor refactor   |
| `docs`    | Update documentation                  |
| `security`| Security fix                          |

### Commit message convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

<body - optional>

<footer - optional>
```

Example:

```
feat(ecs): add auto-scaling policy for API service

- Add target tracking scaling policy based on CPU utilization
- Configure scale-in cooldown to 300s
- Add CloudWatch alarms for scaling events

Refs: INFRA-123
```

### PR template

When creating a Pull Request, make sure to include:

1. **Description of changes**: Clearly explain what changed and why.
2. **Terraform plan output**: Attach the `terraform plan` output for the relevant environment.
3. **Checklist**:
   - [ ] `terraform fmt` has been run
   - [ ] `tflint` has no errors
   - [ ] `tfsec` / `checkov` has no new findings
   - [ ] Documentation has been updated (if needed)
   - [ ] Tested on the dev environment (if applicable)
4. **Reviewer**: Tag at least 1 person from the platform team.
