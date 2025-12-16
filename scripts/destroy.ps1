$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Red
Write-Host "  DESTROY ALL INFRASTRUCTURE" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

$confirm = Read-Host "`nAre you sure you want to destroy all resources? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

Push-Location "$PSScriptRoot\..\terraform"
terraform destroy -auto-approve
Pop-Location

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Infrastructure destroyed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
