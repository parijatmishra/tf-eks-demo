# tf-eks-demo
Amazon EKS cluster with Terraform

## VPC

We need a VPC with an IGW, 3 public subnets, a NAT GW, 3 private subnets with route table set to route to the internet through the NAT GW. We can use an existing VPC or create a new one.

### VPC and Subnet Tagging Requirements

**Important** We nee to tag the VPC and subnets properly, and for that we need the cluster's name.  For each new cluster that shares the VPC, we need to update the tags.

[Amazon EKS needs some tags on the VPC and subnets it uses](eks-vpc-tags).  It creates some of the tags itself, but needs us to create some others.

[eks-vpc-tags]: https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html#subnet-tagging-for-load-balancers

1. Private subnets should be tagged with `kubernetes.io/role/internal-elb=1` - EKS will launch internal load balancers only in these subnets.
2. Public subnets should be tagged with `kubernetes.io/role/elb=1` - EKS will launch public load balancers only in these subnets.
3. Additionally, the VPC, and subnets (public and private) should be tagged with `kubernetes.io/cluster/<cluster-name>=shared` - EKS will not create resources in a VPC or subnet if they are not tagged with a tag with the cluster name in it.

For (1) and (2), since the required tags don't need the cluster name, when we created the VPC above, we already tagged the public and private subnets.

For (3): EKS automatically tags the VPC and the private subnets.  It **does not tag** the *public subnets*.  To tag the public subnets, we need the cluster name.

### Creating the VPC with right tags -- example

We have a sample terraform module for creating a VPC, using the `terraform-aws-modules/vpc/aws` module.

    cd 01-vpc/

We can tag the public and private subnets like so, and this does not change if we add new EKS clusters:

```
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
```

**Caution**. We are going to launch an EKS cluster, with the name `EksClusterTf` in this VPC. Since Amazon EKS tags the VPC and private subnets by itself, we could just add one more tag to the public subnet like this:

```
  public_subnet_tags = {
    "kubernetes.io/role/elb"             = "1"
    "kubernetes.io/cluster/EksClusterTf" = "shared"
  }
```

There is a problem with this approach.  Consider the following sequence of events:
- We created the VPC. The public subnets have a cluster specific tag.
- Below, we create an EKS cluster, specifying the VPC and private subnets.  EKS will tag the VPC and private subnets properly.  All seems well.  Except that terraform does not know about these additional tags.
- Some time later, we happen to run the VPC module again, perhaps to add a new route table or security group. At this point, since terraform does not know about the additional tags added to VPC and private subnets, it *will try to remove them*!

```
$ terraform plan -var-file vpc.tfvars
...
  # module.vpc.aws_subnet.private[2] will be updated in-place
  ~ resource "aws_subnet" "private" {
      ...
      ~ tags                            = {
          - "kubernetes.io/cluster/EksClusterTf" = "shared" -> null
  # module.vpc.aws_vpc.this[0] will be updated in-place
  ~ resource "aws_vpc" "this" {
      ...
      ~ tags                             = {
          - "kubernetes.io/cluster/EksClusterTf" = "shared" -> null
```

**Workaround Approach**. We will per cluster tags to the `default_tags` variable in `vpc.tfvars` instead.  This tag will get applied to *all resources*, even those that don't need to be tagged.  But at least this way, terraform will not remove the tags where they are essential.

```
default_tags = {
  Application                          = "EksClusterTf"
  Environment                          = "dev"
  "kubernetes.io/cluster/EksClusterTf" = "shared"
}
```

**Important**: Replace `EksCLusterTf` with your own chosen name for your cluster. You will have to add more such tags for each new cluster you launch in this VPC.

Now we can build out VPC:

    terraform init # if not done previously in this module
    terraform apply --var-file vpc.tfvars

**Important**: For every new EKS cluster that will share this VPC, we will have to update the tags above.

## EKS Cluster

We will create a EKS cluster or "control plane", and then generate a Kubeconfig file to authenticate to it in later sections.

