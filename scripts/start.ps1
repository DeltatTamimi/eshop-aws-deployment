# ============================================
# START ESHOP AWS DEPLOYMENT
# ============================================

param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\ASUS\eshop-aws-deployment"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  STARTING eShopOnWeb AWS Deployment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check AWS credentials
Write-Host "[1/8] Checking AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "       AWS Account: $($identity.Account)" -ForegroundColor Green
} catch {
    Write-Host "       ERROR: AWS credentials not configured!" -ForegroundColor Red
    Write-Host "       Run 'aws configure' first." -ForegroundColor Red
    exit 1
}

# Step 2: Check Docker
Write-Host "[2/8] Checking Docker..." -ForegroundColor Yellow
try {
    docker info | Out-Null
    Write-Host "       Docker is running" -ForegroundColor Green
} catch {
    Write-Host "       ERROR: Docker is not running!" -ForegroundColor Red
    Write-Host "       Start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Step 3: Clone eShopOnWeb if needed
Write-Host "[3/8] Checking eShopOnWeb source..." -ForegroundColor Yellow
if (!(Test-Path "$ProjectRoot\eShopOnWeb")) {
    Write-Host "       Cloning eShopOnWeb repository..." -ForegroundColor Gray
    git clone https://github.com/dotnet-architecture/eShopOnWeb.git "$ProjectRoot\eShopOnWeb"
    Write-Host "       Cloned successfully" -ForegroundColor Green
} else {
    Write-Host "       eShopOnWeb already exists" -ForegroundColor Green
}

# Step 4: Check terraform.tfvars
Write-Host "[4/8] Checking Terraform variables..." -ForegroundColor Yellow
if (!(Test-Path "$ProjectRoot\terraform\terraform.tfvars")) {
    Write-Host "       Creating terraform.tfvars..." -ForegroundColor Gray
    @"
aws_region     = "eu-central-1"
environment    = "prod"
project_name   = "eshop"
vpc_cidr       = "10.0.0.0/16"
db_username    = "eshop_admin"
db_password    = "MySecurePass2024!"
db_name        = "CatalogDb"
container_port = 8080
desired_count  = 2
"@ | Set-Content "$ProjectRoot\terraform\terraform.tfvars"
    Write-Host "       Created terraform.tfvars (change password if needed)" -ForegroundColor Yellow
} else {
    Write-Host "       terraform.tfvars exists" -ForegroundColor Green
}

# Step 5: Terraform Init
Write-Host "[5/8] Initializing Terraform..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\terraform"
terraform init -input=false | Out-Null
Write-Host "       Terraform initialized" -ForegroundColor Green

# Step 6: Terraform Apply
Write-Host "[6/8] Deploying AWS infrastructure..." -ForegroundColor Yellow
Write-Host "       This takes 10-15 minutes. Please wait..." -ForegroundColor Gray
Write-Host ""
terraform apply -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Host "       ERROR: Terraform apply failed!" -ForegroundColor Red
    exit 1
}

# Get outputs
$ECR_URL = terraform output -raw ecr_repository_url
$APP_URL = terraform output -raw application_url
$AWS_ACCOUNT = $identity.Account

Write-Host ""
Write-Host "       Infrastructure deployed!" -ForegroundColor Green

# Step 7: Build and Push Docker Image
if (!$SkipBuild) {
    Write-Host "[7/8] Building and pushing Docker image..." -ForegroundColor Yellow
    Set-Location $ProjectRoot
    
    # Login to ECR
    Write-Host "       Logging into ECR..." -ForegroundColor Gray
    $PASSWORD = aws ecr get-login-password --region eu-central-1
    $PASSWORD | docker login --username AWS --password-stdin "$AWS_ACCOUNT.dkr.ecr.eu-central-1.amazonaws.com"
    
    # Build
    Write-Host "       Building Docker image..." -ForegroundColor Gray
    docker build -t eshop-web:latest -f docker/Dockerfile .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "       ERROR: Docker build failed!" -ForegroundColor Red
        exit 1
    }
    
    # Tag and Push
    Write-Host "       Pushing to ECR..." -ForegroundColor Gray
    docker tag eshop-web:latest "${ECR_URL}:latest"
    docker push "${ECR_URL}:latest"
    
    Write-Host "       Docker image pushed!" -ForegroundColor Green
} else {
    Write-Host "[7/8] Skipping Docker build (--SkipBuild flag set)" -ForegroundColor Yellow
}

# Step 8: Update ECS Service
Write-Host "[8/8] Deploying to ECS..." -ForegroundColor Yellow
aws ecs update-service --cluster eshop-cluster --service eshop-service --force-new-deployment | Out-Null
Write-Host "       ECS service updated!" -ForegroundColor Green

# Done
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Application URL:" -ForegroundColor White
Write-Host "  $APP_URL" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Wait 2-3 minutes for containers to start." -ForegroundColor Gray
Write-Host ""
Write-Host "  Test credentials:" -ForegroundColor White
Write-Host "  Email: demouser@microsoft.com" -ForegroundColor Gray
Write-Host "  Password: Pass@word1" -ForegroundColor Gray
Write-Host ""