module "staticwebsite" {
    source = "../s3-cloudfront-staticwebsitehosting"

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
    use_private_bucket = true
}