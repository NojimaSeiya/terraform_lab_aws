output "alb_name" {
  value = aws_lb.alb.name
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "target_group_arn" {
  value = aws_lb_target_group.alb.arn
}