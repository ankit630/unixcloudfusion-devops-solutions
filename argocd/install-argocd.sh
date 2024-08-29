#!/bin/bash

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -k ../../unixcloudfusion-k8s-devops/argocd