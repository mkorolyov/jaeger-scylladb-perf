resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus_sg"
  description = "Allow inbound traffic for Prometheus"

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.this.id
}

resource "aws_ecs_cluster" "this" {
  name = local.ecs_cluster_name
}

resource "aws_launch_configuration" "prometheus_lc" {
  associate_public_ip_address = true
  name          = "ecs_launch_configuration"
  image_id      = local.ami_id
  instance_type = "t2.micro"
  key_name      = local.key_pair

  security_groups = [aws_security_group.prometheus_sg.id, aws_security_group.ssh.id]

  user_data = <<-EOF
                #!/bin/bash
                echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
                EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "prometheus_asg" {
  name                 = "ecs_autoscaling_group"
  launch_configuration = aws_launch_configuration.prometheus_lc.name
  desired_capacity     = 1
  min_size             = 1
  max_size             = 1

  vpc_zone_identifier = [aws_subnet.this.id]

  depends_on = [
    aws_launch_configuration.prometheus_lc,
  ]
}

resource "aws_ecs_task_definition" "prometheus_task" {
  family                   = "prometheus_task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "384"
  memory                   = "768"

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "prom/prometheus"
      cpu       = 256
      memory    = 512
      essential = true
      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--storage.tsdb.retention.time=15d",
      ],
      mountPoints = [
        {
          containerPath = "/etc/prometheus/prometheus.yml"
          sourceVolume  = "prometheus-config"
          readOnly      = true
        }
      ],
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/prometheus",
          "awslogs-region" : local.region,
          "awslogs-stream-prefix" : "prometheus"
        }
      }
    },
    {
      name      = "node-exporter"
      image     = local.node_exporter_image
      cpu       = 128
      memory    = 256
      essential = true
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
    name        = "prometheus-config"
    host_path = "../prometheus.yml"
  }

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

resource "aws_ecs_service" "prometheus_service" {
  name            = "prometheus_service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.prometheus_task.arn
  desired_count   = 1

  launch_type = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus_tg.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  depends_on = [aws_lb_listener.prometheus_listener]
}

resource "aws_lb" "prometheus_lb" {
  name               = "prometheus-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prometheus_sg.id]
  subnets            = [aws_subnet.this.id, aws_subnet.this2.id]
}

resource "aws_internet_gateway" "prometheus_igw" {
  vpc_id = aws_vpc.this.id
}

resource "aws_lb_target_group" "prometheus_tg" {
  name     = "prometheus-targetgroup"
  port     = 9090
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    interval            = 30
    path                = "/-/healthy"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

resource "aws_lb_listener" "prometheus_listener" {
  load_balancer_arn = aws_lb.prometheus_lb.arn
  port              = 9090
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus_tg.arn
  }
}

output "prometheus_url" {
  description = "Prometheus Load Balancer URL"
  value       = aws_lb.prometheus_lb.dns_name
}