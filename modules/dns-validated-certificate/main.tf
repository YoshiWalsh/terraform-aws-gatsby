terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0.0"
            configuration_aliases = [ aws, aws.certificates ]
        }
    }
}

locals {
    domains_and_ancestors = {
        for domain in var.domains :
        domain => [
            for i, s in split(".", domain) :
            join(
                ".",
                concat(
                    slice(
                        split(
                            ".",
                            domain
                        ),
                        i,
                        length(split(
                            ".",
                            domain
                        ))
                    ),
                    [""]
                )
            )
        ]
    }
    domain_zone_name = {
        for domain, domain_and_ancestors in local.domains_and_ancestors :
        domain => try(coalesce([
            for i, d in domain_and_ancestors :
            contains(var.route53_zone_names, d) ? d : null
        ]...), null)
    }
    domains_missing_zones = [
        for domain, zone in local.domain_zone_name :
        domain
        if zone == null
    ]
    zones = toset(values(local.domain_zone_name))
}

check "domain_zones" {
    assert {
        condition = length(local.domains_missing_zones) == 0
        error_message = "route53_zone_names is missing an entry for one or more specified domains: ${join(", ", local.domains_missing_zones)}"
    }
}

data "aws_route53_zone" "zones" {
    for_each = local.zones

    name = each.key
    private_zone = false
}

resource "aws_acm_certificate" "cert" {
    provider = aws.certificates
    domain_name = var.domains[0]
    subject_alternative_names = slice(var.domains, 1, length(var.domains))
    validation_method = "DNS"

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_route53_record" "validation_records" {
    provider = aws

    for_each = {
        for domain_validation_option in aws_acm_certificate.cert.domain_validation_options :
        domain_validation_option.domain_name => domain_validation_option
    }

    name = each.value.resource_record_name
    type = each.value.resource_record_type
    records = [each.value.resource_record_value]
    zone_id = data.aws_route53_zone.zones[lookup(local.domain_zone_name, each.key, null)].zone_id
    ttl = 60
    allow_overwrite = true
}

resource "aws_acm_certificate_validation" "validation" {
    provider        = aws.certificates

    certificate_arn = aws_acm_certificate.cert.arn

    validation_record_fqdns = [
        for record in aws_route53_record.validation_records :
        record.fqdn
    ]
}