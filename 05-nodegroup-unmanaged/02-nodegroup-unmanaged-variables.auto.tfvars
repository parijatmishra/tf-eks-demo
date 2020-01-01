default_tags = {
  Application = "TfEksDemo"
  Environment = "dev"
}
cluster_name = "TfEksDemo"
vpc_id       = "vpc-03b587bb9e076424c"
vpc_private_subnet_ids = [
  "subnet-08772b1cee272585f",
  "subnet-0df4e9a4e741e33ef",
  "subnet-00d8f48857a9b10e9",
]
ssh_keypair_name                   = "general1"
cluster_security_group_id          = "sg-0448aafc591484a9a"
nodegroup_iam_instance_profile_arn = "arn:aws:iam::838522581324:instance-profile/TfEksDemo-NodeGroup"
instance_type                      = "t3a.medium"
allow_ssh_security_group_ids = [
  "sg-04e46d18bfb2cf321" /* bastion */
]
