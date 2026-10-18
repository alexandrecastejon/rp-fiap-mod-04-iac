# Virtual Private Cloud (VPC)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.vpc_name }
}

# Internet Gateway para Acesso Externo
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = var.igw_name }
}

# Sub-rede Pública 1 (Para Load Balancers EKS - AZ a)
resource "aws_subnet" "publicA" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 6, 1) # Ex: 10.0.4.0/22
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name                     = var.subnet_publicA_name
    "kubernetes.io/role/elb" = "1"
  }
}

# Sub-rede Pública 2 (Para Load Balancers EKS - AZ b)
resource "aws_subnet" "publicB" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 6, 2) # Ex: 10.0.8.0/22
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = {
    Name                     = var.subnet_publicB_name
    "kubernetes.io/role/elb" = "1"
  }
}

# Sub-rede Privada 1 (Para o EKS Nodes e RDS - AZ a)
resource "aws_subnet" "privateA" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 6, 3) # Ex: 10.0.12.0/22
  availability_zone = "${var.region}a"
  tags = {
    Name                              = var.subnet_privateA_name
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Sub-rede Privada 2 (Para o EKS Nodes e RDS - AZ b)
resource "aws_subnet" "privateB" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 6, 4) # Ex: 10.0.16.0/22
  availability_zone = "${var.region}b"
  tags = {
    Name                              = var.subnet_privateB_name
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# IP Fixo (Elastic IP) para o NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = var.nat_eip_name }
}

# NAT Gateway
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.publicA.id
  tags          = { Name = var.nat_gw_name }
  depends_on    = [aws_internet_gateway.igw]
}

# Tabela de Rotas Pública e Associação
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = var.rt_public_name }
}

resource "aws_route_table_association" "public_assoc" {
  for_each = {
    "publicA" = aws_subnet.publicA.id
    "publicB" = aws_subnet.publicB.id
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.public_rt.id
}

# Tabela de Rotas Privada e Associação
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }
  tags = { Name = var.rt_private_name }
}

resource "aws_route_table_association" "private_assoc" {
  for_each = {
    "privateA" = aws_subnet.privateA.id
    "privateB" = aws_subnet.privateB.id
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.private_rt.id
}
