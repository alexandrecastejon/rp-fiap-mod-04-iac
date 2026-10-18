locals {
  togglemaster_services = ["auth-service", "flag-service", "targeting-service", "evaluation-service", "analytics-service"]

  monitoring_values_path = "gitops/platform/monitoring"

  sync_policy = {
    automated = {
      prune    = true
      selfHeal = true
    }
    retry = {
      limit = 10
      backoff = {
        duration    = "30s"
        factor      = 2
        maxDuration = "10m"
      }
    }
  }

  # Stack de observabilidade gerenciada por GitOps: chart Helm oficial +
  # arquivo de valores versionado neste repositório (multi-source do ArgoCD)
  monitoring_charts = {
    kube-prometheus-stack = {
      repo        = "https://prometheus-community.github.io/helm-charts"
      chart       = "kube-prometheus-stack"
      version     = "92.10.1"
      values_file = "kube-prometheus-stack.yaml"
      values_extra = {
        grafana = {
          ingress = {
            hosts = [var.eks_grafana_domain_name]
            tls   = [{ secretName = "grafana-tls-cert", hosts = [var.eks_grafana_domain_name] }]
          }
        }
      }
    }
    loki = {
      repo         = "https://grafana.github.io/helm-charts"
      chart        = "loki"
      version      = "7.3.0"
      values_file  = "loki.yaml"
      values_extra = {}
    }
    otel-collector = {
      repo         = "https://open-telemetry.github.io/opentelemetry-helm-charts"
      chart        = "opentelemetry-collector"
      version      = "0.176.0"
      values_file  = "otel-gateway.yaml"
      values_extra = {}
    }
    otel-agent = {
      repo         = "https://open-telemetry.github.io/opentelemetry-helm-charts"
      chart        = "opentelemetry-collector"
      version      = "0.176.0"
      values_file  = "otel-agent.yaml"
      values_extra = {}
    }
  }

  monitoring_apps = {
    for name, c in local.monitoring_charts : name => {
      namespace  = "argo-cd"
      project    = "platform"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      sources = [
        {
          repoURL        = c.repo
          chart          = c.chart
          targetRevision = c.version
          helm = {
            releaseName  = name
            valueFiles   = ["$values/${local.monitoring_values_path}/${c.values_file}"]
            valuesObject = c.values_extra
          }
        },
        {
          repoURL        = var.iac_repo_url
          targetRevision = "main"
          ref            = "values"
        },
      ]
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "monitoring"
      }
      # ServerSideApply: os CRDs do Prometheus Operator excedem o limite de annotations
      syncPolicy = merge(local.sync_policy, { syncOptions = ["CreateNamespace=true", "ServerSideApply=true"] })
    }
  }

  dashboards_app = {
    monitoring-dashboards = {
      namespace  = "argo-cd"
      project    = "platform"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      source = {
        repoURL        = var.iac_repo_url
        targetRevision = "main"
        path           = "${local.monitoring_values_path}/dashboards"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "monitoring"
      }
      syncPolicy = local.sync_policy
    }
  }

  togglemaster_apps = {
    for svc in local.togglemaster_services : svc => {
      namespace  = "argo-cd"
      project    = "togglemaster"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      source = {
        repoURL        = var.app_repo_url
        targetRevision = "main"
        path           = "${svc}/k8s/deployment"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      syncPolicy = local.sync_policy
    }
  }
}

# Applications do ArgoCD declaradas como código (antes eram criadas manualmente na UI).
# Cada AppProject limita o que o GitOps pode fazer:
#   togglemaster: só o repositório das aplicações, só o namespace delas, só Deployments
#   platform:     só os charts oficiais da stack de observabilidade + este repositório
resource "helm_release" "argocd_apps" {
  depends_on = [helm_release.argocd]
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argo-cd"
  version    = "2.0.7"
  values = [
    yamlencode({
      projects = {
        togglemaster = {
          namespace   = "argo-cd"
          description = "Microsserviços do ToggleMaster"
          sourceRepos = [var.app_repo_url]
          destinations = [{
            server    = "https://kubernetes.default.svc"
            namespace = var.app_namespace
          }]
          clusterResourceWhitelist = []
          namespaceResourceWhitelist = [
            { group = "apps", kind = "Deployment" },
          ]
        }
        platform = {
          namespace   = "argo-cd"
          description = "Stack de observabilidade (Prometheus, Grafana, Loki, OTel)"
          sourceRepos = concat(distinct([for c in local.monitoring_charts : c.repo]), [var.iac_repo_url])
          destinations = [
            { server = "https://kubernetes.default.svc", namespace = "monitoring" },
            # kube-prometheus-stack cria Services de scrape do control plane em kube-system
            { server = "https://kubernetes.default.svc", namespace = "kube-system" },
          ]
          # Os charts instalam CRDs, ClusterRoles e webhooks
          clusterResourceWhitelist   = [{ group = "*", kind = "*" }]
          namespaceResourceWhitelist = [{ group = "*", kind = "*" }]
        }
      }
      applications = merge(local.togglemaster_apps, local.monitoring_apps, local.dashboards_app)
    })
  ]
}
