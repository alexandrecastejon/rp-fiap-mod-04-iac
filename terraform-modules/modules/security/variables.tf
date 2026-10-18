variable "vpc_id" {
  description = "ID da VPC onde os Security Groups serão criados"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC onde os Security Groups serão criados"
  type        = string
}

variable "nsg_cache_name" {
  description = "Nome Cache NSG"
  type        = string
  default     = "nsg-cache-01"
}

variable "nsg_rds_name" {
  description = "Nome RDS NSG"
  type        = string
  default     = "nsg-rds-01"
}