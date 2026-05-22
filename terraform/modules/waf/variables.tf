variable "name" {
  description = "Name prefix for all WAF resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. production, staging)"
  type        = string
}

variable "scope" {
  description = "Scope of the WAF: REGIONAL (ALB, API GW, AppSync) or CLOUDFRONT"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "default_action" {
  description = "Default action when no rule matches: allow or block"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

# IP Sets
variable "ip_allowlist_ipv4" {
  description = "List of IPv4 CIDRs to always allow"
  type        = list(string)
  default     = []
}

variable "ip_allowlist_ipv6" {
  description = "List of IPv6 CIDRs to always allow"
  type        = list(string)
  default     = []
}

variable "ip_blocklist_ipv4" {
  description = "List of IPv4 CIDRs to always block"
  type        = list(string)
  default     = []
}

variable "ip_blocklist_ipv6" {
  description = "List of IPv6 CIDRs to always block"
  type        = list(string)
  default     = []
}

# Rate limiting
variable "rate_limit_enabled" {
  description = "Enable rate limiting rule"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Maximum requests per 5-minute window per IP before blocking"
  type        = number
  default     = 2000
}

# AWS Managed Rule Groups
variable "managed_rules" {
  description = "Map of AWS managed rule groups to enable"
  type = map(object({
    vendor_name      = string
    name             = string
    priority         = number
    override_action  = string # none, count
    excluded_rules   = list(string)
  }))
  default = {
    common = {
      vendor_name     = "AWS"
      name            = "AWSManagedRulesCommonRuleSet"
      priority        = 10
      override_action = "none"
      excluded_rules  = []
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
      excluded_rules  = []
    }
  }
}

variable "bot_control_enabled" {
  description = "Enable AWS Bot Control managed rule group (additional cost applies)"
  type        = bool
  default     = false
}

# Geo blocking
variable "geo_block_enabled" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}

variable "geo_block_country_codes" {
  description = "List of ISO 3166-1 alpha-2 country codes to block"
  type        = list(string)
  default     = []
}

# Logging
variable "logging_enabled" {
  description = "Enable WAF logging to CloudWatch Logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 90
}

variable "log_redacted_fields" {
  description = "List of HTTP request fields to redact in logs"
  type        = list(string)
  default     = ["authorization", "cookie"]
}

# Association
variable "resource_arns" {
  description = "List of resource ARNs to associate with this WAF (ALB, API Gateway, AppSync)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
