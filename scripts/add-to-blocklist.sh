#!/usr/bin/env bash
# Add an IP address to the WAF blocklist without running a full Terraform apply.
# Uses the AWS CLI to update the IP set directly for immediate blocking.
#
# Usage: ./scripts/add-to-blocklist.sh <IP_CIDR> [environment] [aws-region]
# Example: ./scripts/add-to-blocklist.sh 203.0.113.99/32 netmon eu-west-1

set -euo pipefail

IP_CIDR="${1:?Usage: $0 <IP_CIDR> [environment] [aws-region]}"
ENVIRONMENT="${2:-netmon}"
AWS_REGION="${3:-eu-west-1}"
WAF_NAME="netmon-${ENVIRONMENT}-blocklist-ipv4"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

command -v aws >/dev/null 2>&1 || { log_error "aws CLI not found"; exit 1; }

# Find the IP set by name
IP_SET_JSON=$(aws wafv2 list-ip-sets --scope REGIONAL --region "${AWS_REGION}" \
  --query "IPSets[?Name=='${WAF_NAME}']" --output json)

if [[ "${IP_SET_JSON}" == "[]" ]]; then
  log_error "IP set '${WAF_NAME}' not found in region ${AWS_REGION}."
  log_error "Make sure the WAF has been deployed first: ./scripts/deploy.sh ${ENVIRONMENT}"
  exit 1
fi

IP_SET_ID=$(echo "${IP_SET_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['Id'])")
IP_SET_ARN=$(echo "${IP_SET_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['ARN'])")

log_info "Found IP set: ${WAF_NAME} (${IP_SET_ID})"

# Get current IP set (need lock token for update)
CURRENT=$(aws wafv2 get-ip-set --scope REGIONAL --region "${AWS_REGION}" \
  --name "${WAF_NAME}" --id "${IP_SET_ID}")
LOCK_TOKEN=$(echo "${CURRENT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['LockToken'])")
CURRENT_IPS=$(echo "${CURRENT}" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['IPSet']['Addresses']))")

# Check if IP already in the set
if echo "${CURRENT_IPS}" | grep -q "\"${IP_CIDR}\""; then
  log_warn "${IP_CIDR} is already in the blocklist."
  exit 0
fi

# Merge new IP with existing IPs
NEW_IPS=$(echo "${CURRENT_IPS}" | python3 -c "
import sys, json
ips = json.load(sys.stdin)
ips.append('${IP_CIDR}')
print(json.dumps(ips))
")

log_info "Adding ${IP_CIDR} to blocklist..."
aws wafv2 update-ip-set \
  --scope REGIONAL \
  --region "${AWS_REGION}" \
  --name "${WAF_NAME}" \
  --id "${IP_SET_ID}" \
  --lock-token "${LOCK_TOKEN}" \
  --addresses "${NEW_IPS}"

log_info "Done. ${IP_CIDR} is now blocked."
log_warn "Remember to also update terraform.tfvars ip_blocklist_ipv4 to keep state in sync!"
log_warn "Otherwise the next 'terraform apply' will remove this IP from the blocklist."
