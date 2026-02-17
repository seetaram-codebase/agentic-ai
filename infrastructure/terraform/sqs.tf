# ============================================
# SQS Queues for Document Processing
# ============================================

# ============================================
# Queue 1: Document Upload → Chunker Lambda
# ============================================

# Dead Letter Queue for chunking
resource "aws_sqs_queue" "chunking_dlq" {
  name                      = "${var.app_name}-chunking-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name = "${var.app_name}-chunking-dlq"
  }
}

# Main Chunking Queue (S3 → Chunker Lambda)
resource "aws_sqs_queue" "document_chunking" {
  name                       = "${var.app_name}-document-chunking"
  delay_seconds              = 0
  max_message_size           = 262144  # 256 KB
  message_retention_seconds  = 86400   # 1 day
  receive_wait_time_seconds  = 10      # Long polling
  visibility_timeout_seconds = 360     # 6x Lambda timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.chunking_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.app_name}-document-chunking"
  }
}

# Policy to allow S3 to send messages to Chunking Queue
resource "aws_sqs_queue_policy" "document_chunking" {
  queue_url = aws_sqs_queue.document_chunking.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3ToSendMessage"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.document_chunking.arn
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.documents.arn
        }
      }
    }]
  })
}

# ============================================
# Queue 2: Chunker Lambda → Embedder Lambda
# ============================================

# Dead Letter Queue for embedding
resource "aws_sqs_queue" "embedding_dlq" {
  name                      = "${var.app_name}-embedding-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name = "${var.app_name}-embedding-dlq"
  }
}

# Embedding Queue (Chunker → Embedder Lambda)
resource "aws_sqs_queue" "document_embedding" {
  name                       = "${var.app_name}-document-embedding"
  delay_seconds              = 0
  max_message_size           = 262144  # 256 KB
  message_retention_seconds  = 86400   # 1 day
  receive_wait_time_seconds  = 10      # Long polling
  visibility_timeout_seconds = 180     # 3x Lambda timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.embedding_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.app_name}-document-embedding"
  }
}

