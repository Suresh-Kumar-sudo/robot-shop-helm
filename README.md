# Robot Shop — Helm & Kubernetes Deployment

Helm-based deployment for Robot Shop supporting both local development (Minikube) and production (AWS EKS) environments, managed via ArgoCD GitOps.

---

## Repository

```
https://github.com/Suresh-Kumar-sudo/robot-shop-helm.git
```

> **Before starting:** Fork or clone the repo, then update `values.yaml` per your target environment (see environment-specific sections below).

---

## Deployment Targets

| Environment | Ingress | Storage Class |
|---|---|---|
| Minikube | `ingressLocal` | `default` |
| AWS EKS | `ingressAlb` | `gp3` |

---

## Local Development — Minikube

### values.yaml changes

```yaml
global:
  storageClass: default

ingressAlb:
  enabled: false

ingressLocal:
  enabled: true
```

---

### Step 1 — Start Minikube

```bash
minikube start
```

```bash
kubectl get nodes
```

---

### Step 2 — Enable Ingress

```bash
minikube addons enable ingress
```

```bash
kubectl get pods -n ingress-nginx
```

---

### Step 3 — Enable Metrics Server

```bash
minikube addons enable metrics-server
```

```bash
kubectl top nodes
```

---

### Step 4 — Install KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

kubectl create namespace keda

helm install keda kedacore/keda -n keda
```

```bash
kubectl get pods -n keda
```

---

### Step 5 — Install ArgoCD

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd
```

```bash
kubectl get pods -n argocd
```

---

### Step 6 — Expose ArgoCD UI

```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort", "ports": [{"port":80,"targetPort":8080,"nodePort":31006}]}}'
```

Get the ArgoCD admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

Access the UI at `http://<MINIKUBE-IP>:31006` — get your Minikube IP with:

```bash
minikube ip
```

---

### Step 7 — Deploy Robot Shop

```bash
kubectl apply -f cluster-bootstrap/argocd/applications/robot-shop-app.yaml
```

```bash
kubectl get applications -n argocd
kubectl get all -n robot-shop
```

---

### Step 8 — Access the Application

Add a local DNS entry:

```bash
sudo nano /etc/hosts
```

```
<MINIKUBE-IP>  robot-shop.local
```

Open [http://robot-shop.local](http://robot-shop.local)

---
---

## Production — AWS EKS

### values.yaml changes

```yaml
global:
  storageClass: gp3

ingressAlb:
  enabled: true

ingressLocal:
  enabled: false
```

---

### Step 1 — Install Required Tools

Install the following CLI tools:

| Tool | Purpose |
|---|---|
| `kubectl` | Kubernetes CLI |
| `eksctl` | EKS cluster management |
| `helm` | Kubernetes package manager |
| `aws cli` | AWS resource management |

Verify installations:

```bash
kubectl version --client
eksctl version
helm version
aws --version
```

---

### Step 2 — Configure AWS CLI

```bash
aws configure
```

| Prompt | Value |
|---|---|
| AWS Access Key | `<your-access-key>` |
| AWS Secret Key | `<your-secret-key>` |
| Region | `ap-south-1` |
| Output format | `json` |

Verify:

```bash
aws sts get-caller-identity
```

---

### Step 3 — Create EKS Cluster

```bash
eksctl create cluster \
  --name robot-shop-cluster \
  --region ap-south-1 \
  --nodes 2 \
  --node-type t3.medium
```

```bash
kubectl get nodes
```

---

### Step 4 — Associate IAM OIDC Provider

Required for IAM service accounts used by cluster add-ons.

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster robot-shop-cluster \
  --region ap-south-1 \
  --approve
```

---

### Step 5 — Install AWS Load Balancer Controller

**Add Helm repo:**

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

**Create IAM policy:**

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

**Create IAM service account:**

```bash
eksctl create iamserviceaccount \
  --cluster robot-shop-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

**Get VPC ID:**

```bash
aws eks describe-cluster \
  --name robot-shop-cluster \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text
```

**Install controller:**

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=robot-shop-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=<VPC_ID>
```

---

### Step 6 — Install EBS CSI Driver

**Create IAM service account:**

```bash
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster robot-shop-cluster \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --override-existing-serviceaccounts \
  --approve
```

**Install addon:**

```bash
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster robot-shop-cluster \
  --service-account-role-arn arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_EBS_CSI_DriverRole \
  --force
```

---

### Step 7 — Install Metrics Server

```bash
kubectl top nodes
```

---

### Step 8 — Install KEDA

```bash
bash cluster-bootstrap/keda/install.sh
```

<details>
<summary>install.sh contents</summary>

```bash
#!/bin/bash

set -e

helm repo add kedacore https://kedacore.github.io/charts
helm repo update

kubectl create namespace keda \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --wait
```

</details>

```bash
kubectl get pods -n keda
```

---

### Step 9 — Install ArgoCD

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd
```

Expose via Load Balancer:

```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"LoadBalancer"}}'
```

Wait for the external IP:

```bash
kubectl get svc argocd-server -n argocd
```

Get the admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

Access the UI at `https://<EXTERNAL-IP>` with username `admin`.

---

### Step 10 — Deploy Robot Shop

Apply the gp3 StorageClass and ArgoCD application:

```bash
kubectl apply -f cluster-bootstrap/storageclass/gp3.yaml

kubectl apply -f cluster-bootstrap/argocd/applications/robot-shop-app.yaml
```

```bash
kubectl get applications -n argocd
```

---

## Useful Commands

### Cluster Health

```bash
# All pods across namespaces
kubectl get pods -A

# All services across namespaces
kubectl get svc -A

# Watch pods in real time
kubectl get pods -w
```

### Debugging

```bash
# Describe a resource
kubectl describe pod <POD_NAME> -n <NAMESPACE>

# View logs
kubectl logs <POD_NAME> -n <NAMESPACE>

# Rollout status
kubectl rollout status deployment/<DEPLOYMENT_NAME>
```

### Recovery

```bash
# Restart a deployment
kubectl rollout restart deployment/<DEPLOYMENT_NAME>

# Delete a stuck pod
kubectl delete pod <POD_NAME> -n <NAMESPACE>
```

---

## Future Enhancements

| Feature | Description |
|---|---|
| Kubernetes Network Policies | Restrict pod-to-pod communication — enforce least-privilege networking across namespaces and services |
| Monitoring & Observability | Integrate Prometheus + Grafana for metrics, Loki for log aggregation, and distributed tracing (Tempo / Jaeger) |
| Karpenter / EKS Auto Mode | Replace managed node groups with Karpenter for intelligent, cost-optimised node provisioning on EKS |
| Blue/Green Deployment | Zero-downtime releases by running parallel environments — shift traffic via ArgoCD Rollouts or ALB weighted target groups |