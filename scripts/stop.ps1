# ============================================
# STOP/DESTROY ESHOP AWS DEPLOYMENT
# ============================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Red
Write-Host "  DESTROYING eShopOnWeb AWS Infrastructure" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Red
Write-Host ""

# Confirmation
$confirm = Read-Host "Type 'destroy' to confirm deletion of ALL AWS resources"
if ($confirm -ne "destroy") {
    Write-Host "`nCancelled. No resources were deleted." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting destruction process..." -ForegroundColor Yellow
Write-Host ""

# Step 1: Stop and Delete ECS Service
Write-Host "[1/12] Stopping ECS Service..." -ForegroundColor Yellow
aws ecs update-service --cluster eshop-cluster --service eshop-service --desired-count 0 2>$null | Out-Null
Start-Sleep -Seconds 5
aws ecs delete-service --cluster eshop-cluster --service eshop-service --force 2>$null | Out-Null
Write-Host "        ECS Service deleted" -ForegroundColor Green

# Step 2: Delete ECS Cluster
Write-Host "[2/12] Deleting ECS Cluster..." -ForegroundColor Yellow
aws ecs delete-cluster --cluster eshop-cluster 2>$null | Out-Null
Write-Host "        ECS Cluster deleted" -ForegroundColor Green

# Step 3: Delete RDS Instance
Write-Host "[3/12] Deleting RDS Database (takes 5-10 minutes)..." -ForegroundColor Yellow
aws rds delete-db-instance --db-instance-identifier eshop-sqlserver --skip-final-snapshot --delete-automated-backups 2>$null | Out-Null
Write-Host "        RDS deletion initiated" -ForegroundColor Green

# Step 4: Delete Load Balancer
Write-Host "[4/12] Deleting Load Balancer..." -ForegroundColor Yellow
$ALB_ARN = aws elbv2 describe-load-balancers --names eshop-alb --query "LoadBalancers[0].LoadBalancerArn" --output text 2>$null
if ($ALB_ARN -and $ALB_ARN -ne "None") {
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN 2>$null | Out-Null
}
Write-Host "        Load Balancer deleted" -ForegroundColor Green

# Step 5: Wait for ALB to delete, then delete Target Group
Write-Host "[5/12] Waiting for ALB to delete..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
$TG_ARN = aws elbv2 describe-target-groups --names eshop-tg --query "TargetGroups[0].TargetGroupArn" --output text 2>$null
if ($TG_ARN -and $TG_ARN -ne "None") {
    aws elbv2 delete-target-group --target-group-arn $TG_ARN 2>$null | Out-Null
}
Write-Host "        Target Group deleted" -ForegroundColor Green

# Step 6: Delete ECR Repository
Write-Host "[6/12] Deleting ECR Repository..." -ForegroundColor Yellow
aws ecr delete-repository --repository-name eshop-web --force 2>$null | Out-Null
Write-Host "        ECR Repository deleted" -ForegroundColor Green

# Step 7: Delete NAT Gateway
Write-Host "[7/12] Deleting NAT Gateway..." -ForegroundColor Yellow
$NAT_ID = aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=eshop-nat-gw" "Name=state,Values=available,pending" --query "NatGateways[0].NatGatewayId" --output text 2>$null
if ($NAT_ID -and $NAT_ID -ne "None") {
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID 2>$null | Out-Null
    Write-Host "        Waiting for NAT Gateway to delete (60 seconds)..." -ForegroundColor Gray
    Start-Sleep -Seconds 60
}
Write-Host "        NAT Gateway deleted" -ForegroundColor Green

# Step 8: Release Elastic IP
Write-Host "[8/12] Releasing Elastic IP..." -ForegroundColor Yellow
$EIP_ALLOC = aws ec2 describe-addresses --filters "Name=tag:Name,Values=eshop-nat-eip" --query "Addresses[0].AllocationId" --output text 2>$null
if ($EIP_ALLOC -and $EIP_ALLOC -ne "None") {
    aws ec2 release-address --allocation-id $EIP_ALLOC 2>$null | Out-Null
}
Write-Host "        Elastic IP released" -ForegroundColor Green

# Step 9: Wait for RDS to delete
Write-Host "[9/12] Waiting for RDS to delete..." -ForegroundColor Yellow
$maxWait = 600  # 10 minutes max
$waited = 0
while ($waited -lt $maxWait) {
    $status = aws rds describe-db-instances --db-instance-identifier eshop-sqlserver --query "DBInstances[0].DBInstanceStatus" --output text 2>$null
    if (!$status -or $status -eq "None") {
        break
    }
    Write-Host "        RDS Status: $status (waiting...)" -ForegroundColor Gray
    Start-Sleep -Seconds 30
    $waited += 30
}
Write-Host "        RDS Database deleted" -ForegroundColor Green

# Step 10: Delete DB Subnet Group
Write-Host "[10/12] Deleting DB Subnet Group..." -ForegroundColor Yellow
aws rds delete-db-subnet-group --db-subnet-group-name eshop-db-subnet-group 2>$null | Out-Null
Write-Host "        DB Subnet Group deleted" -ForegroundColor Green

# Step 11: Delete VPC Resources
Write-Host "[11/12] Deleting VPC Resources..." -ForegroundColor Yellow
$VPC_ID = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eshop-vpc" --query "Vpcs[0].VpcId" --output text 2>$null

if ($VPC_ID -and $VPC_ID -ne "None") {
    # Delete Security Groups (except default)
    $SGS = aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName != 'default'].GroupId" --output text 2>$null
    foreach ($sg in $SGS.Split("`t")) {
        if ($sg -and $sg.Trim()) {
            aws ec2 delete-security-group --group-id $sg.Trim() 2>$null | Out-Null
        }
    }
    
    # Delete Subnets
    $SUBNETS = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text 2>$null
    foreach ($subnet in $SUBNETS.Split("`t")) {
        if ($subnet -and $subnet.Trim()) {
            aws ec2 delete-subnet --subnet-id $subnet.Trim() 2>$null | Out-Null
        }
    }
    
    # Delete Route Tables (except main)
    $RTS = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main != ``true``].RouteTableId" --output text 2>$null
    foreach ($rt in $RTS.Split("`t")) {
        if ($rt -and $rt.Trim()) {
            aws ec2 delete-route-table --route-table-id $rt.Trim() 2>$null | Out-Null
        }
    }
    
    # Detach and Delete Internet Gateway
    $IGW = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>$null
    if ($IGW -and $IGW -ne "None") {
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID 2>$null | Out-Null
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW 2>$null | Out-Null
    }
    
    # Delete VPC
    aws ec2 delete-vpc --vpc-id $VPC_ID 2>$null | Out-Null
}
Write-Host "        VPC Resources deleted" -ForegroundColor Green

