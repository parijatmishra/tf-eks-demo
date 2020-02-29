# tf-eks-demo

A demo of how to manage an Amazon EKS cluster, node groups, and Kubernetes
services, via Terraform.

# Pre-requisites

You will need an AWS account with Administrative level access to follow this
tutorial.

You will need the following software installed on the workstation you are
following the guide from:

- The `git` CLI
- The [Terraform CLI](https://www.terraform.io/downloads.html)
- The [AWS CLI](https://aws.amazon.com/cli/) installed and configured to access the account.
- The [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) CLI
- The [helm](https://helm.sh/) CLI (optional; only needed for some parts)

## Configuring the AWS region for Terraform

In each of the folders, there is a file `XXX-settings.tf`. Edit it to reflect
the AWS region you want to use.

You will need to give Terraform
[access to AWS credentials](https://www.terraform.io/docs/providers/aws/index.html).

## Git sub-modules

This repo refers to other repos using git submodules. You will need to
initialize them with the following commands:

```
git submodule init
git submidule update
```

# VPC

Before we can create an EKS cluster, we need a VPC. Amazon EKS has
[some requirements](eks-vpc) and suggestion for the design of the VPC.

Amazon EKS can work with 2 AZs, but in our cluster design (below), we have
chosen to use 3. We need three public subnets and three private subnets, each in
a separate AZ. We will need a NAT Gateway or Instance for the private subnets as
well.

[eks-vpc]: https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
[eks-vpc-tags]: https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html#subnet-tagging-for-load-balancers

### Using an Existing VPC

If you already have an existing VPC, ensure that:

- It has 3 public subnets and 3 private subnets
- There is a NAT Gateway or Instance and the private subnets have access to the
  internet via it.
- The public and private subnets are tagged [properly](eks-vpc-tags)

### Creating a New VPC

We provide a module to create a new VPC meeting our requirements. To use it, go
into the `01-vpc` folder, study the `02-vpc-variables.tf` file, and edit the
`02-vpc-variables.auto.tfvars` file to fill values for the variables. Once done,
create the VPC like this:

```
terraform init # only once per machine
terraform apply
```

**Note**: the `default_tags` variable has a line like this:

```
  "kubernetes.io/cluster/TfEksDemo" = "shared"
```

Here, `TfEksDemo` is the name of the cluster we will launch (below). The VPC
can be used for more than one cluster. If you launch more clusters in this VPC,
you should *first* edit the `default_tags` variable and add a similar line for
the new cluster. If you don't, EKS may not be able to launch public load
balancers in the public subnets.

**Note**: Amazon EKS will automatically create the above tag on the VPC and
private subnets, but not on public subnets. Instead of tagging everything as
above, we could have just tagged the public subnets. Why are we tagging
everything?

When Amazon EKS tags our VPC and private subnets, Terraform does not know
anything about it. As a result, if after launching one or more clusters in our
VPC, if we were to ever apply the VPC module again, terraform would notice the
additional tags, and *it would try to remove them*. For e.g., if we did not add
the tag above, and after creating the cluster (below), tried to apply the VPC
module again, we would see:

```
$ terraform plan
...
  # module.vpc.aws_subnet.private[2] will be updated in-place
  ~ resource "aws_subnet" "private" {
      ...
      ~ tags                            = {
          - "kubernetes.io/cluster/TfEksDemo" = "shared" -> null // <-- NOTE: deletion attempt
  # module.vpc.aws_vpc.this[0] will be updated in-place
  ~ resource "aws_vpc" "this" {
      ...
      ~ tags                             = {
          - "kubernetes.io/cluster/TfEksDemo" = "shared" -> null // <-- NOTE: deletion attempt
```


We don't want that, so we have to pro-actively tell terraform about these tags.

### Bastion EC2 Instance

We may want to log into our worker nodes to debug them, and for that we will
need a bastion node. If you don't plan to SSH into worker nodes, you don't need
one.

If you already have a bastion node, you can skip this step. Otherwise, we
provide a module to create one. To use it, go into the `01a-bastion` folder,
study the `02-bastion-variables.tf` file, and edit the
`02-bastion-variables.auto.tfvars` file with appropriate values. Then, run:

```
terraform init # only once on each new workstation after checkout out this code
terraform apply
```

# EKS Cluster

We will now create our EKS control plane. We provide the module
`02-controlplane` for this. This module will generate a `kubeconfig` file, using
the AWS CLI. To ensure your CLI is setup, try the following commands:

```
aws sts get-caller-identity
```

This should output information about the the AWS account and IAM identity it is
configured to use. You should see something like the following. If you get an
error, you should check your configuration.

```
{
    "UserId": "XXXXXXXXXXXXXXXXXXX",
    "Account": "YYYYYYYYYYY",
    "Arn": "arn:aws:iam::YYYYYYYYYYY:user/zzzzzz"
}
```

You should have permissions to Amazon EKS. Try the command:

```
aws eks list-clusters
```

You should get a list of clusters if any exist, otherwise an empty list:

```
{
    "clusters": []
}
```

Go into the `02-controlplane` folder, study the `02-controlplane-variables.tf`
file, and edit the `02-controlplane-variables.auto.tfvars` file with appropriate
values.

You will get the values of most variables from the outputs of the previous
modules. The new variables to take note of are:

- `cluster_name`: The of the cluster you intend to create. This should match the
  name of the cluster you used in `default_tags` in the `01-vpc` module. If you
  use a different name here, go back and edit the vpc module and apply the
  changes there beforehand.

- `kubeconfig_path`: An absolute or relative path to a location where the
  cluster's Kubeconfig file will be written to. This will be used by subsequent
  commands. A good value could be `~/.kube/<cluster-name>.kubeconfig`. You
  should also set the environment variable `KUBECONFIG` to the value you choose
  here, in every terminal session where you intend to connect to this cluster.

Then, run:

```
terraform init # only once on each new workstation after checkout out this code
terraform apply
```

Before going further, ensure the cluster has been successfully created **and is
in the ACTIVE state**. You can check the cluster's state in the AWS console, or
via the AWS CLI like this:

```
aws eks describe-cluster --name "TfEksDemo" --query cluster.status
"CREATING" # Not active
```

```
aws eks describe-cluster --name "TfEksDemo" --query cluster.status
"ACTIVE" # Ready, proceed with the next steps
```

Once the cluster is built, a `kubeconfig` file for use with `kubectl` command
line or the terraform `kubernetes` provider will be created at the path
specified by `kubeconfig_path` variable. Check the contents of the file to see
it is well-formed.

If the file did not get generated for some reason (most common being the `aws`
cli not being available or configured properly), you can generate it manually,
instead of creating the cluster again, with the following command:

```
aws eks update-kubeconfig --name TfEksDemo --kubeconfig <kubeconfig_path>
```

**Note**: We use a custom location for our cluster's kubeconfig instead of
merging our config into the default location (`~/.kube/config`) so that we don't
accidentally operate on the wrong cluster.

Set the environment variable `KUBECONFIG` to point to this file, so that
subsequent commands use this config.

```
export KUBECONFIG=<kubeconfig-path>
```

To verify that you can access the cluster usnig kubectl, you can try:

```
$ kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   172.20.0.1   <none>        443/TCP   10m
```

## NodeGroup IAM role

We will create "worker nodes" or node groups below. Worker nodes are just EC2
instances. Amazon EKS provides AMIs optimized for use with EKS. This AMI
contains a preinstalled
[`bootstrap.sh`](https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh)
file that is expected to be invoked at boot time via user-data. This script
calls Kubernetes APIs to register the instance as a worker node. The only
mandatory argument is the cluster name, which the script can use to look up the
cluster's Kubernetes API server endpoint and then register itself.

To successfully call the Kubernetes APIs, the bootstrap script must have an
identity already registered in the Kubernetes RBAC system (which is different
from AWS IAM). On AWS, instead of creating an identity separately, it is
recommended that we use an IAM role for the worker node EC2 instances, and
register that IAM role in the Kubernetes RBAC system. This way, we don't have to
pass any authentication credentials to the worker nodes in the user-data
explicitly, keeping our IaC code free of sensitive information. The bootstrap
script will get the IAM role's credentials from EC2 metadata, and use that to
make calls to Kubernetes.

Most online tutorials for EKS create the IAM role as part of the node group
creation. They then ask you to register the IAM role with the Kubernetes RBAC
system *while the nodes are still booting*.  If you don't do this, the API
calls will fail and the nodes will not register.  To be precise, the bootstrap
script keeps retrying, so in practice once you've registered the IAM role, the
nodes should eventually register. However, we prefer to not have a timing
issue.

We will remove this timing constraint. We will create the IAM role first.

To do so, go into the `03-nodegroup-iam` folder, study the
`02-nodegroup-iam-variables.tf` file, and edit the
`02-nodegroup-iam-variables.auto.tfvars` file with appropriate values. You will
find the values in the outputs or inputs of the earlier modules. Then run:

```
terraform init # only once on each new workstation after checkout out this code
terraform apply
```

## Kubernetes RBAC: The `aws-auth` Config Map

To allow our NodeGroup EC2 instances to register themselves with Kubernetes, we
must add the NodeGroup IAM role to it.

To do so, go into the `04-authmap` folder and edit the `03-authmap-authmap.yml`
file. The `mapRoles` field has a multi-line string value which itself is a YAML
document. In the yaml document, replace the value of `rolearn` field with the
NodeGroup IAM role ARN here.

**Note**: In an earlier module we created the NodeGroup IAM role. We specified a
`path` of `/` for the role. If you did not change it, you can copy the
`nodegroup_iam_role_arn` value from the output as-is. If you did change the path
to something other than `/`, then the output of the earlier module would have
contained a path in the ARN, like this:

```
nodegroup_iam_role_arn = arn:aws:iam::838522581324:role/Some/Path/Here/TfEksDemo-NodeGroup
```

You **must** remove the path when copying the ARN. The input ARN to this module
must look like `...:role/<name-of-role>`.

Now run:

```
terraform init # only once on each new workstation after checkout out this code
terraform apply
```

To check that the config map was created correctly, run the command:

```
kubectl get cm aws-auth -n kube-system -o yaml
```

The output should be similar to the following:

```
apiVersion: v1
data:
  mapRoles: |
    - rolearn: arn:aws:iam::838522581324:role/TfEksDemo-NodeGroup
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
kind: ConfigMap
metadata:
...
```

> **Note**: Why do we not create this config map when we created the node group
> above, in a single step? Because the `aws-auth` config map is used for more
> than the worker node IAM roles; it is the central location for *all* IAM
> integration with Kubernetes RBAC. We need to separate it out because you will
> use this for other IAM entities as well. See
[Managing Users or IAM Roles for your Cluster](add-user-role).

[add-user-role]: https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html

### Giving other users access to the EKS cluster

When a cluster is created, the AWS IAM user or role that created the cluster is
given `system:masters` permission on that cluster automatically by Amazon EKS.
This is hidden and does not appear in the `aws-auth` Config Map (that we discuss
below).

If other users are collaborating on administering an EKS cluster, and they don't
use the same AWS IAM user or role as the creator of the cluster, you will need
to give them permissions to access the cluster explicitly. This is also done via
the Config Map. For more details, read this
[article](https://aws.amazon.com/premiumsupport/knowledge-center/amazon-eks-cluster-access/).

## Node Groups

Now we are ready to create our node groups. There are three ways of adding nodes to our cluster:

- "Unmanaged" node groups: this is where *we* create the nodes and register them
  with Kubernetes. This gives us the maximum control, but we have to the most
  work.
- "Managed" node groups: we make an API call to Amazon EKS (i.e., the AWS EKS
  API, not the Kubernetes API), and it will create a node group for us and
  register the nodes with Kubernetes. It achieves the same thing as above more
  easily, but we have less control.
- "Fargate profile": this is not a node group, strictly speaking, but a new
  scheduler in Kubernetes; enaling it allows us to specify that pods run on
  "Fargate".

### Unmanaged Node Groups

We will create an "unmanaged" node group. We will create auto-scaling groups,
that will then create EC2 instances which which then register themselves with
Kubernetes as nodes. We will create three auto-scaling groups, one for each AZ.
This is because we will be using a Kubernetes controller named "Cluster
Autoscaler" later, and that does not work well with ASGs that span multiple AZs.
This situation may change in future if Cluster Autoscaler is enhanced to work
with multi-AZ ASGs.

Go to the `05-nodegroup-unmanaged` folder, study the
`02-nodegroup-unmanaged-variables.tf` file, and edit the
`02-nodegroup-unmanaged-variables.auto.tfvars` file with appropriate values. You
can get the values for most variables from the output/inputs of earlier modules.
The following are new:

- ssh_keypair_name: specify an *existing* EC2 keypair name; this will allow you
  to SSH into the worker nodes
- allow_ssh_security_group_ids: SSH into worker nodes is allowed only from other
  security groups; specify a list here. You would want to specify the security
  group ID of your bastion instance.
- instance_type: the EC2 instance type to use; the value will depend on your
  intended usage.

After a few minutes, your nodes should be registered and you should be able to
see them:

```
$ kubectl get nodes
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-2-101-75.ec2.internal   Ready    <none>   20m   v1.14.8-eks-b8860f
ip-10-2-146-81.ec2.internal   Ready    <none>   20m   v1.14.8-eks-b8860f
ip-10-2-94-162.ec2.internal   Ready    <none>   20m   v1.14.8-eks-b8860f
```

**Troubleshooting**

If after several minutes, you still don't see any nodes, something may have done
wrong with the registration process. SSH into a node group instance, look at the
file `/var/log/cloud-init-output.log` to check that the `/etc/eks/bootstrap.sh`
was invoked, and check the file `/var/log/messages` for messages from `kubelet`.

If you see errors related to permissions, check you `aws-auth` config map. Even
a small typo, or indentation error in the embedded yaml, can cause
authentication to fail silently. Ensure the output of
`kubectl get cm aws-auth -n kube-system -o yaml` is as conforms to the format
(including indentation) in [add-user-role].

Check
[Amazon EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
for more information.

### Managed NodeGroups

TODO

### Fargate Profile

TODO

# Monitoring

## Metrics Server

The [Metrics Server](https://github.com/kubernetes-sigs/metrics-server) is a
core part of the
[Kubernetes Monitoring Architecture](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/monitoring_architecture.md)
but it is not installed by default on EKS clusters. It can be installed by
checking its code from GitHub and following the instructions, or by following
the instructions in the
[Amazon EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html).
We will provide instructions to deploy it below.

Before installing Metrics Server, we will not be able to get node level or pod
level aggregated metrics. For e.g.. the following two commands will give you
errors:

```
kubectl top nodes
kubectl top pods
```

### Installing Metrics Server from GitHub Source

We have added the Metrics Server GitHub repo to our project as a sub-module, for
convenience, at `external/metrics-server`. Go into that folder and run:

```
# In folder 'external/metrics-server'
kubectl apply -f deploy/1.8+/
```

The output should be like the following:

```
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created
serviceaccount/metrics-server created
deployment.apps/metrics-server created
service/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
```

The Metrics Server deployment scripts create a service with the same name. You
can check that the service exists:

```
kubectl get svc metrics-server -n kube-system
NAME             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
metrics-server   ClusterIP   172.20.189.208   <none>        443/TCP   9m54s
```

You can get full details by appending the flag `-o yaml` to the above command.
If you do so, you will observe that the service uses the selector
`k8s-app: metrics-server` to find the matching pods.

You can check that the `metrics-server` deployment is running from the following
command:
```
kubectl get deployment metrics-server -n kube-system
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           4m51s
```

Again, you can get more details by appending the `-o yaml` flag to the command
above. If you do so, you will observe in the output
(`spec.template.metadata.labels`) that the deployment labels the pods it creates
with `k8s-app=metrics-server`, which matches the service selector above.

### Querying Resource Metrics

Now that Metrics Server is installed, we can query aggregated resource metrics,
using, for e.g., the `kubectl top` command:

```
kubectl top nodes
```

The output should be like:

```
kubectl top node
NAME                          CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
ip-10-2-101-75.ec2.internal   41m          2%     411Mi           14%
ip-10-2-146-81.ec2.internal   31m          1%     369Mi           13%
ip-10-2-94-162.ec2.internal   36m          1%     420Mi           14%
```

We can query pod-level metrics, with the following command (in the following
example, we are querying pods in the `kube-system` namespace):

```
kubectl top pods -n kube-system
```

The output should be like:

```
NAME                              CPU(cores)   MEMORY(bytes)
aws-node-5xcsz                    2m           22Mi
aws-node-6wzjz                    3m           23Mi
aws-node-t2zhw                    4m           23Mi
coredns-56678dcf76-h4w7q          2m           7Mi
coredns-56678dcf76-rs2v9          3m           6Mi
kube-proxy-g4cp9                  1m           9Mi
kube-proxy-k928c                  1m           9Mi
kube-proxy-ln28r                  3m           9Mi
metrics-server-596d74f577-c7vft   1m           11Mi
```

## Kubernetes Dashboard

> [Kubernetes Dashboard](https://github.com/kubernetes/dashboard) is a general
> purpose, web-based UI for Kubernetes clusters. It allows users to manage
> applications running in the cluster and troubleshoot them, as well as manage
> the cluster itself.

The dashboard is useful for visually inspecting the state of the cluster.

While the dashboard allows users to create, start/stop and delete kubernetes
resources, it should ideally not be used for this purpose; such resource
management should be done declaratively, such as by using Kubernetes YAML files
or Terraform playbooks. Doing administrative tasks via the dashboard guarantees
your cluster's state will drift from your Infrastructre-as-Code (IaC)
repository, cause conflict when multiple people are working on the same cluster,
and break your automation.

It uses Metrics Server so you should already have that installed, as above.

### Installing Kubernetes Dashboard

> We have added the Kubernetes Dashboard repository to ours in the `external`
> folder, using the command:
> `git submodule add https://github.com/kubernetes/dashboard.git`

To install, go into the `external/dashboard` folder, and run:

```
kubectl apply -f aio/deploy/recommended.yaml
```

The output will be something like:

```
namespace/kubernetes-dashboard created
serviceaccount/kubernetes-dashboard created
service/kubernetes-dashboard created
secret/kubernetes-dashboard-certs created
secret/kubernetes-dashboard-csrf created
secret/kubernetes-dashboard-key-holder created
configmap/kubernetes-dashboard-settings created
role.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrole.rbac.authorization.k8s.io/kubernetes-dashboard created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
deployment.apps/kubernetes-dashboard created
service/dashboard-metrics-scraper created
deployment.apps/dashboard-metrics-scraper created
```

### Viewing the Dashboard

To access the Dashboard from your a given machine, you must create a secure
channel to your Kubernetes cluster. The easiest way is to run the following
command on the machine from which you want to browse the Dashboard UI:

```
kubectl proxy
```

Now you should be able to browse the UI at:

`http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`.

The UI will ask you to login and offer two methods. The first, `KubeConfig`,
does not work on Amazon EKS. You need to use the `Token` login method. See the
next section for how to obtain Tokens.

### Permissions for Kubernetes Dashboard

The UI app that is deployed has very limited permissions. It assumes the
permissions of the logged in users to retrieve data and perform actions.

The UI allows you to login using a "Token" (the other method, named
`Kubeconfig`, does not work with Amazon EKS). Tokens are stored in Kubernetes
Secret objects that are automatically created when a Kubernetes Service Account
API object is created, and give the user/code posessing the token the same
permissions that the Service Account has. The UI deployment created a Service
Account `kubernetes-dashboard/kubernetes-dashboard`. We can get it's token like
this:

```
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep kubernetes-dashboard | awk '{print $1}') | grep '^token:' | awk '{print $2}'
```

If you login with the token obtained above, you will be able to click around but
not see any data, as this service account has very limited permissions.

**Creating Admin and View Service Accounts**

To create some service accounts, go into the `06-users` folder and run:

```
kubectl apply -f .
```

This will create two service accounts in the `kube-system` namespace:

1. `eks-admin` bound to the `cluster-admin` Cluster Role
2. `eks-view` bound to the `view` Cluster Role

You can get the token for each via:

```
ROLE_NAME=eks-admin # or eks-view
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep "${ROLE_NAME}" | awk '{print $1}') | grep '^token:' | awk '{print $2}'
```

If you login with the `eks-admin` token, you will be able to see all the details
of the cluster. If you login with the `eks-view` token, you will see a subset of
the details.

## Prometheus

[Prometheus](https://prometheus.io/) is a general purpose time series database
and metrics server, allowing you to filter, graph, and query the results. It can
natively monitor Kubernetes, its nodes and itself, as Kubernetes metrics API
exposes metrics in the Prometheus format. Prometheus can be deployed as a
Kubernetes service, and it is especially easy using the Helm tool, which
provides a [Helm Chart for
Prometheus](https://hub.helm.sh/charts/stable/prometheus).

If you read the chart documentation, you will see a large number of
configuration variables that can be tweaked. For our demo purposes, we need to
take of only two.

## Deploying Prometheus using Helm

First, create a dedicated namespace for Prometheus resources:

```
kubectl create namespace prometheus
```

Ensure that you have added the "stable" repo to Helm:

```
$ helm repo list
NAME  	URL
stable	https://kubernetes-charts.storage.googleapis.com/
```

If you don't see the `stable` repo in the output of the previous command, add it:

```
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
```

Now, deploy Prometheus from the `prometheus` chart in the `stable` repository,
passing two configuration variables (the argument to `--set` flag):

```
helm install prometheus stable/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2",server.persistentVolume.storageClass="gp2"
```

Verify that all the pods are running:

```
kubectl get pods -n prometheus
```

which should give output like this:

```
NAME                                             READY   STATUS    RESTARTS   AGE
prometheus-alertmanager-fd5df4f8c-gsrxl          2/2     Running   0          59m
prometheus-kube-state-metrics-69bfcf45dd-vrttl   1/1     Running   0          59m
prometheus-node-exporter-2s42w                   1/1     Running   0          59m
prometheus-node-exporter-fg5jx                   1/1     Running   0          59m
prometheus-node-exporter-lhsqg                   1/1     Running   0          59m
prometheus-pushgateway-5746f45dd-6hx8x           1/1     Running   0          59m
prometheus-server-6f5ff4f64b-kc8xn               2/2     Running   0          59m
```

### Viewing the Prometheus UI

The Prometheus server in its current configuration is available on a URL
internal to the Kubernetes cluster, for security, as it does not have any
authentication. To reach it, use `kubectl` to port forward the console to your
local machine:

```
kubectl --namespace=prometheus port-forward deploy/prometheus-server 9090
```

Now you can browse the Prometheus UI on http://localhost:9090/.  To test that it
is working, choose a metric from the "- insert metric at cursor" menu, then
choose Execute. Choose the Graph tab to show the metric over time.

# Managing K8S objects via Terraform

Most people use `kubectl` and Kubernetes YAML files to declaratively manage
their clusters. However, we'd like to use a single system - Terraform - to
manage our environment as much as possible. The
[Terraform Kubernetes Provider][tf-k8s] can help.

To try this, go into the `10-tf-k8s-test` folder, edit the
`variables.auto.tfvars` file with appropriate values (the names are
self-explanatory), and run:

```
$ terraform init # if not done before
$ terraform apply
```

[tf-k8s]: https://www.terraform.io/docs/providers/kubernetes/index.html

What follows an explanation of what this module does.

### Configuring the Kubernetes Provider

The `kubernetes` provider is configured in the file `settings.tf`. Here, we just
need to ensure the environment variable `KUBECONFIG` is pointing to the
kubeconfig file we generated above.

### Creating a namespace

The file `01-namespace.tf` shows how to create a new namespace named `test`.

### Managing a pod

The file `02-pod.tf` creates a pod named `hello-pod` in the `test` namespace,
with label `app=hello-pod`. You can check that the pod is running by:

```
kubectl get pods -n test -l app=hello-pod -o wide
```

The output should be similar to:

```
NAME        READY   STATUS    RESTARTS   AGE    IP            NODE                           NOMINATED NODE   READINESS GATES
hello-pod   1/1     Running   0          176m   10.2.121.14  .ip-10-2-102-225.ec2.internal   <none>           <none>
```

You can get more details about the pod:

```
kubectl describe pods -n test -l app=hello-pod
```

The output should be similar to:

```
Name:               hello-pod
Namespace:          test
...
Containers:
  httpd:
    ...
    Image:          nginx:1.17
...
```

You can see the pod above has one container, named `httpd`. You can SSH in to it and run commands like this:


```
kubectl exec hello-pod --container httpd -n test -it -- bash -il
```

This will give you a shell prompt (`root@hello-pod:/` for this container) where you can run commands:

```
root@hello-pod:/# nginx -V
nginx version: nginx/1.17.6
...
```

### Managing a Deployment

The file `03-deployment.tf` creates a Deployment named `hello-dep` in the `test` namespace, running 3 replicas of a pod very similar to the previous one, labeled with `app=hello-pod-dep` (note that the app label is diffrent from the deployment label). You can check the the deployment and pods are running, like this:

```
kubectl get deployments -n test -l app=hello-dep -o wide
```

The output should be similar to:

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES       SELECTOR
hello-dep   3/3     3            3           179m   httpd        nginx:1.17   app=hello-dep-pod
```

You can get more details:

```
kubectl describe deployments hello-dep -n test
```

The output should be similar to:

```
Name:                   hello-dep
Namespace:              test
...
Pod Template:
  Labels:  app=hello-dep-pod
  Containers:
   httpd:
...
```

You can list the pods:

```
kubectl get pods -n test -l app=hello-dep-pod -o wide
```

The output should be similar to:

```
NAME                         READY   STATUS    RESTARTS   AGE    IP             NODE                           NOMINATED NODE   READINESS GATES
hello-dep-5d4499db45-fxr44   1/1     Running   0          3h2m   10.2.142.50    ip-10-2-153-187.ec2.internal   <none>           <none>
hello-dep-5d4499db45-hklb8   1/1     Running   0          3h2m   10.2.65.237    ip-10-2-82-164.ec2.internal    <none>           <none>
hello-dep-5d4499db45-ktpnm   1/1     Running   0          3h2m   10.2.109.172   ip-10-2-102-225.ec2.internal   <none>           <none>
```

### Managing a Service: Cluster-Internal

We can create a K8S `ClusterIP` service to expose our deployment pods to other pods within the cluster.  The pods will not be accessible from outside our VPC or even from outside our cluster.

The file `04-service-clusterip.tf` shows how to create a deployment of pods, and map a service to it. While the containers of the pods listen on port `80`, the service listens on a cluster internal IP at port `8080`. The service, deployment and the pods all have a label `app=hello-svc`. The service has been configured to look for pods with the label `app=hello-svc`. You can check that the service, deployment and pods are up:

```
$ kubectl get svc -n test -l app=hello-svc -o wide
NAME        TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE    SELECTOR
hello-svc   ClusterIP   172.20.13.82   <none>        8080/TCP   136m   app=hello-svc

$ kubectl describe svc hello-svc -n test
Name:              hello-svc
Namespace:         test
Labels:            app=hello-svc
Annotations:       <none>
Selector:          app=hello-svc
Type:              ClusterIP
IP:                172.20.13.82
Port:              <unset>  8080/TCP
TargetPort:        80/TCP
Endpoints:         10.2.112.202:80,10.2.138.193:80,10.2.66.147:80
Session Affinity:  ClientIP
Events:            <none>

$ kubectl get deployments -n test -l app=hello-svc -o wide
NAME        READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES       SELECTOR
hello-svc   3/3     3            3           15m   httpd        nginx:1.17   app=hello-svc

$ kubectl describe deployments hello-svc -n test
Name:                   hello-svc
Namespace:              test
CreationTimestamp:      Wed, 18 Dec 2019 16:53:37 +0800
Labels:                 app=hello-svc
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=hello-svc
Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
...

$ kubectl get pods -n test -l app=hello-svc -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP             NODE                           NOMINATED NODE   READINESS GATES
hello-svc-6d9df7cc6c-57jsp   1/1     Running   0          17m   10.2.66.147    ip-10-2-82-164.ec2.internal    <none>           <none>
hello-svc-6d9df7cc6c-bvnwc   1/1     Running   0          17m   10.2.112.202   ip-10-2-102-225.ec2.internal   <none>           <none>
hello-svc-6d9df7cc6c-cq5h4   1/1     Running   0          17m   10.2.138.193   ip-10-2-153-187.ec2.internal   <none>           <none>
```

Notice that the pods' IP addresses are reflected in the service's `Endpoints` object.

Pods inside the cluster can access the service at port `8080` using the automatically registered DNS name `hello-svc`. To test this, we first launch a "shell" container in the cluster in the same namespace `test`:

```
$ kubectl run -it shell --image=busybox /bin/sh -n test
/ #
```

Our pod is running an `nginx` web server in its default config. We can try accessing the index page:

```
/ # wget -qO - http://hello-svc:8080/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

Notice that the `wget` command could resolve the hostname `hello-svc`.

# TODO

