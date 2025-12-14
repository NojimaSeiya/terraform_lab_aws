module "network" {
  source = "../../modules/network"
}

module "ec2" {
  source = "../../modules/ec2"

  vpc_id            = module.network.vpc_id
  private_subnet_id = module.network.private_subnet_ids[0]
}

module "rds" {
  source = "../../modules/rds"

  vpc_id            = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  app_sg_id          = module.ec2.app_sg_id
  
  username = "nojima"
  password = "nojima2358"
}