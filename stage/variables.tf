### GENERAL CONFIGS

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

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
