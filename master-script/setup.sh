## Install the EKS Cluster
cd ../aws/EKS/install-eks/
bash -x create-eks-cluster.sh

## Install the Terraform
cd ../../../setup_terraform/scripts/
bash -x setup_terraform_backend.sh

## Install the EFS Volume
cd ../../aws/efs/todoapp/
bash -x setup-efs.sh

## Create the ECR Repository
cd ../../ecr/todo-app
bash -x create_ecr.sh

## Install the Argocd
cd ../../../argocd/
bash -x install-argocd.sh

## Install the Secrets manager in EKS
bash -x install-gitlab-secretsmanager.sh

## Install the Gitlab runner
cd ../gitlab-runner/
bash -x setup-gitlab-runner.sh