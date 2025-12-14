terraform {
  backend "s3" {
    bucket         = "nojima-terraform-tfstate-2025" # バケット名
    key            = "env/lab/terraform.tfstate"     # S3内でのパス
    region         = "ap-northeast-1"                # 東京リージョン
    dynamodb_table = "terraform-lock"                # 作ったDynamoDBテーブル名
    encrypt        = true                            # S3保存時に暗号化
  }
}
