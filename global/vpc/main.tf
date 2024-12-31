# Create a VPC (Virtual Private Cloud)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr # IP address range for the VPC, defined in variables
  enable_dns_support   = true         # Enables DNS resolution through AWS DNS server
  enable_dns_hostnames = true         # Enables DNS hostnames for EC2 instances in the VPC

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc" # Name tag for the VPC
  }
}

# Subnets

data "aws_availability_zones" "available" {
  state = "available"
}

# Private subnets (az1, az2, az3)

resource "aws_subnet" "private" {
  count = 3 # Create 3 private subnets

  vpc_id                  = aws_vpc.main.id                                          # ID of the VPC
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)                 # CIDR block for the subnet (16 IP addresses per subnet)
  availability_zone       = data.aws_availability_zones.available.names[count.index] # Availability zone
  map_public_ip_on_launch = false                                                    # Do not assign public IP addresses to instances in the subnet

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${count.index + 1}" # Name tag for the subnet
  }
}

# Public subnets (az1, az2, az3)

resource "aws_subnet" "public" {
  count = 3 # Create 3 public subnets

  vpc_id                  = aws_vpc.main.id                                          # ID of the VPC
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 3)             # CIDR block for the subnet (8 IP addresses per subnet)
  availability_zone       = data.aws_availability_zones.available.names[count.index] # Availability zone
  map_public_ip_on_launch = true                                                     # Assign public IP addresses to instances in the subnet

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}" # Name tag for the subnet
  }
}


# Databases subnets (az1, az2, az3)

resource "aws_subnet" "databases" {
  count = 3 # Create 3 databases subnets

  vpc_id                  = aws_vpc.main.id                                          # ID of the VPC
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 6)             # CIDR block for the subnet (8 IP addresses per subnet)
  availability_zone       = data.aws_availability_zones.available.names[count.index] # Availability zone
  map_public_ip_on_launch = false                                                    # Do not assign public IP addresses to instances in the subnet

  tags = {
    Name = "${var.project_name}-${var.environment}-databases-${count.index + 1}" # Name tag for the subnet
  }
}
