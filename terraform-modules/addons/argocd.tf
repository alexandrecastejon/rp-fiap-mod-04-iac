resource "helm_release" "argocd" {
  depends_on       = [helm_release.ingress_nginx]
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argo-cd"
  create_namespace = true
  version          = "7.4.4"
  timeout          = 600
  values = [
    <<-EOT
    dex:
      enabled: false
    server:
      extraArgs:
        - --insecure
      ingress:
        enabled: true
        ingressClassName: "nginx"
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        hosts:
          - "${var.eks_argocd_domain_name}"
        tls:
          - hosts:
              - "${var.eks_argocd_domain_name}"
            secretName: "argocd-tls-cert"
    EOT
  ]
}

# Obter a senha - Gitbash
# kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo