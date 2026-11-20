output "bucket_a" {
  value = local.bucket_a
}

output "bucket_b" {
  value = local.bucket_b
}

output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}
