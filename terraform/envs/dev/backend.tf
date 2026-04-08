terraform {
  backend "s3" {
    bucket         = "myapp-dev-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "myapp-dev-terraform-locks"
    encrypt        = true
  }
}
