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
  certificate_arn            = var.certificate_arn
  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Application = "netmon"
    Team        = "infrastructure"
  }
}

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

  # Associate WAF with the ALB created by this environment
  resource_arns = [module.alb.alb_arn]

  tags = {
    Application = "netmon"
    Team        = "infrastructure"
  }
}
