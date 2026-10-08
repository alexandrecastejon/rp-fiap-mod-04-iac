variable "aws_region" {
  description = "A região onde a infraestrutura será criada"
  type        = string
}

variable "aws_bucket_iac_name" {
  description = "Nome do bucket aonde esta armazenado o state da infraestrutura criada"
  type        = string
}

variable "aws_bucket_iac_folder_name" {
  description = "Nome da pasta dentro bucket aonde esta armazenado o state da infraestrutura criada"
  type        = string
}

variable "eks_cluster_name" {
  description = "Nome do Cluster EKS"
  type        = string
}

variable "eks_argocd_domain_name" {
  description = "Endereço de domínio de publicação do ArgoCD"
  type        = string
}

variable "eks_grafana_domain_name" {
  description = "Endereço de domínio de publicação do Grafana"
  type        = string
}

variable "eks_prometheus_domain_name" {
  description = "Endereço de domínio de publicação do Prometheus"
  type        = string
}