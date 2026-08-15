variable "name" {
    type = string
    description = "The name of the VPC"
  
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  type = string 
}

variable "azs" {
    description = "The availability zones of the subnets"
    type = list(string)
  
}

variable "public_subnet_cidrs" {
  description = "The CIDR blocks of the public subnets"
  type = list(string)
}

variable "private_subnet_cidrs" {
  description = "The CIDR blocks of the private subnets"
  type = list(string)
}