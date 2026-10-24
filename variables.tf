variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix applied to all resource tag"
  type        = string
  default     = "secure-bastion-gateway"
}

variable "vpc_cidr" {
  description = " CIDR block for VPC. cannot be changed after creation. "
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZ to spread subnet across. Order matters and must match the subnet lists."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR block for public subnet, one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR block for private subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}
