#!/usr/bin/env bash
set -euo pipefail

# Connect to RDS via AWS SSM port forwarding through an ECS task or SSM-managed instance.
# Usage: ./db-connect.sh <dev|staging|prod> [local_port]
#
# After running this script, open a new terminal and connect with psql:
#   psql -h 127.0.0.1 -p <local_port> -U <db_user> -d <db_name>
#
# The database credentials can be retrieved from AWS Secrets Manager:
#   aws secretsmanager get-secret-value --secret-id myapp-<env>-rds-credentials --region ap-southeast-1

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Validate arguments ---
ENV="${1:-}"
LOCAL_PORT="${2:-5432}"

if [[ -z "$ENV" ]]; then
  error "Usage: $0 <dev|staging|prod> [local_port]"
fi

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  error "Invalid environment '${ENV}'. Must be one of: dev, staging, prod"
fi

REGION="ap-southeast-1"

info "Connecting to RDS in '${ENV}' environment via SSM port forwarding..."
info "  Local port: ${LOCAL_PORT}"
info "  Region:     ${REGION}"

# --- Get RDS endpoint ---
# Try terraform output first, fall back to SSM parameter
info "Retrieving RDS endpoint..."
RDS_ENDPOINT=""

if command -v terraform &>/dev/null && [[ -d "terraform/environments/${ENV}" ]]; then
  RDS_ENDPOINT=$(terraform -chdir="terraform/environments/${ENV}" output -raw rds_endpoint 2>/dev/null || true)
fi

if [[ -z "$RDS_ENDPOINT" ]]; then
  info "Terraform output unavailable, fetching from SSM parameter..."
  RDS_ENDPOINT=$(aws ssm get-parameter \
    --name "/myapp/${ENV}/rds/endpoint" \
    --region "$REGION" \
    --query "Parameter.Value" \
    --output text 2>/dev/null) || error "Could not retrieve RDS endpoint from terraform output or SSM parameter"
fi

info "RDS endpoint: ${RDS_ENDPOINT}"

# --- Find SSM target (ECS task or managed instance) ---
info "Looking for an SSM-managed target instance..."
TARGET_INSTANCE=$(aws ssm describe-instance-information \
  --region "$REGION" \
  --filters "Key=tag:Environment,Values=${ENV}" \
  --query "InstanceInformationList[0].InstanceId" \
  --output text 2>/dev/null || true)

if [[ -z "$TARGET_INSTANCE" || "$TARGET_INSTANCE" == "None" ]]; then
  # Try to find an ECS task with execute-command enabled
  CLUSTER="myapp-${ENV}"
  info "No SSM instance found, looking for ECS tasks in cluster '${CLUSTER}'..."
  TASK_ARN=$(aws ecs list-tasks \
    --cluster "$CLUSTER" \
    --region "$REGION" \
    --desired-status RUNNING \
    --query "taskArns[0]" \
    --output text 2>/dev/null) || error "No running ECS tasks found in cluster '${CLUSTER}'"

  if [[ -z "$TASK_ARN" || "$TASK_ARN" == "None" ]]; then
    error "No running ECS tasks or SSM-managed instances found for environment '${ENV}'"
  fi

  TARGET_INSTANCE="ecs:${CLUSTER}_$(basename "$TASK_ARN")"
  info "Using ECS task as target: ${TARGET_INSTANCE}"
else
  info "Using SSM-managed instance: ${TARGET_INSTANCE}"
fi

# --- Start port forwarding session ---
success "Starting SSM port forwarding session..."
echo -e "${YELLOW}Once connected, use psql in another terminal:${NC}"
echo -e "  psql -h 127.0.0.1 -p ${LOCAL_PORT} -U <db_user> -d <db_name>"
echo ""

aws ssm start-session \
  --target "$TARGET_INSTANCE" \
  --region "$REGION" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=${RDS_ENDPOINT},portNumber=5432,localPortNumber=${LOCAL_PORT}"
