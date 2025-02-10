locals {
  vpc-cidr              = var.vpc-cidr
  vpc-name              = var.vpc-name
  subnets               = var.subnets
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = local.vpc-cidr

  tags = {
    Name = local.vpc-name
  }
}

# 서브넷 생성 (public/private)
resource "aws_subnet" "subnets" {
  for_each = local.subnets
  vpc_id = aws_vpc.main_vpc.id

  cidr_block = cidrsubnet(local.vpc-cidr, 3, each.value.cidr_idx) # create cidr
  availability_zone = each.value.az
  map_public_ip_on_launch = each.value.subnet_type == "public" ? false : true #public subnet 만 public ip 허용

  tags = {
    Name       = each.key
    SubnetType = each.value.subnet_type
  }
}

# 인터넷 게이트웨이 (퍼블릭 서브넷 연결)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# 퍼블릭 라우트 테이블 생성 (인터넷 연결 O)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id  # 인터넷 게이트웨이를 통한 외부 연결
  }

  tags = {
    Name = "public-route-table"
  }
}

# 퍼블릭 서브넷을 퍼블릭 라우트 테이블에 연결
resource "aws_route_table_association" "public_assoc" {
  for_each = { for k, v in local.subnets : k => v if v.subnet_type == "public" }

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.public_rt.id
}

# 프라이빗 라우트 테이블 생성 (인터넷 연결 X)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  # 기본 VPC 내부 통신만 허용 (외부 연결 없음)
  route {
    cidr_block = local.vpc-cidr
    gateway_id = "local"
  }

  tags = {
    Name = "private-route-table"
  }
}

# 프라이빗 서브넷을 프라이빗 라우트 테이블에 연결
resource "aws_route_table_association" "private_assoc" {
  for_each = { for k, v in local.subnets : k => v if v.subnet_type == "private" }

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.private_rt.id
}