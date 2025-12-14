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

variable "username" {
  type = string
}

variable "password" {
  type = string
}
