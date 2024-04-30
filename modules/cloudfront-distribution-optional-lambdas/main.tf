resource "aws_cloudfront_distribution" "distribution" {
    enabled = var.enabled
    aliases = var.aliases

    http_version = var.http_version
    is_ipv6_enabled = var.is_ipv6_enabled
    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    origin {
        origin_id = "main"
        domain_name = var.origin_domain_name

        dynamic s3_origin_config {
            for_each = var.origin_access_identity != "" ? [true] : []

            origin_access_identity = var.origin_access_identity
        }

        dynamic custom_origin_config {
            for_each = var.origin_access_identity == "" ? [true] : []

            http_port = var.custom_origin_http_port
            https_port = var.custom_origin_https_port
            origin_protocol_policy = var.custom_origin_protocol_policy
            origin_ssl_protocls = var.custom_origin_ssl_protocols
        }
    }

    viewer_certificate {
        acm_certificate_arn = var.acm_certificate_arn
        iam_certificate_id = var.iam_certificate_id
        minimum_protocol_version = var.minimum_protocol_version
        ssl_support_method = var.ssl_support_method
    }

    default_cache_behavior {
        target_origin_id = "main"
        min_ttl = var.min_ttl
        default_ttl = var.default_ttl
        max_ttl = var.max_ttl
        compress = var.compress
        viewer_protocol_policy = var.viewer_protocol_policy
        allowed_methods = var.allowed_methods
        cached_methods = var.cached_methods
        forwarded_values {
            cookies {
                forward = var.forward_cookies
            }
            query_string = var.forward_query
        }

        dynamic lambda_function_association {
            for_each = var.viewerrequest_lambda_enabled ? [true] : []

            event_type = "viewer-request"
            lambda_arn = var.viewerrequest_lambda_qualifiedarn
            include_body = var.viewerrequest_lambda_includebody
        }

        dynamic lambda_function_association {
            for_each = var.originrequest_lambda_enabled

            event_type = "origin-request"
            lambda_arn = var.originrequest_lambda_qualifiedarn
            include_body = var.originrequest_lambda_includebody
        }

        dynamic lambda_function_association {
            for_each = var.originresponse_lambda_enabled

            event_type = "origin-response"
            lambda_arn = var.originresponse_lambda_qualifiedarn
            include_body = var.originresponse_lambda_includebody
        }

        dynamic lambda_function_association {
            for_each = var.viewerresponse_lambda_enabled ? [true] : []

            event_type = "viewer-response"
            lambda_arn = var.viewerresponse_lambda_qualifiedarn
            include_body = var.viewerresponse_lambda_includebody
        }
    }

    dynamic custom_error_response {
        for_each = var.custom_response_403_enabled ? [true] : []

        error_code = 403
        response_type = var.custom_response_403_code
        response_page_path = var.custom_response_403_page_path
    }

    dynamic custom_error_response {
        for_each = var.custom_response_404_enabled ? [true] : []

        error_code = 404
        response_type = var.custom_response_404_code
        response_page_path = var.custom_response_404_page_path
    }
}