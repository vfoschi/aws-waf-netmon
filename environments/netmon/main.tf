# Default provider for regional resources (CloudWatch logs, etc.)
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

# us-east-1 provider required for:
# - WAFv2 with CLOUDFRONT scope
# - ACM certificate for CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "netmon"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "aws-waf-netmon"
    }
  }
}

# ─── ACM Certificate (us-east-1 — required by CloudFront) ────────────────────

resource "aws_acm_certificate" "this" {
  count    = var.certificate_domain != "" ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.certificate_domain
  validation_method         = "DNS"
  subject_alternative_names = var.certificate_san

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = replace(var.certificate_domain, "*", "wildcard")
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
  count    = var.route53_zone_id != "" && var.certificate_domain != "" ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

locals {
  resolved_certificate_arn = (
    var.certificate_arn != "" ? var.certificate_arn :
    var.route53_zone_id != "" && var.certificate_domain != "" ? aws_acm_certificate_validation.this[0].certificate_arn :
    var.certificate_domain != "" ? aws_acm_certificate.this[0].arn :
    ""
  )
}

# ─── WAF (us-east-1, CLOUDFRONT scope) ───────────────────────────────────────

module "waf" {
  source = "../../terraform/modules/waf"

  providers = {
    aws = aws.us_east_1
  }

  name        = "netmon-${var.environment}"
  environment = var.environment
  scope       = "CLOUDFRONT"

  ip_allowlist_ipv4 = var.ip_allowlist_ipv4
  ip_allowlist_ipv6 = var.ip_allowlist_ipv6
  ip_blocklist_ipv4 = var.ip_blocklist_ipv4
  ip_blocklist_ipv6 = var.ip_blocklist_ipv6

  rate_limit_enabled   = var.rate_limit_enabled
  rate_limit_threshold = var.rate_limit_threshold

  geo_block_enabled       = var.geo_block_enabled
  geo_block_country_codes = var.geo_block_country_codes

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

  logging_enabled     = true
  log_retention_days  = var.log_retention_days
  log_redacted_fields = ["authorization", "cookie"]

  # CloudFront attaches the WAF via web_acl_id on the distribution — no association resource needed
  resource_arns = []

  tags = {
    Application = "netmon"
    Team        = "infrastructure"
  }
}

# ─── CloudFront Distribution ──────────────────────────────────────────────────

module "cloudfront" {
  source = "../../terraform/modules/cloudfront"

  name        = "netmon-${var.environment}"
  environment = var.environment
  aliases     = var.cloudfront_aliases

  origin_domain          = var.origin_ip
  origin_http_port       = var.origin_port
  origin_protocol_policy = "http-only"

  web_acl_arn     = module.waf.web_acl_arn
  certificate_arn = local.resolved_certificate_arn
  price_class     = var.cloudfront_price_class

  tags = {
    Application = "netmon"
    Team        = "infrastructure"
  }
}
