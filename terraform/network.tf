resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  tags       = {
    Name = "jaeger-vpc"
  }
}

resource "aws_subnet" "this" {
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  tags                    = {
    Name = "jaeger-subnet"
  }
}

resource "aws_subnet" "this2" {
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  tags                    = {
    Name = "jaeger-subnet-2"
  }
}

resource "aws_ecs_cluster" "this" {
  name = local.ecs_cluster_name
}

resource "aws_security_group" "ssh" {
  name_prefix = "ssh-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.this.id
}

resource "aws_internet_gateway" "prometheus_igw" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "internet_gateway" {
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.prometheus_igw.id
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "jaeger-scylla"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.this.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.this2.id
  route_table_id = aws_route_table.this.id
}