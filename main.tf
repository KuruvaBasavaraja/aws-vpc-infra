resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  tags                 = merge(var.common_tags, var.vpc_tags, { Name = local.resource_name })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(var.common_tags, var.igw_tags, { Name = local.resource_name })
}

resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.az_names[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  tags = merge(
    var.common_tags,
    var.public_subnet_tags,
    {
      Name = "${local.resource_name}-public-${local.az_names[count.index]}"
    }
  )
}

resource "aws_subnet" "private_subnet" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = local.az_names[count.index]
  cidr_block        = var.private_subnet_cidrs[count.index]
  tags = merge(
    var.common_tags,
    var.private_subnet_tags,
    {
      Name = "${local.resource_name}-private-${local.az_names[count.index]}"
    }
  )
}

resource "aws_subnet" "database_subnet" {
  count             = length(var.database_subnet_cidrs)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = local.az_names[count.index]
  cidr_block        = var.database_subnet_cidrs[count.index]
  tags = merge(
    var.common_tags,
    var.database_subnet_tags,
    {
      Name = "${local.resource_name}-database-${local.az_names[count.index]}"
    }
  )
}

###DB subnet group for RDS###
resource "aws_db_subnet_group" "rds_snet_group" {
  name       = local.resource_name
  subnet_ids = aws_subnet.database_subnet[*].id

  tags = merge(
    var.common_tags,
    var.db_subnet_group_tags,
    {
      Name = local.resource_name
    }
  )
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "natgateway" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = merge(
    var.common_tags,
    var.natgateway_tags,
    {
      Name = local.resource_name
    }
  )
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.common_tags,
    var.public_route_table_tags,
    {
      Name = "${local.resource_name}-public"
    }
  )
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.common_tags,
    var.private_route_table_tags,
    {
      Name = "${local.resource_name}-private"
    }
  )
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.common_tags,
    var.database_route_table_tags,
    {
      Name = "${local.resource_name}-database"
    }
  )
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgateway.id
}

resource "aws_route" "database_route" {
  route_table_id         = aws_route_table.database.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgateway.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  count          = length(var.database_subnet_cidrs)
  subnet_id      = aws_subnet.database_subnet[count.index].id
  route_table_id = aws_route_table.database.id
}

