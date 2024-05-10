provider "aws" {
    region = var.region
}

provider "aws" {
    alias = "certificates"
    region = "us-east-1"
}




module "s3_cf_staticwebsitehosting" {
    source = "./modules/simple-static-site"

    providers = {
        aws = aws
        aws.certificates = aws.certificates
    }

    domain = var.domain

    domain_route53_zones = var.domain_route53_zones

    redirect_sources = var.redirect_sources

    use_private_bucket = true
}