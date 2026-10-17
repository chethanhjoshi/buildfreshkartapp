# Delete the app, the cluster and the ECR repo so nothing keeps billing.
param([string]$Region = "ap-south-1", [string]$Cluster = "freshkart", [string]$Repo = "freshkart")
kubectl delete -f "$PSScriptRoot\k8s.yaml" --ignore-not-found   # removes the load balancer first
eksctl delete cluster --name $Cluster --region $Region --wait
aws ecr delete-repository --repository-name $Repo --region $Region --force
