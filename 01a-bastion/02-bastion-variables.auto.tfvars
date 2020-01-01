vpc_name = "TfEksDemo"
default_tags = {
  Application = "TfEksDemo"
  Environment = "dev"
}
vpc_id = "vpc-03b587bb9e076424c"
allowed_cidr_blocks = [
  "54.240.199.97/32",
  "103.252.202.166/32"
]
ami           = "ami-00068cd7555f543d5"
instance_type = "t3a.small"
subnet_id     = "subnet-04cb22f5b8f1334c9"
key_name      = "general1"
