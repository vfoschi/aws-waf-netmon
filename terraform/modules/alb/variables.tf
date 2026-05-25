variable "name" {
  description = "Name prefix for all ALB resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB (minimum 2, must be in different AZs)"
  type        = list(string)
}

variable "internal" {
  description = "Whether the ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = false
}

variable "origin_ip" {
  description = "IP address of the backend server to forward all WAF-passed traffic to"
  type        = string
}

variable "origin_port" {
  description = "Port on the backend server to forward traffic to"
  type        = number
  default     = 80
}

variable "origin_availability_zone" {
  description = "AZ for the origin IP target. Use 'all' for IPs outside the VPC (on-premises, other VPCs, public IPs)"
  type        = string
  default     = "all"
}

variable "health_check_path" {
  description = "HTTP path for ALB health checks against the origin"
  type        = string
  default     = "/"
}

# enable_https must be a static bool (not computed) so Terraform can evaluate
# listener count at plan time. Set it to true when a certificate will be provided.
variable "enable_https" {
  description = "Create HTTPS listener on port 443 and redirect HTTP to HTTPS. Requires certificate_arn to also be set."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS. Required when enable_https is true."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
