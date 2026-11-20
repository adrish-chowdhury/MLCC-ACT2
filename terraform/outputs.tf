output "bucket_a" {
  value = local.bucket_a
}

output "bucket_b" {
  value = local.bucket_b
}

output "dashboard_url" {
  value = aws_lambda_function_url.api.function_url
}

output "access_code" {
  value     = random_password.access_code.result
  sensitive = true
}
