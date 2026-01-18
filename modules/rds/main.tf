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

  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]

  skip_final_snapshot = true


  tags = {
    Name = "lab-db-1"
    Env  = "lab"

  }

}

### SecretsManager用 KMS Key
resource "aws_kms_key" "secrets" {
  description = "KMS key for Secrets Manager (RDS credentials)"
  deletion_window_in_days = 7

  tags = {
    Name = "lab-secrets-kms"
    Env = "lab"
  }
}

resource "aws_kms_alias" "secrets" {
  name = "alias/lab-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}


### ランダムパスワード生成
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&()*+,-.:;<=>?[]^_{|}~"
}

### シークレット作成
resource "aws_secretsmanager_secret" "db" {
  name = "lab/rds/postgres/master"
  kms_key_id = aws_kms_key.secrets.arn
}

### バージョン作成
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.db1.address
    port     = aws_db_instance.db1.port
    dbname   = aws_db_instance.db1.db_name
    username = var.db_username
    password = random_password.db.result

  })

}

### lamda作成
resource "aws_serverlessapplicationrepository_cloudformation_stack" "rotation" {
  name = "lab-postgres-rotation"

  ### AWS提供のテンプレ
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_RESOURCE_POLICY"
  ]

  parameters = { endpoint = "https://secretsmanager.ap-northeast-1.amazonaws.com"
    functionName        = "lab-postgres-rotation"
    vpcSubnetIds        = join(",", var.rotation_subnet_ids)
    vpcSecurityGroupIds = join(",", [var.app_sg_id])

  }
}

### lamdaをシークレットに紐づけ
resource "aws_secretsmanager_secret_rotation" "db" {
  secret_id           = aws_secretsmanager_secret.db.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rotation.outputs["RotationLambdaARN"]

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [
    aws_secretsmanager_secret_version.db,
    aws_serverlessapplicationrepository_cloudformation_stack.rotation
  ]
}

