module "vpc" {
  source               = "../../modules/vpc"
  name                 = "idp-dev"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.32.0/20", "10.0.48.0/20"]
}