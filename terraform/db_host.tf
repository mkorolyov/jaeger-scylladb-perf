module "db_host" {
  source = "./ecs_instance"
  deployment_host = "db-host"
  security_group = aws_security_group.scylladb_sg.id
  subnet_id = aws_subnet.this.id
  vpc_id = aws_vpc.this.id
  instance_type = "t2.medium"
  ecs_cluster_id = aws_ecs_cluster.this.id
  aim_instance_profile = aws_iam_instance_profile.instance_profile-infra.name
  ecs_task_role_arn = aws_iam_role.ecs_task_role.arn
}