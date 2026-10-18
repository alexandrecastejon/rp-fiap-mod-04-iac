# IAM Role para Control Plane do Cluster
resource "aws_iam_role" "cluster_role" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

# Chave KMS para criptografar os Secrets do Kubernetes no etcd (envelope encryption).
# Sem ela, os Secrets (senhas do banco, MASTER_KEY, API key do Datadog) ficam só em base64.
resource "aws_kms_key" "eks_secrets" {
  description             = "Criptografia dos Secrets do cluster ${var.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# O control plane precisa usar a chave para cifrar/decifrar os Secrets
resource "aws_iam_role_policy" "cluster_kms" {
  name = "${var.cluster_name}-secrets-kms"
  role = aws_iam_role.cluster_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:ListGrants", "kms:DescribeKey"]
      Resource = aws_kms_key.eks_secrets.arn
    }]
  })
}

# Logs do control plane: "audit" registra quem fez o quê no cluster (inclusive o
# rollout restart do self-healing); "authenticator" registra a autenticação IAM.
# O log group é criado antes do cluster para limitar a retenção (custo).
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 1
}

# Elastic Kubernetes Service (EKS)
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn
  version  = "1.36"

  enabled_cluster_log_types = ["audit", "authenticator"]
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    # Os runners hospedados do GitHub usam IPs dinâmicos, por isso o padrão é 0.0.0.0/0.
    # A API continua exigindo autenticação IAM + access entry; restrinja se usar runner próprio.
    public_access_cidrs = var.allowed_ips
  }
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    # Sem admin implícito para quem cria o cluster: todo acesso é declarado abaixo
    bootstrap_cluster_creator_admin_permissions = false
  }
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy.cluster_kms,
    aws_cloudwatch_log_group.eks,
  ]
}

# IAM Role para Worker Nodes
resource "aws_iam_role" "node_role" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Políticas obrigatórias do EKS
resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_role.name
}
resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_role.name
}
resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_role.name
}

# Políticas de apoio (SQS e DynamoDB) para suas aplicações
resource "aws_iam_role_policy_attachment" "node_sqs_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  role       = aws_iam_role.node_role.name
}
resource "aws_iam_role_policy_attachment" "node_dynamodb_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.node_role.name
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.cluster_name}-node-template"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }
}

# Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]
  ami_type        = "AL2023_x86_64_STANDARD"
  scaling_config {
    min_size     = 1
    desired_size = 2
    max_size     = 3
  }
  launch_template {
    name    = aws_launch_template.eks_nodes.name
    version = aws_launch_template.eks_nodes.latest_version
  }
  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })
}

# ==========================================
# 1. ADMINISTRADORES DO CLUSTER
#    (usuário admin + pipeline de IaC, que instala os add-ons)
# ==========================================
resource "aws_eks_access_entry" "cluster_admin" {
  for_each      = toset(var.cluster_admin_arns)
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each      = aws_eks_access_entry.cluster_admin
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value.principal_arn
  access_scope {
    type = "cluster"
  }
}

# ==========================================
# 2. PIPELINE DAS APLICAÇÕES
#    Menor privilégio: admin apenas no namespace das aplicações
# ==========================================
resource "aws_eks_access_entry" "app_deployer" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.app_deployer_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "app_deployer" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = aws_eks_access_entry.app_deployer.principal_arn
  access_scope {
    type       = "namespace"
    namespaces = [var.app_namespace]
  }
}

# ==========================================
# 3. SELF-HEALING
#    Sem access policy da AWS: a role vira o grupo Kubernetes abaixo, cujas
#    permissões vêm de uma Role RBAC (eks-templates/rbac-self-healing.yml)
#    que só permite reiniciar Deployments no namespace das aplicações
# ==========================================
resource "aws_eks_access_entry" "selfheal" {
  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = var.selfheal_role_arn
  kubernetes_groups = ["togglemaster-selfheal"]
  type              = "STANDARD"
}

# Coleta o certificado do OIDC do EKS para criar o provedor de identidade
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Habilita o OIDC para o cluster EKS, permitindo a autenticação de workloads usando IAM Roles for Service Accounts (IRSA)
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}