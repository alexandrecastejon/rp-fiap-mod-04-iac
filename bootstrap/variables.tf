variable "aws_region" {
  description = "Região onde o bucket de state e as roles serão criados"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_prefix" {
  description = "Prefixo do bucket de state; o ID da conta é adicionado para garantir nome único"
  type        = string
  default     = "togglemaster-tfstate"
}

variable "sqs_queue_name" {
  description = "Fila SQS usada pelo teste de carga do KEDA no pipeline de aplicações"
  type        = string
  default     = "EventQueue"
}

variable "github_owner" {
  description = "Usuário ou organização dona dos repositórios no GitHub"
  type        = string
  default     = "alexandrecastejon"
}

variable "github_owner_id" {
  description = "ID numérico do dono dos repositórios (gh api users/<owner> --jq .id)"
  type        = string
  default     = "106316080"
}

variable "iac_repo_id" {
  description = "ID numérico do repositório de IaC (gh api repos/<owner>/<repo> --jq .id)"
  type        = string
  default     = "1424274829"
}

variable "app_repo_id" {
  description = "ID numérico do repositório de aplicações"
  type        = string
  default     = "1424274878"
}

variable "iac_repo" {
  description = "Repositório de infraestrutura que pode assumir a role de IaC"
  type        = string
  default     = "rp-fiap-mod-04-iac"
}

variable "app_repo" {
  description = "Repositório de aplicações que pode assumir a role de CI das apps"
  type        = string
  default     = "rp-fiap-mod-04-app"
}
