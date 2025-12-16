# ============================================
# CHECK AWS RESOURCES STATUS
# ============================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Checking AWS Resources" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$allDeleted = $true

# ECS Cluster
Write-Host "[1/7] ECS Cluster: " -NoNewline -ForegroundColor Yellow
$ecs = aws ecs describe-clusters --clusters eshop-cluster --query "clusters[?status=='ACTIVE'].clusterName" --output text 2>$null
if ($ecs) {
    Write-Host "EXISTS ($ecs)" -ForegroundColor Red
    $allDeleted = $false
} else {
    Write-Host "Deleted" -ForegroundColor Green
}

# RDS
Write-Host "[2/7] RDS Database: " -NoNewline -ForegroundColor Yellow
$rds = aws rds describe-db-instances --db-instance-identifier eshop-sqlserver --query "DBInstances[0].DBInstanceStatus" --output text 2>$null
if ($rds -and $rds -ne "None") {
    Write-Host "EXISTS ($rds)" -ForegroundColor Red
    $allDeleted = $false
} else {
    Write-Host "Deleted" -ForegroundColor Green
}

# Load Balancer
Write-Host "[3/7] Load Balancer: " -NoNewline -ForegroundColor Yellow
$alb = aws elbv2 describe-load-balancers --names eshop-alb --query "LoadBalancers[0].State.Code" --output text 2>$null
if ($alb -and $alb -ne "None") {
    Write-Host "EXISTS ($alb)" -ForegroundColor Red
    $allDeleted = $false
} else {
    Write-Host "Deleted" -ForegroundColor Green
}

# ECR
Write-Host "[4/7] ECR Repository: " -NoNewline -ForegroundColor Yellow
$ecr = aws ecr describe-repositories --repository-names eshop-web --query "repositories[0].repositoryName" --output text 2>$null
if ($ecr -and $ecr -ne "None") {
    Write-Host "EXISTS ($ecr)" -ForegroundColor Red
    $allDeleted = $false
} else {
    Write-Host "Deleted" -ForegroundColor Green
}

# VPC
Write-Host "[5/7] VPC: " -NoNewline -ForegroundColor Yellow
$vpc = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eshop-vpc" --query "Vpcs[0].VpcId" --output text 2>$null
if ($vpc -and $vpc -ne "None") {
    Write-Host "EXISTS ($vpc)" -ForegroundColor Red
    $allDeleted = $false
} else {
    Write-Host "Deleted" -ForegroundColor Green
}

# NAT Gateway
Write-Host "[6/7] NAT Gateway: " -NoNewline -ForegroundColor Yellow
$nat = aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=eshop-nat-gw" "Name=state,Values=available,pending" --query "NatGateways[0].NatGatewayId" --output text 2>$null
if ($nat -and $nat -ne "None") {
    Write-Host "EXISTS ($nat)" -ForegroundColor Red
    $allDeleted = $false
} else {
    Write-Host "Deleted" -ForegroundColor Green
}

# IAM Roles
Write-Host "[7/7] IAM Roles: " -NoNewline -ForegroundColor Yellow
$role = aws iam get-role --role-name eshop-ecs-execution-role --query "Role.RoleName" --output text 2>$null
if ($role -and $role -ne "None") {
    Write-Host "EXISTS" -ForegroundColor Red
    $allDeleted = $false
} else {
    Write-Host "Deleted" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
if ($allDeleted) {
    Write-Host "  All resources are DELETED!" -ForegroundColor Green
} else {
    Write-Host "  Some resources still exist!" -ForegroundColor Red
    Write-Host "  Run .\scripts\stop.ps1 to delete them." -ForegroundColor Yellow
}
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""