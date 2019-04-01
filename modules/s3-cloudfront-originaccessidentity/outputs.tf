output "static_s3_bucket_name" {
    value = "${aws_s3_bucket.gatsby_static_bucket.id}"
}

output "cf_distribution_domain" {
    value = "${module.gatsby_static_distribution.domain_name}"
}

output "cf_distribution_zone_id" {
    value = "${module.gatsby_static_distribution.hosted_zone_id}"
}