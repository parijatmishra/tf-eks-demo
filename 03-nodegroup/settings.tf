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
