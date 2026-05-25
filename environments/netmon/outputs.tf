output "cloudfront_domain_name" {
  description = "CloudFront domain name — create a CNAME or Route53 alias pointing here"
  value       = module.cloudfront.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution (for Route53 alias records)"
  value       = module.cloudfront.hosted_zone_id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN (us-east-1, CLOUDFRONT scope)"
  value       = module.waf.web_acl_arn
}

output "web_acl_name" {
  description = "WAF Web ACL Name"
  value       = module.waf.web_acl_name
}

output "certificate_arn" {
  description = "ACM certificate ARN (us-east-1)"
  value       = local.resolved_certificate_arn
}

output "certificate_validation_records" {
  description = "DNS CNAME records for manual ACM certificate validation (only when route53_zone_id is empty)"
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
