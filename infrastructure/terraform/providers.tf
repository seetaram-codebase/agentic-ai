# ============================================
# Terraform Configuration & Providers
# ============================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Terraform Cloud Backend
  # To set up:
  # 1. Create account at https://app.terraform.io
  # 2. Create organization and workspace
  # 3. Add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY as workspace variables
  # 4. Add TF_API_TOKEN to GitHub Secrets
  cloud {
    organization = "agentic-ai-org"

    workspaces {
      name = "agentic-ai-rag-workspace"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.app_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
