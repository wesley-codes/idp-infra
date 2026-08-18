output "vpc_id" {
  description = "ID of vpc"
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "ID of public subnets"
  value = aws_subnet.public[*].id
}

output "private_subnet_ids"{
    description = "ID of private subnet"
    value = aws_subnet.private[*].id
}