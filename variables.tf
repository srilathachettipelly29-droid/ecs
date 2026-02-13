variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "instance_type" {
  type = string
}
variable "ami_id" {
  description = "AMI ID"
  type        = string
  default     = "ami-0317b0f0a0144b137"
}


variable "key_name" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 6
}

variable "asg_desired_capacity" {
  type    = number
  default = 3
}

# ECS Fargate variables
variable "ecs_desired_count" {
  type        = number
  default     = 2
  description = "Number of ECS tasks to run"
}

variable "ecs_min_capacity" {
  type        = number
  default     = 1
  description = "Minimum number of ECS tasks for auto-scaling"
}

variable "ecs_max_capacity" {
  type        = number
  default     = 4
  description = "Maximum number of ECS tasks for auto-scaling"
}

variable "container_cpu" {
  type        = number
  default     = 512
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
}

variable "container_memory" {
  type        = number
  default     = 1024
  description = "Memory for ECS task in MB (512, 1024, 2048, 3072, 4096, etc)"
}
