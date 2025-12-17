// modules/rds/main.tf

### プロバイダー宣言
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

### SG設定
resource "aws_security_group" "db" {
  name        = "lab-db-sg"
  description = "Security group for db server (private subnet)"
  vpc_id      = var.vpc_id


  ### DB通信を許可(form app ip)

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
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
  name       = "lab-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}


### RDS作成
resource "aws_db_instance" "db1" {

  identifier        = "lab-db-1"
  db_name           = "labdb1"
  allocated_storage = 20
  storage_type      = "gp3"

  engine         = "postgres"
  instance_class = "db.t3.micro"
  multi_az       = true

  username = var.username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]

  skip_final_snapshot = true


  tags = {
    Name = "lab-db-1"
    Env  = "lab"

  }

}

### ランダムパスワード生成
resource "random_password" "db" {
  length  = 24
  special = true
}

### シークレット作成
resource "aws_sebcretsmanager" "db" {
  name = "lab/rds/postgres/master"
}

### バージョン作成
resource "aws_secretsmanager_secret_version" "db" {
  sercret_id = aws_secretsmanager_secret.db.id

  secret_string = jdonencode({
    engine   = "postgres"
    host     = aws_db_instance.db1.address
    port     = aws_db_instance.db1.port
    dbname   = aws_db_instance.db1.db_name
    username = var.name
    password = random_password.db.result

  })

}

### シークレットの紐づけ
resource "aws_secretsmanager_secret_target_attachment" "db" {
  secret_id   = aws_sebcretsmanager.id
  target_id   = aws_db_instance.db1.id
  target_type = "AWS::RDS::DBInstance"

  depends_on = [aws_secretsmanager_secret_version.db]
}

### lamda作成
resource "aws_serverlessapplicationrepository_cloudformation_stack" "rotation" {
  name = "lab-postgres-rotation"

  ### AWS提供のテンプレ
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  capabilities   = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]
  parameters = { endpoint = "https://secretsmanager.ap-northeast-1.amazonaws.com"
    functionName        = "lab-postgres-rotation"
    vpcSubnetIds        = join(",", var.rotation_subnet_ids)
    vpcSecurityGroupIds = join(",", [var.app_sg_id])

  }
}
