output "queue_url" {
  description = "A URL da fila SQS"
  value       = aws_sqs_queue.queue.url
}

output "evaluation_role_arn" {
  description = "ARN da Role do IAM para o Service Account do Evaluation"
  value       = aws_iam_role.evaluation_role.arn
}

output "keda_sqs_role_arn" {
  description = "ARN da Role do IAM para o Service Account do KEDA"
  value       = aws_iam_role.keda_role.arn
}

output "shared_sqs_policy_arn" {
  description = "ARN da Política do IAM para o SQS"
  value       = aws_iam_policy.sqs_shared_policy.arn
}