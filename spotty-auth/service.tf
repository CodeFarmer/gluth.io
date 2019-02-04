provider "aws" {
  region = "eu-west-2"
}


locals {
  certificate_arn = "arn:aws:acm:eu-west-2:040789721567:certificate/e6493c61-2f9f-4812-90fd-c4f5597e7740"
}



# S3 Bucket for storing Elastic Beanstalk task definitions
resource "aws_s3_bucket" "spotty-auth-beanstalk-deploys" {
  bucket = "spotty-auth-beanstalk-deploy"
}

resource "aws_s3_bucket_object" "spotty-auth-dockerrun" {
  bucket = "${aws_s3_bucket.spotty-auth-beanstalk-deploys.id}"
  key    = "dockerrun"
  source = "Dockerrun.aws.json"
  etag   = "${md5(file("Dockerrun.aws.json"))}"
}



# Beanstalk instance profile
resource "aws_iam_instance_profile" "spotty-auth-beanstalk-ec2" {
  name  = "ng-beanstalk-ec2-user"
  role = "${aws_iam_role.spotty-auth-beanstalk-ec2.name}"
}

resource "aws_iam_role" "spotty-auth-beanstalk-ec2" {
  name = "spotty-auth-beanstalk-ec2-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


## BEANSTALK

resource "aws_elastic_beanstalk_application" "spotty-auth" {
  name = "spotty-auth"
}


resource "aws_elastic_beanstalk_environment" "spotty-auth" {

  name = "spotty-auth"
  application = "spotty-auth"

  solution_stack_name = "64bit Amazon Linux 2018.03 v2.12.7 running Docker 18.06.1-ce"

  // optional
  cname_prefix = "spotty-auth"

  version_label = "${aws_elastic_beanstalk_application_version.default.name}"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro" # t3 instances need a VPC
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"

    # Todo: As Variable
    value = "1"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "${aws_iam_instance_profile.spotty-auth-beanstalk-ec2.name}"
  }

  /*
    aws:elb:listener:443:
    SSLCertificateId: arn:aws:acm:us-east-2:1234567890123:certificate/####################################
    ListenerProtocol: HTTPS
    InstancePort: 80
  */

  setting {
    namespace = "aws:elb:listener:443"
    name      = "SSLCertificateId"
    value     = "${local.certificate_arn}"
  }
  
  setting {
    namespace = "aws:elb:listener:443"
    name      = "ListenerProtocol"
    value     = "HTTPS"
  }
  
  setting {
    namespace = "aws:elb:listener:443"
    name      = "InstancePort"
    value     = "80"
  }
  
}


resource "aws_elastic_beanstalk_application_version" "default" {
  name        = "spotty-auth-default"
  application = "spotty-auth"
  description = "application version created by terraform"
  bucket      = "${aws_s3_bucket.spotty-auth-beanstalk-deploys.id}"
  key         = "${aws_s3_bucket_object.spotty-auth-dockerrun.key}"
}


data "aws_route53_zone" "gluth_io" {
  name         = "gluth.io."
}

resource "aws_route53_record" "spotty-auth" {

  zone_id = "${data.aws_route53_zone.gluth_io.zone_id}"

  type    = "CNAME"
  name    = "spotty-auth.${data.aws_route53_zone.gluth_io.name}"
  ttl     = "60"

  records = [ "${aws_elastic_beanstalk_environment.spotty-auth.cname}" ]

}

output "load balancers" {
  value = "${aws_elastic_beanstalk_environment.spotty-auth.load_balancers}"
}
