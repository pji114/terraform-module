locals {
  private_subnet = var.private_subnets
  public_subnet = var.public_subnets
  vpc_id  = var.vpc_id
  cluster_name = var.cluster_name
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${local.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach EKS required policies to cluster IAM Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Create EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = var.private_subnets
  }

  tags = {
    Name = var.cluster_name
  }
}

# IAM Role for EKS Worker Nodes
resource "aws_iam_role" "eks_worker_role" {
  name = "${local.cluster_name}-eks-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach EKS worker node required policies
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# EKS Node Group
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-worker-group"
  node_role_arn   = aws_iam_role.eks_worker_role.arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.micro"]

  tags = {
    Name = "${var.cluster_name}-worker-group"
  }
}


# ALB Ingress Controller를 위한 IAM 정책
resource "aws_iam_policy" "alb_ingress_policy" {
  name        = "${local.cluster_name}-alb-ingress-policy"
  description = "Policy for ALB Ingress Controller"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeLoadBalancers",
        "ec2:DescribeTargetGroups",
        "ec2:DescribeTags",
        "elasticloadbalancing:*"
      ]
      Resource = "*"
    }]
  })
}

# ALB Ingress Controller에 대한 IAM Role 추가
resource "aws_iam_role" "alb_ingress_role" {
  name = "${local.cluster_name}-alb-ingress-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# ALB Ingress Controller IAM 역할에 정책 연결
resource "aws_iam_role_policy_attachment" "alb_ingress_policy_attach" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_policy.arn
}

# ALB용 보안 그룹 생성
resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Security group for ALB Ingress"
  vpc_id      = local.vpc_id

  # Inbound: HTTP 트래픽 허용 (필요하면 HTTPS도 추가)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 모든 외부 트래픽 허용 (보안 강화 필요)
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTPS 트래픽 허용
  }

  # Outbound: 모든 트래픽 허용 (EKS 노드로 트래픽 전달)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-alb-sg"
  }
}

# ALB 리소스 수정 (보안 그룹 연결)
resource "aws_lb" "alb" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]  # ✅ 수정된 부분
  subnets           = var.public_subnets  # 퍼블릭 서브넷에 배포

  tags = {
    Name = "${var.cluster_name}-alb"
  }
}


# Application Load Balancer (ALB) 생성
resource "aws_lb" "alb" {
  name               = "${local.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = var.public_subnets  # 퍼블릭 서브넷에 배포

  tags = {
    Name = "${local.cluster_name}-alb"
  }
}

# Target Group 생성 (EKS 서비스 연결)
resource "aws_lb_target_group" "tg" {
  name     = "${local.cluster_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ALB Listener 설정 (Ingress 역할)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Egress 설정 - NAT Gateway를 사용하여 외부로 나가는 트래픽 처리
resource "aws_nat_gateway" "eks_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = local.public_subnet[0]

  tags = {
    Name = "eks-nat-gateway"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

# 프라이빗 서브넷의 라우트 테이블 설정 (NAT Gateway를 통해 Egress)
resource "aws_route_table" "private_rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat.id
  }

  tags = {
    Name = "eks-private-route-table"
  }
}

# 프라이빗 서브넷을 라우트 테이블에 연결
resource "aws_route_table_association" "private_assoc" {
  for_each = toset(var.private_subnets)

  subnet_id      = each.value
  route_table_id = aws_route_table.private_rt.id
}