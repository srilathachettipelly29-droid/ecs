#!/usr/bin/env python3
import boto3
import sys

# DynamoDB configuration
dynamodb = boto3.client('dynamodb', region_name='ap-south-1')
table_name = 'terraform-locks'
lock_id = 'terraform-state-srilatha-001/alb-ec2-docker/terraform.tfstate'
new_digest = '5a819c5cee6266128ac320322927dec0'

try:
    # Update the digest value in DynamoDB
    response = dynamodb.update_item(
        TableName=table_name,
        Key={
            'LockID': {'S': lock_id}
        },
        UpdateExpression='SET Digest = :digest',
        ExpressionAttributeValues={
            ':digest': {'S': new_digest}
        }
    )
    
    print(f"✅ Successfully updated DynamoDB lock")
    print(f"   Table: {table_name}")
    print(f"   LockID: {lock_id}")
    print(f"   New Digest: {new_digest}")
    sys.exit(0)
    
except Exception as e:
    print(f"❌ Error updating DynamoDB: {e}")
    sys.exit(1)
