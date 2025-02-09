provider "aws" {
  region = "ap-northeast-2"  # 원하는 리전으로 변경 가능
}

variable "vpc_id" {
  description = "VPC ID where EKS will be deployed"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnets for EKS worker nodes"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}