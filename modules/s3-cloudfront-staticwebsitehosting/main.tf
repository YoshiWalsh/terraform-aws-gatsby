terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0.0"
            configuration_aliases = [ aws, aws.certificates ]
        }
    }
}

locals {
    domains_and_ancestors = {
        for domain in var.domains :
        domain => [
            for i, s in split(".", domain) :
            join(
                ".",
                concat(
                    slice(
                        split(
                            ".",
                            domain
                        ),
                        i,
                        length(split(
                            ".",
                            domain
                        ))
                    ),
                    [""]
                )
            )
        ]
    }
    domain_zone_name = {
        for domain, domain_and_ancestors in local.domains_and_ancestors :
        domain => try(coalesce([
            for i, d in domain_and_ancestors :
            contains(var.domain_route53_zones, d) ? d : null
        ]...), null)
    }
    domains_missing_zones = [
        for domain, zone in local.domain_zone_name :
        domain
        if zone == null
    ]
    zones = values(local.domain_zone_name)
}

check "domain_zones" {
    assert {
        condition = length(local.domains_missing_zones) == 0
        error_message = "domain_route53_zones is missing an entry for one or more specified domains: ${join(", ", local.domains_missing_zones)}"
    }
}

locals {
    domains_needing_certs = var.issue_certificate ? [
        for domain in var.domains :
        domain
        if lookup(var.acm_certificate_arns, domain, null) == null && lookup(var.iam_certificate_ids, domain, null) == null
    ] : []
    domain_zones_needing_certs = {
        for domain in local.domains_needing_certs :
        domain => lookup(local.domain_zone_name, domain, null)
    }
    zones_needing_certs = values(local.domain_zones_needing_certs)
    all_zones_with_domains_needing_certs = {
        for zone in local.zones_needing_certs :
        zone => [
            for domain, zone_name in local.domain_zones_needing_certs :
            domain
            if zone == zone_name
        ]
    }
    zones_with_domains_needing_certs = {
        for zone, domains in local.all_zones_with_domains_needing_certs :
        zone => domains
        if length(domains) > 0
    }

    needs_r53 = (length(local.domains_needing_certs) > 0) || var.create_dns_records

    domain = var.domains[0]
}

