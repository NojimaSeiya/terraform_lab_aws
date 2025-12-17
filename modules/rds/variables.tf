// modules/rds/variables.tf

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type = string
}

variable "db_username" {
  type = string
}

variable "rotation_subnet_ids" {
  type = list(string)
}

variable "rotation_days" {
  type    = number
  default = 30
}
