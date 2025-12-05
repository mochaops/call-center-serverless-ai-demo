resource "random_id" "suffix" { byte_length = 4 }

resource "aws_s3_bucket" "recordings" {
  count  = var.create_buckets && var.recordings_bucket_name == null ? 1 : 0
  bucket = local.recordings_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket" "outputs" {
  count  = var.create_buckets && var.outputs_bucket_name == null ? 1 : 0
  bucket = local.outputs_bucket_name
  force_destroy = true
}

# Versioning + SSE-KMS
resource "aws_s3_bucket_versioning" "rec" {
  count  = var.create_buckets && var.recordings_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.recordings[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_versioning" "out" {
  count  = var.create_buckets && var.outputs_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.outputs[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rec" {
  count  = var.create_buckets && var.recordings_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.recordings[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "out" {
  count  = var.create_buckets && var.outputs_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.outputs[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

# Enable EventBridge notifications for recordings bucket
resource "aws_s3_bucket_notification" "recordings" {
  count  = var.create_buckets && var.recordings_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.recordings[0].id

  eventbridge = true
}
