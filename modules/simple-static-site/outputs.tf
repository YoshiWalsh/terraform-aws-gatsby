output "static_s3_bucket_name" {
    value = module.staticwebsite.static_s3_bucket_name
}

output "cf_distribution_domain" {
    value = module.staticwebsite.cf_distribution_domain
}

output "cf_distribution_zone_id" {
    value = module.staticwebsite.cf_distribution_zone_id
}

output "cf_distribution_id" {
    value = module.staticwebsite.cf_distribution_id
}