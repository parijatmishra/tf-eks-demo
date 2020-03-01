vpc_name = "TfEksDemo"
default_tags = {
  Application = "TfEksDemo"
  Environment = "dev"
  /* Tag VPC and subnets with "kubernetes.io/cluster/<cluster-name>=shared"
   * for *each* cluster you plan to launch in this VPC.
   */
  "kubernetes.io/cluster/TfEksDemo" = "shared"
}

azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

# http://www.davidc.net/sites/default/subnets/subnets.html?network=10.2.0.0&mask=16&division=25.f423720
cidr            = "10.2.0.0/16"
public_subnets  = ["10.2.0.0/20", "10.2.16.0/20", "10.2.32.0/20"]
private_subnets = ["10.2.64.0/19", "10.2.96.0/19", "10.2.128.0/19"]
intra_subnets   = ["10.2.192.0/21", "10.2.200.0/21", "10.2.208.0/21"]
