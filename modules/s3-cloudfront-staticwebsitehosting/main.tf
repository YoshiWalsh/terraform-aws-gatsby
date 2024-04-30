terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0.0"
            configuration_aliases = [ aws, aws.certificates ]
        }
    }
}

resource "aws_s3_bucket" "static_bucket" {
    count = var.existing_s3_bucket == null ? 1 : 0

    bucket_prefix = "${var.domain}-"
}

data "aws_s3_bucket" "existing_bucket" {
    count = var.existing_s3_bucket != null ? 1 : 0

    bucket = var.existing_s3_bucket
}

resource "aws_s3_bucket_website_configuration" "static_website_configuration" {
    count = (var.use_private_bucket || var.existing_s3_bucket != null) ? 0 : 1

    bucket = aws_s3_bucket.static_bucket[0].id
    index_document {
        suffix = var.index_document
    }
    error_document {
        key = var.error_document
    }
}

resource "aws_s3_bucket_public_access_block" "static_bucket_publicaccess" {
    count = var.existing_s3_bucket == null ? 1 : 0

    bucket = aws_s3_bucket.static_bucket[0].id

    block_public_acls = var.use_private_bucket
    block_public_policy = var.use_private_bucket
    ignore_public_acls = var.use_private_bucket
    restrict_public_buckets = var.use_private_bucket
}

resource "aws_cloudfront_origin_access_identity" "oai" {
    count = (var.use_private_bucket && var.existing_s3_bucket == null) ? 1 : 0
    
    comment = var.domain
}

data "aws_iam_policy_document" "static_bucket_policy_document" {
    count = var.existing_s3_bucket == null ? 1 : 0

    statement {
        actions = [
            "s3:GetObject"
        ]

        resources = [
            "${aws_s3_bucket.static_bucket[0].arn}/*"
        ]

        principals {
            type = var.use_private_bucket ? "AWS" : "*"
            identifiers = [var.use_private_bucket ? aws_cloudfront_origin_access_identity.oai[0].iam_arn : "*"]
        }

        effect = "Allow"
    }    
}

resource "aws_s3_bucket_policy" "static_bucket_policy" {
    count = var.existing_s3_bucket == null ? 1 : 0

    bucket = aws_s3_bucket.static_bucket[0].id

    policy = data.aws_iam_policy_document.static_bucket_policy_document[0].json
}


data "aws_route53_zone" "primary_zone" {
    count = (var.issue_certificate && try(coalesce(var.acm_certificate_arn, var.iam_certificate_id), null) == null) ? 1 : 0

    name = lookup(var.domain_route53_zones, var.domain, var.domain)
    private_zone = false
}

module "primary_cert" {
    count = (var.issue_certificate && try(coalesce(var.acm_certificate_arn, var.iam_certificate_id), null) == null) ? 1 : 0

    source = "github.com/azavea/terraform-aws-acm-certificate?ref=4.0.0"

    providers = {
        aws.acm_account = aws.certificates
        aws.route53_account = aws
    }

    domain_name = var.domain
    subject_alternative_names = []
    hosted_zone_id = data.aws_route53_zone.primary_zone[0].id
    validation_record_ttl = "60"
}

locals {
    https = var.acm_certificate_arn != "" || var.iam_certificate_id != "" || var.issue_certificate
}

resource "aws_iam_role" "lambda_role" {
    count = var.use_private_bucket ? 1 : 0
    
    name = "${replace("${var.domain}", ".", "-")}_lambda"

    assume_role_policy = file("${path.module}/data/lambda_role_assumepolicy.json")
}

resource "aws_iam_role_policy" "lambda_role_policy" {
    count = var.use_private_bucket ? 1 : 0
    
    name = "${replace("${var.domain}", ".", "-")}_lambda"
    role = aws_iam_role.lambda_role[0].id

    policy = file("${path.module}/data/lambda_role_policy.json")
}

data "template_file" "originrequest_lambda_template" {
    count = var.use_private_bucket ? 1 : 0
    
    template = file("${path.module}/data/originrequest_lambda/index.js.tpl")
    vars = {
        index_document = var.index_document
        passthrough = var.cloudfront_lambda_originrequest_enabled ? var.cloudfront_lambda_originrequest_qualifiedarn : ""
    }
}

data "archive_file" "originrequest_lambda_archive" {
    count = var.use_private_bucket ? 1 : 0
    
    type = "zip"
    output_path = "${path.module}/artifacts/originrequest_lambda.zip"

    source {
        filename = "index.js"
        content = data.template_file.originrequest_lambda_template[0].rendered
    }
}

