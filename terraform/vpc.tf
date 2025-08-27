# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# ========================================
# NAT GATEWAYS - CURRENTLY DISABLED FOR COST SAVINGS
# ========================================
# 
# COST ANALYSIS:
# - 2 NAT Gateways = $65/month ($32.40 each)  
# - This exceeds our entire $40/month budget!
# 
# CURRENT APPROACH:
# - RDS in private subnet (no internet access needed)
# - EC2 in public subnet (direct internet via IGW)
# - No private subnet internet access required
# 
# WHEN TO ENABLE:
# - If private subnet services need internet access
# - If Lambda functions require VPC + internet
# - Cost budget increases to >$100/month
# 
# TO ENABLE: Uncomment resources below and run terraform apply

# Elastic IPs for NAT Gateways (DISABLED - COST SAVINGS)
# resource "aws_eip" "nat" {
#   count = var.enable_nat_gateway ? length(aws_subnet.public) : 0

#   domain = "vpc"
#   depends_on = [aws_internet_gateway.main]

#   tags = {
#     Name = "${var.project_name}-nat-eip-${count.index + 1}"
#   }
# }

# NAT Gateways (DISABLED - COST SAVINGS: $65/month)
# resource "aws_nat_gateway" "main" {
#   count = var.enable_nat_gateway ? length(aws_subnet.public) : 0

#   allocation_id = aws_eip.nat[count.index].id
#   subnet_id     = aws_subnet.public[count.index].id

#   tags = {
#     Name = "${var.project_name}-nat-${count.index + 1}"
#   }

#   depends_on = [aws_internet_gateway.main]
# }

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Tables for Private Subnets
# NOTE: No internet routes since NAT Gateways are disabled for cost savings
# Private subnet resources (RDS) don't need internet access
resource "aws_route_table" "private" {
  count = length(aws_subnet.private)

  vpc_id = aws_vpc.main.id

  # No default route - private subnets are fully isolated
  # This saves $65/month in NAT Gateway costs
  # 
  # To enable internet access via NAT Gateway:
  # 1. Uncomment NAT Gateway resources above
  # 2. Add variable: enable_nat_gateway = true
  # 3. Uncomment the route block below
  
  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.main[count.index].id
  # }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}