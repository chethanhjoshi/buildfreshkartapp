# Build the image, push it to ECR, create the EKS cluster (if missing) and deploy.
# Needs: aws CLI (configured with `aws configure`), eksctl, kubectl, Docker Desktop.
# Run from the project root:  .\deploy\eks\deploy.ps1
param(
    [string]$Region = "ap-south-1",
    [string]$Cluster = "freshkart",
    [string]$Repo = "freshkart",
    [string]$Tag = (Get-Date -Format "yyyyMMddHHmmss")
)
$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."
Set-Location $root

$account = aws sts get-caller-identity --query Account --output text
$registry = "$account.dkr.ecr.$Region.amazonaws.com"
$image = "$registry/${Repo}:$Tag"

# 1. ECR repo + image
aws ecr describe-repositories --repository-names $Repo --region $Region *> $null
if ($LASTEXITCODE -ne 0) { aws ecr create-repository --repository-name $Repo --region $Region | Out-Null }
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $registry
docker build --platform linux/amd64 -t $image .
docker push $image

# 2. Cluster (takes ~15-20 min the first time)
eksctl get cluster --name $Cluster --region $Region *> $null
if ($LASTEXITCODE -ne 0) { eksctl create cluster -f deploy/eks/cluster.yaml }
aws eks update-kubeconfig --name $Cluster --region $Region

# 3. Secret from .env, then the app
kubectl create secret generic freshkart-env --from-env-file=.env --dry-run=client -o yaml | kubectl apply -f -
(Get-Content deploy/eks/k8s.yaml -Raw) -replace 'image: IMAGE', "image: $image" | kubectl apply -f -
kubectl rollout status deployment/freshkart --timeout=300s

Write-Host "Waiting for the load balancer hostname..."
do {
    Start-Sleep 10
    $lb = kubectl get svc freshkart -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
} until ($lb)
Write-Host "App URL (DNS can take a few minutes): http://$lb"
