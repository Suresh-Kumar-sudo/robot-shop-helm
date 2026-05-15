Amazon EKS Setup
1. Install Required Tools

Install:

kubectl
eksctl
helm
aws cli

Verify:

kubectl version --client


eksctl version


helm version


aws --version
2. Configure AWS CLI
aws configure

Provide:

AWS Access Key
AWS Secret Key
Region → ap-south-1
Output → json

Verify:

aws sts get-caller-identity
3. Create EKS Cluster
eksctl create cluster \
  --name robot-shop-cluster \
  --region ap-south-1 \
  --nodes 2 \
  --node-type t3.medium

Verify:

kubectl get nodes
4. Associate IAM OIDC Provider
eksctl utils associate-iam-oidc-provider \
  --cluster robot-shop-cluster \
  --region ap-south-1 \
  --approve
5. Install AWS Load Balancer Controller

Add Helm Repo:

helm repo add eks https://aws.github.io/eks-charts


helm repo update

Download IAM Policy:

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json

Create IAM Policy:

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

Create IAM Service Account:

eksctl create iamserviceaccount \
  --cluster robot-shop-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

Get VPC ID:

aws eks describe-cluster \
  --name robot-shop-cluster \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text

Install Controller:

helm install aws-load-balancer-controller \
eks/aws-load-balancer-controller \
-n kube-system \
--set clusterName=robot-shop-cluster \
--set serviceAccount.create=false \
--set serviceAccount.name=aws-load-balancer-controller \
--set region=ap-south-1 \
--set vpcId=<VPC_ID>
6. Install EBS CSI Driver

Create IAM Service Account:

eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster robot-shop-cluster \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --override-existing-serviceaccounts \
  --approve

Install Addon:

eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster robot-shop-cluster \
  --service-account-role-arn arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_EBS_CSI_DriverRole \
  --force
7. Install Metrics Server
bash cluster-bootstrap/metrics-server/install.sh

Verify:

kubectl top nodes
8. Install KEDA
bash cluster-bootstrap/keda/install.sh

Verify:

kubectl get pods -n keda
9. Install ArgoCD
kubectl create namespace argocd


kubectl apply -n argocd \
-f cluster-bootstrap/argocd/install.yaml
10. Deploy Robot Shop
kubectl apply -f \
cluster-bootstrap/argocd/applications/robot-shop-app.yaml

Verify:

kubectl get applications -n argocd
Useful Commands
Pods
kubectl get pods -A
Services
kubectl get svc -A
Describe Resource
kubectl describe pod <POD_NAME> -n <NAMESPACE>
Logs
kubectl logs <POD_NAME> -n <NAMESPACE>
Watch Resources
kubectl get pods -w
Rollout Status
kubectl rollout status deployment/<DEPLOYMENT_NAME>
Restart Deployment
kubectl rollout restart deployment/<DEPLOYMENT_NAME>
Delete Stuck Pod
kubectl delete pod <POD_NAME> -n <NAMESPACE>