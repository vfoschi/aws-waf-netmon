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

# ── Network ───────────────────────────────────────────────────────────────────

variable "vpc_id" {
  description = "ID of the VPC where the ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of public subnet IDs for the ALB (minimum 2, different AZs)"
  type        = list(string)
}

variable "alb_internal" {
  description = "Set to true for an internal ALB, false for internet-facing"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
  default     = false
}

# ── Origin (backend IP) ───────────────────────────────────────────────────────

variable "origin_ip" {
  description = "IP address of the backend server. All traffic that passes WAF is forwarded here."
  type        = string
}

variable "origin_port" {
  description = "Port on the backend server to forward traffic to"
  type        = number
  default     = 80
}

variable "origin_availability_zone" {
  description = "AZ for the origin IP target. Use 'all' for IPs outside the VPC (on-premises or external)"
  type        = string
  default     = "all"
}

variable "health_check_path" {
  description = "HTTP path used by ALB health checks against the origin"
  type        = string
  default     = "/"
}

# ── TLS Certificate ───────────────────────────────────────────────────────────

variable "certificate_domain" {
  description = "Domain name for the ACM certificate (e.g. netmon2.technacy.it or *.technacy.it). Leave empty to skip HTTPS."
  type        = string
  default     = ""
}

variable "certificate_san" {
  description = "Additional Subject Alternative Names for the ACM certificate (e.g. [\"*.technacy.it\"])"
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for automatic DNS validation of the ACM certificate. Leave empty to validate manually."
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN of an existing ACM certificate. Overrides certificate_domain when set."
  type        = string
  default     = ""
}

# ── IP Allowlist / Blocklist ───────────────────────────────────────────────────

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
  description = "Exclude SizeRestrictions_BODY rule (use if NETMON accepts large payloads)"
  type        = bool
  default     = false
}

variable "exclude_hosting_provider_ips" {
  description = "Exclude HostingProviderIPList rule (use if NETMON cloud agents must reach the service)"
  type        = bool
  default     = false
}

# ── Bot Control ────────────────────────────────────────────────────────────────

variable "bot_control_enabled" {
  description = "Enable AWS Bot Control (extra cost ~$10/month + per-million-requests)"
  type        = bool
  default     = false
}

# ── Logging ────────────────────────────────────────────────────────────────────

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 90
}
