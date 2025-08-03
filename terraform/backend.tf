terraform {
  backend "s3" {
    bucket = "devops-terraform-state-1754244313"
    key    = "devops/terraform.tfstate"
    region = "us-east-1"
  }
}