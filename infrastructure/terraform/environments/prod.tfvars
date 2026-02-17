# Production Environment Variables
aws_region         = "us-east-1"
environment        = "prod"
app_name           = "rag-demo"
ecs_cpu            = 1024
ecs_memory         = 2048
ecs_desired_count  = 2

# Lambda Chunker (uses LangChain, pypdf, tiktoken)
lambda_chunker_timeout = 120
lambda_chunker_memory  = 1024

# Lambda Embedder (uses LangChain, Azure OpenAI, Chroma)
lambda_embedder_timeout = 60
lambda_embedder_memory  = 1024

log_retention_days = 30

# Container Registry - Using AWS ECR
use_jfrog          = false
jfrog_registry_url = ""
jfrog_repository   = ""

