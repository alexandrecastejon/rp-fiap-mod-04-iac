locals {
  runbook_url = "https://github.com/${var.github_repo}/blob/main/docs/runbooks/auth-service-5xx.md"
  apm_url     = "https://app.${var.datadog_site}/apm/entity/service:${var.monitored_service}?env=${var.environment}"

  webhook_name    = "selfheal-github"
  pagerduty_route = "@pagerduty-${var.pagerduty_service_name}"
  slack_route     = var.slack_account_name == "" ? "" : "@slack-${var.slack_account_name}-${var.slack_channel}"

  metric_filter = "env:${var.environment},service:${var.monitored_service}"
}

# ------------------------------------------------------------------
# Objetos criados ao conectar as integrações pelo console do Datadog são
# adotados pelo código (import), em vez de duplicados. Após a primeira
# importação estes blocos não têm efeito.
# ------------------------------------------------------------------
import {
  to = datadog_integration_pagerduty_service_object.togglemaster
  id = var.pagerduty_service_name
}

import {
  for_each = var.slack_account_name == "" ? toset([]) : toset(["alertas"])
  to       = datadog_integration_slack_channel.alertas[0]
  id       = "${var.slack_account_name}:#${var.slack_channel}"
}

# ------------------------------------------------------------------
# PagerDuty: serviço que recebe os incidentes (integração já instalada no tile)
# ------------------------------------------------------------------
resource "datadog_integration_pagerduty_service_object" "togglemaster" {
  service_name = var.pagerduty_service_name
  service_key  = var.pagerduty_integration_key
}

# ------------------------------------------------------------------
# Slack (ChatOps): canal com a notificação detalhada
# ------------------------------------------------------------------
resource "datadog_integration_slack_channel" "alertas" {
  count        = var.slack_account_name == "" ? 0 : 1
  account_name = var.slack_account_name
  channel_name = "#${var.slack_channel}"

  display {
    message      = true
    notified     = true
    snapshot     = true
    tags         = true
    mute_buttons = true
  }
}

# ------------------------------------------------------------------
# Self-healing: webhook que dispara o workflow do GitHub Actions
# (workflow_dispatch). O token só tem "Actions: write" no repositório de IaC.
# ------------------------------------------------------------------
resource "datadog_webhook" "selfheal" {
  name      = local.webhook_name
  url       = "https://api.github.com/repos/${var.github_repo}/actions/workflows/self-healing.yml/dispatches"
  encode_as = "json"

  custom_headers = jsonencode({
    Authorization          = "Bearer ${var.github_selfheal_token}"
    Accept                 = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
  })

  # Variáveis $ALERT_* são substituídas pelo Datadog no envio
  payload = jsonencode({
    ref = "main"
    inputs = {
      deployment   = var.monitored_deployment
      alert_id     = "$ALERT_ID"
      alert_title  = "$EVENT_TITLE"
      alert_status = "$ALERT_TRANSITION"
      alert_link   = "$LINK"
    }
  })
}

# ------------------------------------------------------------------
# Alerta: taxa de erros HTTP 5xx do auth-service (métricas de trace do APM)
# ------------------------------------------------------------------
resource "datadog_monitor" "auth_5xx" {
  name     = "[ToggleMaster] ${var.monitored_service} - taxa de erros HTTP 5xx acima de ${var.error_rate_critical}%"
  type     = "query alert"
  priority = 2

  query = join("", [
    "sum(last_5m):100 * sum:trace.${var.apm_operation}.errors{${local.metric_filter}}.as_count()",
    " / sum:trace.${var.apm_operation}.hits{${local.metric_filter}}.as_count()",
    " > ${var.error_rate_critical}",
  ])

  monitor_thresholds {
    critical          = var.error_rate_critical
    critical_recovery = var.error_rate_warning
    warning           = var.error_rate_warning
  }

  require_full_window = false
  notify_no_data      = false
  include_tags        = true
  renotify_interval   = 0

  # Fadiga de alertas: aviso só vai para o Slack; plantão (PagerDuty) e
  # automação só no crítico; a recuperação resolve o incidente automaticamente.
  message = <<-EOT
    {{#is_alert}}
    🚨 **${var.monitored_service}: {{value}}% das requisições com erro HTTP 5xx** (limite: {{threshold}}%)

    **Impacto:** a validação de API keys falha; flag-service, targeting-service e evaluation-service passam a responder com erro.
    **Ação automática:** self-healing acionado — `kubectl rollout restart deployment/${var.monitored_deployment}` via GitHub Actions.
    **Investigar:** [APM do serviço](${local.apm_url}) · [Runbook](${local.runbook_url})
    @webhook-${local.webhook_name}
    {{/is_alert}}

    {{#is_warning}}
    ⚠️ **${var.monitored_service}: taxa de erro 5xx em {{value}}%** (aviso em {{warn_threshold}}%). Sem ação automática por enquanto.
    {{/is_warning}}

    {{#is_recovery}}
    ✅ **${var.monitored_service} recuperado:** taxa de erro 5xx em {{value}}%. Incidente resolvido automaticamente.
    {{/is_recovery}}

    {{#is_alert}}${local.pagerduty_route}{{/is_alert}}{{#is_alert_recovery}}${local.pagerduty_route}{{/is_alert_recovery}}
    ${local.slack_route}
  EOT

  tags = [
    "env:${var.environment}",
    "service:${var.monitored_service}",
    "team:togglemaster",
    "managed-by:terraform",
  ]

  depends_on = [
    datadog_webhook.selfheal,
    datadog_integration_pagerduty_service_object.togglemaster,
  ]
}
