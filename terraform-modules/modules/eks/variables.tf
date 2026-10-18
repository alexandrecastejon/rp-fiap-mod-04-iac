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

variable "cluster_admin_arns" {
  description = "ARNs IAM (usuários/roles) com acesso de administrador ao cluster"
  type        = list(string)
}

variable "app_deployer_arn" {
  description = "ARN da role do pipeline das aplicações (acesso restrito ao namespace)"
  type        = string
}

variable "selfheal_role_arn" {
  description = "ARN da role do workflow de self-healing (mapeada para RBAC restrito)"
  type        = string
}

variable "app_namespace" {
  description = "Namespace onde as aplicações são implantadas"
  type        = string
  default     = "eks-namespace"
}

variable "node_instance_type" {
  description = "Tamanho das máquinas do EKS"
  type        = string
  default     = "t3.medium"
}