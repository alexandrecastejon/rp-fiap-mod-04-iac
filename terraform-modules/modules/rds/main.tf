# Subnet Group Relational Database Service (RDS)
resource "aws_db_subnet_group" "db_subnet" {
  description = "Subnets para o banco de dados via Terraform"
  subnet_ids  = var.subnet_ids
}

# Relational Database Service (RDS)
resource "aws_db_instance" "postgres" {
  identifier             = var.rds_name
  engine                 = "postgres"
  engine_version         = "17.9"
  instance_class         = var.instance_class
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_pass
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = var.security_groups
  multi_az               = false
  publicly_accessible    = false
  storage_encrypted      = true
  skip_final_snapshot    = true
  deletion_protection    = false
  tags                   = { Name = var.rds_name }
}
