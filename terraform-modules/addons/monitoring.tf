resource "helm_release" "kube_prometheus_stack" {
  depends_on = [helm_release.ingress_nginx]
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
  depends_on = [helm_release.ingress_nginx]
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

resource "helm_release" "opentelemetry_collector" {
  depends_on = [helm_release.ingress_nginx]
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = "monitoring"
  create_namespace = true
  version    = "0.87.1"
  values = [
    <<-EOT
    mode: deployment
    config:
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318
      exporters:
        otlp/newrelic:
          endpoint: "otlp.nr-data.net:4317"
          headers:
            "api-key": "${var.new_relic_license_key}"
        prometheusremotewrite:
          endpoint: "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/write"
          tls:
            insecure: true
        loki:
          endpoint: "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
      service:
        pipelines:
          traces:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [otlp/newrelic]
          metrics:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [prometheusremotewrite, otlp/newrelic]
    EOT
  ]
}