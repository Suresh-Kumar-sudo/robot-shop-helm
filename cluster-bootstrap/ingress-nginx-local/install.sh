#!/bin/bash

minikube addons enable ingress

kubectl get pods -n ingress-nginx