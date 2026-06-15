module "vpc" {
  source      = "./modules/vpc"
  vpc_cidr    = "10.0.0.0/16"
  environment = var.environment
}

module "iam" {
  source      = "./modules/iam"
  environment = var.environment
}

module "eks" {
  source             = "./modules/eks"
  environment        = var.environment
  cluster_role_arn   = module.iam.cluster_role_arn
  node_role_arn      = module.iam.node_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "rds" {

  source = "./modules/rds"

  environment = var.environment

  private_subnet_ids = module.vpc.private_subnet_ids

  vpc_id = module.vpc.vpc_id
}