terraform {
  backend "s3" {
    bucket         = "idp-infra-tfstate-meka-us-east-1"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "idp-infra-tf-locks"
    encrypt        = true
  }
}
