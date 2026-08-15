variable "name" {
    type = string
    description = "The name of the VPC"
  
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  type = string 
}