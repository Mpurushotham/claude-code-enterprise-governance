# Evidence-sink infra only. Identity, seats, and inference live in the Claude
# Enterprise plan (SSO/SCIM via the admin console) — nothing to provision here.
variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "audit_bucket_name" {
  type    = string
  default = "abc-claude-audit-evidence"
}

variable "access_log_bucket_name" {
  description = "Existing bucket that receives S3 server access logs for the evidence bucket (e.g. the org log-archive bucket)."
  type        = string
}

variable "noncurrent_retention_days" {
  description = "Days to keep superseded (noncurrent) evidence object versions."
  type        = number
  default     = 365
}
