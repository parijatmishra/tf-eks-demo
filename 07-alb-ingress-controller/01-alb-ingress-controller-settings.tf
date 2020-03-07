terraform {
  required_version = "~> 0.12"
  required_providers {
    aws = "~> 2.0"
  }
}
provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  // config is picked up from env variables, in particular KUBECONFIG
  // see: https://www.terraform.io/docs/providers/kubernetes/index.html#authentication
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "current" {
  name = var.cluster_name
}
