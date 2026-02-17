# ============================================
# AWS SSM Parameter Store for Secrets
# Stores Azure OpenAI keys securely
# ============================================

# SSM Parameters for Azure OpenAI Chat (US East)
resource "aws_ssm_parameter" "azure_openai_endpoint_1" {
  name  = "/${var.app_name}/azure-openai/us-east/endpoint"
  type  = "String"
  value = "https://my-openai-us-east-1.openai.azure.com/"

  tags = { Name = "${var.app_name}-azure-endpoint-1" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "azure_openai_key_1" {
  name  = "/${var.app_name}/azure-openai/us-east/api-key"
  type  = "SecureString"
  value = "REPLACE_WITH_REAL_KEY"  # Update via AWS Console or CLI

  tags = { Name = "${var.app_name}-azure-key-1" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "azure_openai_deployment_1" {
  name  = "/${var.app_name}/azure-openai/us-east/deployment"
  type  = "String"
  value = "gpt-4o-mini"

  tags = { Name = "${var.app_name}-azure-deployment-1" }

  lifecycle {
    ignore_changes = [value]
  }
}

# SSM Parameters for Azure OpenAI Chat (EU West - Failover)
resource "aws_ssm_parameter" "azure_openai_endpoint_2" {
  name  = "/${var.app_name}/azure-openai/eu-west/endpoint"
  type  = "String"
  value = "https://my-openai-eu-west-1.openai.azure.com/"

  tags = { Name = "${var.app_name}-azure-endpoint-2" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "azure_openai_key_2" {
  name  = "/${var.app_name}/azure-openai/eu-west/api-key"
  type  = "SecureString"
  value = "REPLACE_WITH_REAL_KEY"  # Update via AWS Console or CLI

  tags = { Name = "${var.app_name}-azure-key-2" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "azure_openai_deployment_2" {
  name  = "/${var.app_name}/azure-openai/eu-west/deployment"
  type  = "String"
  value = "gpt-4o-mini"

  tags = { Name = "${var.app_name}-azure-deployment-2" }

  lifecycle {
    ignore_changes = [value]
  }
}

# SSM Parameters for Azure OpenAI Embeddings (US East)
resource "aws_ssm_parameter" "azure_embedding_endpoint_1" {
  name  = "/${var.app_name}/azure-openai/us-east/embedding-endpoint"
  type  = "String"
  value = "https://my-openai-us-east-1.openai.azure.com/"

  tags = { Name = "${var.app_name}-azure-embedding-endpoint-1" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "azure_embedding_key_1" {
  name  = "/${var.app_name}/azure-openai/us-east/embedding-key"
  type  = "SecureString"
  value = "REPLACE_WITH_REAL_KEY"

  tags = { Name = "${var.app_name}-azure-embedding-key-1" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "azure_embedding_deployment_1" {
  name  = "/${var.app_name}/azure-openai/us-east/embedding-deployment"
  type  = "String"
  value = "text-embedding-3-small"

  tags = { Name = "${var.app_name}-azure-embedding-deployment-1" }

  lifecycle {
    ignore_changes = [value]
  }
}

# SSM Parameters for Azure OpenAI Embeddings (EU West - Failover)
resource "aws_ssm_parameter" "azure_embedding_endpoint_2" {
  name  = "/${var.app_name}/azure-openai/eu-west/embedding-endpoint"
  type  = "String"
  value = "https://my-openai-eu-west-1.openai.azure.com/"

  tags = { Name = "${var.app_name}-azure-embedding-endpoint-2" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "azure_embedding_key_2" {
  name  = "/${var.app_name}/azure-openai/eu-west/embedding-key"
  type  = "SecureString"
  value = "REPLACE_WITH_REAL_KEY"

  tags = { Name = "${var.app_name}-azure-embedding-key-2" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "azure_embedding_deployment_2" {
  name  = "/${var.app_name}/azure-openai/eu-west/embedding-deployment"
  type  = "String"
  value = "text-embedding-3-small"

  tags = { Name = "${var.app_name}-azure-embedding-deployment-2" }

  lifecycle {
    ignore_changes = [value]
  }
}
