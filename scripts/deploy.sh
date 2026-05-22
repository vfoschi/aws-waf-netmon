#!/usr/bin/env bash
# Deploy AWS WAF for NETMON
# Usage: ./scripts/deploy.sh [environment] [--auto-approve]
# Example: ./scripts/deploy.sh netmon --auto-approve

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

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_prerequisites() {
  log_info "Checking prerequisites..."

  command -v terraform >/dev/null 2>&1 || { log_error "terraform not found. Install from https://www.terraform.io/downloads"; exit 1; }
  command -v aws >/dev/null 2>&1       || { log_error "aws CLI not found. Install from https://aws.amazon.com/cli/"; exit 1; }

  TERRAFORM_VERSION=$(terraform version -json | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  log_info "Terraform version: ${TERRAFORM_VERSION}"

  AWS_IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null) || {
    log_error "AWS credentials not configured or not valid."
    log_error "Run: aws configure   OR   export AWS_PROFILE=your-profile"
    exit 1
  }

  AWS_ACCOUNT=$(echo "${AWS_IDENTITY}" | python3 -c "import sys,json; print(json.load(sys.stdin)['Account'])")
  AWS_USER=$(echo "${AWS_IDENTITY}"    | python3 -c "import sys,json; print(json.load(sys.stdin)['Arn'])")
  log_info "AWS Account: ${AWS_ACCOUNT}"
  log_info "AWS Identity: ${AWS_USER}"
}

check_tfvars() {
  if [[ ! -f "${ENV_DIR}/terraform.tfvars" ]]; then
    log_warn "terraform.tfvars not found in ${ENV_DIR}/"
    log_warn "Copying terraform.tfvars.example to terraform.tfvars ..."
    cp "${ENV_DIR}/terraform.tfvars.example" "${ENV_DIR}/terraform.tfvars"
    log_warn "Please review and edit ${ENV_DIR}/terraform.tfvars before proceeding."
    if [[ "${AUTO_APPROVE}" != "--auto-approve" ]]; then
      read -r -p "Press ENTER when done, or Ctrl+C to cancel..."
    fi
  fi
}

deploy() {
  log_info "Deploying WAF for environment: ${ENVIRONMENT}"
  cd "${ENV_DIR}"

  log_info "Running terraform init..."
  terraform init -upgrade

  log_info "Running terraform validate..."
  terraform validate

  log_info "Running terraform plan..."
  terraform plan -out=tfplan -input=false

  if [[ "${AUTO_APPROVE}" == "--auto-approve" ]]; then
    log_info "Auto-approving apply..."
    terraform apply -auto-approve tfplan
  else
    echo ""
    read -r -p "Apply the plan? [y/N] " CONFIRM
    if [[ "${CONFIRM}" =~ ^[Yy]$ ]]; then
      terraform apply tfplan
    else
      log_warn "Deployment cancelled."
      rm -f tfplan
      exit 0
    fi
  fi

  rm -f tfplan

  log_info "Deployment complete! Outputs:"
  terraform output
}

check_prerequisites
check_tfvars
deploy

log_info "Done."
