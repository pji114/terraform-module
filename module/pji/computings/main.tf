locals {
  vpc_name = var.vpc_name
  cluster_name = var.cluster_name
}

module "pji-eks" {
  source = "../../aws/eks"
  vpc_name = local.vpc_name
}

module "ecr" {
  source = "../../aws/ecr"
  cluster_name = local.cluster_name
}