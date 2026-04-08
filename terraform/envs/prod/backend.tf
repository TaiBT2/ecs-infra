terraform {
  backend "s3" {
    bucket         = "myapp-prod-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "myapp-prod-terraform-locks"
    encrypt        = true
  }
}
