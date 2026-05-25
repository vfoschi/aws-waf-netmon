locals {
  common_tags = merge(
    {
      Name        = var.name
      Environment = var.environment
      ManagedBy   = "terraform"
      Service     = "waf"
    },
    var.tags
  )

  has_ipv4_allowlist = length(var.ip_allowlist_ipv4) > 0
  has_ipv6_allowlist = length(var.ip_allowlist_ipv6) > 0
  has_any_allowlist  = local.has_ipv4_allowlist || local.has_ipv6_allowlist

  has_ipv4_blocklist = length(var.ip_blocklist_ipv4) > 0
  has_ipv6_blocklist = length(var.ip_blocklist_ipv6) > 0
  has_any_blocklist  = local.has_ipv4_blocklist || local.has_ipv6_blocklist
}

# ─── IP Sets ─────────────────────────────────────────────────────────────────

resource "aws_wafv2_ip_set" "allowlist_ipv4" {
  count              = local.has_ipv4_allowlist ? 1 : 0
  name               = "${var.name}-allowlist-ipv4"
  description        = "IPv4 addresses that are always allowed"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.ip_allowlist_ipv4
  tags               = local.common_tags
}

resource "aws_wafv2_ip_set" "allowlist_ipv6" {
  count              = local.has_ipv6_allowlist ? 1 : 0
  name               = "${var.name}-allowlist-ipv6"
  description        = "IPv6 addresses that are always allowed"
  scope              = var.scope
  ip_address_version = "IPV6"
  addresses          = var.ip_allowlist_ipv6
  tags               = local.common_tags
}

resource "aws_wafv2_ip_set" "blocklist_ipv4" {
  count              = local.has_ipv4_blocklist ? 1 : 0
  name               = "${var.name}-blocklist-ipv4"
  description        = "IPv4 addresses that are always blocked"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.ip_blocklist_ipv4
  tags               = local.common_tags
}

resource "aws_wafv2_ip_set" "blocklist_ipv6" {
  count              = local.has_ipv6_blocklist ? 1 : 0
  name               = "${var.name}-blocklist-ipv6"
  description        = "IPv6 addresses that are always blocked"
  scope              = var.scope
  ip_address_version = "IPV6"
  addresses          = var.ip_blocklist_ipv6
  tags               = local.common_tags
}

# ─── Web ACL ─────────────────────────────────────────────────────────────────

resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = "WAF WebACL for ${var.name} - ${var.environment}"
  scope       = var.scope
  tags        = local.common_tags

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # Priority 1: Allow trusted IPs (IPv4)
  dynamic "rule" {
    for_each = local.has_ipv4_allowlist ? [1] : []
    content {
      name     = "AllowTrustedIPv4"
      priority = 1

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowlist_ipv4[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-AllowTrustedIPv4"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 2: Allow trusted IPs (IPv6)
  dynamic "rule" {
    for_each = local.has_ipv6_allowlist ? [1] : []
    content {
      name     = "AllowTrustedIPv6"
      priority = 2

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowlist_ipv6[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-AllowTrustedIPv6"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 3: Block known-bad IPs (IPv4)
  dynamic "rule" {
    for_each = local.has_ipv4_blocklist ? [1] : []
    content {
      name     = "BlockBadIPv4"
      priority = 3

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blocklist_ipv4[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-BlockBadIPv4"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 4: Block known-bad IPs (IPv6)
  dynamic "rule" {
    for_each = local.has_ipv6_blocklist ? [1] : []
    content {
      name     = "BlockBadIPv6"
      priority = 4

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blocklist_ipv6[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-BlockBadIPv6"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 5: Rate limiting
  dynamic "rule" {
    for_each = var.rate_limit_enabled ? [1] : []
    content {
      name     = "RateLimitPerIP"
      priority = 5

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit_threshold
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-RateLimitPerIP"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 6: Geo blocking
  dynamic "rule" {
    for_each = var.geo_block_enabled && length(var.geo_block_country_codes) > 0 ? [1] : []
    content {
      name     = "GeoBlock"
      priority = 6

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.geo_block_country_codes
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-GeoBlock"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priorities 10–60: AWS Managed Rule Groups
  dynamic "rule" {
    for_each = var.managed_rules
    content {
      name     = rule.key
      priority = rule.value.priority

      dynamic "override_action" {
        for_each = rule.value.override_action == "count" ? [1] : []
        content {
          count {}
        }
      }
      dynamic "override_action" {
        for_each = rule.value.override_action == "none" ? [1] : []
        content {
          none {}
        }
      }

      statement {
        managed_rule_group_statement {
          vendor_name = rule.value.vendor_name
          name        = rule.value.name

          dynamic "rule_action_override" {
            for_each = rule.value.excluded_rules
            content {
              name = rule_action_override.value
              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  # Priority 70: Bot Control (optional, extra cost)
  dynamic "rule" {
    for_each = var.bot_control_enabled ? [1] : []
    content {
      name     = "BotControl"
      priority = 70

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = "AWSManagedRulesBotControlRuleSet"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-BotControl"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}

# ─── Logging ─────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "waf" {
  count             = var.logging_enabled ? 1 : 0
  name              = "aws-waf-logs-${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count                   = var.logging_enabled ? 1 : 0
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  dynamic "redacted_fields" {
    for_each = toset(var.log_redacted_fields)
    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }

  depends_on = [aws_cloudwatch_log_group.waf]
}

# ─── Resource Associations ───────────────────────────────────────────────────

resource "aws_wafv2_web_acl_association" "this" {
  for_each     = { for i, arn in var.resource_arns : tostring(i) => arn }
  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
