module "vpc"{
    source ="../../modules/vpc"
    name = "idp-dev"
    vpc_cidr = "10.0.0.0/16"
}