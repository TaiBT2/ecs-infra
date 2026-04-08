terraform {
  backend "s3" {
    bucket         = "myapp-staging-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "myapp-staging-terraform-locks"
    encrypt        = true
  }
}
