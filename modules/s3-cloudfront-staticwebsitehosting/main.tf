resource "aws_s3_bucket" "gatsby_static_bucket" {
    bucket_prefix = "${var.domain}-"

    website {
        index_document = "${var.index_document}"
        error_document = "${var.error_document}"
    }
}

resource "aws_s3_bucket_public_access_block" "gatsby_static_bucket_publicaccess" {
    bucket = "${aws_s3_bucket.gatsby_static_bucket.id}"

    block_public_acls = false
    block_public_policy = false
    ignore_public_acls = false
    restrict_public_buckets = false
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
                type = "*"
                identifiers = ["*"]
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

module "gatsby_static_distribution" {
    source = "../cloudfront-distribution-optional-lambdas"

    enabled = true
    aliases = ["${var.domain}"]
    http_version = "http2"
    is_ipv6_enabled = true

    origin_domain_name = "${aws_s3_bucket.gatsby_static_bucket.website_endpoint}"
    custom_origin_http_port = "80"
    custom_origin_https_port = "443"
    custom_origin_protocol_policy = "http-only"
    custom_origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]

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
    originrequest_lambda_enabled = "${var.cloudfront_lambda_originrequest_enabled}"
    originrequest_lambda_qualifiedarn = "${var.cloudfront_lambda_originrequest_qualifiedarn}"
    originrequest_lambda_includebody = false
    originresponse_lambda_enabled = "${var.cloudfront_lambda_originresponse_enabled}"
    originresponse_lambda_qualifiedarn = "${var.cloudfront_lambda_originresponse_qualifiedarn}"
    originresponse_lambda_includebody = false
    viewerresponse_lambda_enabled = "${var.cloudfront_lambda_viewerresponse_enabled}"
    viewerresponse_lambda_qualifiedarn = "${var.cloudfront_lambda_viewerresponse_qualifiedarn}"
    viewerresponse_lambda_includebody = false
}