// modules/network/main.tf

### プロバイダー宣言
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

### VPCの作成
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "lab-vpc"
    Env  = "lab"
  }
}

### AZ情報の取得
data "aws_availability_zones" "available" {
  state = "available"
}

### パブリックサブネットの作成
resource "aws_subnet" "public" {

  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "lab-public-${count.index}"
    Env  = "lab"
    Type = "Public"

  }
}

### インターネットゲートウェイの作成
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "lab-igw"
    Env  = "lab"
  }
}


### パブリックサブネット用ルートテーブル作成
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id


  tags = {
    Name = "lab-public-rt"
    Env  = "lab"
  }
}

### ルート追加
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

### サブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

### プライベートサブネットの作成
resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "lab-private-${count.index}"
    Env  = "lab"
    Type = "private"
  }
}

### プライベートサブネット用ルートテーブル作成
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "lab-private-rt"
    Env  = "lab"
  }
}

### サブネットとルートテーブルの関連付け
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


### NAT Gateway用ElasticIP
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "lab-nat-eip"
    Env  = "lab"
  }
}

### Nat Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [
    aws_internet_gateway.this
  ]

  tags = {
    Name = "lab-nat-gw"
    Env  = "lab"
  }
}

### プライベートルートテーブルにNAT向けデフォルトルート追加
resource "aws_route" "private_default_via_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}










