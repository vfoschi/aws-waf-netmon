variable "aws_region" {
  description = "AWS region for CloudWatch logs (WAF and ACM will always be in us-east-1 for CloudFront)"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# ── Origin (backend server — any public IP is supported) ─────────────────────

variable "origin_ip" {
  description = "Public IP or hostname of the backend server. CloudFront forwards all WAF-passed traffic here."
  type        = string
}

variable "origin_port" {
  description = "HTTP port on the backend server"
  type        = number
  default     = 80
}

# ── CloudFront ────────────────────────────────────────────────────────────────

variable "cloudfront_aliases" {
  description = "Domain names served by CloudFront (e.g. [\"netmon2.technacy.it\"]). Must match the certificate."
  type        = list(string)
  default     = []
}

variable "cloudfront_price_class" {
  description = "PriceClass_100 (US/Europe/Israel, cheapest) or PriceClass_All (global)"
  type        = string
  default     = "PriceClass_100"
}

# ── TLS Certificate ───────────────────────────────────────────────────────────

variable "certificate_domain" {
  description = "Domain for the ACM certificate (e.g. *.technacy.it). Certificate is created in us-east-1 for CloudFront."
  type        = string
  default     = ""
}

variable "certificate_san" {
  description = "Additional Subject Alternative Names for the ACM certificate"
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for automatic DNS validation. Leave empty to validate manually."
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN of an existing ACM certificate in us-east-1. Overrides certificate_domain when set."
  type        = string
  default     = ""
}

# ── IP Allowlist / Blocklist ───────────────────────────────────────────────────

variable "ip_allowlist_ipv4" {
  description = "IPv4 CIDRs to always allow. Use /32 for single IPs, network address for subnets."
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

# ── Rate Limiting ──────────────────────────────────────────────────────────────

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

# ── Geo Blocking ───────────────────────────────────────────────────────────────

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

# ── Rule Exceptions ────────────────────────────────────────────────────────────

variable "exclude_size_restriction_body" {
  description = "Exclude SizeRestrictions_BODY rule"
  type        = bool
  default     = false
}

variable "exclude_hosting_provider_ips" {
  description = "Exclude HostingProviderIPList rule"
  type        = bool
  default     = false
}

# ── Bot Control ────────────────────────────────────────────────────────────────

variable "bot_control_enabled" {
  description = "Enable AWS Bot Control (extra cost)"
  type        = bool
  default     = false
}

# ── Logging ────────────────────────────────────────────────────────────────────

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 90
}
