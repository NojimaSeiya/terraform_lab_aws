// modules/alb/main.tf

### プロバイダー宣言
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

### SG設定
resource "aws_security_group" "alb" {
  name        = "lab-alb-sg"
  description = "Security group for alb"
  vpc_id      = var.vpc_id


  ### WEB通信を許可(form any)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }

  ### アウトバウンドは全許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lab-alb-sg"
    Env  = "lab"
  }
}

### ALB作成
resource "aws_lb" "alb" {
  name                   = "app-alb"
  security_groups = [aws_security_group.alb.id]
  subnets             = var.public_subnet_ids
  internal            = false

  tags = {
    Name = "lab-alb"
    Env  = "lab"
  }

}

### ターゲットグループ作成
resource "aws_lb_target_group" "alb" {
  name     = "lab-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    interval            = 30
    path                = "/index.html"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

### リスナー作成
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    
      redirect {
        port = "443"
        protocol = "HTTPS"
        status_code = "HTTP_301"
      }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }

}

