#!/usr/bin/env bash
# DANGER: Destroy AWS WAF for NETMON — removes ALL WAF protections.
# Usage: ./scripts/destroy.sh [environment] [--auto-approve]

set -euo pipefail

ENVIRONMENT="${1:-netmon}"
AUTO_APPROVE="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_DIR="${REPO_ROOT}/environments/${ENVIRONMENT}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  WARNING: This will DESTROY the WAF protecting NETMON!       ║${NC}"
echo -e "${RED}║  All web traffic will be UNPROTECTED until re-deployed.       ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "${AUTO_APPROVE}" != "--auto-approve" ]]; then
  read -r -p "Type 'yes' to confirm destruction: " CONFIRM
  if [[ "${CONFIRM}" != "yes" ]]; then
    log_info "Destruction cancelled."
    exit 0
  fi
fi

command -v terraform >/dev/null 2>&1 || { log_error "terraform not found"; exit 1; }
command -v aws >/dev/null 2>&1       || { log_error "aws CLI not found"; exit 1; }

aws sts get-caller-identity --output json >/dev/null 2>&1 || {
  log_error "AWS credentials not configured."
  exit 1
}

log_info "Running terraform destroy for environment: ${ENVIRONMENT}"
cd "${ENV_DIR}"

terraform init -upgrade
terraform destroy ${AUTO_APPROVE:+"-auto-approve"}

log_info "Destruction complete. WAF has been removed."
log_warn "Run ./scripts/deploy.sh ${ENVIRONMENT} to re-enable WAF protection."
