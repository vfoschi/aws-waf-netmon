provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "netmon"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "aws-waf-netmon"
    }
  }
}

# ─── ACM Certificate ─────────────────────────────────────────────────────────
# Creates a DNS-validated certificate when certificate_domain is set.
# If route53_zone_id is also set, DNS validation records are created
# automatically and Terraform waits for the cert to be ISSUED before continuing.
# Otherwise, the output "certificate_validation_records" shows the CNAMEs to add manually.

resource "aws_acm_certificate" "this" {
  count             = var.certificate_domain != "" ? 1 : 0
  domain_name       = var.certificate_domain
  validation_method = "DNS"

  subject_alternative_names = var.certificate_san

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = var.certificate_domain
    Environment = var.environment
    Application = "netmon"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = (
    var.route53_zone_id != "" && var.certificate_domain != "" ?
    {
      for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
        name   = dvo.resource_record_name
        record = dvo.resource_record_value
        type   = dvo.resource_record_type
      }
    } : {}
  )

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "this" {
  count           = var.route53_zone_id != "" && var.certificate_domain != "" ? 1 : 0
  certificate_arn = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
}

locals {
  # Priority: explicit certificate_arn override → auto-validated cert → unvalidated cert ARN → empty
  resolved_certificate_arn = (
    var.certificate_arn != "" ? var.certificate_arn :
    var.route53_zone_id != "" && var.certificate_domain != "" ? aws_acm_certificate_validation.this[0].certificate_arn :
    var.certificate_domain != "" ? aws_acm_certificate.this[0].arn :
    ""
  )
}

# ─── ALB ─────────────────────────────────────────────────────────────────────

module "alb" {
  source = "../../terraform/modules/alb"

  name        = "netmon-${var.environment}"
  environment = var.environment
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids
  internal    = var.alb_internal

  origin_ip                = var.origin_ip
  origin_port              = var.origin_port
  origin_availability_zone = var.origin_availability_zone

  health_check_path          = var.health_check_path
  certificate_arn            = local.resolved_certificate_arn
  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Application = "netmon"
    Team        = "infrastructure"
  }
}

# ─── WAF ─────────────────────────────────────────────────────────────────────

module "waf" {
  source = "../../terraform/modules/waf"

  name        = "netmon-${var.environment}"
  environment = var.environment
  scope       = var.waf_scope

  # IP allowlist: office, VPN, monitoring IPs
  ip_allowlist_ipv4 = var.ip_allowlist_ipv4
  ip_allowlist_ipv6 = var.ip_allowlist_ipv6

  # IP blocklist: known malicious IPs
  ip_blocklist_ipv4 = var.ip_blocklist_ipv4
  ip_blocklist_ipv6 = var.ip_blocklist_ipv6

  # Rate limiting: 2000 req/5min per IP (adjustable)
  rate_limit_enabled   = var.rate_limit_enabled
  rate_limit_threshold = var.rate_limit_threshold

  # Geographic blocking (disabled by default for NETMON)
  geo_block_enabled       = var.geo_block_enabled
  geo_block_country_codes = var.geo_block_country_codes

  # AWS Managed Rules
  managed_rules = {
    common = {
      vendor_name     = "AWS"
      name            = "AWSManagedRulesCommonRuleSet"
      priority        = 10
      override_action = "none"
      excluded_rules  = var.exclude_size_restriction_body ? ["SizeRestrictions_BODY"] : []
    }
    known_bad_inputs = {
      vendor_name     = "AWS"
      name            = "AWSManagedRulesKnownBadInputsRuleSet"
      priority        = 20
      override_action = "none"
      excluded_rules  = []
    }
    sqli = {
      vendor_name     = "AWS"
      name            = "AWSManagedRulesSQLiRuleSet"
      priority        = 30
      override_action = "none"
      excluded_rules  = []
    }
    linux = {
      vendor_name     = "AWS"
      name            = "AWSManagedRulesLinuxRuleSet"
      priority        = 40
      override_action = "none"
      excluded_rules  = []
    }
    ip_reputation = {
      vendor_name     = "AWS"
      name            = "AWSManagedRulesAmazonIpReputationList"
      priority        = 50
      override_action = "none"
      excluded_rules  = []
    }
    anonymous_ip = {
      vendor_name     = "AWS"
      name            = "AWSManagedRulesAnonymousIpList"
      priority        = 60
      override_action = "none"
      excluded_rules  = var.exclude_hosting_provider_ips ? ["HostingProviderIPList"] : []
    }
  }

  bot_control_enabled = var.bot_control_enabled

  # Logging
  logging_enabled     = true
  log_retention_days  = var.log_retention_days
  log_redacted_fields = ["authorization", "cookie"]

  # Associate WAF with the ALB created above
  resource_arns = [module.alb.alb_arn]

  tags = {
    Application = "netmon"
    Team        = "infrastructure"
  }
}
