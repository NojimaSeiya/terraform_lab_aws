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

resource "aws_iam_role_policy" "ec2_read_db_secret" {
  name = "ec2-read-db-secret"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadRDSSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
         Resource = "arn:aws:secretsmanager:ap-northeast-1:121333001740:secret:lab/rds/postgres/master-*"
      },
      {
        Sid    = "DecryptSecretsWithKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.secrets_kms_key_arn
      }
    ]
  })
}


### SG設定
resource "aws_security_group" "app" {
  name        = "lab-app-sg"
  description = "Security group for app server (private subnet)"
  vpc_id      = var.vpc_id


  ### WEB通信を許可(form alb)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
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

### 起動テンプレート作成
resource "aws_launch_template" "app" {
  name                   = "lab-app-lt"
  image_id               = data.aws_ami.al2023.id
  iam_instance_profile { name = aws_iam_instance_profile.ec2_ssm_profile.name }
  instance_type = "t3.micro"


  ### パブリックIP無効化
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  ### 起動時にSSMエージェントとApacheをインストール＆起動
  user_data = base64encode(<<-EOF
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

              TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              echo "Hello from  $${INSTANCE_ID}" > /var/www/html/index.html

              EOF
  )

}

### ASG作成
resource "aws_autoscaling_group" "app" {
  name = "lab-app-asg"
  launch_template { 
    id  = aws_launch_template.app.id
    version = "$Latest"
    
    }
  vpc_zone_identifier       = var.private_subnet_ids
  max_size                  = 6
  min_size                  = 2
  desired_capacity          = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  target_group_arns = [var.target_group_arn]


}



