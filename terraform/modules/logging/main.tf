variable "name_prefix" { type = string }

resource "aws_s3_bucket" "logs" {
  bucket_prefix = "${var.name_prefix}-logs-"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-alb-logs"
    status = "Enabled"

    filter {
      prefix = "alb/"
    }

    expiration {
      days = 90
    }
  }
}

output "logs_bucket_id" {
  value = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  value = aws_s3_bucket.logs.arn
}
