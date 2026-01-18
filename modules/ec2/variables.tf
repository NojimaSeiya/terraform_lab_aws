// modules/ec2/variables.tf
variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "alb_name" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "secrets_kms_key_arn" {
  type = string
}
