resource "aws_s3_bucket" "gatsby_static_bucket" {
    bucket_prefix = "${var.domain}-"

    website {
        index_document = "index.html"
        error_document = "404.html"
    }
}

resource "aws_s3_bucket_public_access_block" "gatsby_static_bucket_publicaccess" {
    bucket = "${aws_s3_bucket.gatsby_static_bucket.id}"

    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_identity" "gatsby_oai" {
    comment = "${var.domain}"
}

data "aws_iam_policy_document" "gatsby_static_bucket_policy_document" {
    statement {
        actions = [
            "s3:GetObject"
        ]

        resources = [
            "${aws_s3_bucket.gatsby_static_bucket.arn}/*"
        ]

        principals = [
            {
                type = "AWS"
                identifiers = ["${aws_cloudfront_origin_access_identity.gatsby_oai.iam_arn}"]
            }
        ]

        effect = "Allow"
    }    
}

resource "aws_s3_bucket_policy" "gatsby_static_bucket_policy" {
    bucket = "${aws_s3_bucket.gatsby_static_bucket.id}"

    policy = "${data.aws_iam_policy_document.gatsby_static_bucket_policy_document.json}"
}

locals {
    https = "${var.acm_certificate_arn != "" || var.iam_certificate_id != ""}"
}

resource "aws_iam_role" "gatsby_lambda_role" {
  name = "${replace("${var.domain}", ".", "-")}_lambda"


  assume_role_policy = "${file("${path.module}/data/gatsby_lambda_role_assumepolicy.json")}"
}

resource "aws_iam_role_policy" "gatsby_lambda_role_policy" {
  name = "${replace("${var.domain}", ".", "-")}_lambda"
  role = "${aws_iam_role.gatsby_lambda_role.id}"

  policy = "${file("${path.module}/data/gatsby_lambda_role_policy.json")}"
}

data "template_file" "gatsby_originrequest_lambda_template" {
    template = "${file("${path.module}/data/originrequest_lambda/index.js.tpl")}"
    vars = {
        index_document = "${var.index_document}"
        passthrough = "${var.cloudfront_lambda_originrequest_enabled ? var.cloudfront_lambda_originrequest_qualifiedarn : ""}"
    }
}

data "archive_file" "gatsby_originrequest_lambda_archive" {
    type = "zip"
    output_path = "${path.module}/artifacts/originrequest_lambda.zip"

    source {
        filename = "index.js"
        content = "${data.template_file.gatsby_originrequest_lambda_template.rendered}"
    }
}

