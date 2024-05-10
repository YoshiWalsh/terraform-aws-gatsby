variable domains {
    type = list
    description = "Domains (including alternative names) to request certificates for."
}

variable route53_zone_names {
    type = list
    description = "List of zone names of all R53 zones which we need to create domains in. Zone names must include the trailing '.'"
}