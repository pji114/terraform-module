locals {
  vpc_name       = "Application-VPC"
  private_subnets = [for s in data.aws_subnet.private_subnets_filtered : s.id if can(regex("private_app*", s.tags["Name"]))]
  public_subnets  = [for s in data.aws_subnet.private_subnets_filtered : s.id if can(regex("public_*", s.tags["Name"]))]
  vpc_id = data.aws_vpc.selected_vpc.id
}

data "aws_vpc" "selected_vpc" {
  filter {
    name   = "tag:Name"
    values = [local.vpc_name]  # 원하는 VPC 이름 입력
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected_vpc.id]  # 위에서 조회한 VPC ID 사용
  }
}

data "aws_subnet" "private_subnets_filtered" {
  for_each = toset(data.aws_subnets.private_subnets.ids)

  id = each.value
}

output "all_subnets" {
  value = data.aws_vpc.selected_vpc
}

output "private_subnets" {
  value = local.private_subnets
}

output "public_subnets" {
  value = local.public_subnets
}