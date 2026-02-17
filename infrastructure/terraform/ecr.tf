# ============================================
# Container Registry (ECR or JFrog)
# ============================================

# Toggle between ECR and JFrog
variable "use_jfrog" {
  description = "Use JFrog Artifactory instead of ECR"
  type        = bool
  default     = false
}

variable "jfrog_registry_url" {
  description = "JFrog Artifactory Docker registry URL (e.g., your-org.jfrog.io)"
  type        = string
  default     = ""
}

variable "jfrog_repository" {
  description = "JFrog repository name for Docker images"
  type        = string
  default     = "docker-local"
}

# ============================================
# Option 1: AWS ECR (default)
# ============================================
resource "aws_ecr_repository" "backend" {
  count = var.use_jfrog ? 0 : 1

  name                 = "${var.app_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.app_name}-backend"
  }
}

# Lifecycle policy to clean up old images
resource "aws_ecr_lifecycle_policy" "backend" {
  count = var.use_jfrog ? 0 : 1

  repository = aws_ecr_repository.backend[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ============================================
# Option 2: JFrog Artifactory
# ============================================
# Note: JFrog resources are managed externally
# This just provides the image URL for ECS

locals {
  # Container image URL based on registry choice
  container_registry_url = var.use_jfrog ? "${var.jfrog_registry_url}/${var.jfrog_repository}/${var.app_name}-backend" : (
    length(aws_ecr_repository.backend) > 0 ? aws_ecr_repository.backend[0].repository_url : ""
  )
}

# ============================================
# Outputs
# ============================================
output "container_registry_url" {
  description = "Container registry URL (ECR or JFrog)"
  value       = local.container_registry_url
}

output "container_registry_type" {
  description = "Container registry type being used"
  value       = var.use_jfrog ? "jfrog" : "ecr"
}

