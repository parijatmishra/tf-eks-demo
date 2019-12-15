default_tags = {
  Application = "EksClusterTf"
  Environment = "dev"
}

cluster_name = "EksClusterTf"

vpc_id = "vpc-00f201ec4c27127a6"

vpc_private_subnet_ids = [
  "subnet-0233ab82d2f14371a",
  "subnet-0c7a3cf7b2e829ef8",
  "subnet-0655629959cd0e80b",
]
