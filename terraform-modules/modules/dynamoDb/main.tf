# Table DynamoDb
resource "aws_dynamodb_table" "table" {
  name           = var.table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "event_id"
  attribute {
    name = "event_id"
    type = "S"
  }
  tags = {
    Name = var.table_name
  }
}

# Política de Mínimo Privilégio para o DynamoDB
resource "aws_iam_policy" "dynamodb_shared_policy" {
  name        = "shared-dynamodb-policy"
  description = "Permite gravação e leitura de DynamoDB"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.table.arn
    }]
  })
}

# Relação de Confiança (OIDC) para o Analytics
data "aws_iam_policy_document" "analytics_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:*:analytics-sa"]
    }
    principals {
      identifiers = [var.eks_oidc_provider_arn] 
      type        = "Federated"
    }
  }
}

# Cria a Role
resource "aws_iam_role" "analytics_role" {
  name               = "analytics-service-role"
  assume_role_policy = data.aws_iam_policy_document.analytics_assume_role.json
}

# Anexa a permissão do DynamoDB na Role
resource "aws_iam_role_policy_attachment" "analytics_dynamo_attach" {
  role       = aws_iam_role.analytics_role.name
  policy_arn = aws_iam_policy.dynamodb_shared_policy.arn
}

# Anexa a permissão do SQS na Role
resource "aws_iam_role_policy_attachment" "analytics_sqs_attach" {
  role       = aws_iam_role.analytics_role.name
  policy_arn = var.sqs_shared_policy_arn 
}
