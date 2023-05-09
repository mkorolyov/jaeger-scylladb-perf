resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "jaeger-vpc"
  }
}

resource "aws_subnet" "this" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "jaeger-subnet"
  }
}

resource "aws_subnet" "this2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "jaeger-subnet-2"
  }
}

resource "aws_security_group" "ssh" {
  name_prefix = "ssh-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.this.id
}

resource "aws_network_acl_rule" "ssh_inbound" {
  rule_number      = 100
  protocol         = "6"
  rule_action      = "allow"
  egress           = false
  cidr_block       = "0.0.0.0/0"
  from_port        = 22
  to_port          = 22
  network_acl_id   = aws_network_acl.this.id
}

resource "aws_network_acl" "this" {
  vpc_id = aws_vpc.this.id

  ingress {
    protocol = "tcp"
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 22
    to_port = 22
  }

  egress {
    protocol = "tcp"
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 65535
  }
}

resource "aws_route" "internet_gateway" {
  route_table_id            = aws_route_table.this.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.prometheus_igw.id
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prometheus_igw.id
  }

  tags = {
    Name = "jaeger-scylla"
  }
}

#resource "aws_eip" "this" {
#  vpc = true
#}
#
#resource "aws_eip_association" "this" {
#  instance_id   = aws_launch_configuration.prometheus_lc.associate_public_ip_address
#  allocation_id = aws_eip.this.id
#
#  provisioner "local-exec" {
#    command = "sleep 10"  # wait for instance to be ready
#  }
#
#  depends_on = [
#    aws_autoscaling_group.prometheus_asg,
#    aws_eip.this,
#  ]
#}