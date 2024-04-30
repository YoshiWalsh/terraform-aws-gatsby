terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0.0"
            configuration_aliases = [ aws, aws.certificates ]
        }
    }
}

module "staticwebsite" {
    source = "../s3-cloudfront-staticwebsitehosting"

    providers = {
        aws = aws
        aws.certificates = aws.certificates
    }

    domain = var.domain
    acm_certificate_arn = var.acm_certificate_arn
    iam_certificate_id = var.iam_certificate_id
    https_minimum_protocol_version = var.https_minimum_protocol_version
    https_support_non_sni = var.https_support_non_sni
    https_redirect = var.https_redirect
    cache_all_objects = var.cache_all_objects
    error_document = var.error_document
    cloudfront_lambda_viewerrequest_enabled = var.cloudfront_lambda_viewerrequest_enabled
    cloudfront_lambda_viewerrequest_qualifiedarn = var.cloudfront_lambda_viewerrequest_qualifiedarn
    cloudfront_lambda_originrequest_enabled = var.cloudfront_lambda_originrequest_enabled
    cloudfront_lambda_originrequest_qualifiedarn = var.cloudfront_lambda_originrequest_qualifiedarn
    cloudfront_lambda_originresponse_enabled = var.cloudfront_lambda_originresponse_enabled
    cloudfront_lambda_originresponse_qualifiedarn = var.cloudfront_lambda_originresponse_qualifiedarn
    cloudfront_lambda_viewerresponse_enabled = var.cloudfront_lambda_viewerresponse_enabled
    cloudfront_lambda_viewerresponse_qualifiedarn = var.cloudfront_lambda_viewerresponse_qualifiedarn
    issue_certificate = var.issue_certificate
    domain_route53_zones =  var.domain_route53_zones
    create_dns_records = var.create_dns_records

    use_private_bucket = true
}