output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "app_sg_id" {
  value = aws_security_group.app.id
}