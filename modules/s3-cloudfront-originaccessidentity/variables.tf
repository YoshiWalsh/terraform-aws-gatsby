variable "domain" {
    type = "string"
    description = "The domain name to host the website at."
}

variable "acm_certificate_arn" {
    type = "string"
    default = ""
    description = "The ARN of the ACM certificate to use when serving pages via HTTPS. Optional, provide either this or iam_certificate_id if you wish to enable HTTPS."
}

variable "iam_certificate_id" {
    type ="string"
    default = ""
    description = "The ID of the IAM certificate to use when serving pages via HTTPS. Optional, provide either this or acm_certificate_arn if you wish to enable HTTPS."
}

variable "https_minimum_protocol_version" {
    type = "string"
    default = "TLSv1.1_2016" # Amazon's recommendation as of 2019-03-21
    description = "Controls which protocols and ciphers visitors are allowed to use. For more details, see https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html#secure-connections-supported-ciphers"
}

variable "https_support_non_sni" {
    type = "string"
    default = "false" # Amazon's recommendation, and likely to stay Amazon's recommendation forever
    description = "Adds support for browsers which don't support SNI. Involves extra costs. Leaving this false is strongly recommended."
}

variable "https_redirect" {
    type = "string"
    default = "true"
    description = "If true, redirects HTTP requests to HTTPS. If false, allows both HTTP and HTTPS requests."
}

variable "cache_all_objects" {
    type = "string"
    default = "false"
    description = "Forces caching for all objects, including HTML files. Slightly improves load-times. If this is enabled, you MUST create a CloudFront Invalidation every time you update your site."
}

variable "index_document" {
    type = "string"
    default = "index.html"
    description = "The name of the index document within each directory."
}

variable "error_document" {
    type = "string"
    default = "404.html"
    description = "The path to the page that should be returned if the user requests a non-existent key."
}