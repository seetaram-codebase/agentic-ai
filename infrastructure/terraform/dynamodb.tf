# ============================================
# DynamoDB Tables
# ============================================

# Azure OpenAI Configuration Table
resource "aws_dynamodb_table" "config" {
  name         = "${var.app_name}-config"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "config_id"

  attribute {
    name = "config_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.app_name}-config"
  }
}

# Document Metadata Table
resource "aws_dynamodb_table" "documents" {
  name         = "${var.app_name}-documents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.app_name}-documents"
  }
}
