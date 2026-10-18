data "aws_eks_cluster" "my_cluster" {
  name = var.eks_cluster_name
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.my_cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.my_cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.my_cluster.name]
      command     = "aws"
    }
  }
}