# ECR Repository for Java Application
resource "aws_ecr_repository" "java_app" {
  name                 = "java-ecs-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "java-app-ecr"
    Environment = var.environment
  }
}

# ECR Repository Policy (allow pull from ECS)
resource "aws_ecr_repository_policy" "java_app" {
  repository = aws_ecr_repository.java_app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPullImage"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
      }
    ]
  })
}

# Lifecycle policy to keep only last 5 images
resource "aws_ecr_lifecycle_policy" "java_app" {
  repository = aws_ecr_repository.java_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Output ECR repository URL
output "ecr_repository_url" {
  description = "ECR repository URL for Java application"
  value       = aws_ecr_repository.java_app.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.java_app.arn
}
