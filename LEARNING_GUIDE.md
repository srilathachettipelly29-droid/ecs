# Terraform ALB + EC2 + Docker + ASG - Complete Learning Guide

## Table of Contents
1. Architecture Overview
2. Infrastructure Components
3. File Structure & Breakdown
4. Deployment Process
5. Troubleshooting Guide
6. Best Practices
7. Cost Optimization

---

## 1. Architecture Overview

### High-Level Architecture
```
Internet
    ↓
Application Load Balancer (ALB)
    ↓
Target Group (Port 80)
    ↓
Auto Scaling Group (2-6 instances)
    ↓
EC2 Instances (Ubuntu, Docker, Java, Nginx)
    ↓
VPC (10.0.0.0/16) with Subnets
```

### What We Built:
- **VPC**: Virtual Private Cloud with CIDR 10.0.0.0/16
- **Subnets**: 2 public subnets across availability zones
- **ALB**: Application Load Balancer distributing traffic
- **ASG**: Auto Scaling Group managing EC2 instances (min: 2, max: 6, desired: 3)
- **Security Groups**: Control inbound/outbound traffic
- **Instances**: Ubuntu with Docker, Java, and Nginx

---

## 2. Infrastructure Components

### 2.1 VPC & Networking (vpc.tf)
```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr  # 10.0.0.0/16
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.igw.id
  }
}
```

**Key Concepts:**
- **CIDR Blocks**: Define IP address ranges (10.0.0.0/16 = 65,536 addresses)
- **Subnets**: Divide VPC into smaller networks (10.0.1.0/24, 10.0.2.0/24)
- **IGW**: Internet Gateway allows traffic between VPC and internet
- **Route Table**: Defines how traffic is routed

### 2.2 Security Groups (security.tf)
```hcl
resource "aws_security_group" "alb_sg" {
  ingress {
    from_port   = 80      # Allow HTTP
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # From anywhere
  }
  
  egress {
    from_port   = 0       # Allow all outbound
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # Only from ALB
  }
}
```

**Why Two Security Groups?**
- ALB Security Group: Accepts traffic from internet on port 80
- EC2 Security Group: Accepts traffic ONLY from ALB (not internet directly)
- This creates a secure boundary - instances don't expose ports to internet

### 2.3 Load Balancer (alb.tf)
```hcl
resource "aws_lb" "alb" {
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "tg" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
```

**How ALB Works:**
1. Receives requests on port 80
2. Performs health checks every 30 seconds on "/"
3. Only sends traffic to healthy targets (2 consecutive successful checks)
4. Distributes load across instances in target group

### 2.4 Auto Scaling Group (asg.tf)
```hcl
resource "aws_launch_template" "app" {
  name_prefix   = "app-"
  image_id      = var.ami_id       # Ubuntu 22.04 LTS
  instance_type = var.instance_type # t2.small
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update system
    apt-get update -y
    
    # Install Docker
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    
    # Run Nginx on port 80
    docker run -d -p 80:80 --name web-server nginx:latest
    
    # Run Java app on port 8080
    docker run -d -p 8080:8080 \
      --name java-app \
      openjdk:11-jre-slim \
      java -jar /app/application.jar
  EOF
  )
}

resource "aws_autoscaling_group" "app" {
  name                = "app-asg-${aws_launch_template.app.latest_version}"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.asg_min_size      # 2
  max_size         = var.asg_max_size      # 6
  desired_capacity = var.asg_desired_capacity # 3
  
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown              = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "app-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "CPUUtilization"
  threshold           = "70"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
}
```

**Auto Scaling Explained:**
- **Launch Template**: Blueprint for creating instances (AMI, instance type, user data)
- **User Data**: Script runs when instance starts (install Docker, pull images)
- **Min/Max/Desired**: 2 minimum, 6 maximum, 3 normally running
- **Health Checks**: Remove unhealthy instances, launch replacements
- **Scaling Policies**: Add/remove instances based on CPU usage
  - CPU > 70%: Add 1 instance
  - CPU < 30%: Remove 1 instance

---

## 3. File Structure & Breakdown

### 3.1 Project Files

#### provider.tf
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-srilatha-001"
    key            = "alb-ec2-docker/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
```
**Purpose:** Configure AWS provider and state backend
- **State Backend**: Stores Terraform state in S3 (not locally)
- **DynamoDB**: Locks state to prevent concurrent modifications
- **Encryption**: Secures state file in S3

#### variables.tf
```hcl
variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 3
}
```
**Purpose:** Define all configurable parameters

#### terraform.tfvars
```hcl
aws_region = "ap-south-1"
vpc_cidr   = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

