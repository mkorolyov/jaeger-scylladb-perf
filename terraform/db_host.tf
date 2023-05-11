resource "aws_instance" "db_host" {
  ami                         = local.ami_id # Amazon Linux 2 LTS
  instance_type               = "t2.medium"
  key_name                    = local.key_pair
  security_groups             = [aws_security_group.ssh.id, aws_security_group.scylladb_sg.id]
  subnet_id                   = aws_subnet.this.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.instance_profile-infra.name

  tags = {
    Name = "db-host"
  }

  user_data = <<-EOF
     #!/bin/bash
    sudo echo "ECS_DISABLE_METRICS=true
    ECS_UPDATES_ENABLED=true
    ECS_ENGINE_TASK_CLEANUP_WAIT_DURATION=15m
    ECS_IMAGE_CLEANUP_INTERVAL=10m
    ECS_CONTAINER_STOP_TIMEOUT=60s
    ECS_RESERVED_MEMORY=128
    ECS_ENABLE_TASK_IAM_ROLE=true
    ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
    ECS_NUM_IMAGES_DELETE_PER_CYCLE=50
    ECS_CLUSTER=${local.ecs_cluster_name}
    ECS_INSTANCE_ATTRIBUTES={\"deployment-host\":\"db-host\"}
    " >> /etc/ecs/ecs.config
    EOF
}

resource "aws_ecs_task_definition" "db_node_exporter_task" {
  family                   = "node_exporter"
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  requires_compatibilities = ["EC2"]
  cpu                      = "128"
  memory                   = "128"

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:deployment-host == db-host"
  }

  container_definitions = jsonencode([
    {
      name         = "node-exporter"
      image        = local.node_exporter_image
      cpu          = 128
      memory       = 128
      essential    = true
      portMappings = [
        {
          containerPort = 9100
          hostPort      = 9100
          protocol      = "tcp"
        }
      ],
      mountPoints = [
        {
          containerPath = "/host/proc"
          sourceVolume  = "proc"
          readOnly      = true
        },
        {
          containerPath = "/host/sys"
          sourceVolume  = "sys"
          readOnly      = true
        },
        {
          containerPath = "/host"
          sourceVolume  = "root"
          readOnly      = true
        }
      ]
    }
  ])

  volume {
    name      = "proc"
    host_path = "/proc"
  }

  volume {
    name      = "sys"
    host_path = "/sys"
  }

  volume {
    name      = "root"
    host_path = "/"
  }
}

resource "aws_ecs_service" "db_node_exporter" {
  name            = "db_node_exporter"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.db_node_exporter_task.arn
  desired_count   = 1

  launch_type = "EC2"
}