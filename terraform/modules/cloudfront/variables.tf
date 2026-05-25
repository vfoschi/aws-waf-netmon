variable "name" {
  description = "Name prefix for CloudFront resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aliases" {
  description = "List of domain aliases served by this distribution (e.g. [\"netmon2.technacy.it\"])"
  type        = list(string)
  default     = []
}

variable "origin_domain" {
  description = "Hostname or public IP of the backend server (can be any public IP)"
  type        = string
}

variable "origin_http_port" {
  description = "HTTP port on the origin server"
  type        = number
  default     = 80
}

variable "origin_https_port" {
  description = "HTTPS port on the origin server"
  type        = number
  default     = 443
}

variable "origin_protocol_policy" {
  description = "Protocol CloudFront uses to connect to origin: http-only, https-only, or match-viewer"
  type        = string
  default     = "http-only"

  validation {
    condition     = contains(["http-only", "https-only", "match-viewer"], var.origin_protocol_policy)
    error_message = "origin_protocol_policy must be http-only, https-only, or match-viewer."
  }
}

variable "web_acl_arn" {
  description = "ARN of the WAFv2 WebACL (must be CLOUDFRONT scope, deployed in us-east-1)"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate (must be in us-east-1 for CloudFront)"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 = US/Europe/Israel (cheapest). PriceClass_All = all edge locations."
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
