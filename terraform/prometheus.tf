resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus_sg"
  description = "Allow inbound traffic for Prometheus"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
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

module "prometheus_host" {
  source               = "./ecs_instance"
  deployment_host      = "prometheus"
  security_group      = aws_security_group.prometheus_sg.id
  subnet_id            = aws_subnet.this.id
  vpc_id               = aws_vpc.this.id
  instance_type        = "t2.micro"
  ecs_cluster_id       = aws_ecs_cluster.this.id
  aim_instance_profile = aws_iam_instance_profile.instance_profile-infra.name
  ecs_task_role_arn    = aws_iam_role.ecs_task_role.arn
}

#data "aws_ecr_authorization_token" "token" {}

resource "aws_ecr_repository" "prometheus" {
  name                 = "prometheus"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  lifecycle {
    prevent_destroy = false
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:deployment-host == prometheus"
  }

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/prometheus:latest"
      cpu       = 256
      memory    = 256
      essential = true
      command   = [
        "--log.level=debug",
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--web.console.libraries=/usr/share/prometheus/console_libraries",
        "--web.console.templates=/usr/share/prometheus/consoles"
      ]
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "prometheus" {
  name            = "prometheus"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1

  launch_type = "EC2"
}