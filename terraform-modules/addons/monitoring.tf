resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true
  version    = "57.2.0"
  values = [
    <<-EOT
    grafana:
      additionalDataSources:
        - name: Loki
          type: loki
          url: http://loki:3100
          access: proxy      
      ingress:
        enabled: true
        ingressClassName: "nginx"
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        hosts:
          - "${var.eks_grafana_domain_name}"
        tls:
          - hosts:
              - "${var.eks_grafana_domain_name}"
            secretName: "grafana-tls-cert"
    prometheus:
      ingress:
        enabled: true
        ingressClassName: "nginx"
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        hosts:
          - "${var.eks_prometheus_domain_name}"
        tls:
          - hosts:
              - "${var.eks_prometheus_domain_name}"
            secretName: "prometheus-tls-cert"
    EOT
  ]
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = "monitoring"
  create_namespace = true
  version    = "2.10.2"
  values = [
    <<-EOT
    grafana:
      enabled: false
    promtail:
      enabled: true
    loki:
      isDefault: false
    EOT
  ]
}