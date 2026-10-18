output "monitor_url" {
  description = "Link do monitor de taxa de erros no Datadog"
  value       = "https://app.${var.datadog_site}/monitors/${datadog_monitor.auth_5xx.id}"
}

output "webhook_name" {
  description = "Handle do webhook de self-healing usado na mensagem do monitor"
  value       = "@webhook-${datadog_webhook.selfheal.name}"
}
