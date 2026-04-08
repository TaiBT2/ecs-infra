#!/usr/bin/env bash
set -euo pipefail

# Check Terraform formatting across all files in the terraform/ directory.
# Usage: ./tf-fmt-check.sh

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"

if [[ ! -d "$TF_DIR" ]]; then
  error "Terraform directory not found: ${TF_DIR}"
  exit 1
fi

info "Checking Terraform formatting in ${TF_DIR}..."

UNFORMATTED=$(terraform fmt -check -recursive "$TF_DIR" 2>&1) || true

if [[ -z "$UNFORMATTED" ]]; then
  success "All Terraform files are properly formatted"
  exit 0
else
  error "The following files need formatting:"
  echo ""
  echo "$UNFORMATTED" | while IFS= read -r file; do
    echo -e "  ${RED}-${NC} ${file}"
  done
  echo ""
  error "Run 'terraform fmt -recursive ${TF_DIR}' to fix formatting"
  exit 1
fi
