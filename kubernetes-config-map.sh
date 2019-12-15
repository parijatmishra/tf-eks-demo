#!/bin/bash
# See: https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html
# See: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
#       - Tab: Unmanaged nodes -> "To enable worker nodes to join your cluster"
set -ex
cat <<EOF > aws-auth-cm.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
# mapRoles: |
#     - rolearn: $NODEGROUP_IAM_ROLE_ARN
#       username: system:node:{{EC2PrivateDNSName}}
#       groups:
#         - system:bootstrappers
#         - system:nodes
#     - rolearn: $ADMINISTRATOR_ROLE_ARN
#       username: $ADMINISTRATOR_ROLE_ARN
#       groups:
#         - system:masters
# mapUsers: |
#     - userarn: arn:aws:iam::555555555555:user/admin
#       username: admin
#       groups:
#         - system:masters
#     - userarn: arn:aws:iam::111122223333:user/ops-user
#       username: ops-user
#       groups:
#         - system:masters
EOF
kubectl apply -f aws-auth-cm.yml
