resource "aws_s3_bucket" "gatsby_static_bucket" {
    bucket_prefix = "${var.domain}-"

    website {
        index_document = "index.html"
        error_document = "404.html"
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

resource "aws_cloudfront_distribution" "gatsby_static_distribution" {
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
        domain_name = "${aws_s3_bucket.gatsby_static_bucket.website_endpoint}"

        custom_origin_config {
            http_port = "80"
            https_port = "443"
            origin_protocol_policy = "http-only"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }

    viewer_certificate {
        acm_certificate_arn = "${var.acm_certificate_arn}"
        iam_certificate_id = "${var.iam_certificate_id}"
        minimum_protocol_version = "${var.https_minimum_protocol_version}"
        ssl_support_method = "${var.https_support_non_sni == "true" ? "vip" : "sni-only"}"
    }

    default_cache_behavior {
        target_origin_id = "main"
        min_ttl = "${var.cache_all_objects == "true" ? 31536000 : 0}"
        default_ttl = "${var.cache_all_objects == "true" ? 31536000 : 0}"
        max_ttl = 31536000
        compress = true
        viewer_protocol_policy = "${var.https_redirect == "true" ? "redirect-to-https" : "allow-all"}"
        allowed_methods = ["GET", "HEAD", "OPTIONS"]
        cached_methods = ["GET", "HEAD", "OPTIONS"]
        forwarded_values {
            cookies {
                forward = "none"
            }
            query_string = false
        }
    }
}