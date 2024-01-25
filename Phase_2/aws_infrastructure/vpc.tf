resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet1_cidr
  availability_zone       = var.availability_zone1
  map_public_ip_on_launch = true

  tags = {
    Name = "Subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet2_cidr
  availability_zone       = var.availability_zone2
  map_public_ip_on_launch = false

  tags = {
    Name = "Subnet2"
  }
}
