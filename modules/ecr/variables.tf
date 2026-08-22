variable "name" {
  description = "ECR repo name"
  type = string
}

variable "force_delete" {
  description = "Allow terraform destroy to remove the repo even if it has images"
  type = bool
  default = true
}

