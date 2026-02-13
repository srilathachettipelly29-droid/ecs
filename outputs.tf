output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "DNS name of the load balancer"
}

output "alb_arn" {
  value       = aws_lb.alb.arn
  description = "ARN of the load balancer"
}

output "target_group_arn" {
  value       = aws_lb_target_group.tg.arn
  description = "ARN of the target group"
}


output "alb_url" {
  value       = "http://${aws_lb.alb.dns_name}"
  description = "URL to access the application through the load balancer"
}

# ECS Outputs
output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "Name of the ECS cluster"
}

output "ecs_cluster_arn" {
  value       = aws_ecs_cluster.main.arn
  description = "ARN of the ECS cluster"
}

output "ecs_service_name" {
  value       = aws_ecs_service.java_app.name
  description = "Name of the ECS service"
}

output "ecs_task_definition_arn" {
  value       = aws_ecs_task_definition.java_app.arn
  description = "ARN of the ECS task definition"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.java_app.repository_url
  description = "URL of the ECR repository for Java application"
}

output "ecr_repository_name" {
  value       = aws_ecr_repository.java_app.name
  description = "Name of the ECR repository"
}

output "cloudwatch_log_group" {
  value       = aws_cloudwatch_log_group.ecs_logs.name
  description = "CloudWatch log group for ECS tasks"
}