resource "aws_lambda_function" "gatsby_originrequest_lambda" {
    filename = "${path.module}/artifacts/originrequest_lambda.zip"
    function_name = "${replace("${var.domain}", ".", "-")}_originrequest"
    role = "${aws_iam_role.gatsby_lambda_role.arn}"
    handler = "index.handler"

    source_code_hash = "${data.archive_file.gatsby_originrequest_lambda_archive.output_base64sha256}"
    runtime = "nodejs8.10"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

data "template_file" "gatsby_originresponse_lambda_template" {
    template = "${file("${path.module}/data/originresponse_lambda/index.js.tpl")}"
    vars = {
        index_document = "${var.index_document}"
        passthrough = "${var.cloudfront_lambda_originresponse_enabled ? var.cloudfront_lambda_originresponse_qualifiedarn : ""}"
    }
}

data "archive_file" "gatsby_originresponse_lambda_archive" {
    type = "zip"
    output_path = "${path.module}/artifacts/originresponse_lambda.zip"

    source {
        filename = "index.js"
        content = "${data.template_file.gatsby_originresponse_lambda_template.rendered}"
    }
}

resource "aws_lambda_function" "gatsby_originresponse_lambda" {
    filename = "${path.module}/artifacts/originresponse_lambda.zip"
    function_name = "${replace("${var.domain}", ".", "-")}_originresponse"
    role = "${aws_iam_role.gatsby_lambda_role.arn}"
    handler = "index.handler"

    source_code_hash = "${data.archive_file.gatsby_originresponse_lambda_archive.output_base64sha256}"
    runtime = "nodejs8.10"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

module "gatsby_static_distribution" {
    source = "../cloudfront-distribution-optional-lambdas"

    enabled = true
    aliases = ["${var.domain}"]
    http_version = "http2"
    is_ipv6_enabled = true

    origin_domain_name = "${aws_s3_bucket.gatsby_static_bucket.bucket_regional_domain_name}"
    origin_access_identity = "${aws_cloudfront_origin_access_identity.gatsby_oai.cloudfront_access_identity_path}"

    acm_certificate_arn = "${var.acm_certificate_arn}"
    iam_certificate_id = "${var.iam_certificate_id}"
    minimum_protocol_version = "${var.https_minimum_protocol_version}"
    ssl_support_method = "${var.https_support_non_sni ? "vip" : "sni-only"}"

    min_ttl = "${var.cache_all_objects ? 31536000 : 0}"
    default_ttl = "${var.cache_all_objects ? 31536000 : 0}"
    max_ttl = 31536000
    compress = true
    viewer_protocol_policy = "${var.https_redirect ? "redirect-to-https" : "allow-all"}"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    forward_cookies = "none"
    forward_query = false

    custom_response_403_enabled = true
    custom_response_403_code = "404"
    custom_response_403_page_path = "/${var.error_document}"
    
    viewerrequest_lambda_enabled = "${var.cloudfront_lambda_viewerrequest_enabled}"
    viewerrequest_lambda_qualifiedarn = "${var.cloudfront_lambda_viewerrequest_qualifiedarn}"
    viewerrequest_lambda_includebody = false
    originrequest_lambda_enabled = true
    originrequest_lambda_qualifiedarn = "${aws_lambda_function.gatsby_originrequest_lambda.qualified_arn}"
    originrequest_lambda_includebody = false
    originresponse_lambda_enabled = true
    originresponse_lambda_qualifiedarn = "${aws_lambda_function.gatsby_originresponse_lambda.qualified_arn}"
    originresponse_lambda_includebody = false
    viewerresponse_lambda_enabled = "${var.cloudfront_lambda_viewerresponse_enabled}"
    viewerresponse_lambda_qualifiedarn = "${var.cloudfront_lambda_viewerresponse_qualifiedarn}"
    viewerresponse_lambda_includebody = false
}

/*resource "aws_cloudfront_distribution" "gatsby_static_distribution" {
    enabled = true
    aliases = ["${var.domain}"]

    http_version = "http2"
    is_ipv6_enabled = true
    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    origin {
        origin_id = "main"
        domain_name = "${aws_s3_bucket.gatsby_static_bucket.bucket_regional_domain_name}"

        s3_origin_config {
            origin_access_identity = "${aws_cloudfront_origin_access_identity.gatsby_oai.cloudfront_access_identity_path}"
        }
    }

    viewer_certificate {
        acm_certificate_arn = "${var.acm_certificate_arn}"
        iam_certificate_id = "${var.iam_certificate_id}"
        minimum_protocol_version = "${var.https_minimum_protocol_version}"
        ssl_support_method = "${var.https_support_non_sni ? "vip" : "sni-only"}"
    }

    default_cache_behavior {
        target_origin_id = "main"
        min_ttl = "${var.cache_all_objects ? 31536000 : 0}"
        default_ttl = "${var.cache_all_objects ? 31536000 : 0}"
        max_ttl = 31536000
        compress = true
        viewer_protocol_policy = "${var.https_redirect ? "redirect-to-https" : "allow-all"}"
        allowed_methods = ["GET", "HEAD", "OPTIONS"]
        cached_methods = ["GET", "HEAD", "OPTIONS"]
        forwarded_values {
            cookies {
                forward = "none"
            }
            query_string = false
        }
        lambda_function_association {
            event_type = "origin-request"
            lambda_arn = "${aws_lambda_function.gatsby_originrequest_lambda.qualified_arn}"
            include_body = false
        }
        lambda_function_association {
            event_type = "origin-response"
            lambda_arn = "${aws_lambda_function.gatsby_originresponse_lambda.qualified_arn}"
            include_body = false
        }
        
        lambda_function_association {
            event_type = "${var.cloudfront_lambda_viewerrequest == "" ? "" : "viewer-request"}"
            lambda_arn = "${var.cloudfront_lambda_viewerrequest == "" ? "" : var.cloudfront_lambda_viewerrequest}"
            include_body = false
        }
        # Can't do this because the origin-request and origin-response Lambda functions are already used. Instead, those functions include a pass-through mechanism.
        # lambda_function_association {
        #     event_type = "${var.cloudfront_lambda_originrequest == "" ? "" : "origin-request"}"
        #     lambda_arn = "${var.cloudfront_lambda_originrequest == "" ? "" : var.cloudfront_lambda_originrequest}"
        #     include_body = false
        # }
        # lambda_function_association {
        #     event_type = "${var.cloudfront_lambda_originresponse == "" ? "" : "origin-response"}"
        #     lambda_arn = "${var.cloudfront_lambda_originresponse == "" ? "" : var.cloudfront_lambda_originresponse}"
        #     include_body = false
        # }
        lambda_function_association {
            event_type = "${var.cloudfront_lambda_viewerresponse == "" ? "" : "viewer-response"}"
            lambda_arn = "${var.cloudfront_lambda_viewerresponse == "" ? "" : var.cloudfront_lambda_viewerresponse}"
            include_body = false
        }
    }

    custom_error_response {
        error_code = 403
        response_code = 404
        response_page_path = "/${var.error_document}"
    }
}*/