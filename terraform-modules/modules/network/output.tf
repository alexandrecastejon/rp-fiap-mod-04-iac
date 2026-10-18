output "vpc_id" {
  description = "Exporta o ID da VPC recém criada"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "Exporta o CIDR da VPC recém criada"
  value       = aws_vpc.main.cidr_block
}

output "elastic_ip" {
  description = "Exporta o Elastic IP do NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}

output "private_subnet_NameA" {
  description = "Exporta o ID da Sub-rede Pública"
  value       = aws_subnet.publicA.tags
}

output "private_subnet_NameB" {
  description = "Exporta o ID da Sub-rede Pública"
  value       = aws_subnet.publicB.tags
}

output "public_subnet_idA" {
  description = "Exporta o ID da Sub-rede Pública"
  value       = aws_subnet.publicA.id
}

output "public_subnet_idB" {
  description = "Exporta o ID da Sub-rede Pública"
  value       = aws_subnet.publicB.id
}

output "private_subnet_idA" {
  description = "Exporta o ID da Sub-rede Privada"
  value       = aws_subnet.privateA.id
}

output "private_subnet_idB" {
  description = "Exporta o ID da Sub-rede Privada"
  value       = aws_subnet.privateB.id
}