resource "aws_s3_bucket" "static_bucket" {
    count = var.existing_s3_bucket == null ? 1 : 0

    bucket_prefix = "${replace(substr(local.domain, 0, 36), ".", "-")}-"
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
    
    comment = local.domain
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


data "aws_route53_zone" "zones" {
    for_each = local.needs_r53 ? toset(local.zones) : toset([])

    name = each.key
    private_zone = false
}

module "cert" {
    for_each = local.zones_with_domains_needing_certs

    source = "github.com/azavea/terraform-aws-acm-certificate?ref=4.0.0"

    providers = {
        aws.acm_account = aws.certificates
        aws.route53_account = aws
    }

    domain_name = each.value[0]
    subject_alternative_names = slice(each.value, 1, length(each.value))
    hosted_zone_id = lookup(data.aws_route53_zone.zones, each.key, null).zone_id
    validation_record_ttl = "60"
}

locals {
    https = length(keys(var.acm_certificate_arns)) > 0 || length(keys(var.iam_certificate_ids)) > 0 || var.issue_certificate
    deploy_originrequest = var.use_private_bucket
    deploy_originresponse = var.use_private_bucket || var.preserve_query_string_on_redirect
    deploy_lambdas = local.deploy_originrequest || local.deploy_originresponse
}

resource "aws_iam_role" "lambda_role" {
    count = local.deploy_lambdas ? 1 : 0
    
    name = "${replace("${local.domain}", ".", "-")}_lambda"

    assume_role_policy = file("${path.module}/data/lambda_role_assumepolicy.json")
}

resource "aws_iam_role_policy" "lambda_role_policy" {
    count = local.deploy_lambdas ? 1 : 0
    
    name = "${replace("${local.domain}", ".", "-")}_lambda"
    role = aws_iam_role.lambda_role[0].id

    policy = file("${path.module}/data/lambda_role_policy.json")
}

data "template_file" "originrequest_lambda_template" {
    count = local.deploy_originrequest ? 1 : 0
    
    template = file("${path.module}/data/originrequest_lambda/index.js.tpl")
    vars = {
        index_document = var.index_document
        passthrough = var.cloudfront_lambda_originrequest_enabled ? var.cloudfront_lambda_originrequest_qualifiedarn : ""
    }
}

data "archive_file" "originrequest_lambda_archive" {
    count = local.deploy_originrequest ? 1 : 0
    
    type = "zip"
    output_path = "${path.module}/artifacts/${replace("${local.domain}", ".", "-")}originrequest_lambda.zip"

    source {
        filename = "index.js"
        content = data.template_file.originrequest_lambda_template[0].rendered
    }
}

resource "aws_lambda_function" "originrequest_lambda" {
    count = local.deploy_originrequest ? 1 : 0

    provider = aws.certificates
    
    filename = "${path.module}/artifacts/${replace("${local.domain}", ".", "-")}originrequest_lambda.zip"
    function_name = "${replace("${local.domain}", ".", "-")}_originrequest"
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
    count = local.deploy_originresponse ? 1 : 0
    
    template = file("${path.module}/data/originresponse_lambda/index.js.tpl")
    vars = {
        index_document = var.index_document
        passthrough = var.cloudfront_lambda_originresponse_enabled ? var.cloudfront_lambda_originresponse_qualifiedarn : ""
        preserveRedirectQuery = var.preserve_query_string_on_redirect ? "true" : "false"
        emulateStaticWebsiteHosting = var.use_private_bucket ? "true" : "false"
    }
}

data "archive_file" "originresponse_lambda_archive" {
    count = local.deploy_originresponse ? 1 : 0
    
    type = "zip"
    output_path = "${path.module}/artifacts/${replace("${local.domain}", ".", "-")}originresponse_lambda.zip"

    source {
        filename = "index.js"
        content = data.template_file.originresponse_lambda_template[0].rendered
    }
}

resource "aws_lambda_function" "originresponse_lambda" {
    count = local.deploy_originresponse ? 1 : 0

    provider = aws.certificates
    
    filename = "${path.module}/artifacts/${replace("${local.domain}", ".", "-")}originresponse_lambda.zip"
    function_name = "${replace("${local.domain}", ".", "-")}_originresponse"
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
    aliases = var.domains

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

    dynamic viewer_certificate {
        for_each = data.aws_route53_zone.zones

        content {
            acm_certificate_arn = viewer_certificate.value.arn
            minimum_protocol_version = var.https_minimum_protocol_version
            ssl_support_method = var.https_support_non_sni ? "vip" : "sni-only"
        }
    }

    dynamic viewer_certificate {
        for_each = var.acm_certificate_arns

        content {
            acm_certificate_arn = viewer_certificate.value
            minimum_protocol_version = var.https_minimum_protocol_version
            ssl_support_method = var.https_support_non_sni ? "vip" : "sni-only"
        }
    }

    dynamic viewer_certificate {
        for_each = var.iam_certificate_ids

        content {
            iam_certificate_id = viewer_certificate.value
            minimum_protocol_version = var.https_minimum_protocol_version
            ssl_support_method = var.https_support_non_sni ? "vip" : "sni-only"
        }
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
            query_string = var.preserve_query_string_on_redirect || var.pass_query_string
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

        # User-supplied origin functions can only be used directly when we don't need them ourselves
        dynamic lambda_function_association {
            for_each = (!local.deploy_originrequest && var.cloudfront_lambda_originrequest_enabled) ? [true] : []

            content {
                event_type = "origin-request"
                lambda_arn = var.cloudfront_lambda_originrequest_qualifiedarn
                include_body = false
            }
        }

        dynamic lambda_function_association {
            for_each = (!local.deploy_originresponse && var.cloudfront_lambda_originresponse_enabled) ? [true] : []

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
            for_each = local.deploy_originrequest ? [true] : []

            content {
                event_type = "origin-request"
                lambda_arn = aws_lambda_function.originrequest_lambda[0].qualified_arn
                include_body = false
            }
        }

        dynamic lambda_function_association {
            for_each = local.deploy_originresponse ? [true] : []

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
    for_each = var.create_dns_records ? local.domain_zone_name : []

    zone_id = data.aws_route53_zone.zones[each.value].id
    name = each.key
    type = "A"
    
    alias {
        name = aws_cloudfront_distribution.static_distribution.domain_name
        zone_id = aws_cloudfront_distribution.static_distribution.hosted_zone_id
        evaluate_target_health = false
    }
}

resource "aws_route53_record" "main_dns_ipv6" {
    for_each = var.create_dns_records ? local.domain_zone_name : []

    zone_id = data.aws_route53_zone.zones[each.value].id
    name = each.key
    type = "AAAA"
    
    alias {
        name = aws_cloudfront_distribution.static_distribution.domain_name
        zone_id = aws_cloudfront_distribution.static_distribution.hosted_zone_id
        evaluate_target_health = false
    }
}