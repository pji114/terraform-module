variable "vpc-cidr" {
  type = string
}

variable "vpc-name" {
  type = string
}

variable "subnets" {
  type = map(object({
    az          = string
    cidr_idx    = number
    subnet_type = string
  }))
}