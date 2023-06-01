provider "aws" {
  region = local.region
}

variable "instance_type" {}
variable "deployment_host" {}
variable "vpc_id" {}
variable "subnet_id" {}
variable "security_group" {}
variable "ecs_cluster_id" {}
variable "aim_instance_profile" {}
variable "ecs_task_role_arn" {}

resource "aws_instance" "ecs_ec2_instance" {
  ami                         = local.ami_id # Amazon Linux 2 LTS
  instance_type               = var.instance_type
  key_name                    = local.key_pair
  vpc_security_group_ids      = [var.security_group]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  iam_instance_profile        = var.aim_instance_profile

  tags = {
    Name = var.deployment_host
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
    ECS_INSTANCE_ATTRIBUTES={\"deployment-host\":\"${var.deployment_host}\"}
    " >> /etc/ecs/ecs.config
    EOF
}

resource "aws_ecs_task_definition" "node_exporter" {
  family                   = "${var.deployment_host}_node_exporter"
  network_mode             = "bridge"
  execution_role_arn       = var.ecs_task_role_arn
  task_role_arn            = var.ecs_task_role_arn
  requires_compatibilities = ["EC2"]
  cpu                      = "128"
  memory                   = "128"

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:deployment-host == ${var.deployment_host}"
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
  name            = "${var.deployment_host}-node_exporter"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.node_exporter.arn
  desired_count   = 1

  launch_type = "EC2"
}
