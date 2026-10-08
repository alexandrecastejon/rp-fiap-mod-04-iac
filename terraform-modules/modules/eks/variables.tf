variable "cluster_name" {
  description = "Nome do Cluster EKS"
  type        = string
}

variable "subnet_ids" {
  description = "Ids das Subnets"
  type        = list(string)
}

variable "allowed_ips" {
  description = "IPs permitidos para acessar o endpoint público"
  type        = list(string)
}

variable "node_instance_type" {
  description = "Tamanho das máquinas do EKS"
  type        = string
  default     = "t3.medium"
}