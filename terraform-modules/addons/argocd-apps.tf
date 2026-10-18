locals {
  togglemaster_services = ["auth-service", "flag-service", "targeting-service", "evaluation-service", "analytics-service"]
}

# Applications do ArgoCD declaradas como código (antes eram criadas manualmente na UI).
# O AppProject limita o que o GitOps pode fazer: só o repositório das aplicações,
# só o namespace das aplicações e só o tipo de recurso que o repositório GitOps contém.
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
      }
      applications = {
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
          syncPolicy = {
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
        }
      }
    })
  ]
}
