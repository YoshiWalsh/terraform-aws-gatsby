terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0.0"
            configuration_aliases = [ aws, aws.certificates ]
        }
    }
}

resource "random_id" "environment_identifier" {
    keepers = {
    }

    byte_length = 8
}

module "staticwebsite" {
    source = "../s3-cloudfront-staticwebsitehosting"

    providers = {
        aws = aws
        aws.certificates = aws.certificates
    }

    domains = [var.domain]
    cache_all_objects = true
    index_document = "index.html"
    error_document = "404.html"
    cloudfront_lambda_viewerrequest_enabled = var.cloudfront_lambda_viewerrequest_qualifiedarn != null
    cloudfront_lambda_viewerrequest_qualifiedarn = var.cloudfront_lambda_viewerrequest_qualifiedarn
    cloudfront_lambda_originrequest_enabled = var.cloudfront_lambda_originrequest_qualifiedarn != null
    cloudfront_lambda_originrequest_qualifiedarn = var.cloudfront_lambda_originrequest_qualifiedarn
    cloudfront_lambda_originresponse_enabled = var.cloudfront_lambda_originresponse_qualifiedarn != null
    cloudfront_lambda_originresponse_qualifiedarn = var.cloudfront_lambda_originresponse_qualifiedarn
    cloudfront_lambda_viewerresponse_enabled = var.cloudfront_lambda_viewerresponse_qualifiedarn != null
    cloudfront_lambda_viewerresponse_qualifiedarn = var.cloudfront_lambda_viewerresponse_qualifiedarn
    issue_certificate = true
    domain_route53_zones =  var.domain_route53_zones
    create_dns_records = true

    use_private_bucket = var.use_private_bucket
    preserve_query_string_on_redirect = true
}

resource "aws_s3_bucket" "redirect_bucket" {
    count = length(var.redirect_sources) > 0 ? 1 : 0

    bucket_prefix = "${replace(substr(var.domain, 0, 33), ".", "-")}-rdr"
}

resource "aws_s3_bucket_website_configuration" "static_website_configuration" {
    count = length(var.redirect_sources) > 0 ? 1 : 0

    bucket = aws_s3_bucket.redirect_bucket[0].id

    redirect_all_requests_to {
        protocol = "https"
        host_name = var.domain
    }
}

resource "aws_s3_bucket_public_access_block" "static_bucket_publicaccess" {
    count = length(var.redirect_sources) > 0 ? 1 : 0

    bucket = aws_s3_bucket.redirect_bucket[0].id

    block_public_acls = false
    block_public_policy = false
    ignore_public_acls = false
    restrict_public_buckets = false
}

module "redirect" {
    count = length(var.redirect_sources) > 0 ? 1 : 0

    source = "../s3-cloudfront-staticwebsitehosting"

    providers = {
        aws = aws
        aws.certificates = aws.certificates
    }

    domains = var.redirect_sources
    existing_s3_bucket = coalesce(aws_s3_bucket.redirect_bucket[0].id, "NOTUSED") # Using coalesce here allows us to guarantee to Terraform that this value will not be null
    cache_all_objects = true

    issue_certificate = true
    domain_route53_zones =  var.domain_route53_zones
    create_dns_records = true
    use_private_bucket = false
    pass_query_string = true
    preserve_query_string_on_redirect = false # Unnecessary because S3 Static Website Hosting redirect buckets do this automatically
}