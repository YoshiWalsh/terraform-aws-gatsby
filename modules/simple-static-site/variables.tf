variable "domain" {
    type = string
    description = "The domain name to host the website at."
    nullable = false
}

variable "cloudfront_lambda_viewerrequest_qualifiedarn" {
    type = string
    default = null
    description = "A list of qualified ARNs for published Lambda functions that should be registered with the CloudFront distribution's viewer request event."
}

variable "cloudfront_lambda_originrequest_qualifiedarn" {
    type = string
    default = null
    description = "A list of qualified ARNs for published Lambda functions that should be registered with the CloudFront distribution's origin request event."
}

variable "cloudfront_lambda_originresponse_qualifiedarn" {
    type = string
    default = null
    description = "A list of qualified ARNs for published Lambda functions that should be registered with the CloudFront distribution's origin response event."
}

variable "cloudfront_lambda_viewerresponse_qualifiedarn" {
    type = string
    default = null
    description = "A list of qualified ARNs for published Lambda functions that should be registered with the CloudFront distribution's viewer response event."
}

variable "domain_route53_zones" {
    type = map
    default = {}
    description = "Used to specify the existing Route53 zones to create each domain within. R53 zone names must include the trailing '.'"
    nullable = false
}

variable "redirect_sources" {
    type = list
    default = []
    description = "A list of additional domains which will be configured to redirect to this domain."
    nullable = false
}

variable "use_private_bucket" {
    type = bool
    default = false
    description = "Uses an Origin Access Identity and Lambda@Edge in order to replicate S3 Static Website Hosting functionality but with a private bucket."
    nullable = false
}