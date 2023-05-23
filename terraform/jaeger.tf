resource "aws_security_group" "jaeger-server" {
  name        = "jaeger-server"
  description = "Allow all necessary ports for jaeger-server"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 14268
    to_port     = 14269
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 16686
    to_port     = 16686
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 14250
    to_port     = 14250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "jaeger-server_host" {
  source               = "./ecs_instance"
  deployment_host      = "jaeger-server"
  security_group       = aws_security_group.jaeger-server.id
  subnet_id            = aws_subnet.this.id
  vpc_id               = aws_vpc.this.id
  instance_type        = "t2.micro"
  ecs_cluster_id       = aws_ecs_cluster.this.id
  aim_instance_profile = aws_iam_instance_profile.instance_profile-infra.name
  ecs_task_role_arn    = aws_iam_role.ecs_task_role.arn
}

resource "aws_ecs_task_definition" "jaeger-server" {
  family                   = "jaeger-server"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:deployment-host == jaeger-server"
  }

  container_definitions = jsonencode([
    {
      name         = "jaeger-server"
      image        = "jaegertracing/jaeger-collector:latest"
      cpu          = 512
      memory       = 512
      essential    = true
      portMappings = [
        {
          containerPort = 16686
          hostPort      = 16686
          protocol      = "tcp"
        },
        {
          containerPort = 14250
          hostPort      = 14250
          protocol      = "tcp"
        },
        {
          containerPort = 14268
          hostPort      = 14268
          protocol      = "tcp"
        },
        {
          containerPort = 14269
          hostPort      = 14269
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "SPAN_STORAGE_TYPE"
          value = "cassandra"
        },
        {
          name  = "CASSANDRA_SERVERS"
          value = "${module.db_host.public_ip4}"
        },
        {
          name  = "CASSANDRA_KEYSPACE"
          value = "jaeger_v1_datacenter1"
        },
        {
          name  = "JAEGER_REPORTER_TYPE"
          value = "prometheus"
        },
      ]
    },
  ])
}

resource "aws_ecs_service" "jaeger-server" {
  name            = "jaeger-server"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.jaeger-server.arn
  desired_count   = 1
  launch_type     = "EC2"
}