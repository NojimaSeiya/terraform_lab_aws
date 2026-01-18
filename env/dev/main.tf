module "network" {
  source = "../../modules/network"
}

###module "ec2" {
### source = "../../modules/ec2"

  ###vpc_id             = module.network.vpc_id
  ###private_subnet_ids = module.network.private_subnet_ids
  ###alb_name           = module.alb.alb_name
  ###alb_sg_id          = module.alb.alb_sg_id
  ###target_group_arn   = module.alb.target_group_arn
  ###secrets_kms_key_arn = module.rds.secrets_kms_key_arn

###}

module "rds" {
  source = "../../modules/rds"

  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  app_sg_id           = module.ec2.app_sg_id
  rotation_subnet_ids = module.network.private_subnet_ids

  db_username = "nojima"
}

module "alb" {
  source = "../../modules/alb"

  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  acm_certificate_arn = "arn:aws:acm:ap-northeast-1:121333001740:certificate/0fb554bd-ee84-42c8-a5b0-74eaa63348b2"

}