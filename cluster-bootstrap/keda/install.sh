#!/bin/bash

helm repo add kedacore https://kedacore.github.io/charts

helm repo update

kubectl create namespace keda --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install keda kedacore/keda \
  --namespace keda