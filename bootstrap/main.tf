# ==========================================================
# BOOTSTRAP - executado UMA vez, localmente, por um admin.
# Cria a base de confiança que os pipelines precisam antes
# de existirem: bucket do tfstate, provedor OIDC do GitHub
# e as roles que o GitHub Actions assume (sem access keys).
# ==========================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # State local de propósito: este stack cria o próprio bucket de state.
  # O arquivo terraform.tfstate é ignorado pelo .gitignore.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "FIAP-MOD4"
      ManagedBy = "terraform-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "${var.state_bucket_prefix}-${local.account_id}"
  oidc_host   = "token.actions.githubusercontent.com"

  # O GitHub emite o "sub" no formato imutável, com os IDs numéricos do dono e
  # do repositório. Se o repositório for apagado e recriado com o mesmo nome,
  # o ID muda e a trust deixa de aceitar o token.
  iac_sub = "repo:${var.github_owner}@${var.github_owner_id}/${var.iac_repo}@${var.iac_repo_id}"
  app_sub = "repo:${var.github_owner}@${var.github_owner_id}/${var.app_repo}@${var.app_repo_id}"
}

# ------------------------------
# Bucket do Terraform state
# ------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Recusa qualquer acesso sem TLS
resource "aws_s3_bucket_policy" "tfstate_tls_only" {
  bucket = aws_s3_bucket.tfstate.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# Versões antigas do state expiram para não acumular custo
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ------------------------------
# OIDC GitHub Actions -> AWS
# ------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${local.oidc_host}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# Role do repositório de IaC. Precisa de permissões amplas porque o
# Terraform cria VPC, EKS, RDS e as próprias roles de IAM dos serviços.
# O risco é contido pela trust policy: só a branch main e os environments
# com aprovação manual deste repositório conseguem assumi-la.
resource "aws_iam_role" "github_iac" {
  name                 = "gha-togglemaster-iac"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_host}:aud" = "sts.amazonaws.com" }
        StringLike = {
          "${local.oidc_host}:sub" = [
            "${local.iac_sub}:ref:refs/heads/main",
            "${local.iac_sub}:environment:APPLY_APPROVAL",
            "${local.iac_sub}:environment:DESTROY_APPROVAL",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_iac_admin" {
  role       = aws_iam_role.github_iac.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Role do repositório de aplicações: menor privilégio.
# Só faz push nos 5 repositórios ECR e lê os endpoints que o deploy injeta.
# O acesso ao Kubernetes é concedido pelo módulo EKS, restrito ao namespace.
resource "aws_iam_role" "github_app" {
  name                 = "gha-togglemaster-app"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_host}:aud" = "sts.amazonaws.com" }
        StringLike = {
          "${local.oidc_host}:sub" = [
            "${local.app_sub}:ref:refs/heads/main",
            # job de teste de carga do KEDA, protegido por aprovação manual
            "${local.app_sub}:environment:APPLY_APPROVAL",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_app" {
  name = "togglemaster-app-ci"
  role = aws_iam_role.github_app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPushServiceRepos"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/ecr-*-service-01"
      },
      {
        Sid    = "ReadDeployEndpoints"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "rds:DescribeDBInstances",
          "elasticache:DescribeCacheClusters",
          "sqs:GetQueueUrl",
        ]
        Resource = "*"
      },
      {
        Sid      = "KedaLoadTestQueue"
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = "arn:aws:sqs:${var.aws_region}:${local.account_id}:${var.sqs_queue_name}"
      },
      {
        Sid      = "ReadServiceRoles"
        Effect   = "Allow"
        Action   = "iam:GetRole"
        Resource = "arn:aws:iam::${local.account_id}:role/*-service-role"
      },
    ]
  })
}

# Role do self-healing: assumida SOMENTE pelo workflow self-healing.yml
# (environment SELF_HEALING do repositório de IaC). Na AWS só descreve o cluster;
# no Kubernetes é mapeada para um grupo com RBAC restrito a rollout restart.
resource "aws_iam_role" "github_selfheal" {
  name                 = "gha-togglemaster-selfheal"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
          "${local.oidc_host}:sub" = "${local.iac_sub}:environment:SELF_HEALING"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_selfheal" {
  name = "togglemaster-selfheal"
  role = aws_iam_role.github_selfheal.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DescribeCluster"
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = "arn:aws:eks:${var.aws_region}:${local.account_id}:cluster/*"
    }]
  })
}
