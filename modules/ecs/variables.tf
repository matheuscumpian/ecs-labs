locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "example"
}

variable "organization" {
  description = "The name of the organization"
  type        = string
  default     = "example-org-cf87eb"
}

variable "environment" {
  description = "The environment to deploy to"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}


variable "public_subnet_ids" {
  description = "The IDs of the public subnets"
  type        = list(string)
}


variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
