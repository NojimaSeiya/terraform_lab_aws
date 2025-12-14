output "instance_id" {
  value = aws_instance.app1.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}