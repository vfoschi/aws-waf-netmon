locals {
  common_tags = merge(
    {
      Name        = var.name
      Environment = var.environment
      ManagedBy   = "terraform"
      Service     = "cloudfront"
    },
    var.tags
  )
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.name} - ${var.environment}"
  aliases         = var.aliases
  web_acl_id      = var.web_acl_arn
  price_class     = var.price_class
  tags            = local.common_tags

  origin {
    domain_name = var.origin_domain
    origin_id   = "custom-origin"

    custom_origin_config {
      http_port              = var.origin_http_port
      https_port             = var.origin_https_port
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "custom-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = false

    # CachingDisabled + AllViewer: no caching, forward all headers/cookies/query strings
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
