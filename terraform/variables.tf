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
