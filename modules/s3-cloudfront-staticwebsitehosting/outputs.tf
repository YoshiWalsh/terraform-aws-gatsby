output "static_s3_bucket_name" {
    value = try(aws_s3_bucket.static_bucket[0].id, var.existing_s3_bucket)
}

output "cf_distribution_domain" {
    value = aws_cloudfront_distribution.static_distribution.domain_name
}

output "cf_distribution_zone_id" {
    value = aws_cloudfront_distribution.static_distribution.hosted_zone_id
}

output "cf_oai_arn" {
    value = try(aws_cloudfront_origin_access_identity.oai[0].iam_arn, null)
}