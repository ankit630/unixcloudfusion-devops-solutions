## Install the EKS Cluster
cd ../aws/EKS/install-eks/
bash -x create-eks-cluster.sh

## Install the Terraform
cd ../../../
bash -x terraform/scripts/manage_terraform.sh terraform/components/todoapp/efs/ apply -auto-approve
bash -x terraform/scripts/manage_terraform.sh terraform/components/todoapp/ecr/ apply -auto-approve

## Install the Argocd
cd argocd/
bash -x install-argocd.sh

## Install the Secrets manager in EKS
bash -x install-gitlab-secretsmanager.sh

## Install the Gitlab runner
cd ../gitlab-runner/
bash -x setup-gitlab-runner.sh