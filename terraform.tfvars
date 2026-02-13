aws_region = "ap-south-1"
vpc_cidr   = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

instance_type  = "t2.small"
instance_count = 2
ami_id         = "ami-0c1fe732b5494dc14"
key_name       = "my-keypair"

# ASG Configuration
environment          = "prod"
asg_min_size         = 2
asg_max_size         = 6
asg_desired_capacity = 3

# ECS Fargate Configuration
ecs_desired_count = 2
ecs_min_capacity  = 1
ecs_max_capacity  = 4
container_cpu     = 512
container_memory  = 1024
