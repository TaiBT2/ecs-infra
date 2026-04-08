# AWS Access Management

## Request SSO access

To be granted AWS access, you need to:

1. Contact your **Team Lead** or **IT Admin** to request adding your account to AWS IAM Identity Center (SSO).
2. Provide the following information:
   - Company email
   - Team / project
   - Environment access needed (dev / staging / prod)
   - Required permission level (ReadOnly, PowerUser, Admin)
3. After approval, you will receive an invitation email from AWS SSO. Follow the instructions in the email to activate your account.

> **Note:** Production access requires approval from an Engineering Manager or above.

## Configure AWS SSO

After obtaining your SSO account, configure it on your local machine:

```bash
aws configure sso
```

Enter the following information when prompted:

```
SSO session name (Recommended): infra-ecs
SSO start URL [None]: https://<DOMAIN>.awsapps.com/start
SSO region [None]: ap-southeast-1
SSO registration scopes [sso:account:access]:
```

Your browser will open for authentication. After authenticating, select the appropriate account and role.

The configuration will be saved to `~/.aws/config`. Example of a generated profile:

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

Daily login:

```bash
aws sso login --profile dev
```

## Assume role for a specific environment

In some cases, you need to assume a role to access resources in a different environment:

```bash
# Assume role for the staging environment
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT_ID_STAGING>:role/InfraDeployRole \
  --role-session-name my-session \
  --duration-seconds 3600 \
  --profile dev

# Export credentials from the output
export AWS_ACCESS_KEY_ID="<AccessKeyId>"
export AWS_SECRET_ACCESS_KEY="<SecretAccessKey>"
export AWS_SESSION_TOKEN="<SessionToken>"

# Verify
aws sts get-caller-identity
```

Or configure a profile with source_profile:

```ini
[profile staging]
role_arn = arn:aws:iam::<ACCOUNT_ID_STAGING>:role/InfraDeployRole
source_profile = dev
region = ap-southeast-1
```

Then use it directly:

```bash
aws ecs list-clusters --profile staging
```

## MFA setup and usage

### Set up MFA

1. Log in to the AWS SSO portal: `https://<DOMAIN>.awsapps.com/start`
2. Go to **MFA devices** > **Register device**.
3. Select the MFA type:
   - **Authenticator app** (recommended): Google Authenticator, Authy, 1Password
   - **Security key**: YubiKey, Titan Key
4. Scan the QR code with your authenticator app and enter the verification code.

### Using MFA

MFA is automatically required when logging in via SSO. If using an IAM role directly (not through SSO):

```bash
aws sts get-session-token \
  --serial-number arn:aws:iam::<ACCOUNT_ID>:mfa/<username> \
  --token-code <6-digit-code-from-app> \
  --duration-seconds 3600
```

> **Mandatory:** All accounts must have MFA enabled. Accounts without MFA will be disabled after 7 days.

## Connect to RDS via SSM port forwarding

To securely connect to RDS without opening public access, use AWS Systems Manager Session Manager.

### Install Session Manager plugin

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

Verify the installation:

```bash
session-manager-plugin --version
```

### Connect to the database

Use the script included in the repository:

```bash
./scripts/db-connect.sh dev
```

The script will automatically:
1. Find a suitable bastion instance or ECS task.
2. Set up SSM port forwarding from localhost:5432 to the RDS endpoint.
3. Print the connection information.

### Connect with psql

After port forwarding is running (keep the terminal open), open a new terminal:

```bash
psql -h localhost -p 5432 -U myapp -d myapp
```

Enter the password when prompted. The password is stored in AWS Secrets Manager - retrieve it with the command:

```bash
aws secretsmanager get-secret-value \
  --secret-id myapp/dev/db-password \
  --query 'SecretString' \
  --output text \
  --profile dev
```

## Access ECS containers

To access a shell inside a running ECS container (similar to `docker exec`):

```bash
# List running tasks
aws ecs list-tasks \
  --cluster myapp-dev \
  --service-name myapp-api-dev \
  --profile dev

# Execute command into the container
aws ecs execute-command \
  --cluster myapp-dev \
  --task <task-id> \
  --container myapp-api \
  --command "/bin/sh" \
  --interactive \
  --profile dev
```

> **Note:** ECS Exec must be enabled in the task definition (`enableExecuteCommand = true`). This configuration is already included in the Terraform code.

## View logs

### CloudWatch Logs

View real-time logs from the ECS service:

```bash
# View latest logs (tail)
aws logs tail /ecs/myapp-dev --follow --profile dev

# View logs within a specific time range
aws logs tail /ecs/myapp-dev \
  --since 1h \
  --profile dev

# Filter logs by pattern
aws logs filter-log-events \
  --log-group-name /ecs/myapp-dev \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s000) \
  --profile dev
```

### Logs from other services

```bash
# ALB access logs (if enabled)
aws s3 ls s3://myapp-dev-alb-logs/ --profile dev

# RDS logs
aws rds describe-db-log-files \
  --db-instance-identifier myapp-dev \
  --profile dev
```

## Security policies

Security rules that are **mandatory** to follow when working with AWS:

### Do not use IAM Users

- **Always use IAM Roles** through SSO or assume-role.
- Do not create IAM users with static access keys.
- The only exception: service accounts for CI/CD (managed by Terraform).

### Use Roles

- Each environment (dev, staging, prod) has its own role with appropriate permissions.
- Do not share roles between environments.
- Use `source_profile` or SSO to switch between environments.

### Principle of Least Privilege

- Only request permissions necessary for your work.
- ReadOnly access is sufficient for most daily tasks (viewing logs, debugging).
- PowerUser / Admin access is only needed when deploying or changing infrastructure.
- Review permissions periodically every quarter.

### Do not use long-term credentials

- Do not store access keys / secret keys in files, code, or environment variables long-term.
- Session tokens from SSO / assume-role expire automatically (default 1 hour).
- If credentials are found to be exposed, **report immediately** to the security team and rotate credentials.

### Additional rules

- Do not open security groups with `0.0.0.0/0` for any port other than 80/443.
- Do not disable encryption for any resource (S3, RDS, EBS).
- Do not create public S3 buckets.
- All infrastructure changes must go through a Pull Request and be reviewed.
