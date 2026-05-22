#!/usr/bin/env bash
# Validate Terraform configuration without deploying.
# Usage: ./scripts/validate.sh [environment]

set -euo pipefail

ENVIRONMENT="${1:-netmon}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

FAILED=0

validate_env() {
  local env_dir="${REPO_ROOT}/environments/${1}"
  log_info "Validating environment: ${1}"

  if [[ ! -d "${env_dir}" ]]; then
    log_error "Environment directory not found: ${env_dir}"
    return 1
  fi

  cd "${env_dir}"
  terraform init -backend=false -upgrade >/dev/null 2>&1
  terraform validate && log_info "  ✓ ${1} is valid" || { log_error "  ✗ ${1} failed validation"; return 1; }
  terraform fmt -check -recursive "${REPO_ROOT}" && log_info "  ✓ Formatting OK" || {
    log_error "  ✗ Formatting issues found. Run: terraform fmt -recursive ."
    return 1
  }
}

validate_env "${ENVIRONMENT}" || FAILED=1

if [[ $FAILED -eq 0 ]]; then
  log_info "All checks passed."
else
  log_error "Validation failed."
  exit 1
fi
