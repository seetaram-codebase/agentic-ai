# ============================================
# Variables
# ============================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "rag-demo"
}

variable "ecs_cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "ECS task memory (MB)"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

# Lambda Chunker settings
variable "lambda_chunker_timeout" {
  description = "Chunker Lambda timeout (seconds)"
  type        = number
  default     = 60
}

variable "lambda_chunker_memory" {
  description = "Chunker Lambda memory (MB)"
  type        = number
  default     = 512
}

# Lambda Embedder settings
variable "lambda_embedder_timeout" {
  description = "Embedder Lambda timeout (seconds)"
  type        = number
  default     = 30
}

variable "lambda_embedder_memory" {
  description = "Embedder Lambda memory (MB)"
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
