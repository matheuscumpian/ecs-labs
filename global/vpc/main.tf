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

# Private subnets (larger blocks)
resource "aws_subnet" "private" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index) # /24 blocks: 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"
  }
}

# Public subnets
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 3) # /24 blocks: 10.0.3.0/24, 10.0.4.0/24, 10.0.5.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
  }
}

# Database subnets
resource "aws_subnet" "databases" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 6) # /24 blocks: 10.0.6.0/24, 10.0.7.0/24, 10.0.8.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-databases-${count.index + 1}"
  }
}

# Internet Gateway

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id # ID of the VPC

  tags = {
    Name = "${var.project_name}-${var.environment}-ig" # Name tag for the Internet Gateway
  }
}



# Elastic IPs

resource "aws_eip" "nat" {
  domain = "vpc" # Allocate the Elastic IP in the VPC

  tags = {
    Name = "${var.project_name}-${var.environment}-nat" # Name tag for the Elastic IP
  }
}


resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id # ID of the Elastic IP

  subnet_id = aws_subnet.public[0].id # ID of the public subnet

  depends_on = [
    aws_internet_gateway.main,
    aws_subnet.public
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-1"
    }
  )
}


# Route table

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id # ID of the VPC

  depends_on = [aws_vpc.main]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id # ID of the VPC

  depends_on = [aws_vpc.main]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

# Routes

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"                  # Route all traffic to the Internet Gateway
  gateway_id             = aws_internet_gateway.main.id # Internet Gateway ID

  depends_on = [
    aws_route_table.public,
    aws_internet_gateway.main
  ]
}


resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id

  depends_on = [
    aws_route_table.private,
    aws_nat_gateway.main
  ]
}

# Route table associations

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# Parameter Store

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project_name}/${var.environment}/vpc_id"
  type  = "String"
  value = aws_vpc.main.id

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}


resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/private_subnet_ids"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)

  depends_on = [aws_subnet.private]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}


resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/public_subnet_ids"
  type  = "StringList"
  value = join(",", aws_subnet.public[*].id)

  depends_on = [aws_subnet.public]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}


resource "aws_ssm_parameter" "databases_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/databases_subnet_ids"
  type  = "StringList"
  value = join(",", aws_subnet.databases[*].id)

  depends_on = [aws_subnet.databases]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}


resource "aws_ssm_parameter" "nat_gateway_id" {
  name  = "/${var.project_name}/${var.environment}/nat_gateway_id"
  type  = "String"
  value = aws_nat_gateway.main.id

  depends_on = [aws_nat_gateway.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}


resource "aws_ssm_parameter" "internet_gateway_id" {
  name  = "/${var.project_name}/${var.environment}/internet_gateway_id"
  type  = "String"
  value = aws_internet_gateway.main.id

  depends_on = [aws_internet_gateway.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}
