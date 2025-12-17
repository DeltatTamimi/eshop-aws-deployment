
# eShopOnWeb AWS Deployment

## About This Project

This is my semester project for the Cloud Computing course where I deployed Microsoft's eShopOnWeb sample application to AWS using Infrastructure as Code. I chose AWS instead of the default Azure option because I wanted to challenge myself and learn a different cloud platform.

## What I Built

A complete cloud-native deployment featuring:
- **Infrastructure as Code** using Terraform
- **Containerized application** with Docker and AWS ECS Fargate
- **Managed database** using AWS RDS SQL Server
- **Automated CI/CD** using GitHub Actions
- **Load balancing** with AWS Application Load Balancer

## Architecture Overview

```text
                    Internet
                       │
                       ▼
                ┌─────────────┐
                │     ALB     │
                │  (Public)   │
                └──────┬──────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
   ┌──────────┐             ┌──────────┐
   │ ECS Task │             │ ECS Task │
   │ (Fargate)│             │ (Fargate)│
   └─────┬────┘             └─────┬────┘
         │                        │
         └──────────┬─────────────┘
                    ▼
             ┌─────────────┐
             │  RDS SQL    │
             │  Server     │
             └─────────────┘

```

## Tech Stack

| Component | Technology |
| --- | --- |
| Cloud Provider | AWS (eu-central-1 Frankfurt) |
| IaC | Terraform |
| Compute | ECS Fargate |
| Database | RDS SQL Server Express |
| Container Registry | Amazon ECR |
| Load Balancer | Application Load Balancer |
| CI/CD | GitHub Actions |
| Application | ASP.NET Core 8.0 |

## Quick Start

### Prerequisites

* AWS CLI configured (`aws configure`)
* Terraform installed
* Docker Desktop running
* Git installed

### 1. Clone the Repository

```bash
git clone [https://github.com/DeltatTamimi/eshop-aws-deployment.git](https://github.com/DeltatTamimi/eshop-aws-deployment.git)
cd eshop-aws-deployment

```

### 2. Clone the Application

```bash
git clone [https://github.com/dotnet-architecture/eShopOnWeb.git](https://github.com/dotnet-architecture/eShopOnWeb.git)

```

### 3. Start Everything (Easy Mode)

```powershell
.\scripts\start.ps1

```

This script will:

* Check AWS credentials
* Verify Docker is running
* Deploy infrastructure with Terraform (~10-15 minutes)
* Build and push Docker image
* Deploy to ECS

### 4. Access Your Application

The script will show you the URL, or get it manually:

```bash
cd terraform
terraform output application_url

```

## Managing the Application

### Start/Deploy

```powershell
.\scripts\start.ps1

```

### Stop/Destroy (Important!)

```powershell
.\scripts\stop.ps1

```

Type `destroy` when prompted.

### Check Status

```powershell
.\scripts\check.ps1

```

## CI/CD Pipeline

### Automatic Deployment

Push to the `main` branch triggers automatic deployment:

```bash
git add .
git commit -m "Your changes"
git push

```

### Manual Destroy via GitHub

1. Go to Actions tab
2. Click "Destroy AWS Infrastructure"
3. Click "Run workflow"
4. Type `destroy`
5. Click "Run workflow"

## Test Credentials

The application comes with pre-seeded users:

| Email | Password |
| --- | --- |
| demouser@microsoft.com | Pass@word1 |
| admin@microsoft.com | Pass@word1 |

## Challenges I Faced

### 1. Container Crashing - Environment Variables

**Problem**: The ECS tasks kept crashing with "URI is empty" error.

**Root Cause**: The eShopOnWeb app checks `ASPNETCORE_ENVIRONMENT` and requires different configurations for "Production" vs "Docker" environments.

**Solution**: Set `ASPNETCORE_ENVIRONMENT=Docker` instead of "Production" and added `UseOnlyInMemoryDatabase=true` to bypass Azure-specific configurations.

### 2. Docker Build Failures

**Problem**: Dockerfile couldn't restore dependencies due to missing test project references.

**Solution**: Used .NET SDK 9.0 for building (compatible with .NET 8 projects) and copied the entire eShopOnWeb folder instead of individual projects.

### 3. ECR Push Authentication Issues

**Problem**: Docker couldn't login to ECR with 400 Bad Request errors.

**Root Cause**: IAM user lacked ECR permissions and Docker credential helper conflicts.

**Solution**:

* Added `AmazonEC2ContainerRegistryPowerUser` policy to IAM user
* Used manual password method: `docker login --username AWS --password $PASSWORD`

### 4. GitHub Push Failures - Large Files

**Problem**: Terraform provider files (~685MB) exceeded GitHub's 100MB limit.

**Solution**: Added `.terraform/` to `.gitignore` and cloned eShopOnWeb during CI/CD instead of committing it.

### 5. Terraform State Loss

**Problem**: After cleaning `.terraform` folder, `terraform destroy` couldn't find resources.

**Solution**: Created a robust stop script using AWS CLI that deletes resources directly, independent of Terraform state.

## Project Structure

```
eshop-aws-deployment/
├── .github/workflows/     # CI/CD pipelines
│   ├── deploy.yml        # Auto-deploy on push
│   └── destroy.yml       # Manual infrastructure destruction
├── docker/
│   └── Dockerfile        # Multi-stage build
├── docs/
│   └── architecture.md   # Detailed architecture docs
├── scripts/
│   ├── start.ps1         # One-command deployment
│   ├── stop.ps1          # One-command destruction
│   └── check.ps1         # Verify resources status
├── terraform/
│   ├── modules/          # Reusable infrastructure modules
│   │   ├── vpc/
│   │   ├── ecs/
│   │   ├── rds/
│   │   └── ecr/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── README.md

```

## What I Learned

1. **Terraform modules** make infrastructure code clean and reusable
2. **ECS Fargate** simplifies container deployment significantly
3. **IAM permissions** are crucial - many errors were permission-related
4. **Environment variables** need careful handling between local and cloud
5. **Git large file handling** requires planning for repos with big dependencies
6. **CI/CD pipelines** save enormous time once configured properly
7. **AWS networking** (VPCs, subnets, security groups) is complex but powerful

## Documentation

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

## Author

Mohannad Altamimi
Created for Cloud Computing Semester Project - December 2025
