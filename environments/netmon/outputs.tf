output "alb_dns_name" {
  description = "DNS name of the ALB — point your domain CNAME (or Route53 alias) here"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB (for Route53 alias records)"
  value       = module.alb.alb_zone_id
}

output "certificate_arn" {
  description = "ARN of the ACM certificate attached to the ALB"
  value       = local.resolved_certificate_arn
}

output "certificate_validation_records" {
  description = "DNS CNAME records to add for manual ACM certificate validation (only needed when route53_zone_id is not set)"
  value = (
    var.certificate_domain != "" && var.route53_zone_id == "" ?
    [
      for dvo in aws_acm_certificate.this[0].domain_validation_options : {
        name  = dvo.resource_record_name
        type  = dvo.resource_record_type
        value = dvo.resource_record_value
      }
    ] : []
  )
}

output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = module.waf.web_acl_id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN"
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
