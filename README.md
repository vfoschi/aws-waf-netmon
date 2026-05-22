# aws-waf-netmon

AWS WAFv2 infrastructure for NETMON web services, managed with Terraform.

## What this deploys

- **AWS WAFv2 Web ACL** with the following protection layers (in order of evaluation):
  1. IP Allowlist — trusted office/VPN IPs always bypass all rules
  2. IP Blocklist — known-bad IPs always blocked before any other rule
  3. Rate Limiting — blocks IPs exceeding 2,000 requests / 5 min
  4. Geo Blocking — optional country-level blocking
  5. **AWS Managed Rules** (OWASP Top 10 and beyond):
     - `AWSManagedRulesCommonRuleSet` — XSS, SQLi, RFI, path traversal, etc.
     - `AWSManagedRulesKnownBadInputsRuleSet` — Log4Shell, OGNL injection, Spring4Shell
     - `AWSManagedRulesSQLiRuleSet` — SQL injection patterns
     - `AWSManagedRulesLinuxRuleSet` — Linux-specific attack patterns
     - `AWSManagedRulesAmazonIpReputationList` — AWS threat intelligence feeds
     - `AWSManagedRulesAnonymousIpList` — Tor exit nodes, VPNs, open proxies
     - `AWSManagedRulesBotControlRuleSet` — *(optional, extra cost)*
- **CloudWatch Logs** for WAF traffic analysis and alerting
- **IP sets** for allowlist and blocklist management

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | ≥ 1.5.0 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | ≥ 2.x | https://aws.amazon.com/cli/ |
| Python 3 | ≥ 3.8 | Required by helper scripts |

AWS credentials with the following IAM permissions:
- `wafv2:*`
- `cloudwatch:*` / `logs:*`
- `elasticloadbalancing:SetWebACL` (if associating with an ALB)

## Quick start

```bash
# 1. Clone the repository
git clone https://github.com/your-org/aws-waf-netmon.git
cd aws-waf-netmon

# 2. Copy and edit the variables file
cp environments/netmon/terraform.tfvars.example environments/netmon/terraform.tfvars
$EDITOR environments/netmon/terraform.tfvars

# 3. Configure AWS credentials (choose one)
export AWS_PROFILE=your-profile
# OR
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=eu-west-1

# 4. Deploy
./scripts/deploy.sh netmon
```

## Repository structure

```
aws-waf-netmon/
├── terraform/
│   └── modules/
│       └── waf/               # Reusable WAFv2 Terraform module
│           ├── main.tf        # IP sets, Web ACL, logging, associations
│           ├── variables.tf   # All module inputs
│           ├── outputs.tf     # Web ACL ARN, log group, etc.
│           └── versions.tf    # Provider version constraints
├── environments/
│   └── netmon/                # NETMON-specific configuration
│       ├── main.tf            # Calls the waf module with NETMON settings
│       ├── variables.tf       # Environment-level variables
│       ├── outputs.tf         # Exposes Web ACL ARN and log group
│       ├── versions.tf        # Backend configuration (S3 optional)
│       └── terraform.tfvars.example  # Template — copy to terraform.tfvars
├── scripts/
│   ├── deploy.sh              # Interactive deploy with plan preview
│   ├── destroy.sh             # Destroy WAF (with safety prompt)
│   ├── validate.sh            # Lint + validate without deploying
│   └── add-to-blocklist.sh    # Emergency IP block via AWS CLI (immediate)
└── README.md
```

## Attaching the WAF to your NETMON ALB

Edit `terraform.tfvars` and add your ALB ARN:

```hcl
resource_arns = [
  "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/netmon-alb/abc123",
]
```

Find your ALB ARN with:

```bash
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn]' --output table
```

## Attaching the WAF to a CloudFront distribution

1. Change scope to `CLOUDFRONT` and region to `us-east-1`:

```hcl
# environments/netmon/terraform.tfvars
waf_scope  = "CLOUDFRONT"
aws_region = "us-east-1"
```

2. Deploy. Note the `web_acl_arn` from the output.

3. Attach in your CloudFront Terraform (or manually in the Console):

```hcl
resource "aws_cloudfront_distribution" "netmon" {
  web_acl_id = "<web_acl_arn from output>"
  # ...
}
```

## Emergency: block an IP immediately

To block an IP without waiting for a full Terraform run:

```bash
./scripts/add-to-blocklist.sh 203.0.113.99/32 netmon eu-west-1
```

This updates the AWS IP set directly via CLI. Remember to also add the IP to `ip_blocklist_ipv4` in `terraform.tfvars` — otherwise the next `terraform apply` will revert the change.

## WAF cost estimate

| Component | Cost |
|-----------|------|
| Web ACL | $5.00 / month |
| Each rule | $1.00 / month |
| Per 1M requests | $0.60 |
| Bot Control (optional) | $10.00 / month + $1.00/million |

For NETMON with the default 6 managed rule groups + 3 custom rules = **~$14/month base** + request volume.

Full pricing: https://aws.amazon.com/waf/pricing/

## Terraform state

By default, state is stored locally. For team use, enable the S3 backend in `environments/netmon/versions.tf`:

```hcl
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "netmon/waf/terraform.tfstate"
  region         = "eu-west-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

Create the S3 bucket and DynamoDB lock table before running `terraform init`.

## Logs

WAF logs are in CloudWatch Logs under the log group `aws-waf-logs-netmon-production`.

View blocked requests:

```bash
aws logs filter-log-events \
  --log-group-name "aws-waf-logs-netmon-production" \
  --filter-pattern '{ $.action = "BLOCK" }' \
  --start-time $(date -d '1 hour ago' +%s000) \
  --output json | python3 -c "
import sys, json
for e in json.load(sys.stdin)['events']:
    msg = json.loads(e['message'])
    print(msg.get('httpRequest', {}).get('clientIp','?'), '→', msg.get('terminatingRuleId','?'))
"
```

## Adding a new environment (e.g. staging)

```bash
cp -r environments/netmon environments/staging
# Edit environments/staging/main.tf, variables.tf, terraform.tfvars.example
./scripts/deploy.sh staging
```

## Troubleshooting

**`WAFCapacityExceededException`** — You've exceeded the 1,500 WCU limit for a REGIONAL Web ACL. Disable Bot Control (`bot_control_enabled = false`) or remove a managed rule group.

**`WAFUnavailableEntityException` on association** — The resource ARN is wrong or the resource is in a different region than the WAF. REGIONAL WAFs must be in the same region as the ALB.

**Legitimate traffic getting blocked** — Add your source IP to `ip_allowlist_ipv4`, or put a rule in `count` mode by setting `override_action = "count"` in `managed_rules`. Check logs for the blocking rule name.

**CloudFront WAF not working** — CloudFront WAFs must be deployed in `us-east-1`, regardless of where your CloudFront distribution serves from.
