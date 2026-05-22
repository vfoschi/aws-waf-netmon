variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "waf_scope" {
  description = "WAF scope: REGIONAL (for ALB/API GW) or CLOUDFRONT (must be us-east-1)"
  type        = string
  default     = "REGIONAL"
}

variable "ip_allowlist_ipv4" {
  description = "IPv4 CIDRs to always allow (office, VPN, monitoring)"
  type        = list(string)
  default     = []
}

variable "ip_allowlist_ipv6" {
  description = "IPv6 CIDRs to always allow"
  type        = list(string)
  default     = []
}

variable "ip_blocklist_ipv4" {
  description = "IPv4 CIDRs to always block"
  type        = list(string)
  default     = []
}

variable "ip_blocklist_ipv6" {
  description = "IPv6 CIDRs to always block"
  type        = list(string)
  default     = []
}

variable "rate_limit_enabled" {
  description = "Enable per-IP rate limiting"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Max requests per 5-minute window per IP"
  type        = number
  default     = 2000
}

variable "geo_block_enabled" {
  description = "Enable geo blocking"
  type        = bool
  default     = false
}

variable "geo_block_country_codes" {
  description = "ISO 3166-1 alpha-2 country codes to block"
  type        = list(string)
  default     = []
}

variable "exclude_size_restriction_body" {
  description = "Exclude SizeRestrictions_BODY rule (use if NETMON accepts large payloads)"
  type        = bool
  default     = false
}

variable "exclude_hosting_provider_ips" {
  description = "Exclude HostingProviderIPList rule (use if NETMON cloud agents must reach the service)"
  type        = bool
  default     = false
}

variable "bot_control_enabled" {
  description = "Enable AWS Bot Control (extra cost ~$10/month + per-million-requests)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 90
}

variable "resource_arns" {
  description = "ARNs of ALBs or API Gateways to associate with this WAF"
  type        = list(string)
  default     = []
}
