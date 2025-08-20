terraform {
  backend "s3" {
    bucket         = "myproject-terraform-state-fc-34852"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
  }
}