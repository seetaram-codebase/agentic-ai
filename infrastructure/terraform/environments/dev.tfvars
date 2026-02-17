# Development Environment Variables
aws_account_id       = "971778147952"
aws_region         = "us-east-1"
environment        = "dev"
app_name           = "rag-demo"
ecs_cpu            = 512
ecs_memory         = 1024
ecs_desired_count  = 1

# Lambda Chunker (uses LangChain, pypdf, tiktoken)
lambda_chunker_timeout = 60
lambda_chunker_memory  = 512

# Lambda Embedder (uses LangChain, Azure OpenAI, Chroma)
lambda_embedder_timeout = 30
lambda_embedder_memory  = 512

log_retention_days = 7

