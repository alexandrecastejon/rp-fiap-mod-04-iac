# Runbook — auth-service com taxa de erros HTTP 5xx acima de 5%

| | |
|---|---|
| **Alerta** | `[ToggleMaster] auth-service - taxa de erros HTTP 5xx acima de 5%` (Datadog) |
| **Severidade** | P2 — degrada toda a plataforma (flag, targeting e evaluation dependem do auth) |
| **Automação** | Self-healing: `kubectl rollout restart deployment/auth-deployment` |
| **Código** | [`terraform-modules/datadog`](../../terraform-modules/datadog) · [`self-healing.yml`](../../.github/workflows/self-healing.yml) |

## Fluxo automático

```
Datadog (trace.http.server.request: errors/hits do auth-service > 5% em 5 min)
  ├─> PagerDuty  : abre incidente no serviço togglemaster-auth-service
  ├─> Slack      : notificação detalhada em #togglemaster-alertas
  └─> Webhook    : GitHub Actions "self-healing" (workflow_dispatch)
        └─> OIDC -> role gha-togglemaster-selfheal -> RBAC só de rollout restart
              └─> kubectl rollout restart deployment/auth-deployment
Recuperação (< 2%): Datadog resolve o incidente no PagerDuty e avisa no Slack
```

Níveis (prevenção de fadiga de alertas):

| Nível | Limite | Notifica | Automação |
|---|---|---|---|
| Aviso | ≥ 2% | Slack | não |
| Crítico | > 5% | Slack + PagerDuty | sim |
| Recuperação | < 2% | Slack + resolve PagerDuty | não |

## Diagnóstico manual (se a automação não resolver)

1. **Confirmar o sintoma** — Datadog APM → serviço `auth-service` (env `fiap-fase4`): taxa de erro e traces com erro.
2. **Logs** — Grafana → dashboard *ToggleMaster - Saúde do Ecossistema* → painel de logs com `deployment = auth-deployment`, ou no Loki:
   ```logql
   {k8s_namespace_name="eks-namespace", k8s_deployment_name="auth-deployment"} |~ "(?i)error"
   ```
3. **Estado dos pods**
   ```bash
   kubectl -n eks-namespace get pods -l app=auth-service
   kubectl -n eks-namespace describe deployment auth-deployment
   ```
4. **Causas conhecidas**
   - *Injeção de falha ativa* (demonstração): `GET /admin/chaos` mostra `error_rate > 0`. O restart zera o estado.
   - *Banco indisponível*: erros de conexão no log → verificar a instância RDS `rds-auth-db-01`.
5. **Ação corretiva manual** — Actions → *FIAP - MODULO 04 - SELF-HEALING* → *Run workflow* com `auth-deployment`.

## Demonstração (prova real)

```bash
# 1) Injetar 100% de falha no /validate (MASTER_KEY do Secret auth-secret; /admin só via port-forward)
MASTER_KEY=$(kubectl -n eks-namespace get secret auth-secret -o jsonpath='{.data.MASTER_KEY}' | base64 -d)
kubectl -n eks-namespace port-forward deploy/auth-deployment 8001:8001 &
curl -s -X POST localhost:8001/admin/chaos -H "Authorization: Bearer $MASTER_KEY" -d '{"error_rate": 100}'

# 2) Gerar tráfego no /validate do auth-service (rota pública; /auth/admin é bloqueada no Ingress)
for i in $(seq 1 600); do curl -s -o /dev/null -w "%{http_code} " -H "Authorization: Bearer demo" https://apis.togglemaster.click/auth/validate; sleep 0.5; done

# 3) Acompanhar o restart automático
kubectl -n eks-namespace get pods -l app=auth-service -w
```
