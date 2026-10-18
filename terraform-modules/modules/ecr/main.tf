# Elastic Container Registry (ECR)
resource "aws_ecr_repository" "repo" {
  name = var.repository_name
  # Tags imutáveis: a tag do commit sempre aponta para a mesma imagem (GitOps auditável)
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = var.repository_name
  }
}