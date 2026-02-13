terraform {
  backend "s3" {
    bucket         = "terraform-state-srilatha-001"
    key            = "alb-ec2-docker/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
