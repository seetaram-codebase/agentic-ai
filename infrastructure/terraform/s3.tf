# ============================================
# S3 Bucket for Document Storage
# ============================================

resource "aws_s3_bucket" "documents" {
  bucket = "${var.app_name}-documents-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.app_name}-documents"
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 Event Notification to SQS (Chunking Queue)
resource "aws_s3_bucket_notification" "document_upload" {
  bucket = aws_s3_bucket.documents.id

  queue {
    queue_arn     = aws_sqs_queue.document_chunking.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
    filter_suffix = ".pdf"
  }

  queue {
    queue_arn     = aws_sqs_queue.document_chunking.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
    filter_suffix = ".txt"
  }

  depends_on = [aws_sqs_queue_policy.document_chunking]
}
