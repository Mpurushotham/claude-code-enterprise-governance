# Guardrail evidence: KMS-encrypted, versioned, access-logged, Athena-queryable.
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "audit" {
  description         = "ABC Claude guardrail evidence"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.audit_key.json
}

# Explicit equivalent of the default key policy: key use is governed by IAM in
# this account, so the key is never orphaned and no principal is granted here.
data "aws_iam_policy_document" "audit_key" {
  # In a key policy "*" means "this key" and the root principal delegates to IAM,
  # so these IAM-policy checks do not apply.
  # checkov:skip=CKV_AWS_109:Key policy; resource "*" is the key itself.
  # checkov:skip=CKV_AWS_111:Key policy; resource "*" is the key itself.
  # checkov:skip=CKV_AWS_356:Key policy; resource "*" is the key itself.
  statement {
    sid       = "EnableIAMPolicies"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_s3_bucket" "audit" {
  # checkov:skip=CKV_AWS_144:Single-region evidence store by design; versioning + KMS cover integrity.
  # checkov:skip=CKV2_AWS_62:No downstream consumers; evidence is queried on demand via Athena.
  bucket = var.audit_bucket_name
}

resource "aws_s3_bucket_logging" "audit" {
  bucket        = aws_s3_bucket.audit.id
  target_bucket = var.access_log_bucket_name
  target_prefix = "s3-access/${var.audit_bucket_name}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }

  rule {
    id     = "expire-athena-results"
    status = "Enabled"
    filter { prefix = "athena-results/" }
    expiration { days = 30 }
  }

  rule {
    id     = "expire-superseded-evidence"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = var.noncurrent_retention_days }
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_athena_workgroup" "guardrails" {
  name = "abc-claude-guardrails"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.audit.bucket}/athena-results/"
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.audit.arn
      }
    }
  }
}
