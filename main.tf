provider "aws" {
    region = var.region
}

provider "aws" {
    alias = "certificates"
    region = "us-east-1"
}

resource "random_id" "environment_identifier" {
    keepers = {
    }

    byte_length = 8
}


#//////////////////////
resource "aws_iam_role" "test_lambda_role" {
  name = "${replace("${var.domain}", ".", "-")}_testlambda"


  assume_role_policy = file("./modules/s3-cloudfront-staticwebsitehosting/data/lambda_role_assumepolicy.json")
}

resource "aws_iam_role_policy" "test_lambda_role_policy" {
  name = "${replace("${var.domain}", ".", "-")}_testlambda"
  role = aws_iam_role.test_lambda_role.id

  policy = file("./modules/s3-cloudfront-staticwebsitehosting/data/lambda_role_policy.json")
}

data "archive_file" "test_viewerrequest_lambda_archive" {
    type = "zip"
    output_path = "${path.module}/artifacts/test_viewerrequest_lambda.zip"

    source {
        filename = "index.js"
        content = file("./examples/bells-and-whistles/password.js")
    }
}

resource "aws_lambda_function" "test_viewerrequest_lambda" {
    filename = "${path.module}/artifacts/test_viewerrequest_lambda.zip"
    function_name = "gatsby_${random_id.environment_identifier.hex}_viewerrequest"
    role = aws_iam_role.test_lambda_role.arn
    handler = "index.handler"

    source_code_hash = data.archive_file.test_viewerrequest_lambda_archive.output_base64sha256
    runtime = "nodejs20.x"
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
        content = file("./examples/bells-and-whistles/rewrite.js")
    }
}

resource "aws_lambda_function" "test_originrequest_lambda" {
    filename = "${path.module}/artifacts/test_originrequest_lambda.zip"
    function_name = "gatsby_${random_id.environment_identifier.hex}_originrequest"
    role = aws_iam_role.test_lambda_role.arn
    handler = "index.handler"

    source_code_hash = data.archive_file.test_originrequest_lambda_archive.output_base64sha256
    runtime = "nodejs20.x"
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
        content = file("./examples/bells-and-whistles/preserve-querystring-on-redirect.js")
    }
}

resource "aws_lambda_function" "test_originresponse_lambda" {
    filename = "${path.module}/artifacts/test_originresponse_lambda.zip"
    function_name = "gatsby_${random_id.environment_identifier.hex}_originresponse"
    role = aws_iam_role.test_lambda_role.arn
    handler = "index.handler"

    source_code_hash = data.archive_file.test_originresponse_lambda_archive.output_base64sha256
    runtime = "nodejs20.x"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

#//////////////////////




module "s3_cf_staticwebsitehosting" {
    source = "./modules/s3-cloudfront-originaccessidentity"

    providers = {
        aws = aws
    }

    domain = var.domain
    cache_all_objects = "true"

    cloudfront_lambda_viewerrequest_enabled = true
    cloudfront_lambda_viewerrequest_qualifiedarn = aws_lambda_function.test_viewerrequest_lambda.qualified_arn
    cloudfront_lambda_originrequest_enabled = true
    cloudfront_lambda_originrequest_qualifiedarn = aws_lambda_function.test_originrequest_lambda.qualified_arn
    cloudfront_lambda_originresponse_enabled = true
    cloudfront_lambda_originresponse_qualifiedarn = aws_lambda_function.test_originresponse_lambda.qualified_arn

    domain_route53_zones = var.domain_route53_zones
    create_dns_records = true
}