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

# ---- optional app host (EC2) ----
variable "deploy_app" {
  type    = bool
  default = true
}

variable "app_region" {
  type    = string
  default = "us-east-1"
}

variable "repo_url" {
  type    = string
  default = "https://github.com/adrish-chowdhury/MLCC-ACT2.git"
}

variable "gemini_api_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "allowed_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Who may reach the app on port 3000. Restrict to your IP/32 for testing."
}
