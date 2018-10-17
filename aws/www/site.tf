provider "aws" {
  region     = "eu-west-2"
}

// DNS

data "aws_route53_zone" "gluth_io" {
  name         = "gluth.io."
}


resource "aws_route53_record" "default" {

  zone_id = "${data.aws_route53_zone.gluth_io.zone_id}"

  type    = "A"
  name    = "${data.aws_route53_zone.gluth_io.name}"

  alias {
    name                   = "${aws_s3_bucket.static_site.website_domain}"
    zone_id                = "${aws_s3_bucket.static_site.hosted_zone_id}"
    evaluate_target_health = true
  }
  
}

resource "aws_route53_record" "www" {

  zone_id = "${data.aws_route53_zone.gluth_io.zone_id}"

  type    = "A"
  name    = "www.${data.aws_route53_zone.gluth_io.zone_id}"


  alias {
    name                   = "${aws_s3_bucket.www.website_domain}"
    zone_id                = "${aws_s3_bucket.www.hosted_zone_id}"
    evaluate_target_health = true
  }

}

// S3 setup

resource "aws_s3_bucket" "static_site" {
  bucket = "gluth.io"
  acl    = "public-read"
  policy = "${file("policy.json")}"

  website {
    index_document = "index.html"
    routing_rules = ""
  }
}

resource "aws_s3_bucket_object" "index" {
  bucket = "gluth.io"
  key    = "index.html"
  source = "../../public/index.html"
  content_type = "text/html"
  etag   = "${md5(file("../../public/index.html"))}"
  // apparently this is necessary.
  depends_on = ["aws_s3_bucket.static_site"]
}

resource "aws_s3_bucket_object" "style" {
  bucket = "gluth.io"
  key    = "style.css"
  source = "../../public/style.css"
  content_type = "text/css"
  etag   = "${md5(file("../../public/style.css"))}"
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