resource "aws_lambda_function" "originrequest_lambda" {
    count = var.use_private_bucket ? 1 : 0
    
    filename = "${path.module}/artifacts/originrequest_lambda.zip"
    function_name = "${replace("${var.domain}", ".", "-")}_originrequest"
    role = aws_iam_role.lambda_role[0].arn
    handler = "index.handler"

    source_code_hash = data.archive_file.originrequest_lambda_archive[0].output_base64sha256
    runtime = "nodejs20.x"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

data "template_file" "originresponse_lambda_template" {
    count = var.use_private_bucket ? 1 : 0
    
    template = file("${path.module}/data/originresponse_lambda/index.js.tpl")
    vars = {
        index_document = var.index_document
        passthrough = var.cloudfront_lambda_originresponse_enabled ? var.cloudfront_lambda_originresponse_qualifiedarn : ""
    }
}

data "archive_file" "originresponse_lambda_archive" {
    count = var.use_private_bucket ? 1 : 0
    
    type = "zip"
    output_path = "${path.module}/artifacts/originresponse_lambda.zip"

    source {
        filename = "index.js"
        content = data.template_file.originresponse_lambda_template[0].rendered
    }
}

resource "aws_lambda_function" "originresponse_lambda" {
    count = var.use_private_bucket ? 1 : 0
    
    filename = "${path.module}/artifacts/originresponse_lambda.zip"
    function_name = "${replace("${var.domain}", ".", "-")}_originresponse"
    role = aws_iam_role.lambda_role[0].arn
    handler = "index.handler"

    source_code_hash = data.archive_file.originresponse_lambda_archive[0].output_base64sha256
    runtime = "nodejs20.x"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_cloudfront_distribution" "static_distribution" {
    enabled = true
    aliases = [var.domain]

    http_version = "http2"
    is_ipv6_enabled = true

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    origin {
        origin_id = "main"
        domain_name = (
            var.existing_s3_bucket == null ?
            (
                var.use_private_bucket ?
                aws_s3_bucket.static_bucket[0].bucket_regional_domain_name :
                aws_s3_bucket_website_configuration.static_website_configuration[0].website_endpoint
            ) :
            (
                var.use_private_bucket ?
                data.aws_s3_bucket.existing_bucket[0].bucket_regional_domain_name :
                data.aws_s3_bucket.existing_bucket[0].website_endpoint
            )
        )

        dynamic custom_origin_config {
            for_each = var.use_private_bucket ? [] : [true]

            content {
                http_port = 80
                https_port = 443
                origin_protocol_policy = "http-only"
                origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
            }
        }

        dynamic s3_origin_config {
            for_each = var.use_private_bucket ? [true] : []

            content {
                origin_access_identity = aws_cloudfront_origin_access_identity.oai[0].cloudfront_access_identity_path
            }
        }
    }

    viewer_certificate {
        acm_certificate_arn = try(module.primary_cert[0].arn, var.acm_certificate_arn, null)
        iam_certificate_id = var.iam_certificate_id
        minimum_protocol_version = var.https_minimum_protocol_version
        ssl_support_method = var.https_support_non_sni ? "vip" : "sni-only"
    }

    default_cache_behavior {
        target_origin_id = "main"
        min_ttl = var.cache_all_objects ? 31536000 : 0
        default_ttl = var.cache_all_objects ? 31536000 : 0
        max_ttl = 31536000
        compress = true
        viewer_protocol_policy = var.https_redirect ? "redirect-to-https" : "allow-all"
        allowed_methods = ["GET", "HEAD", "OPTIONS"]
        cached_methods = ["GET", "HEAD", "OPTIONS"]
        forwarded_values {
            cookies {
                forward = "none"
            }
            query_string = false
        }

        # User-supplied viewer functions are always used directly
        dynamic lambda_function_association {
            for_each = var.cloudfront_lambda_viewerrequest_enabled ? [true] : []

            content {
                event_type = "viewer-request"
                lambda_arn = var.cloudfront_lambda_viewerrequest_qualifiedarn
                include_body = false
            }
        }

        dynamic lambda_function_association {
            for_each = var.cloudfront_lambda_viewerresponse_enabled ? [true] : []

            content {
                event_type = "viewer-response"
                lambda_arn = var.cloudfront_lambda_viewerresponse_qualifiedarn
                include_body = false
            }
        }

        # User-supplied origin functions can only be used directly when not using a private bucket
        dynamic lambda_function_association {
            for_each = (!var.use_private_bucket && var.cloudfront_lambda_originrequest_enabled) ? [true] : []

            content {
                event_type = "origin-request"
                lambda_arn = var.cloudfront_lambda_originrequest_qualifiedarn
                include_body = false
            }
        }

        dynamic lambda_function_association {
            for_each = (!var.use_private_bucket && var.cloudfront_lambda_originresponse_enabled) ? [true] : []

            content {
                event_type = "origin-response"
                lambda_arn = var.cloudfront_lambda_originresponse_qualifiedarn
                include_body = false
            }
        }

        # When using a private bucket, we need to use the two origin
        # functions to emulate S3 Static Website Hosting's behaviour.
        # User-supplied origin functions are still supported via a
        # passthrough mechanism in the Lambda scripts.
        dynamic lambda_function_association {
            for_each = var.use_private_bucket ? [true] : []

            content {
                event_type = "origin-request"
                lambda_arn = aws_lambda_function.originrequest_lambda[0].qualified_arn
                include_body = false
            }
        }

        dynamic lambda_function_association {
            for_each = var.use_private_bucket ? [true] : []

            content {
                event_type = "origin-response"
                lambda_arn = aws_lambda_function.originresponse_lambda[0].qualified_arn
                include_body = false
            }
        }
    }

    custom_error_response {
        error_code = 403
        response_code = 404
        response_page_path = "/${var.error_document}"
    }
}

resource "aws_route53_record" "main_dns_ipv4" {
    count = var.create_dns_records ? 1 : 0

    zone_id = data.aws_route53_zone.primary_zone[0].id
    name = var.domain
    type = "A"
    
    alias {
        name = aws_cloudfront_distribution.static_distribution.domain_name
        zone_id = aws_cloudfront_distribution.static_distribution.hosted_zone_id
        evaluate_target_health = false
    }
}

resource "aws_route53_record" "main_dns_ipv6" {
    count = var.create_dns_records ? 1 : 0

    zone_id = data.aws_route53_zone.primary_zone[0].id
    name = var.domain
    type = "AAAA"
    
    alias {
        name = aws_cloudfront_distribution.static_distribution.domain_name
        zone_id = aws_cloudfront_distribution.static_distribution.hosted_zone_id
        evaluate_target_health = false
    }
}