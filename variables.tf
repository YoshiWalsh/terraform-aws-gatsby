variable "domain" {
    type = "string"
    description = "The domain name to host the website at."
}

variable "domain_route53_zones" {
    type = "map"
    description = "Used to specify the existing Route53 zones to create each domain within. R53 zone names must include the trailing '.'"
}

variable "region" {
    type = "string"
    description = "The AWS region to create resources in."
    default = "us-east-1"
}