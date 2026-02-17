# ============================================
# Outputs
# ============================================

# Container Registry (ECR or JFrog outputs are in ecr.tf)

# ECS
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.backend.name
}

# S3
output "s3_bucket_name" {
  description = "S3 bucket for document uploads"
  value       = aws_s3_bucket.documents.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.documents.arn
}

# SQS Queues
output "sqs_chunking_queue_url" {
  description = "SQS queue URL for document chunking (S3 → Chunker)"
  value       = aws_sqs_queue.document_chunking.url
}

output "sqs_embedding_queue_url" {
  description = "SQS queue URL for embedding (Chunker → Embedder)"
  value       = aws_sqs_queue.document_embedding.url
}

output "sqs_chunking_dlq_url" {
  description = "SQS dead letter queue for chunking"
  value       = aws_sqs_queue.chunking_dlq.url
}

output "sqs_embedding_dlq_url" {
  description = "SQS dead letter queue for embedding"
  value       = aws_sqs_queue.embedding_dlq.url
}

# Lambda Functions
output "lambda_chunker_name" {
  description = "Chunker Lambda function name"
  value       = aws_lambda_function.chunker.function_name
}

output "lambda_chunker_arn" {
  description = "Chunker Lambda function ARN"
  value       = aws_lambda_function.chunker.arn
}

output "lambda_embedder_name" {
  description = "Embedder Lambda function name"
  value       = aws_lambda_function.embedder.function_name
}

output "lambda_embedder_arn" {
  description = "Embedder Lambda function ARN"
  value       = aws_lambda_function.embedder.arn
}

# DynamoDB
output "dynamodb_config_table" {
  description = "DynamoDB table for Azure OpenAI config"
  value       = aws_dynamodb_table.config.name
}

output "dynamodb_documents_table" {
  description = "DynamoDB table for document metadata"
  value       = aws_dynamodb_table.documents.name
}

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.default.id
}

output "security_group_id" {
  description = "ECS security group ID"
  value       = aws_security_group.ecs.id
}

# SSM Parameters
output "ssm_parameter_prefix" {
  description = "SSM parameter prefix for Azure OpenAI configs"
  value       = "/${var.app_name}/azure-openai"
}

output "ssm_chat_us_east_key" {
  description = "SSM parameter path for US East API key"
  value       = aws_ssm_parameter.azure_openai_key_1.name
}

output "ssm_chat_eu_west_key" {
  description = "SSM parameter path for EU West API key"
  value       = aws_ssm_parameter.azure_openai_key_2.name
}

