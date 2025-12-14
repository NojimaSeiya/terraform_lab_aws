// modules/rds/main.tf

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
resource "aws_security_group" "db" {
  name        = "lab-db-sg"
  description = "Security group for db server (private subnet)"
  vpc_id      =var.vpc_id


  ### DB通信を許可(form app ip)

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [var.app_sg_id]
  }

  ### アウトバウンドは全許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lab-db-sg"
    Env  = "lab"
  }
}


### サブネットグループ作成
resource "aws_db_subnet_group" "db" {
  subnet_ids = var.private_subnet_ids
}


### RDS作成
resource "aws_db_instance" "db1" {

    identifier  =   "lab-db-1"
    db_name = "labdb1"
    allocated_storage       = 20
    storage_type = "gp3"

    engine = "postgres"
    instance_class = "db.t3.micro"

    db_subnet_group_name = aws_db_subnet_group.db.name
    multi_az = false
    vpc_security_group_ids = [aws_security_group.db.id]

    username                = var.username
    password                = var.password

    skip_final_snapshot     = true
    

    tags = {
        Name = "lab-db-1"
        Env = "lab"

    }

}