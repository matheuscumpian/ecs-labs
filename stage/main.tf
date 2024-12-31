# Terraform block: Configures Terraform settings including required providers and backend configuration
terraform {
  # Define the required providers for this Terraform configuration
  required_providers {
    aws = {
      source  = "hashicorp/aws" # Official AWS provider from HashiCorp
      version = "~> 5.0"        # Use version 5.x.x of the provider, allowing minor version updates
    }
  }

  # Configure Terraform Cloud as the backend
  cloud {
    organization = "example-org-cf87eb" # Organization name in Terraform Cloud

    # Workspace configuration for different environments
    workspaces {
      name = "ecs-labs-stage"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1" # Set AWS region to US East (N. Virginia)
}

module "vpc" {
  source = "git::https://github.com/matheuscumpian/ecs-labs.git//global/vpc?ref=main"

  environment  = var.environment
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}
