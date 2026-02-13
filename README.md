# Terraform ALB + EC2 + Docker + ASG

Complete infrastructure-as-code project for deploying a highly available, auto-scaling application on AWS.

## Quick Start

### Prerequisites
- AWS Account with credentials configured
- Terraform >= 1.5.0
- AWS CLI installed

### Deploy

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan -var-file=terraform.tfvars

# Deploy infrastructure
terraform apply -auto-approve -var-file=terraform.tfvars

# Get ALB URL
terraform output alb_url
```

### Access Application
```
http://tf-lb-xxxxxxxxxx-ap-south-1.elb.amazonaws.com
```

## Architecture

```
Internet
    ↓
ALB (Application Load Balancer)
    ↓
Target Group (Port 80)
    ↓
Auto Scaling Group (2-6 instances)
    ↓
EC2 Instances (Ubuntu + Docker + Java + Nginx)
    ↓
VPC (10.0.0.0/16)
```

## Features

✅ **High Availability**
- Multi-AZ deployment
- Auto Scaling Group (min: 2, max: 6, desired: 3)
- Application Load Balancer with health checks

✅ **Auto Scaling**
- Scale up when CPU > 70%
- Scale down when CPU < 30%
- CloudWatch monitoring and alarms

✅ **Containerized Application**
- Docker containers running Nginx (port 80) + Java app (port 8080)
- Automatic service startup with user data

✅ **Security**
- VPC with public subnets
- Security groups restricting traffic flow
- ALB as internet gateway

✅ **Infrastructure as Code**
- Complete Terraform configuration
- Version controlled
- GitHub Actions CI/CD pipeline

## Files

| File | Purpose |
|------|---------|
| `provider.tf` | AWS provider & S3 backend configuration |
| `variables.tf` | Variable definitions |
| `terraform.tfvars` | Variable values |
| `vpc.tf` | VPC, subnets, internet gateway, route tables |
| `security.tf` | Security groups |
| `alb.tf` | Load balancer, target group, listener |
| `asg.tf` | Launch template, Auto Scaling Group, scaling policies |
| `ec2.tf` | EC2 instances (legacy, not used by ASG) |
| `outputs.tf` | Output values |
| `.github/workflows/terraform.yml` | GitHub Actions CI/CD pipeline |

## Outputs

```bash
terraform output

alb_arn = "arn:aws:elasticloadbalancing:ap-south-1:..."
alb_dns_name = "tf-lb-xxxxx-ap-south-1.elb.amazonaws.com"
alb_url = "http://tf-lb-xxxxx-ap-south-1.elb.amazonaws.com"
asg_arn = "arn:aws:autoscaling:ap-south-1:..."
asg_name = "app-asg-1"
launch_template_id = "lt-xxxxx"
launch_template_latest_version = "4"
target_group_arn = "arn:aws:elasticloadbalancing:ap-south-1:..."
```

## Management

### Check Infrastructure Status
```bash
# ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names app-asg-1 \
  --region ap-south-1

# Running instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=asg-app-instance" \
  --region ap-south-1

# Target health
aws elbv2 describe-target-health \
  --target-group-arn <arn> \
  --region ap-south-1
```

### Scale Infrastructure
```bash
# Manually adjust desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name app-asg-1 \
  --desired-capacity 5 \
  --region ap-south-1
```

### Terminate Instances
```bash
# Force ASG to launch new instances
aws ec2 terminate-instances \
  --instance-ids i-xxxxx \
  --region ap-south-1
```

## Troubleshooting

### 502 Bad Gateway Error
1. Check target health: `aws elbv2 describe-target-health --target-group-arn <arn>`
2. Check instance logs: `aws ec2 get-console-output --instance-id <id>`
3. Wait 3-5 minutes for instances to fully boot
4. Verify security groups allow port 80 from ALB to instances

### Terraform State Issues
See [STATE_SYNC_FIX.md](STATE_SYNC_FIX.md) for detailed resolution steps.

### GitHub Actions Workflow Failing
- Check AWS credentials in GitHub Secrets
- Verify DynamoDB state lock isn't stale
- See STATE_SYNC_FIX.md for solutions

## Cost Estimation

**Monthly cost (3 t2.small instances):**
- EC2: ~$50
- ALB: ~$16
- Data Transfer: ~$10-30
- **Total: ~$76-96/month**

## Learning Guide

Complete learning guide available in [LEARNING_GUIDE.md](LEARNING_GUIDE.md) covering:
- Architecture concepts
- Component breakdown
- Deployment process
- Best practices
- Troubleshooting
- Cost optimization

## CI/CD Pipeline

GitHub Actions workflow automatically:
1. Validates Terraform code on pull requests
2. Shows planned changes in PR comments
3. Deploys on push to main branch
4. Generates deployment outputs

**Workflow status:** See `.github/workflows/terraform.yml`

## Important Notes

⚠️ **Always modify infrastructure through Terraform**, not manual AWS console changes:
- Keeps code and reality in sync
- Enables team collaboration
- Maintains state consistency
- Allows easy rollback

## Cleanup

To destroy all resources:
```bash
terraform destroy -auto-approve -var-file=terraform.tfvars
```

**Warning:** This will delete:
- EC2 instances
- Load balancer
- VPC and subnets
- All associated resources

## Next Steps

1. **HTTPS/TLS**: Add SSL certificate to ALB
2. **Database**: Add RDS for persistent storage
3. **CDN**: Add CloudFront for static content
4. **Monitoring**: Enhanced CloudWatch dashboards
5. **Backup**: Implement automated backups
6. **Multi-region**: Deploy across multiple regions

## Support

For issues or questions:
1. Check [LEARNING_GUIDE.md](LEARNING_GUIDE.md)
2. Review [STATE_SYNC_FIX.md](STATE_SYNC_FIX.md)
3. Check terraform logs: `TF_LOG=DEBUG terraform plan`
4. Review AWS CloudWatch logs

## License

MIT License - Feel free to use and modify

## Contributors

- Terraform Configuration: Infrastructure Team
- Learning Guide: Documentation Team
- CI/CD Pipeline: DevOps Team

---

**Last Updated:** February 5, 2026
**Terraform Version:** 1.5.0
**AWS Region:** ap-south-1
