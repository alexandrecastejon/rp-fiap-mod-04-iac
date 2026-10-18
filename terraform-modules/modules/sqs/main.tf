# Simple Queue Service (SQS)
resource "aws_sqs_queue" "queue" {
  name                      = var.queue_name
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 0
  tags = {
    Name = var.queue_name
  }
}

# Política de Mínimo Privilégio para o SQS
resource "aws_iam_policy" "sqs_shared_policy" {
  name        = "shared-sqs-policy"
  description = "Permite envio e consumo de mensagens na fila SQS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]
      Resource = aws_sqs_queue.queue.arn
    }]
  })
}

# Política de Mínimo Privilégio para o KEDA
resource "aws_iam_policy" "sqs_keda_policy" {
  name        = "keda-sqs-policy"
  description = "Permite ao KEDA ler o tamanho das filas SQS para autoescala"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:GetQueueAttributes"]
      Resource = "*"
    }]
  })
}

# Relação de Confiança (OIDC) para o Evaluation
data "aws_iam_policy_document" "evaluation_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:eks-namespace:evaluation-sa"]
    }
    principals {
      identifiers = [var.eks_oidc_provider_arn]
      type        = "Federated"
    }
  }
}

# Relação de Confiança (OIDC) para o KEDA
data "aws_iam_policy_document" "keda_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:keda:keda-operator",
        "system:serviceaccount:keda:keda-metrics-apiserver"
      ]
    }
    principals {
      identifiers = [var.eks_oidc_provider_arn]
      type        = "Federated"
    }
  }
}
# Cria a Role para o Evaluation
resource "aws_iam_role" "evaluation_role" {
  name               = "evaluation-service-role"
  assume_role_policy = data.aws_iam_policy_document.evaluation_assume_role.json
}

# Cria a Role para o KEDA
resource "aws_iam_role" "keda_role" {
  name               = "keda-operator-role"
  assume_role_policy = data.aws_iam_policy_document.keda_assume_role.json
}

# Anexa a permissão do SQS na Role do Evaluation
resource "aws_iam_role_policy_attachment" "evaluation_sqs_attach" {
  role       = aws_iam_role.evaluation_role.name
  policy_arn = aws_iam_policy.sqs_shared_policy.arn
}

# Anexa a permissão do SQS na Role do KEDA
resource "aws_iam_role_policy_attachment" "keda_sqs_attach" {
  role       = aws_iam_role.keda_role.name
  policy_arn = aws_iam_policy.sqs_keda_policy.arn
}