Go into the directory:

    cd 02-eks-cluster

Create/Edit file `variables.tfvars` with the following keys and values:

- `default_tags`: choose any number of tags to apply to the resources created by this module.
- `cluster_name`: a name for your cluster, kept in variable for consistency.  We use the name `EksClusterTf` in the commands below.  Substitute that with the name you specify here.
- `vpc_id`: VPC ID of the VPC.  You can get it from the output of the previous section (`terraform output vpc_id`)
- `vpc_private_subnets`: A list of 3 private subnet IDs.  You can get it from the outputof the previoous section (`terraform output vpc_private_subnet_ids`)

The `variables.tfvars` file should look something like this:

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

Now run terraform to build the EKS cluster:

    $ terraform init # if not done previously in this module
    $ terraform apply --var-file variables.tfvars

Once the cluster is built, generate a kubeconfig for use with `kubectl` command line too, and/or the terraform `kubernetes` provider:

    aws eks update-kubeconfig --name EksClusterTf --kubeconfig ~/.kube/EksClusterTf

We use a custom location for our cluster's kubeconfig instead of merging our config into the default location (`~/.kube/config`) so that we don't accidentally operate on the wrong cluster.

Set the environment variable `KUBECONFIG` to point to this file, so that subsequent commands use this config.

    export KUBECONFIG=~/.kube/EksClusterTf

To verify that you can access the cluster usnig kubectl, you can try:

    $ kubectl get svc
    NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
    kubernetes   ClusterIP   172.20.0.1   <none>        443/TCP   28h

## Node Group

Before running the commands below, ensure `kubectl` is in the `PATH`, and `KUBECONFIG` is set and pointing to the right kubeconfig. (If you are using a single kubeconfig, ensure the `current-context` is pointing to the right context.)

### Node Group worker nodes

We will create an "unmanaged" node group - that is, a node group whose instances are created by an auto-scaling group we define.  In fact, we will create three auto-scaling groups, one for each AZ.  This is because we will be using a Kubernetes controller named "Cluster Autoscaler" later, and that does not work well with ASGs that span multiple AZs.  This situation may change in future if Cluster Autoscaler is enhanced to work with multi-AZ ASGs.

*Note* there are two other ways of creating node groups - "Managed node groups" via the AWS EKS API, and a "Fargate profile", also via the EKS API. We do not cover them here.

Go into the directory:

    cd 03-eks-cluster/

Create/edit a `variables.tfvars` file with the following information:

- `default_tags`: same as above.
- `cluster_name`: same as above; should be the same value as in the previous section, otherwise the nodes will not be able to join the cluster.
- `vpc_id`: same as above.
- `vpc_private_subnet_ids`: same as above.
- `ssh_keypair_name`: specify an EC2 keypair name, to be able to SSH into the worker nodes. The keypair must already exist.
- `cluster_security_group_id`: the EC2 Security Group for the control plane; you can get its value from the output of the previous module (`terraform output cluster_security_group_id`)
- `cluster_endpoint`: the Kubernetes API endpoint of our cluster created above; you can get its value from the output of the previous module (`terraform output cluster_endpoint`)
- `cluster_certificate_authority_data`: the Kubernetes cluster's CA's certificate; you can get its value from the output of the previous module (`terraform output cluster_certificate_authority` and copy the value of the `data` field).

The `variables.tfvars` file should look something like this:

```
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

ssh_keypair_name = "general1"

cluster_security_group_id = "sg-0f894f76d939e967a"

cluster_endpoint = "https://....eks.amazonaws.com"

cluster_certificate_authority_data = "LS0tLS1C..."
```

**Note: you will quickly (in a few mins) need to execute the instructions in the next paragraph as well, otherwise the nodegroup creation will fail.**

To create the cluster, run:

    $ terraform init # if not done previously in this module
    $ terraform apply -var-file=variables.tfvars

Note the output `nodegroup_iam_role_arn`.  We will need it quickly.

