variable "domain" {
    type = string
    description = "The domain name to host the website at."
}

variable "acm_certificate_arn" {
    type = string
    default = ""
    description = "The ARN of the ACM certificate to use when serving pages via HTTPS."
}

variable "iam_certificate_id" {
    type = string
    default = ""
    description = "The ID of the IAM certificate to use when serving pages via HTTPS."
}

variable "issue_certificate" {
    type = bool
    default = true
    description = "If set and no existing certificate is passed, a new certificate will be requested using DNS vallidation. Does nothing if acm_certificate_arn or iam_certificate_id are specified."
}

variable "https_minimum_protocol_version" {
    type = string
    default = "TLSv1.1_2016" # Amazon's recommendation as of 2019-03-21
    description = "Controls which protocols and ciphers visitors are allowed to use. For more details, see https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html#secure-connections-supported-ciphers"
}

variable "https_support_non_sni" {
    type = string
    default = false # Amazon's recommendation, and likely to stay Amazon's recommendation forever
    description = "Adds support for browsers which don't support SNI. Involves extra costs. Leaving this false is strongly recommended."
}

variable "https_redirect" {
    type = string
    default = "true"
    description = "If true, redirects HTTP requests to HTTPS. If false, allows both HTTP and HTTPS requests."
}

variable "cache_all_objects" {
    type = string
    default = false
    description = "Forces caching for all objects, including HTML files. Slightly improves load-times. If this is enabled, you MUST create a CloudFront Invalidation every time you update your site."
}

variable "index_document" {
    type = string
    default = "index.html"
    description = "The name of the index document within each directory."
}

variable "error_document" {
    type = string
    default = "404.html"
    description = "The path to the page that should be returned if the user requests a non-existent key."
}

variable "cloudfront_lambda_viewerrequest_enabled" {
    type = string
    default = false
    description = "Whether or not to enable the viewer request Lambda@Edge function."
}

variable "cloudfront_lambda_viewerrequest_qualifiedarn" {
    type = string
    default = ""
    description = "A list of qualified ARNs for published Lambda functions that should be registered with the CloudFront distribution's viewer request event."
}

variable "cloudfront_lambda_originrequest_enabled" {
    type = string
    default = false
    description = "Whether or not to enable the origin request Lambda@Edge function."
}

variable "cloudfront_lambda_originrequest_qualifiedarn" {
    type = string
    default = ""
    description = "A list of qualified ARNs for published Lambda functions that should be registered with the CloudFront distribution's origin request event."
}

variable "cloudfront_lambda_originresponse_enabled" {
    type = string
    default = false
    description = "Whether or not to enable the origin response Lambda@Edge function."
}

variable "cloudfront_lambda_originresponse_qualifiedarn" {
    type = string
    default = ""
    description = "A list of qualified ARNs for published Lambda functions that should be registered with the CloudFront distribution's origin response event."
}

variable "cloudfront_lambda_viewerresponse_enabled" {
    type = string
    default = false
    description = "Whether or not to enable the viewer response Lambda@Edge function."
}

variable "cloudfront_lambda_viewerresponse_qualifiedarn" {
    type = string
    default = ""
    description = "A list of qualified ARNs for published Lambda functions that should be registered with the CloudFront distribution's viewer response event."
}

variable "use_private_bucket" {
    type = bool
    default = false
    description = "Uses an Origin Access Identity and Lambda@Edge in order to replicate S3 Static Website Hosting functionality but with a private bucket."
}

variable "existing_s3_bucket" {
    type = string
    default = null
    description = "If specified, the module will not create an S3 bucket and will instead just create a CloudFront distribution linking to it. If used in conjunction with use_private_bucket, you are responsible for adding the OAI ARN from the output into your bucket's policy."
}

variable "domain_route53_zones" {
    type = map
    default = {}
    description = "Used to specify the existing Route53 zones to create each domain within. R53 zone names must include the trailing '.'"
}