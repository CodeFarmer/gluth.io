provider "aws" {
  region     = "eu-west-2"
}


// DNS

// formerly:
// ns1.hover.com
// ns1.hover.com

resource "aws_route53_zone" "gluth_io" {
  name = "gluth.io"
}

resource "aws_route53_record" "mx" {
  zone_id = "${aws_route53_zone.gluth_io.zone_id}"
  name    = "mx"
  type    = "MX"
  ttl     = "300"
  records = [ "10 mx.hover.com.cust.hostedemail.com" ]
}

resource "aws_route53_record" "mail" {
  zone_id = "${aws_route53_zone.gluth_io.zone_id}"
  name    = "mail.gluth.io"
  type    = "CNAME"
  ttl     = "300"
  records = [ "mail.hover.com.cust.hostedemail.com" ]
}

output "nameservers" {
  value="${aws_route53_zone.gluth_io.name_servers}"
}