In the top directory, edit the file `kubernetes-config-map.sh`.  Replace the text `$NODEGROUP_IAM_ROLE_ARN` with the value of the `nodegroup_iam_role_arn` captured above.  Uncomment the first `- rolearn` stanza under `mapRoles`, so it looks something like this:

```
  mapRoles: |
      - rolearn: <ARN you captured above>
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
#     - rolearn: $ADMINISTRATOR_ROLE_ARN
...
```

Now, run:

    $ sh kubernetes-config-map.sh

The EC2 instances will register as Kubernetes nodes in a few minutes.  To check their status, run:

    $ kubectl get nodes

This should give you a list of nodes.

**What did we just do?**

We created a node group above, by creating an Auto-Scaling Group that will launch EC2 instances from an AWS provided, EKS optimized AMI.  In the user-data of the instance, we will invoke a built-in "bootstrap script", giving it our cluster name as an argument. The bootstrap script will discover the endpoint of the cluster with the specified name, by calling the AWS EKS APIs. Then it will call the K8S APIs to register the node. To be able to do this, the code running in the EC2 instance:

1. Needs to have the credentials to call AWS EKS APIs
2. Needs to have credentials to call K8S APIs - note that K8S uses its own RBAC system

For (1) we will create an IAM role and an EC2 instance profile that uses that role.  The role will have permissions to call various AWS APIs.

For (2) we can use the same IAM role, but we have to tell Kubernetes about it.  On AWS EKS, the K8S API server can *authenticate* credentials with AWS IAM.  We have to provide the IAM role information to K8S in a `ConfigMap` named `aws-auth`.

In the file `kubernetes-config-map.sh`, we run two commands:

- the `cat <<EOF > aws-auth-cm.yml` command uses a bash HEREDOC syntax to create a file named `aws-auth-cm.yml`, with its contents being a Kubernetes `ConfigMap` named `aws-auth`.  In the steps above, we uncommented a `mapRoles` field and a role, and specified the ARN of our node's IAM role in the `rolearn` field.
- the `kubectl apply ...` command then posts the config map to our K8S cluster.

We had to run this command after starting out cluster creation because we don't have the IAM role beforehand.  When we ran the previous `terraform apply` command, because terraform will create an auto-scaling group, which will then create EC2 instances, which will run a bootstrap script, which starts calling the cluster's K8S APIs using our IAM role's credentials. If the K8S API call fails, the bootstrap script will retry a few times. This takes a few minutes, and that is the time we have to register the newly generated IAM role with K8S via a config map.

We could have broken the node group generation step in two phases:

- generate the IAM role and then register it with K8S using the config map
- launch the node group, secure in the knowledge that our IAM role is already registered and the bootstrap script will succeed the first time.

**Troubleshooting**

If after several minutes, you still don't see any nodes, something may have done wrong with the registration process.  On a node group instance, look at the file `/var/log/cloud-init-output.log` to check that the `/etc/eks/bootstrap.sh` was invoked, and check the file `/var/log/messages` for messages from `kubelet`.

# TODO
+ EKS cluster log group
+ EKS service IAM role
+ EKS worker node IAM role
+ EKS control plane security group
+ EKS node group security group
+ EKS cluster with logging enabled - using auto-scaling per az
+ Generate kubeconfig
+ Tag VPC public subnets with 'kubernetes.io/cluster/<cluster-name>=shared'
+ EKS worker node launch configs and auto-scaling groups - one per AZ
- EKS worker node IAM Role authentication ConfigMap
- Create Nodegroup
- Install metrics-server
- Install kubernetes dashboard
- Install prometheus
- Install cluster autoscaler
- Install vertical pod autoscaler
- Associate IAM OIDC provider
- Deploy a simple pod and
    - scale vertically
    - scale horizontally
    - scale cluster
- Use MixedInstancesPolicy with ASG to start using Spot
- Use Fargate (use it for load tests?)
- Use EKS Managed Node Groups