instance_type = "t2.small"
asg_min_size  = 2
asg_max_size  = 6
asg_desired_capacity = 3
```
**Purpose:** Provide actual values for variables

#### outputs.tf
```hcl
output "alb_url" {
  value       = "http://${aws_lb.alb.dns_name}"
  description = "URL to access the application"
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
  description = "Name of Auto Scaling Group"
}
```
**Purpose:** Display important values after deployment

### 3.2 GitHub Actions Workflow (.github/workflows/terraform.yml)

```yaml
name: Terraform CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-south-1
      
      - uses: hashicorp/setup-terraform@v3
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Plan
        run: terraform plan -var-file=terraform.tfvars
      
      - name: Terraform Apply
        if: github.event_name == 'push'
        run: terraform apply -auto-approve -var-file=terraform.tfvars
```

**CI/CD Pipeline Steps:**
1. **On Push to Main**: Automatically deploy infrastructure
2. **On Pull Request**: Show plan without applying
3. **Format Check**: Ensure code follows Terraform style
4. **Validation**: Check for syntax errors
5. **Plan**: Show what will change
6. **Apply**: Create/update infrastructure

---

## 4. Deployment Process

### Step 1: Initialize Terraform
```bash
terraform init
```
- Downloads AWS provider
- Creates .terraform directory
- Configures S3 backend
- Initializes state lock

### Step 2: Plan Changes
```bash
terraform plan -var-file=terraform.tfvars
```
**Output Shows:**
- Resources to be created (+)
- Resources to be updated (~)
- Resources to be destroyed (-)

### Step 3: Apply Changes
```bash
terraform apply -auto-approve -var-file=terraform.tfvars
```
**Creates:**
- VPC, Subnets, IGW
- Security Groups
- ALB, Target Group
- Launch Template
- Auto Scaling Group

### Step 4: Verify Deployment
```bash
terraform output alb_url
# Output: http://tf-lb-...ap-south-1.elb.amazonaws.com
```

**Access the Application:**
1. Copy the ALB URL
2. Open in browser
3. See Nginx default page (port 80)
4. Java app running on port 8080 (internal)

### Scaling in Action
```bash
# Check ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names app-asg-1 \
  --region ap-south-1

# Check instances
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters "Name=tag:Name,Values=asg-app-instance"

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn <arn> \
  --region ap-south-1
```

---

## 5. Troubleshooting Guide

### Issue: 502 Bad Gateway

**Cause:** ALB can't reach EC2 instances

**Solutions:**
1. **Check Security Groups:**
   - EC2 SG must allow port 80 from ALB SG
   - ALB SG must allow port 80 from 0.0.0.0/0

2. **Check Health Status:**
   ```bash
   aws elbv2 describe-target-health --target-group-arn <arn>
   # Look for: "unhealthy" or "initial"
   ```

3. **Check Instance Logs:**
   ```bash
   aws ec2 get-console-output --instance-id <id>
   # Look for Docker startup errors
   ```

4. **Wait for Instance Startup:**
   - Instances take 3-5 minutes to fully boot
   - Docker needs time to pull images
   - Health checks pass after services start

### Issue: User Data Script Failed

**Common Causes:**
1. **Wrong Linux Distribution:**
   - AMI is Ubuntu (use `apt-get`)
   - NOT Amazon Linux (don't use `yum`)

2. **Docker Commands Failed:**
   - Verify Docker daemon started
   - Check image pull succeeded
   - Ensure ports not already in use

3. **Fix:**
   ```bash
   # Create new launch template version
   aws ec2 create-launch-template-version \
     --launch-template-id <id> \
     --source-version 1 \
     --launch-template-data file://data.json
   
   # Update ASG to use new version
   aws autoscaling update-auto-scaling-group \
     --auto-scaling-group-name app-asg-1 \
     --launch-template '{"LaunchTemplateId":"<id>","Version":"2"}'
   
   # Terminate instances to force recreation
   aws ec2 terminate-instances --instance-ids <id>
   ```

### Issue: Terraform State Lock

**Symptom:** "Error acquiring state lock"

**Solution:**
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>

# Or wait for previous operation to complete
```

---

## 6. Best Practices

### 1. Infrastructure as Code (IaC)
✅ **DO:**
- Version control all Terraform files
- Use meaningful variable names
- Document complex resources
- Use modules for reusability

❌ **DON'T:**
- Make manual AWS console changes
- Hardcode values in code
- Skip code reviews
- Ignore state file

