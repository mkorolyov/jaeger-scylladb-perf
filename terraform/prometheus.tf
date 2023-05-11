resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus_sg"
  description = "Allow inbound traffic for Prometheus"

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

resource "aws_ecs_cluster" "this" {
  name = "scylladb-ecs-cluster"
}

resource "aws_launch_configuration" "prometheus_lc" {
  name                        = "prometheus"
  associate_public_ip_address = true
  image_id                    = local.ami_id
  instance_type               = "t2.micro"
  key_name                    = local.key_pair
  iam_instance_profile        = aws_iam_instance_profile.instance_profile-infra.name

  security_groups = [aws_security_group.prometheus_sg.id, aws_security_group.ssh.id]

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
                " >> /etc/ecs/ecs.config
                EOF

#  lifecycle {
#    create_before_destroy = false
#  }
}

resource "aws_autoscaling_group" "prometheus_asg" {
  launch_configuration = aws_launch_configuration.prometheus_lc.name
  desired_capacity     = 1
  min_size             = 1
  max_size             = 1

  vpc_zone_identifier = [aws_subnet.this.id]

  #  tags = [
  #    {
  #      key   = "prometheus_node"
  #      value = "true"
  #      propagate_at_launch = true
  #    }
  #  ]

#  tag {
#    key                 = "prometheus_node"
#    value               = "true"
#    propagate_at_launch = true
#  }

  depends_on = [
    aws_launch_configuration.prometheus_lc,
  ]
}

data "aws_ecr_authorization_token" "token" {}

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

  provisioner "local-exec" {
    command = <<EOF
      docker login ${data.aws_ecr_authorization_token.token.proxy_endpoint} -u AWS -p ${data.aws_ecr_authorization_token.token.password}
      docker buildx build --platform linux/amd64 -t prometheus ../prometheus
      docker tag prometheus:latest ${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/prometheus:latest
      docker push ${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/prometheus:latest
    EOF
  }
}

resource "aws_ecs_task_definition" "prometheus_task" {
  family                   = "prometheus_task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "384"
  memory                   = "384"

  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_task_role.arn

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
      #      logConfiguration = {
      #        "logDriver" : "awslogs",
      #        "options" : {
      #          "awslogs-group" : "/ecs/prometheus",
      #          "awslogs-region" : local.region,
      #          "awslogs-stream-prefix" : "prometheus"
      #        }
      #      }
    },
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

#resource "aws_cloudwatch_log_group" "prometheus_log_group" {
#  name = "/ecs/prometheus"
#  #  role_arn = aws_iam_role.prometheus-logs.arn
#}

#resource "aws_cloudwatch_log_metric_filter" "prometheus_log_group_subscription" {
#  name           = "prometheus-log-group-subscription"
#  pattern        = ""
#  log_group_name = aws_cloudwatch_log_group.prometheus_log_group.name
#
#  metric_transformation {
#    name      = "EventCount"
#    namespace = "JaegerScyllaDB"
#    value     = "1"
#  }
#}

resource "aws_lb" "prometheus_lb" {
  name               = "prometheus-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prometheus_sg.id]
  subnets            = [aws_subnet.this.id, aws_subnet.this2.id]
}

resource "aws_lb_target_group" "prometheus_tg" {
  port     = 9090
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    interval            = 30
    path                = "/metrics"
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