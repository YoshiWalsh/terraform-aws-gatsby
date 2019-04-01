resource "aws_cloudfront_distribution" "distribution_permutation" {
    /* CONDITION */

    enabled = "${var.enabled}"
    aliases = "${var.aliases}"

    http_version = "${var.http_version}"
    is_ipv6_enabled = "${var.is_ipv6_enabled}"
    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    origin {
        origin_id = "main"
        domain_name = "${var.origin_domain_name}"

        /* ORIGIN SLOT */
    }

    viewer_certificate {
        acm_certificate_arn = "${var.acm_certificate_arn}"
        iam_certificate_id = "${var.iam_certificate_id}"
        minimum_protocol_version = "${var.minimum_protocol_version}"
        ssl_support_method = "${var.ssl_support_method}"
    }

    default_cache_behavior {
        target_origin_id = "main"
        min_ttl = "${var.min_ttl}"
        default_ttl = "${var.default_ttl}"
        max_ttl = "${var.max_ttl}"
        compress = "${var.compress}"
        viewer_protocol_policy = "${var.viewer_protocol_policy}"
        allowed_methods = "${var.allowed_methods}"
        cached_methods = "${var.cached_methods}"
        forwarded_values {
            cookies {
                forward = "${var.forward_cookies}"
            }
            query_string = "${var.forward_query}"
        }

        /* LAMBDA SLOT */
    }

    /* CUSTOM RESPONSE SLOT */
}