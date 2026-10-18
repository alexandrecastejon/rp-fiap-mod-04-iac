output "state_bucket_name" {
  description = "Cadastrar como variable AWS_BUCKET_NAME no repositório de IaC"
  value       = aws_s3_bucket.tfstate.bucket
}

output "iac_role_arn" {
  description = "Cadastrar como variable AWS_IAC_ROLE_ARN no repositório de IaC"
  value       = aws_iam_role.github_iac.arn
}

output "app_role_arn" {
  description = "Cadastrar como variable AWS_APP_ROLE_ARN no repositório de aplicações"
  value       = aws_iam_role.github_app.arn
}

output "selfheal_role_arn" {
  description = "Cadastrar como variable AWS_SELFHEAL_ROLE_ARN no repositório de IaC"
  value       = aws_iam_role.github_selfheal.arn
}
