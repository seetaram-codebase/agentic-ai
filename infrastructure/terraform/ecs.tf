# ============================================
# ECS Cluster, Task Definition & Service
# ============================================

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.app_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.app_name}-cluster" }
}

# Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.app_name}-ecs-logs" }
}

# ============================================
# ECS Task Definition
# ============================================

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.app_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "${aws_ecr_repository.backend.repository_url}:latest"

      portMappings = [{ containerPort = 8000, hostPort = 8000, protocol = "tcp" }]

      environment = [
        { name = "USE_SSM_CONFIG", value = "true" },
        { name = "USE_DYNAMODB_CONFIG", value = "false" },
        { name = "APP_NAME", value = var.app_name },
        { name = "DYNAMODB_CONFIG_TABLE", value = aws_dynamodb_table.config.name },
        { name = "DYNAMODB_DOCUMENTS_TABLE", value = aws_dynamodb_table.documents.name },
        { name = "S3_BUCKET", value = aws_s3_bucket.documents.id },
        { name = "SQS_QUEUE_URL", value = aws_sqs_queue.document_chunking.url },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\" || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 120
      }
    }
  ])

  tags = { Name = "${var.app_name}-backend-task" }
}

# ============================================
# ECS Service
# ============================================
resource "aws_ecs_service" "backend" {
  name            = "backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = { Name = "${var.app_name}-backend-service" }
}
