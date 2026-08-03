locals {
  cidr_block   = "10.0.0.0/16"
  subnet_count = 3

  availability_zones = slice(data.aws_availability_zones.available.names, 0, local.subnet_count)
  public_subnets     = [for i in range(local.subnet_count) : cidrsubnet(local.cidr_block, 8, i + 1)]
  private_subnets    = [for i in range(local.subnet_count) : cidrsubnet(local.cidr_block, 8, i + 11)]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = local.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.public_subnets[count.index]
  availability_zone = local.availability_zones[count.index]

  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count = length(local.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each   = toset(local.availability_zones)
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw" {
  vpc_id            = aws_vpc.vpc.id
  connectivity_type = "public"
  availability_mode = "regional"

  dynamic "availability_zone_address" {
    for_each = aws_eip.nat
    content {
      availability_zone = availability_zone_address.key
      allocation_ids    = [availability_zone_address.value.id]
    }
  }
}

resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.availability_zones[count.index]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
}

resource "aws_route_table_association" "private" {
  count = length(local.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
