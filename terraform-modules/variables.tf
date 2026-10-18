variable "aws_region" {
  description = "A região onde a infraestrutura será criada"
  type        = string
}

variable "admin_user_names" {
  description = "Usuários IAM da conta que recebem acesso de administrador ao cluster EKS"
  type        = list(string)
  default     = ["alexandrecastejon"]
}

variable "allow_ips" {
  description = "CIDRs com acesso ao endpoint público da API do Kubernetes (runners hospedados do GitHub exigem 0.0.0.0/0)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_cluster_name" {
  description = "Nome do Cluster EKS"
  type        = string
}

variable "ecr_repos" {
  description = "Mapa de configurações dos repositórios ECR (Docker)"
  type = map(object({
    identifier = string
  }))
  default = {
    auth = {
      identifier = "ecr-auth-service-01"
    }
    flag = {
      identifier = "ecr-flag-service-01"
    }
    targeting = {
      identifier = "ecr-targeting-service-01"
    }
    evaluation = {
      identifier = "ecr-evaluation-service-01"
    }
    analytics = {
      identifier = "ecr-analytics-service-01"
    }
  }
}

variable "cache_cluster_name" {
  description = "O nome do cluster de cache ElastiCache"
  type        = string
  default     = "cache-cluster-01"
}

variable "sqs_queue_name" {
  description = "Mapa com os nomes das filas SQS"
  type        = string
  default     = "EventQueue"
}

variable "dynamodb_table_name" {
  description = "O nome da tabela DynamoDB para armazenar as configurações dos microsserviços"
  type        = string
  default     = "ToggleMasterAnalytics"
}

variable "rds_dbs" {
  description = "Mapa de configurações dos bancos de dados dos microserviços"
  type = map(object({
    identifier = string
    database   = string
  }))
  default = {
    auth = {
      identifier = "rds-auth-db-01"
      database   = "auth_db"
    }
    flag = {
      identifier = "rds-flag-db-01"
      database   = "flags_db"
    }
    targeting = {
      identifier = "rds-targeting-db-01"
      database   = "targeting_db"
    }
  }
}

variable "db_user" {
  description = "O nome de usuário do banco de dados PostgreSQL"
  type        = string
}

variable "db_pass" {
  description = "A senha do banco de dados PostgreSQL"
  type        = string
  sensitive   = true
}