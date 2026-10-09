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
    global:
      domain: "${var.eks_argocd_domain_name}"
    dex:
      enabled: false
    configs:
      cm:
        url: "https://${var.eks_argocd_domain_name}"
    server:
      ingress:
        enabled: true
        controller: generic
        ingressClassName: "nginx"
        hostname: "${var.eks_argocd_domain_name}"
        path: /
        pathType: Prefix
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        extraTls:
          - hosts:
              - "${var.eks_argocd_domain_name}"
            secretName: "argocd-tls-cert"
    EOT
  ]
}

# Obter a senha - Gitbash
# kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo