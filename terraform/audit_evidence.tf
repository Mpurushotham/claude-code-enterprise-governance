# Guardrail evidence: KMS-encrypted, versioned, access-logged, Athena-queryable.
resource "aws_kms_key" "audit" {
  description         = "ABC Claude guardrail evidence"
  enable_key_rotation = true
}

resource "aws_s3_bucket" "audit" { bucket = var.audit_bucket_name }

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
