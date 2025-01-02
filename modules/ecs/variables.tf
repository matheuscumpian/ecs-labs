variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "example"
}

variable "organization" {
  description = "The name of the organization"
  type        = string
  default     = "example-org-cf87eb"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ECS instances"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "additional_tags" {
  description = "Additional tags to add to resources"
  type        = map(string)
  default     = {}
}

variable "allowed_http_ingress_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the ALB over HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_ingress_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the ALB over HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
