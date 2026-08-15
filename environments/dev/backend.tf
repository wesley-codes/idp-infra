# Wires Terraform's state for the DEV environment to the S3 bucket + DynamoDB lock table
# created by bootstrap/create-backend.sh.
#
# Fill in the SAME values you used in the bootstrap script, then run:
#   cd environments/dev && aws-vault exec terraform -- terraform init

terraform {
  backend "s3" {
    bucket         = "idp-infra-tfstate-meka-us-east-1"  # same bucket as bootstrap
    key            = "dev/terraform.tfstate"            # path in the bucket for THIS env
    region         = "us-east-1"                        # your region
    dynamodb_table = "idp-infra-tf-locks"               # same lock table
    encrypt        = true
  }
}
