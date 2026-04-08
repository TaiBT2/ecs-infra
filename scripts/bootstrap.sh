#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Terraform remote state infrastructure (S3 bucket + DynamoDB lock table).
# Usage: ./bootstrap.sh <dev|staging|prod>

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Validate arguments ---
ENV="${1:-}"
if [[ -z "$ENV" ]]; then
  error "Usage: $0 <dev|staging|prod>"
fi

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  error "Invalid environment '${ENV}'. Must be one of: dev, staging, prod"
fi

# --- Variables ---
BUCKET="myapp-${ENV}-terraform-state"
TABLE="myapp-${ENV}-terraform-locks"
REGION="ap-southeast-1"

info "Bootstrapping Terraform backend for environment: ${ENV}"
info "  Bucket: ${BUCKET}"
info "  Table:  ${TABLE}"
info "  Region: ${REGION}"

# --- S3 Bucket ---
if aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null; then
  success "S3 bucket '${BUCKET}' already exists"
else
  info "Creating S3 bucket '${BUCKET}'..."
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"

  info "Enabling versioning on '${BUCKET}'..."
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

  info "Enabling server-side encryption on '${BUCKET}'..."
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "aws:kms"
          },
          "BucketKeyEnabled": true
        }
      ]
    }'

  info "Blocking public access on '${BUCKET}'..."
  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  success "S3 bucket '${BUCKET}' created and configured"
fi

# --- DynamoDB Table ---
if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" >/dev/null 2>&1; then
  success "DynamoDB table '${TABLE}' already exists"
else
  info "Creating DynamoDB table '${TABLE}'..."
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --region "$REGION" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

  info "Waiting for table to become active..."
  aws dynamodb wait table-exists --table-name "$TABLE" --region "$REGION"

  info "Enabling point-in-time recovery on '${TABLE}'..."
  aws dynamodb update-continuous-backups \
    --table-name "$TABLE" \
    --region "$REGION" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

  success "DynamoDB table '${TABLE}' created and configured"
fi

echo ""
success "Bootstrap complete for '${ENV}' environment!"
