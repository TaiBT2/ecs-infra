#!/usr/bin/env bash
set -euo pipefail

# Rotate RDS credentials in Secrets Manager and force ECS redeployment.
# Usage: ./rotate-secrets.sh <dev|staging|prod>

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

if [[ -z "$ENV" ]]; then
  error "Usage: $0 <dev|staging|prod>"
fi

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  error "Invalid environment '${ENV}'. Must be one of: dev, staging, prod"
fi

REGION="ap-southeast-1"
SECRET_ID="myapp-${ENV}-rds-credentials"
CLUSTER="myapp-${ENV}"
SERVICE="myapp-${ENV}-api"

info "Rotating secrets for environment: ${ENV}"
info "  Secret:  ${SECRET_ID}"
info "  Cluster: ${CLUSTER}"
info "  Service: ${SERVICE}"
info "  Region:  ${REGION}"

# --- Trigger rotation ---
info "Triggering secret rotation for '${SECRET_ID}'..."
aws secretsmanager rotate-secret \
  --secret-id "$SECRET_ID" \
  --region "$REGION"

success "Rotation initiated"

# --- Wait for rotation to complete ---
info "Waiting for rotation to complete..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
  STATUS=$(aws secretsmanager describe-secret \
    --secret-id "$SECRET_ID" \
    --region "$REGION" \
    --query "RotationEnabled" \
    --output text 2>/dev/null)

  LAST_ROTATED=$(aws secretsmanager describe-secret \
    --secret-id "$SECRET_ID" \
    --region "$REGION" \
    --query "LastRotatedDate" \
    --output text 2>/dev/null || echo "None")

  VERSIONS=$(aws secretsmanager describe-secret \
    --secret-id "$SECRET_ID" \
    --region "$REGION" \
    --query "VersionIdsToStages" \
    --output json 2>/dev/null)

  # Check if there is still a pending version (AWSPENDING stage)
  if echo "$VERSIONS" | grep -q "AWSPENDING"; then
    info "Rotation in progress... (attempt $((ATTEMPT + 1))/${MAX_ATTEMPTS})"
    sleep 10
    ATTEMPT=$((ATTEMPT + 1))
  else
    success "Secret rotation completed"
    break
  fi
done

if [[ $ATTEMPT -ge $MAX_ATTEMPTS ]]; then
  error "Rotation did not complete within expected time. Check AWS console for details."
fi

# --- Force ECS service update ---
info "Forcing new ECS deployment for service '${SERVICE}' in cluster '${CLUSTER}'..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --region "$REGION" \
  --force-new-deployment \
  --query "service.deployments[0].id" \
  --output text

success "New deployment triggered"

# --- Wait for new task to be running ---
info "Waiting for new tasks to reach RUNNING state..."
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --region "$REGION"

# --- Verify ---
RUNNING_COUNT=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --region "$REGION" \
  --query "services[0].runningCount" \
  --output text)

success "Service '${SERVICE}' is stable with ${RUNNING_COUNT} running task(s)"
echo ""
success "Secret rotation and redeployment complete for '${ENV}' environment!"
