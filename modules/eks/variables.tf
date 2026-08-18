variable "name" {
  description = "Name of Cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of Ids"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the K8s API to the internet. true = dev; false = prod (private + bastion)."
  type        = bool
  default     = true
}

variable "private_subnet_ids" {
  description = "IDs of private subnet"
  type = list(string)
}