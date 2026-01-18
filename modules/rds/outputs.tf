// modules/rds/outputs.tf

# 必要になったら後で追加していく

output "secrets_kms_key_arn" {
  value = aws_kms_key.secrets.arn
}
