#!/bin/bash

kubectl create namespace argocd

kubectl apply -n argocd -f install.yaml

kubectl apply -f applications/robot-shop-app.yaml