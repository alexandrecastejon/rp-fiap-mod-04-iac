terraform {
  required_version = ">= 1.6"
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.25"
    }
  }
  backend "s3" {}
}

# Credenciais via TF_VAR_* (GitHub Secrets). A organização é definida pelo site:
# datadoghq.com (US1), us5.datadoghq.com (US5), datadoghq.eu (EU) ...
provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.${var.datadog_site}/"
}
