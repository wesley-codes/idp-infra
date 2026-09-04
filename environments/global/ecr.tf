module "ecr" {
  source = "../../modules/ecr"
  name   = "idp-dev/web"
}


output "ecr_repository_url" {
  value = module.ecr.repository_url
}