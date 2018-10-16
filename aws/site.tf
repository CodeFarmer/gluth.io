provider "aws" {
  region     = "eu-west-2"
}


// DNS

// formerly:
// ns1.hover.com
// ns1.hover.com

resource "aws_route53_zone" "site" {
  name = "gluth.io"
}

resource "aws_route53_record" "default" {

  zone_id = "${aws_route53_zone.site.zone_id}"
  name    = "gluth.io"
  type    = "A"

  alias {
    // FIXME get this from a var
    name = "gluth.io.s3-website.eu-west-2.amazonaws.com"
//    name                   = "${aws_s3_bucket.static_site.website_domain}"
    zone_id                = "${aws_s3_bucket.static_site.hosted_zone_id}"
    evaluate_target_health = true
  }
  
}

resource "aws_route53_record" "www" {
  zone_id = "${aws_route53_zone.site.zone_id}"
  name    = "www.gluth.io"
  type    = "A"

  alias {
    // FIXME get this from a var
    name = "www.gluth.io.s3-website.eu-west-2.amazonaws.com"
    name                   = "${aws_s3_bucket.www.website_domain}"
    zone_id                = "${aws_s3_bucket.www.hosted_zone_id}"
    evaluate_target_health = true
  }

}

resource "aws_route53_record" "mx" {
  zone_id = "${aws_route53_zone.site.zone_id}"
  name    = "mx"
  type    = "MX"
  ttl     = "300"
  records = [ "10 mx.hover.com.cust.hostedemail.com" ]
}

resource "aws_route53_record" "mail" {
  zone_id = "${aws_route53_zone.site.zone_id}"
  name    = "mail.gluth.io"
  type    = "CNAME"
  ttl     = "300"
  records = [ "mail.hover.com.cust.hostedemail.com" ]
}

output "nameservers" {
  value="${aws_route53_zone.site.name_servers}"
}

// S3 setup

resource "aws_s3_bucket" "static_site" {
  bucket = "gluth.io"
  acl    = "public-read"
  policy = "${file("policy.json")}"

  website {
    index_document = "index.html"
    routing_rules = <<EOF
EOF
  }
}

resource "aws_s3_bucket_object" "index" {
  bucket = "gluth.io"
  key    = "index.html"
  source = "../public/index.html"
  etag   = "${md5(file("../public/index.html"))}"
  // apparently this is necessary.
  depends_on = ["aws_s3_bucket.static_site"]
}

resource "aws_s3_bucket_object" "style" {
  bucket = "gluth.io"
  key    = "style.css"
  source = "../public/style.css"
  etag   = "${md5(file("../public/style.css"))}"
  // apparently this is necessary.
  depends_on = ["aws_s3_bucket.static_site"]
}

// redirect www calls to main site
resource "aws_s3_bucket" "www" {
  bucket = "www.gluth.io"
  acl    = "public-read"

  website {
    redirect_all_requests_to = "gluth.io"
  }
}
