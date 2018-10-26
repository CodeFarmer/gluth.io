provider "aws" {
  region     = "eu-west-2"
}

locals {
  certificate_arn = "arn:aws:acm:us-east-1:040789721567:certificate/37e53493-3636-4b93-908b-e25f6ab1c011"
}

// DNS

data "aws_route53_zone" "gluth_io" {
  name         = "gluth.io."
}

/*
resource "aws_route53_record" "default" {

  zone_id = "${data.aws_route53_zone.gluth_io.zone_id}"

  type    = "A"
  name    = "${data.aws_route53_zone.gluth_io.name}"
  depends_on = [ "aws_route53_record.www" ]

  alias {
    // Apparently this doesn't work because you can't alias to a CNAME?
    name                   = "${aws_route53_record.www.name}"
    zone_id                = "${data.aws_route53_zone.gluth_io.zone_id}"
    evaluate_target_health = true
  }

}
*/

resource "aws_route53_record" "www" {

  zone_id = "${data.aws_route53_zone.gluth_io.zone_id}"

  type    = "CNAME"
  name    = "www.${data.aws_route53_zone.gluth_io.name}"
  ttl     = "60"

  records = [ "${aws_cloudfront_distribution.website.domain_name}" ]
  
}

// S3 setup

resource "aws_s3_bucket" "static_site" {
  bucket = "gluth.io"
  acl    = "public-read"
  policy = "${file("policy.json")}"
}

resource "aws_s3_bucket_object" "index" {
  bucket = "gluth.io"
  key    = "index.html"
  source = "public/index.html"
  content_type = "text/html"
  etag   = "${md5(file("public/index.html"))}"
  // apparently this is necessary.
  depends_on = ["aws_s3_bucket.static_site"]
}

resource "aws_s3_bucket_object" "style" {
  bucket = "gluth.io"
  key    = "style.css"
  source = "public/style.css"
  content_type = "text/css"
  etag   = "${md5(file("public/style.css"))}"
  depends_on = ["aws_s3_bucket.static_site"]
}


// CloudFront (HTTPS)
resource "aws_cloudfront_distribution" "website" {

  origin {
    domain_name = "${aws_s3_bucket.static_site.bucket_regional_domain_name}"
    origin_id = "${aws_s3_bucket.static_site.id}"
  }

  // FIXME this should be available from the route53 entry without a
  // cyclic dependency
  aliases = [ "www.gluth.io", "gluth.io" ]

  enabled             = true
  is_ipv6_enabled     = true

  default_root_object = "index.html"

  default_cache_behavior = {
    
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    forwarded_values = []

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {

      query_string = false
      
      cookies {
        forward = "none"
      }
      
    }

    target_origin_id = "${aws_s3_bucket.static_site.id}"
    
  }

  viewer_certificate {
    acm_certificate_arn = "${local.certificate_arn}"
    ssl_support_method = "sni-only"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
}
