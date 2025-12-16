$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  eShopOnWeb Full Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "`n[1/5] Initializing Terraform..." -ForegroundColor Green
Push-Location "$ProjectRoot\terraform"
terraform init
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Error: Terraform init failed" -ForegroundColor Red
    Pop-Location
    exit 1 
}

Write-Host "`n[2/5] Planning infrastructure..." -ForegroundColor Green
terraform plan -out=tfplan
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Error: Terraform plan failed" -ForegroundColor Red
    Pop-Location
    exit 1 
}

Write-Host "`n[3/5] Applying infrastructure..." -ForegroundColor Green
terraform apply -auto-approve tfplan
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Error: Terraform apply failed" -ForegroundColor Red
    Pop-Location
    exit 1 
}
Pop-Location

Write-Host "`n[4/5] Building and pushing Docker image..." -ForegroundColor Green
& "$ProjectRoot\scripts\push-to-ecr.ps1"
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Error: Docker push failed" -ForegroundColor Red
    exit 1 
}

Write-Host "`n[5/5] Updating ECS service..." -ForegroundColor Green
aws ecs update-service --cluster eshop-cluster --service eshop-service --force-new-deployment --query "service.serviceName" --output text

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Push-Location "$ProjectRoot\terraform"
$AppUrl = terraform output -raw application_url
Pop-Location

Write-Host "`nApplication URL: $AppUrl" -ForegroundColor Yellow
Write-Host "`nNote: It may take a few minutes for the service to be fully available." -ForegroundColor White
