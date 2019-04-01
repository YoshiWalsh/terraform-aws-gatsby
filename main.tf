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


#//////////////////////
resource "aws_iam_role" "test_lambda_role" {
  name = "${replace("${var.domain}", ".", "-")}_testlambda"


  assume_role_policy = "${file("./modules/s3-cloudfront-originaccessidentity/data/gatsby_lambda_role_assumepolicy.json")}"
}

resource "aws_iam_role_policy" "test_lambda_role_policy" {
  name = "${replace("${var.domain}", ".", "-")}_testlambda"
  role = "${aws_iam_role.test_lambda_role.id}"

  policy = "${file("./modules/s3-cloudfront-originaccessidentity/data/gatsby_lambda_role_policy.json")}"
}

data "archive_file" "test_viewerrequest_lambda_archive" {
    type = "zip"
    output_path = "${path.module}/artifacts/test_viewerrequest_lambda.zip"

    source {
        filename = "index.js"
        content = "${file("./examples/bells-and-whistles/password.js")}"
    }
}

resource "aws_lambda_function" "test_viewerrequest_lambda" {
    filename = "${path.module}/artifacts/test_viewerrequest_lambda.zip"
    function_name = "test_terraform_viewerrequest_lambda"
    role = "${aws_iam_role.test_lambda_role.arn}"
    handler = "index.handler"

    source_code_hash = "${data.archive_file.test_viewerrequest_lambda_archive.output_base64sha256}"
    runtime = "nodejs8.10"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

data "archive_file" "test_originrequest_lambda_archive" {
    type = "zip"
    output_path = "${path.module}/artifacts/test_originrequest_lambda.zip"

    source {
        filename = "index.js"
        content = "${file("./examples/bells-and-whistles/rewrite.js")}"
    }
}

resource "aws_lambda_function" "test_originrequest_lambda" {
    filename = "${path.module}/artifacts/test_originrequest_lambda.zip"
    function_name = "test_terraform_originrequest_lambda"
    role = "${aws_iam_role.test_lambda_role.arn}"
    handler = "index.handler"

    source_code_hash = "${data.archive_file.test_originrequest_lambda_archive.output_base64sha256}"
    runtime = "nodejs8.10"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

data "archive_file" "test_originresponse_lambda_archive" {
    type = "zip"
    output_path = "${path.module}/artifacts/test_originresponse_lambda.zip"

    source {
        filename = "index.js"
        content = "${file("./examples/bells-and-whistles/preserve-querystring-on-redirect.js")}"
    }
}

resource "aws_lambda_function" "test_originresponse_lambda" {
    filename = "${path.module}/artifacts/test_originresponse_lambda.zip"
    function_name = "test_terraform_originresponse_lambda"
    role = "${aws_iam_role.test_lambda_role.arn}"
    handler = "index.handler"

    source_code_hash = "${data.archive_file.test_originresponse_lambda_archive.output_base64sha256}"
    runtime = "nodejs8.10"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

#//////////////////////




module "s3_cf_staticwebsitehosting" {
    source = "./modules/s3-cloudfront-originaccessidentity"

    domain = "${var.domain}"
    acm_certificate_arn = "${module.primary_cert.arn}"
    cache_all_objects = "true"

    cloudfront_lambda_viewerrequest_enabled = true
    cloudfront_lambda_viewerrequest_qualifiedarn = "${aws_lambda_function.test_viewerrequest_lambda.qualified_arn}"
    cloudfront_lambda_originrequest_enabled = true
    cloudfront_lambda_originrequest_qualifiedarn = "${aws_lambda_function.test_originrequest_lambda.qualified_arn}"
    cloudfront_lambda_originresponse_enabled = true
    cloudfront_lambda_originresponse_qualifiedarn = "${aws_lambda_function.test_originresponse_lambda.qualified_arn}"
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