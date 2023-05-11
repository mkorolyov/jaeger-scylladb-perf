resource "aws_iam_role" "prometheus-logs" {
  name = "prometheus-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

#resource "aws_iam_role_policy" "ecs_policy" {
#  name = "ecs-policy-infra"
#  role = aws_iam_role.ecs_task_role.id
#
#  depends_on = [aws_iam_role.ecs_task_role]
#  policy     = <<EOF
#{
#    "Version": "2012-10-17",
#    "Statement": [
#      {
#        "Action": [
#          "ecr:GetAuthorizationToken",
#          "ecr:BatchCheckLayerAvailability",
#          "ecr:GetDownloadUrlForLayer",
#          "ecr:BatchGetImage",
#          "ecr:DescribeRepositories",
#          "ec2:DescribeInstances"
#        ],
#        "Effect": "Allow",
#        "Resource": "*"
#        }
#    ]
#}
#EOF
#}

resource "aws_iam_role_policy" "ecs_policy" {
  name = "ecs-policy-infra"
  role = aws_iam_role.ecs_task_role.id

  depends_on = [aws_iam_role.ecs_task_role]
  policy     = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "*",
        "Effect": "Allow",
        "Resource": "*"
        }
    ]
}
EOF
}


resource "aws_iam_role_policy" "instance_policy" {
  name = "instance_policy-infra"
  role = aws_iam_role.instance_role-infra.id

  depends_on = [aws_iam_role.instance_role-infra]
  policy     = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "ecs:*",
          "es:*",
          "logs:*",
          "cloudwatch:*",
          "ec2:*",
          "ecr:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "instance_role-infra" {
  name               = "instance_role-infra"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecr_access_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ecs_task_role.name
}

resource "aws_iam_role_policy_attachment" "ce2_ecr_access_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.instance_role-infra.name
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "instance_profile-infra" {
  name       = "instance_profile-infra"
  role       = aws_iam_role.instance_role-infra.name
  depends_on = [aws_iam_role.instance_role-infra]
}