output "public_ip4" {
  value = aws_instance.ecs_ec2_instance.public_ip
}