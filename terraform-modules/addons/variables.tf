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

variable "app_repo_url" {
  description = "Repositório GitOps monitorado pelo ArgoCD"
  type        = string
  default     = "https://github.com/alexandrecastejon/rp-fiap-mod-04-app.git"
}

variable "app_namespace" {
  description = "Namespace onde as aplicações são implantadas"
  type        = string
  default     = "eks-namespace"
}

variable "datadog_api_key" {
  description = "API Key do Datadog usada pelo exporter do OTel Collector"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Site/região da conta Datadog (ex: datadoghq.com, us5.datadoghq.com, datadoghq.eu)"
  type        = string
  default     = "datadoghq.com"
}