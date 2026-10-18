# Bootstrap (executar uma única vez)

Cria a base de confiança que os pipelines precisam **antes** de existirem:

| Recurso | Para quê |
|---|---|
| Bucket S3 `togglemaster-tfstate-<account-id>` | State remoto do Terraform (versionado, criptografado, sem acesso público, só TLS) |
| Provedor OIDC `token.actions.githubusercontent.com` | GitHub Actions obtém credenciais AWS temporárias, sem access keys |
| Role `gha-togglemaster-iac` | Assumida só pela `main` e pelos environments com aprovação do repositório de IaC |
| Role `gha-togglemaster-app` | Menor privilégio: push nos 5 ECRs + leitura dos endpoints usados no deploy |
| Role `gha-togglemaster-selfheal` | Só o workflow de self-healing (environment `SELF_HEALING`); na AWS só `eks:DescribeCluster`, no Kubernetes só `rollout restart` (RBAC) |

O state deste stack fica **local** (ignorado pelo git), pois é ele que cria o bucket de state.

## Execução

```bash
aws login                      # usuário administrador da conta
cd bootstrap
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

## Configuração do GitHub

### Repositório `rp-fiap-mod-04-iac`

| Tipo | Nome | Valor |
|---|---|---|
| Variable | `AWS_REGION` | `us-east-1` |
| Variable | `AWS_IAC_ROLE_ARN` | output `iac_role_arn` |
| Variable | `AWS_BUCKET_NAME` | output `state_bucket_name` |
| Variable | `AWS_BUCKET_IAC_FOLDER_NAME` | ex.: `iac/terraform.tfstate` |
| Variable | `AWS_BUCKET_ADDONS_FOLDER_NAME` | ex.: `addons/terraform.tfstate` |
| Variable | `HOSTED_ZONE_ID` | ID da hosted zone do domínio no Route53 |
| Variable | `APIS_DOMAIN_NAME` / `ARGOCD_DOMAIN_NAME` / `GRAFANA_DOMAIN_NAME` | subdomínios do domínio registrado (o Prometheus não é exposto) |
| Secret | `LETSENCRYPT_EMAIL` | e-mail para avisos de expiração dos certificados (secret para não aparecer nos logs públicos) |
| Variable | `DATADOG_SITE` | site da organização Datadog (`datadoghq.com` = US1, `us5.datadoghq.com` = US5) |
| Secret | `DB_USER` / `DB_PASS` | credenciais dos RDS |
| Secret | `DATADOG_API_KEY` | API key dedicada ao projeto |
| Secret | `DATADOG_APP_KEY` | Application key usada pelo Terraform do Datadog (monitores/integrações) |
| Secret | `PAGERDUTY_INTEGRATION_KEY` | Integration key do serviço `togglemaster-auth-service` no PagerDuty |
| Secret | `GH_SELFHEAL_TOKEN` | Fine-grained token **só com Actions: write neste repositório**, usado pelo webhook do Datadog |
| Variable | `AWS_SELFHEAL_ROLE_ARN` | output `selfheal_role_arn` |
| Variable | `SLACK_ACCOUNT_NAME` | nome da conta Slack conectada no tile do Datadog (vazio = sem Slack) |
| Secret | `GRAFANA_ADMIN_PASSWORD` | senha do admin do Grafana (gerada aleatoriamente; ver no Secret `grafana-admin` do namespace `monitoring`) |
| Environment | `APPLY_APPROVAL` / `DESTROY_APPROVAL` | **com required reviewers** (aprovação manual) |
| Environment | `SELF_HEALING` | **sem** reviewers (a automação age sozinha), restrito à branch `main` |

### Repositório `rp-fiap-mod-04-app`

| Tipo | Nome | Valor |
|---|---|---|
| Variable | `AWS_REGION` | `us-east-1` |
| Variable | `AWS_APP_ROLE_ARN` | output `app_role_arn` |
| Variable | `SONAR_ORGANIZATION` | organização no SonarCloud |
| Secret | `SONAR_TOKEN` | token do SonarCloud |
| Secret | `DB_USER` / `DB_PASS` | mesmas credenciais dos RDS |
| Secret | `MASTER_KEY` | chave forte e aleatória (ex.: `openssl rand -hex 32`) |
| Secret | `SERVICE_API_KEY` | `tm_key_` + `openssl rand -hex 32`; o auth-service guarda só o hash |
| Secret | `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | opcionais (evitam limite de pull anônimo) |
| Environment | `APPLY_APPROVAL` | **com required reviewers** (teste de carga do KEDA) |

> Ao referenciar um environment inexistente, o GitHub o cria **sem** regras de proteção.
> Crie os environments com required reviewers antes da primeira execução.
