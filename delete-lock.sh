#!/bin/bash

# Delete the lock from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key LockID={S="terraform-state-srilatha-001/alb-ec2-docker/terraform.tfstate"} \
  --region ap-south-1

echo "Lock deleted"
