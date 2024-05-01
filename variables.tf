variable "domain" {
    type = string
    description = "The domain name to host the website at."
}

variable "domain_route53_zones" {
    type = list
    default = []
    description = "List of zone names of all R53 zones which we need to create domains in. Zone names must include the trailing '.'"
}

variable "region" {
    type = string
    description = "The AWS region to create resources in."
    default = "us-east-1"
}

variable "redirect_sources" {
    type = list
    default = []
    description = "A list of additional domains which will be configured to redirect to this domain."
}