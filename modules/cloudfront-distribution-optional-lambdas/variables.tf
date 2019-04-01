variable "enabled" {
    type = "string"
}

variable "aliases" {
    type = "list"
    default = []
}

variable "http_version" {
    type = "string"
    default = "http2"
}

variable "is_ipv6_enabled" {
    type = "string"
    default = true
}

variable "origin_domain_name" {
    type = "string"
}

variable "origin_access_identity" {
    type = "string"
    default = ""
}

variable "custom_origin_http_port" {
    type = "string"
    default = "80"
}

variable "custom_origin_https_port" {
    type = "string"
    default = "443"
}

variable "custom_origin_protocol_policy" {
    type = "string"
    default = "https-only"
}

variable "custom_origin_ssl_protocols" {
    type = "list"
    default = ["TLSv1", "TLSv1.1", "TLSv1.2"]
}

variable "acm_certificate_arn" {
    type = "string"
    default = ""
}

variable "iam_certificate_id" {
    type = "string"
    default = ""
}

variable "minimum_protocol_version" {
    type = "string"
    default = "TLSv1.1_2016"
}

variable "ssl_support_method" {
    type = "string"
    default = "sni-only"
}

variable "min_ttl" {
    type = "string"
    default = 0
}

variable "default_ttl" {
    type = "string"
    default = 0
}

variable "max_ttl" {
    type = "string"
    default = 31557600 # 1 year
}

variable "compress" {
    type = "string"
    default = false
}

variable "viewer_protocol_policy" {
    type = "string"
    default = "redirect-to-https"
}

variable "allowed_methods" {
    type = "list"
    default = ["GET", "HEAD", "OPTIONS"]
}

variable "cached_methods" {
    type = "list"
    default = ["GET", "HEAD"]
}

variable "forward_cookies" {
    type = "string"
    default = "none"
}

variable "forward_query" {
    type = "string"
    default = false
}

variable "custom_response_403_enabled" {
    type = "string"
    default = false
}

variable "custom_response_403_code" {
    type = "string"
    default = 403
}

variable "custom_response_403_page_path" {
    type = "string"
    default = ""
}

variable "custom_response_404_enabled" {
    type = "string"
    default = false
}

variable "custom_response_404_code" {
    type = "string"
    default = 404
}

variable "custom_response_404_page_path" {
    type = "string"
    default = ""
}

variable "viewerrequest_lambda_enabled" {
    type = "string"
    default = false
}

variable "viewerrequest_lambda_qualifiedarn" {
    type = "string"
    default = ""
}

variable "viewerrequest_lambda_includebody" {
    type = "string"
    default = false
}

variable "originrequest_lambda_enabled" {
    type = "string"
    default = false
}

variable "originrequest_lambda_qualifiedarn" {
    type = "string"
    default = ""
}

variable "originrequest_lambda_includebody" {
    type = "string"
    default = false
}

variable "originresponse_lambda_enabled" {
    type = "string"
    default = false
}

variable "originresponse_lambda_qualifiedarn" {
    type = "string"
    default = ""
}

variable "originresponse_lambda_includebody" {
    type = "string"
    default = false
}

variable "viewerresponse_lambda_enabled" {
    type = "string"
    default = false
}

variable "viewerresponse_lambda_qualifiedarn" {
    type = "string"
    default = ""
}

variable "viewerresponse_lambda_includebody" {
    type = "string"
    default = false
}