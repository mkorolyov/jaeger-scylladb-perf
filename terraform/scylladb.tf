resource "aws_security_group" "scylladb_sg" {
  name        = "scylladb"
  description = "Allow all necessary ports for ScyllaDB"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 0
    to_port     = 9044
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "scylladb_task" {
  family                   = "scylladb"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:deployment-host == db-host"
  }

  container_definitions = jsonencode([
    {
      name         = "scylladb-1"
      image        = local.scylladb_image
      cpu          = 512
      memory       = 1024
      essential    = true
      portMappings = [
        {
          containerPort = 9042
          hostPort      = 9042
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "SCYLLA_SEEDS"
          value = "127.0.0.1"
        }
      ]
    },
    {
      name         = "scylladb-2"
      image        = local.scylladb_image
      cpu          = 512
      memory       = 1024
      essential    = true
      portMappings = [
        {
          containerPort = 9043
          hostPort      = 9043
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "SCYLLA_SEEDS"
          value = "127.0.0.1"
        }
      ]
    },
    {
      name         = "scylladb-3"
      image        = local.scylladb_image
      cpu          = 512
      memory       = 1024
      essential    = true
      portMappings = [
        {
          containerPort = 9044
          hostPort      = 9044
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "SCYLLA_SEEDS"
          value = "127.0.0.1"
        }
      ]
    },
  ])
}

resource "aws_ecs_service" "scylladb" {
  name            = "scylladb"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.scylladb_task.arn
  desired_count   = 1
  launch_type     = "EC2"
}