### 2. Security
✅ **DO:**
- Use security groups to restrict traffic
- Never expose instances directly to internet
- Use ALB as gateway
- Enable encryption for state files
- Use IAM roles instead of access keys

❌ **DON'T:**
- Allow port 22 (SSH) from 0.0.0.0/0
- Store secrets in code
- Use default VPC
- Disable health checks

### 3. Scaling
✅ **DO:**
- Set appropriate min/max/desired capacity
- Use CPU/memory metrics for scaling
- Test auto-scaling policies
- Monitor CloudWatch alarms

❌ **DON'T:**
- Scale too aggressively (costs money)
- Ignore health check failures
- Run without monitoring
- Skip cooldown periods

### 4. Cost Optimization
✅ **DO:**
- Use appropriate instance types (t2.small not t2.2xlarge)
- Set min/max correctly
- Clean up unused resources
- Use spot instances for non-critical workloads

❌ **DON'T:**
- Leave testing environments running
- Oversized instances
- Excessive scaling up

---

## 7. Cost Optimization

### Current Setup Costs (Approximate)

**Monthly Estimate (3 t2.small instances):**
| Component | Hourly | Monthly |
|-----------|--------|---------|
| 3 × t2.small EC2 | $0.023 × 3 | ~$50 |
| ALB | $0.0225 × 730h | ~$16 |
| Data Transfer | Varies | ~$10-30 |
| **Total** | | ~$76-96 |

### How to Reduce Costs

1. **Use Reserved Instances** (40% discount)
   - Commit to 1-year or 3-year term
   - Fixed capacity needed

2. **Use Spot Instances** (70% discount)
   - For non-critical workloads
   - Can be interrupted anytime

3. **Right-Sizing**
   - Start with t2.micro
   - Scale up if needed
   - Monitor actual CPU/memory

4. **Consolidation**
   - Combine with other applications
   - Use ASG to scale down at night

### CloudWatch Monitoring
```bash
# View CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --statistics Average \
  --start-time 2026-02-05T00:00:00Z \
  --end-time 2026-02-06T00:00:00Z \
  --period 3600
```

---

## 8. Key Terraform Commands

```bash
# Initialize project
terraform init

# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Plan changes (preview)
terraform plan

# Apply changes (create/update)
terraform apply

# Destroy resources
terraform destroy

# Show current state
terraform show

# Output specific value
terraform output alb_url

# Refresh state
terraform refresh

# Taint resource for recreation
terraform taint aws_instance.example

# Import existing resource
terraform import aws_instance.example i-1234567890abcdef0
```

---

## 9. Useful AWS CLI Commands

```bash
# List running instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"

# Get instance console output
aws ec2 get-console-output --instance-id <id>

# Check ASG status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <name>

# Check ALB health
aws elbv2 describe-target-health --target-group-arn <arn>

# Stop instance
aws ec2 stop-instances --instance-ids <id>

# Start instance
aws ec2 start-instances --instance-ids <id>

# Terminate instance
aws ec2 terminate-instances --instance-ids <id>

# Get logs from CloudWatch
aws logs tail /aws/lambda/function-name --follow
```

---

## 10. Glossary

| Term | Definition |
|------|-----------|
| **ALB** | Application Load Balancer - distributes traffic |
| **ASG** | Auto Scaling Group - manages EC2 instances automatically |
| **CIDR** | Classless Inter-Domain Routing - notation for IP ranges |
| **EC2** | Elastic Compute Cloud - virtual machines |
| **IAM** | Identity and Access Management - permissions/roles |
| **IGW** | Internet Gateway - connects VPC to internet |
| **Launch Template** | Blueprint for creating EC2 instances |
| **Security Group** | Virtual firewall controlling traffic |
| **Target Group** | Set of instances ALB sends traffic to |
| **VPC** | Virtual Private Cloud - isolated network |

---

## Conclusion

This infrastructure demonstrates:
1. **High Availability** - Multiple AZs, auto-scaling
2. **Scalability** - Handles traffic spikes automatically
3. **Security** - Layered security groups, ALB gateway
4. **Cost Efficiency** - Auto-scaling prevents over-provisioning
5. **Automation** - Terraform and GitHub Actions CI/CD

### Next Steps:
- Add HTTPS/TLS certificate
- Implement auto-scaling based on other metrics
- Add RDS database
- Set up CloudFront CDN
- Implement monitoring/alerting
- Create backup/disaster recovery plan

---

**Last Updated:** February 5, 2026
**Infrastructure:** Terraform ALB + EC2 + Docker + Auto Scaling
**Region:** ap-south-1 (Mumbai)
