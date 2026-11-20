output "bucket_a" {
  value = local.bucket_a
}

output "bucket_b" {
  value = local.bucket_b
}

output "app_url" {
  value = var.deploy_app ? "http://${aws_instance.app[0].public_ip}:3000" : null
}
