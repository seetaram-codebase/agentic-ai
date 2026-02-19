# ============================================
# Lambda Functions: Chunker and Embedder
# ============================================

# Shared IAM Role for both Lambdas
resource "aws_iam_role" "lambda_execution" {
  name = "${var.app_name}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.app_name}-lambda-execution"
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.app_name}-lambda-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.documents.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:SendMessage", "sqs:SendMessageBatch"]
        Resource = [aws_sqs_queue.document_chunking.arn, aws_sqs_queue.document_embedding.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = [aws_dynamodb_table.config.arn, aws_dynamodb_table.documents.arn]
      },
      {
        Sid      = "SSMAccess"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.app_name}/*"
      },
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}

# ============================================
# Lambda 1: Chunker
# Uses: RecursiveCharacterTextSplitter, tiktoken, PyPDFLoader
# ============================================

# Create a minimal placeholder ZIP for initial deployment
# The actual code with dependencies will be deployed via GitHub Actions
data "archive_file" "chunker_code" {
  type        = "zip"
  output_path = "${path.module}/chunker_placeholder.zip"

  source {
    content  = "def lambda_handler(event, context): return {'statusCode': 200, 'body': 'Placeholder - deploy via CI/CD'}"
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "chunker" {
  function_name    = "${var.app_name}-chunker"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = var.lambda_chunker_timeout
  memory_size      = var.lambda_chunker_memory
  filename         = data.archive_file.chunker_code.output_path
  source_code_hash = data.archive_file.chunker_code.output_base64sha256

  environment {
    variables = {
      DYNAMODB_DOCUMENTS_TABLE = aws_dynamodb_table.documents.name
      EMBEDDING_QUEUE_URL      = aws_sqs_queue.document_embedding.url
      S3_BUCKET                = aws_s3_bucket.documents.id
    }
  }

  tags = {
    Name = "${var.app_name}-chunker"
  }

  lifecycle {
    ignore_changes = [
      source_code_hash,  # Code will be updated via GitHub Actions
      filename
    ]
  }
}

resource "aws_cloudwatch_log_group" "chunker" {
  name              = "/aws/lambda/${aws_lambda_function.chunker.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_event_source_mapping" "chunker_trigger" {
  event_source_arn = aws_sqs_queue.document_chunking.arn
  function_name    = aws_lambda_function.chunker.arn
  batch_size       = 1
  enabled          = true
}

# ============================================
# Lambda 2: Embedder
# Uses: OpenAIEmbeddings (Azure), Chroma vectorstore
# ============================================

# Create a minimal placeholder ZIP for initial deployment
# The actual code with dependencies will be deployed via GitHub Actions
data "archive_file" "embedder_code" {
  type        = "zip"
  output_path = "${path.module}/embedder_placeholder.zip"

  source {
    content  = "def lambda_handler(event, context): return {'statusCode': 200, 'body': 'Placeholder - deploy via CI/CD'}"
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "embedder" {
  function_name    = "${var.app_name}-embedder"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = var.lambda_embedder_timeout
  memory_size      = var.lambda_embedder_memory
  filename         = data.archive_file.embedder_code.output_path
  source_code_hash = data.archive_file.embedder_code.output_base64sha256

  environment {
    variables = {
      DYNAMODB_CONFIG_TABLE    = aws_dynamodb_table.config.name
      DYNAMODB_DOCUMENTS_TABLE = aws_dynamodb_table.documents.name
      USE_CHROMA               = "true"
      CHROMA_PERSIST_DIR       = "/tmp/chroma_db"
      APP_NAME                 = var.app_name
      # Pinecone configuration (API key from SSM)
      PINECONE_API_KEY_PARAM   = aws_ssm_parameter.pinecone_api_key.name
      PINECONE_INDEX           = var.pinecone_index
      USE_PINECONE             = var.use_pinecone ? "true" : "false"
      # Azure OpenAI multi-region configuration (from existing SSM parameters)
      AZURE_REGION_PRIMARY     = "us-east"
      AZURE_REGION_FAILOVER    = "eu-west"
      AZURE_OPENAI_API_VERSION = "2024-02-01"
    }
  }

  tags = {
    Name = "${var.app_name}-embedder"
  }

  lifecycle {
    ignore_changes = [
      source_code_hash,  # Code will be updated via GitHub Actions
      filename
    ]
  }
}

resource "aws_cloudwatch_log_group" "embedder" {
  name              = "/aws/lambda/${aws_lambda_function.embedder.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_event_source_mapping" "embedder_trigger" {
  event_source_arn = aws_sqs_queue.document_embedding.arn
  function_name    = aws_lambda_function.embedder.arn
  batch_size       = 5
  enabled          = true
}
