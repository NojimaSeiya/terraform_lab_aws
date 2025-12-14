// modules/ec2/main.tf

### プロバイダー宣言
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

### AMI作成
data "aws_ami" "al2023" {
  most_recent = true # 最新のAMIを取得
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

### IAM設定
resource "aws_iam_role" "ec2_ssm_role" {
  name = "lab-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "lab-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

### SG設定
resource "aws_security_group" "app" {
  name        = "lab-app-sg"
  description = "Security group for app server (private subnet)"
  vpc_id      =var.vpc_id


  ### WEB通信を許可(form my ip)

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["106.72.191.107/32"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["106.72.191.107/32"]
  }

  ### アウトバウンドは全許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lab-app-sg"
    Env  = "lab"
  }
}

### EC2作成
resource "aws_instance" "app1" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name


  ### パブリックIP無効化
  associate_public_ip_address = false

  ### 起動時にSSMエージェントとApacheをインストール＆起動
  user_data = <<-EOF
              #! /bin/bash

              dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              
              dnf update -y
              dnf install -y httpd

              systemctl enable httpd
              systemctl start httpd

              dnf install -y postgresql15
              systemctl enable postgresql15
              systemctl start postgresql15

              echo "Hello World from Terraform Web Server" > /var/www/html/index.html
              EOF

  tags = {
    Name = "lab-app-1"
    Env  = "lab"
    Role = "app"
  }
}
