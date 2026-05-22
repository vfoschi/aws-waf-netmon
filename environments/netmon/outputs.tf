output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = module.waf.web_acl_id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN — use this to attach the WAF to CloudFront distributions"
  value       = module.waf.web_acl_arn
}

output "web_acl_name" {
  description = "WAF Web ACL Name"
  value       = module.waf.web_acl_name
}

output "web_acl_capacity" {
  description = "WAF capacity units consumed (max 1500 for REGIONAL)"
  value       = module.waf.web_acl_capacity
}

output "log_group_name" {
  description = "CloudWatch Log Group name for WAF logs"
  value       = module.waf.log_group_name
}
