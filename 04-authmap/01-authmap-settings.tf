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
  // Configuration is picked up from env variables. See documentation.
  // We set KUBECONFIG to the path of the generated kubeconfig file.
}
