resource "aws_vpc" "this" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
        Name = "${var.name}"
    }
}

resource "aws_subnet" "public"{
    count = length(var.azs) #one per AZ
    vpc_id = aws_vpc.this.id 
    cidr_block = var.public_subnet_cidrs[count.index]
    availability_zone = var.azs[count.index]
    map_public_ip_on_launch = true
    tags ={
        Name = "${var.name}-public-${var.azs[count.index]}"
        "kubernetes.io/role/elb" = "1"
    }
}


resource "aws_subnet" "private"{
    count = length(var.azs)
    vpc_id = aws_vpc.this.id 
    cidr_block = var.private_subnet_cidrs[count.index]
    availability_zone = var.azs[count.index]
    tags ={
        Name = "${var.name}-private-${var.azs[count.index]}"
        "kubernetes.io/role/internal-elb" = "1"
    }
}