# Step 12: Delete IAM Roles and CloudWatch
Write-Host "[12/12] Cleaning up IAM and CloudWatch..." -ForegroundColor Yellow
aws iam detach-role-policy --role-name eshop-ecs-execution-role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>$null | Out-Null
aws iam delete-role --role-name eshop-ecs-execution-role 2>$null | Out-Null
aws iam delete-role --role-name eshop-ecs-task-role 2>$null | Out-Null
aws logs delete-log-group --log-group-name /ecs/eshop 2>$null | Out-Null
Write-Host "        IAM Roles and CloudWatch cleaned up" -ForegroundColor Green

# Clean up local Terraform state
Write-Host ""
Write-Host "Cleaning up local Terraform state..." -ForegroundColor Yellow
$tfPath = "C:\Users\ASUS\eshop-aws-deployment\terraform"
Remove-Item -Path "$tfPath\.terraform" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$tfPath\terraform.tfstate" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$tfPath\terraform.tfstate.backup" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$tfPath\tfplan" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$tfPath\.terraform.lock.hcl" -Force -ErrorAction SilentlyContinue
Write-Host "        Local state cleaned" -ForegroundColor Green

# Done
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  ALL RESOURCES DESTROYED!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Run the check script to verify:" -ForegroundColor White
Write-Host "  .\scripts\check.ps1" -ForegroundColor Yellow
Write-Host ""