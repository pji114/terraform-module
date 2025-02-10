locals {
  vpc_name = var.vpc_name
}

module "pji-eks" {
  source = "../../aws/eks"
  vpc_name = local.vpc_name
}