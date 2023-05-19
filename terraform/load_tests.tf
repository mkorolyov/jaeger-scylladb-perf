resource "aws_security_group" "load_tests" {
  name        = "load_tests"
  description = "Allow traffic for load tests"

  ingress {
    from_port   = 9100
    to_port     = 9101
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

module "load_tests_host" {
  source               = "./ecs_instance"
  deployment_host      = "load_tests"
  security_group       = aws_security_group.load_tests.id
  subnet_id            = aws_subnet.this.id
  vpc_id               = aws_vpc.this.id
  instance_type        = "t2.micro"
  ecs_cluster_id       = aws_ecs_cluster.this.id
  aim_instance_profile = aws_iam_instance_profile.instance_profile-infra.name
  ecs_task_role_arn    = aws_iam_role.ecs_task_role.arn
}

resource "aws_ecr_repository" "load_tests" {
  name                 = "load_tests"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  lifecycle {
    prevent_destroy = false
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_task_definition" "load_tests" {
  family                   = "load_tests"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:deployment-host == load_tests"
  }

  container_definitions = jsonencode([
    {
      name      = "busybox"
      image     = "busybox:latest"
      cpu       = 32
      memory    = 32
      essential = true
    },
    {
      name        = "load_tests"
      image       = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/load_tests:latest"
      cpu         = 256
      memory      = 256
      essential   = false
      environment = [
        {
          name  = "CONCURRENCY"
          value = "10"
        },
        {
          name  = "SPANS_COUNT"
          value = "10"
        },
        {
          name  = "TAGS_COUNT"
          value = "10"
        },
        {
          name  = "DURATION_S"
          value = "60"
        },
        {
          name  = "JAEGER_COLLECTOR_HOST"
          value = "${module.jaeger-server_host.public_ip4}"
        }
      ]
      portMappings = [
        {
          containerPort = 9101
          hostPort      = 9101
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "load_tests" {
  name            = "load_tests"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.load_tests.arn
  desired_count   = 1

  launch_type = "EC2"
}