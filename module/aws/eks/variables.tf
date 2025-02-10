provider "aws" {
  region = "ap-northeast-2"  # 원하는 리전으로 변경 가능
}

variable "vpc_name" {
  description = "Name of the VPC"
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}

