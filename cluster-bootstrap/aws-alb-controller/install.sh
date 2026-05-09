#!/bin/bash

helm repo add eks https://aws.github.io/eks-charts

helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=robot-shop-cluster \
  --set serviceAccount.create=true \
  --set region=ap-south-1 \
  --set vpcId=vpc-xxxxxxxx