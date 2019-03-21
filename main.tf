provider "aws" {
    region = "${var.region}"
}

provider "aws" {
    alias = "certificates"
    region = "us-east-1"
}

data "aws_route53_zone" "primary_zone" {
    name = "${lookup(var.domain_route53_zones, var.domain, var.domain)}"
    private_zone = false
}

module "primary_cert" {
    source = "github.com/azavea/terraform-aws-acm-certificate?ref=1.0.0"

    providers = {
        aws.acm_account = "aws.certificates"
        aws.route53_account = "aws"
    }

    domain_name = "${var.domain}"
    subject_alternative_names = []
    hosted_zone_id = "${data.aws_route53_zone.primary_zone.id}"
    validation_record_ttl = "60"
}

module "s3_cf_staticwebsitehosting" {
    source = "./modules/s3-cloudfront-staticwebsitehosting"

    domain = "${var.domain}"
    acm_certificate_arn = "${module.primary_cert.arn}"
    cache_all_objects = "true"
}

resource "aws_route53_record" "main_dns_ipv4" {
    zone_id = "${data.aws_route53_zone.primary_zone.id}"
    name = "${var.domain}"
    type = "A"
    
    alias {
        name = "${module.s3_cf_staticwebsitehosting.cf_distribution_domain}"
        zone_id = "${module.s3_cf_staticwebsitehosting.cf_distribution_zone_id}"
        evaluate_target_health = false
    }
}

resource "aws_route53_record" "main_dns_ipv6" {
    zone_id = "${data.aws_route53_zone.primary_zone.id}"
    name = "${var.domain}"
    type = "AAAA"
    
    alias {
        name = "${module.s3_cf_staticwebsitehosting.cf_distribution_domain}"
        zone_id = "${module.s3_cf_staticwebsitehosting.cf_distribution_zone_id}"
        evaluate_target_health = false
    }
}