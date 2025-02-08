locals {
  subnets   = var.subnets
  vpc-cidr  = var.vpc-cidr
  vpc-name  = var.vpc-name
}

module "computing-vpc" {
  source = "../../aws/vpc"
  subnets = local.subnets
  vpc-cidr = local.vpc-cidr
  vpc-name = local.vpc-name
}