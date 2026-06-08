resource "aws_vpc" "main" {

  cidr_block           = var.vpc_cidr

  enable_dns_hostnames = true

  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

resource "aws_subnet" "public_1" {

  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.1.0/24"

  availability_zone = "ap-south-1a"

  map_public_ip_on_launch = true

  tags = {

    Name = "${var.environment}-public-subnet-1"

    Type = "Public"
  }
}

resource "aws_subnet" "public_2" {

  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.2.0/24"

  availability_zone = "ap-south-1b"

  map_public_ip_on_launch = true

  tags = {

    Name = "${var.environment}-public-subnet-2"

    Type = "Public"
  }
}

resource "aws_subnet" "private_1" {

  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.11.0/24"

  availability_zone = "ap-south-1a"

  tags = {

    Name = "${var.environment}-private-subnet-1"

    Type = "Private"
  }
}

resource "aws_subnet" "private_2" {

  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.12.0/24"

  availability_zone = "ap-south-1b"

  tags = {

    Name = "${var.environment}-private-subnet-2"

    Type = "Private"
  }
}

resource "aws_eip" "nat" {

  domain = "vpc"

  tags = {
    Name = "${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public_1.id

  tags = {
    Name = "${var.environment}-nat"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block = "0.0.0.0/0"

    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "public_1" {

  subnet_id = aws_subnet.public_1.id

  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {

  subnet_id = aws_subnet.public_2.id

  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {

  subnet_id = aws_subnet.private_1.id

  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {

  subnet_id = aws_subnet.private_2.id

  route_table_id = aws_route_table.private.id
}