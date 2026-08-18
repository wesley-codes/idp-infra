module "vpc" {
  source               = "../../modules/vpc"
  name                 = "idp-dev"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.32.0/20", "10.0.48.0/20"]
}

module "eks" {
  source     = "../../modules/eks"
  name       = "idp-dev"
  subnet_ids = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  private_subnet_ids = concat(module.vpc.private_subnet_ids)
}

