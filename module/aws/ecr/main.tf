locals {
  cluster_name  = var.cluster_name
}

resource "aws_ecr_repository" "app_repository" {
  name                 = "${local.cluster_name}-app-repo"
  image_tag_mutability = "MUTABLE"  # 같은 태그 덮어쓰기 가능
  force_delete         = true       # Terraform destroy 시 ECR 자동 삭제

  image_scanning_configuration {
    scan_on_push = true  # 보안 스캔 활성화
  }

  tags = {
    Name = "${local.cluster_name}-app-repo"
  }
}

# EKS 노드가 ECR에 접근할 수 있도록 IAM 정책 추가
resource "aws_iam_policy" "ecr_access" {
  name        = "${local.cluster_name}-ecr-access-policy"
  description = "Allow EKS nodes to access ECR"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = aws_ecr_repository.app_repository.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# EKS 노드 IAM 역할에 ECR 접근 정책 부여
resource "aws_iam_role_policy_attachment" "eks_ecr_access" {
  policy_arn = aws_iam_policy.ecr_access.arn
  role       = aws_iam_role.eks_worker_role.name  # 기존 EKS Worker Role 사용
}