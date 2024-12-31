# Create a VPC (Virtual Private Cloud)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr # IP address range for the VPC, defined in variables
  enable_dns_support   = true         # Enables DNS resolution through AWS DNS server
  enable_dns_hostnames = true         # Enables DNS hostnames for EC2 instances in the VPC

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc" # Name tag for the VPC
  }
}
