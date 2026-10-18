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

variable "app_repo_url" {
  description = "Repositório GitOps monitorado pelo ArgoCD"
  type        = string
  default     = "https://github.com/alexandrecastejon/rp-fiap-mod-04-app.git"
}

variable "iac_repo_url" {
  description = "Repositório com os valores GitOps da stack de observabilidade"
  type        = string
  default     = "https://github.com/alexandrecastejon/rp-fiap-mod-04-iac.git"
}

variable "app_namespace" {
  description = "Namespace onde as aplicações são implantadas"
  type        = string
  default     = "eks-namespace"
}
