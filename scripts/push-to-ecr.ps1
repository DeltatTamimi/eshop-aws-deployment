param(
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Push Docker Image to ECR" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AWS_REGION = aws configure get region
if (-not $AWS_REGION) { $AWS_REGION = "eu-central-1" }

Write-Host "`nAWS Account: $AWS_ACCOUNT_ID" -ForegroundColor Yellow
Write-Host "AWS Region: $AWS_REGION" -ForegroundColor Yellow

Push-Location "$PSScriptRoot\..\terraform"
try {
    $ECR_URL = terraform output -raw ecr_repository_url 2>$null
    if (-not $ECR_URL) {
        Write-Host "`nError: Could not get ECR URL. Make sure Terraform has been applied." -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host "ECR Repository: $ECR_URL" -ForegroundColor Yellow

Write-Host "`n[1/4] Logging into ECR..." -ForegroundColor Green
$ECR_REGISTRY = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to login to ECR" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2/4] Building Docker image..." -ForegroundColor Green
Push-Location "$PSScriptRoot\.."
docker build -t "eshop-web:$ImageTag" -f docker/Dockerfile .
Pop-Location

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to build Docker image" -ForegroundColor Red
    exit 1
}

Write-Host "`n[3/4] Tagging image..." -ForegroundColor Green
docker tag "eshop-web:$ImageTag" "${ECR_URL}:$ImageTag"
docker tag "eshop-web:$ImageTag" "${ECR_URL}:latest"

Write-Host "`n[4/4] Pushing image to ECR..." -ForegroundColor Green
docker push "${ECR_URL}:$ImageTag"
docker push "${ECR_URL}:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to push image to ECR" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Image pushed successfully!" -ForegroundColor Green
Write-Host "  ${ECR_URL}:$ImageTag" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
