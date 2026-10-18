variable "datadog_api_key" {
  description = "API key da organização Datadog"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Application key usada pelo Terraform para gerenciar monitores e integrações"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Site da organização Datadog (ex: us5.datadoghq.com)"
  type        = string
  default     = "us5.datadoghq.com"
}

variable "environment" {
  description = "Valor da tag env (definido no OTel Collector como deployment.environment.name)"
  type        = string
  default     = "fiap-fase4"
}

variable "monitored_service" {
  description = "Serviço APM monitorado pelo alerta de taxa de erro"
  type        = string
  default     = "auth-service"
}

variable "monitored_deployment" {
  description = "Deployment reiniciado pelo self-healing quando o alerta dispara"
  type        = string
  default     = "auth-deployment"
}

variable "apm_operation" {
  description = "Nome da operação APM dos spans HTTP de servidor (prefixo das métricas trace.<operação>.hits/errors)"
  type        = string
  default     = "http.server.request"
}

variable "error_rate_critical" {
  description = "Percentual de erros 5xx que dispara o alerta crítico"
  type        = number
  default     = 5
}

variable "error_rate_warning" {
  description = "Percentual de erros 5xx que gera aviso (sem acionar plantão nem automação)"
  type        = number
  default     = 2
}

variable "pagerduty_service_name" {
  description = "Nome do serviço no PagerDuty que recebe os incidentes"
  type        = string
  default     = "togglemaster-auth-service"
}

variable "pagerduty_integration_key" {
  description = "Integration key (Events API) do serviço no PagerDuty"
  type        = string
  sensitive   = true
}

variable "slack_account_name" {
  description = "Nome da conta Slack conectada no tile do Datadog (vazio = sem notificação no Slack)"
  type        = string
  default     = ""
}

variable "slack_channel" {
  description = "Canal do Slack que recebe os alertas"
  type        = string
  default     = "togglemaster-alertas"
}

variable "github_repo" {
  description = "Repositório (owner/nome) que hospeda o workflow de self-healing"
  type        = string
  default     = "alexandrecastejon/rp-fiap-mod-04-iac"
}

variable "github_selfheal_token" {
  description = "Fine-grained token do GitHub (somente Actions: write no repositório de IaC) usado pelo webhook"
  type        = string
  sensitive   = true
}
