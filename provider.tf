terraform {
  backend "s3" {
    bucket         = "terraform-state-srilatha-2026"
    key            = "alb-ec2-docker/terraform.tfstate"
    region         = "us-east-1" # make sure region matches your new bucket
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}


