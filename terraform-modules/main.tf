data "aws_caller_identity" "current" {}

locals {
  # Roles criadas pelo stack bootstrap/ (OIDC do GitHub Actions)
  iac_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/gha-togglemaster-iac"
  app_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/gha-togglemaster-app"
  admin_arns   = [for u in var.admin_user_names : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${u}"]
}

module "network" {
  source = "./modules/network"
  region = var.aws_region
}

module "security" {
  source   = "./modules/security"
  vpc_id   = module.network.vpc_id
  vpc_cidr = module.network.vpc_cidr
}

module "eks_cluster" {
  source             = "./modules/eks"
  cluster_name       = var.eks_cluster_name
  allowed_ips        = var.allow_ips
  subnet_ids         = [module.network.private_subnet_idA, module.network.private_subnet_idB]
  cluster_admin_arns = concat(local.admin_arns, [local.iac_role_arn])
  app_deployer_arn   = local.app_role_arn
}

module "ecr_repos" {
  source          = "./modules/ecr"
  for_each        = var.ecr_repos
  repository_name = each.value.identifier
}

module "cache_cluster" {
  source             = "./modules/cache"
  cache_cluster_name = var.cache_cluster_name
  subnet_ids         = [module.network.private_subnet_idA, module.network.private_subnet_idB]
  security_groups    = [module.security.cache_sg_id]
}

module "sqs_queue" {
  source                = "./modules/sqs"
  queue_name            = var.sqs_queue_name
  eks_oidc_issuer_url   = module.eks_cluster.oidc_issuer_url
  eks_oidc_provider_arn = module.eks_cluster.oidc_provider_arn
}

module "dynamodb_tables" {
  source                = "./modules/dynamoDb"
  table_name            = var.dynamodb_table_name
  eks_oidc_issuer_url   = module.eks_cluster.oidc_issuer_url
  eks_oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  sqs_shared_policy_arn = module.sqs_queue.shared_sqs_policy_arn
}

module "rds_databases" {
  source          = "./modules/rds"
  for_each        = var.rds_dbs
  rds_name        = each.value.identifier
  db_name         = each.value.database
  db_user         = var.db_user
  db_pass         = var.db_pass
  subnet_ids      = [module.network.private_subnet_idA, module.network.private_subnet_idB]
  security_groups = [module.security.rds_sg_id]
}
