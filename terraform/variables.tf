variable "region_a" {
  type    = string
  default = "us-east-1"
}

variable "region_b" {
  type    = string
  default = "us-west-2"
}

variable "bucket_prefix" {
  type        = string
  default     = "mlcc-act2"
  description = "Buckets become <prefix>-a-<account-id> and <prefix>-b-<account-id>"
}

variable "healing_enabled" {
  type        = bool
  default     = true
  description = "Set false (and apply) BEFORE terraform destroy, otherwise the healer recreates what you delete."
}

variable "reconcile_schedule" {
  type    = string
  default = "rate(5 minutes)"
}

variable "site_region" {
  type    = string
  default = "us-east-1"
}

variable "site_dist_dir" {
  type        = string
  default     = "../dist"
  description = "Output of `npm run build` (run it first)."
}
