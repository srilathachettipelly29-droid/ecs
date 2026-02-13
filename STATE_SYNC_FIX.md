# State Sync Issue Fix

## Problem
GitHub Actions workflow failing with:
```
Error refreshing state: state data in S3 does not have the expected content.
```

## Root Cause
Manual AWS CLI commands (terminating instances, creating launch template versions, updating ASG) updated the infrastructure state without updating the Digest in DynamoDB.

## Solution

### Option 1: Recalculate S3 Checksum (Recommended)
```bash
# Download current state
aws s3 cp s3://terraform-state-srilatha-001/alb-ec2-docker/terraform.tfstate ./

# Calculate MD5
md5sum terraform.tfstate
# Output: 5a819c5cee6266128ac320322927dec0

# Update DynamoDB with new digest value
aws dynamodb update-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "terraform-state-srilatha-001/alb-ec2-docker/terraform.tfstate"}}' \
  --update-expression "SET Digest = :digest" \
  --expression-attribute-values '{":digest": {"S": "5a819c5cee6266128ac320322927dec0"}}' \
  --region ap-south-1
```

### Option 2: Clear Lock and Reinitialize
```bash
# Delete the lock
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "terraform-state-srilatha-001/alb-ec2-docker/terraform.tfstate"}}' \
  --region ap-south-1

# Then run terraform init again
terraform init
```

### Option 3: Migrate to Local Backend (For Testing)
Edit `provider.tf`:
```hcl
terraform {
  # Temporarily comment out S3 backend
  # backend "s3" {
  #   ...
  # }
}
```

Then:
```bash
terraform init
# Choose to copy existing state locally
```

## Prevention

### Avoid Manual AWS CLI Changes
Instead of directly terminating instances, use Terraform:

**Instead of:**
```bash
aws ec2 terminate-instances --instance-ids i-xxx
```

**Do this:**
```hcl
# Update Terraform configuration
# Then apply
terraform apply -auto-approve
```

### Update Infrastructure Through Terraform Only
1. Edit `.tf` files
2. Run `terraform plan` to preview
3. Run `terraform apply` to update
4. Commit changes to git

### Use Terraform Taint for Forced Recreation
```bash
# Force recreation of specific resource
terraform taint aws_launch_template.app

# Apply changes
terraform apply -auto-approve
```

## Current Status
- ASG is working correctly
- Instances are healthy
- Application is running
- GitHub Actions workflow needs state sync fix

## Next Steps
1. Execute Option 1 (recalculate checksum)
2. Push fix to GitHub
3. Re-run GitHub Actions workflow
4. Verify deployment succeeds
