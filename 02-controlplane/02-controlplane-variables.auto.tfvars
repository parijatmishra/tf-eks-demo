default_tags = {
  Application = "TfEksDemo"
  Environment = "dev"
}

cluster_name = "TfEksDemo"

vpc_id = "vpc-00f201ec4c27127a6"

vpc_private_subnet_ids = [
  "subnet-08772b1cee272585f",
  "subnet-0df4e9a4e741e33ef",
  "subnet-00d8f48857a9b10e9",
]

kubeconfig_path = "~/.kube/TfEksDemo.kubeconfig"
