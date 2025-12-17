
# Architecture Documentation

## Project Overview

This document explains how I designed and deployed the eShopOnWeb application on AWS. I'll walk through each component, explain my design choices, and share the challenges I encountered along the way.

## Architecture Diagram

```text
                         Internet
                            │
                            ▼
                  ┌──────────────────┐
                  │  Application     │
                  │  Load Balancer   │
                  │  (Public Subnet) │
                  └────────┬─────────┘
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
      ┌─────────────┐             ┌─────────────┐
      │  ECS Task   │             │  ECS Task   │
      │  Container  │             │  Container  │
      │  (Private)  │             │  (Private)  │
      └──────┬──────┘             └──────┬──────┘
             │                           │
             └───────────┬─────────────┘
                         ▼
                  ┌──────────────┐
                  │  RDS SQL     │
                  │  Server      │
                  │  (Private)   │
                  └──────────────┘

```

## Network Design

### VPC Configuration

I created a VPC with CIDR block `10.0.0.0/16` which provides 65,536 IP addresses. This is way more than needed for this project, but it's good practice to plan for growth.

| Subnet Type | CIDR Blocks | Purpose |
| --- | --- | --- |
| Public | 10.0.0.0/24, 10.0.1.0/24 | ALB only |
| Private | 10.0.10.0/24, 10.0.11.0/24 | ECS tasks, RDS |

### Design Rationale

I split the network into public and private subnets following the principle of defense in depth:

* **Public subnets** have direct internet access via Internet Gateway. Only the load balancer sits here because it needs to receive external traffic.
* **Private subnets** have NO direct internet access. Application containers and the database are protected here. They reach the internet through a NAT Gateway only when needed (e.g., pulling Docker images).

### NAT Gateway

The NAT Gateway lets private resources access the internet without being directly exposed. This is necessary for:

* Pulling Docker images from ECR
* Downloading NuGet packages during builds
* Any outbound API calls the app might make

## Compute Layer - ECS Fargate

### Why Fargate Over Other Options?

| Option | Learning Curve | Management Overhead | My Choice |
| --- | --- | --- | --- |
| EC2 Instances | Low | High (patching, scaling) | ❌ |
| ECS on EC2 | Medium | Medium | ❌ |
| **ECS Fargate** | Medium | **None** | **✅** |
| EKS (Kubernetes) | High | High | ❌ Overkill |

I chose Fargate because:

1. No server management - perfect for a semester project
2. Automatic scaling capabilities
3. Integrated with other AWS services

### Task Configuration

Each ECS task runs with:

* **CPU**: 512 units (0.5 vCPU)
* **Memory**: 1024 MB (1 GB)
* **Port**: 8080 (mapped from container)
* **Count**: 2 tasks for high availability

I run 2 tasks so that if one fails, the application stays available while ECS replaces it.

### The Container Environment Challenge

**Initial Problem**: Tasks kept crashing with "URI is empty" errors.

After reading through the eShopOnWeb source code, I discovered it checks `ASPNETCORE_ENVIRONMENT`:

* **"Production"** → Expects Azure Key Vault configuration
* **"Docker"** → Uses local SQL Server configuration

**Solution**: Set `ASPNETCORE_ENVIRONMENT=Docker` and added `UseOnlyInMemoryDatabase=true` to bypass database complexities during initial testing.

## Database Layer - RDS SQL Server

### Why RDS Instead of Containerized Database?

Running SQL Server in a container might seem simpler, but it's problematic:

| Consideration | Container | RDS | Winner |
| --- | --- | --- | --- |
| Data Persistence | Ephemeral | Persistent | RDS |
| Backups | Manual | Automated (7 days) | RDS |
| High Availability | Complex | Multi-AZ option | RDS |
| Performance | Basic | Optimized | RDS |
| Management | Manual | Fully managed | RDS |

### Instance Configuration & Demo Trade-off

I provisioned a fully managed RDS SQL Server instance with the following specs:

| Setting | Value | Reason |
| --- | --- | --- |
| Engine | SQL Server Express | Free license, sufficient for demo |
| Instance | db.t3.small | Smallest available for SQL Server |
| Storage | 20 GB (auto-scaling) | Enough for sample data |
| Security | Private Subnet | Isolated from public internet |

**Note on Data Persistence:**
For the final presentation/demo, I configured the application container to use an **In-Memory Database** (via the `UseOnlyInMemoryDatabase=true` environment variable).

I made this architectural decision for two reasons:

1. **Stability:** It prevents connection timeouts during the short live demo if the RDS instance is "cold" or waking up.
2. **Speed:** It allows the application to start up immediately after deployment without waiting for database schema migrations.

The RDS infrastructure remains fully provisioned and connected via Security Groups, demonstrating that the network architecture is correct, even if the application logic bypasses it for the demo.

### Security Configuration

The RDS security group ONLY allows traffic from the ECS security group on port 1433:

```
ECS Security Group → RDS Security Group (Port 1433)
      ✅                           ❌ Internet

```

This means even if someone compromises the load balancer, they cannot reach the database.

## Load Balancing

### Application Load Balancer

| Setting | Value |
| --- | --- |
| Type | Application (Layer 7) |
| Scheme | Internet-facing |
| Protocol | HTTP (Port 80) |
| Target Type | IP (required for Fargate) |
| Health Check Path | / |
| Health Check Interval | 30 seconds |

### Why No HTTPS?

I only configured HTTP because:

1. HTTPS requires a domain name and SSL certificate
2. AWS Certificate Manager (ACM) is free but adds complexity
3. For a demo project, HTTP is acceptable

**In production**, I would absolutely add:

* Domain name (Route 53)
* SSL certificate (ACM)
* HTTPS listener on port 443
* HTTP to HTTPS redirect

## Container Registry - ECR

Amazon ECR stores my Docker images with:

* **Image scanning** enabled for vulnerability detection
* **Lifecycle policy** keeping only the last 10 images

### Build Process

The Dockerfile uses a multi-stage build:

**Stage 1 (Build)**:

* Uses .NET SDK 9.0 (compatible with .NET 8 projects)
* Copies eShopOnWeb source
* Runs `dotnet publish`

**Stage 2 (Runtime)**:

* Uses .NET ASP.NET 8.0 runtime (smaller image)
* Copies only published files
* Runs as non-root user for security

## CI/CD Pipeline

### GitHub Actions Workflow

```text
Push to main
     │
     ▼
┌────────────────┐
│  Build & Push  │ (3-5 min)
│  Docker Image  │
└───────┬────────┘
        │
        ▼
┌────────────────┐
│   Update ECS   │ (2-3 min)
│    Service     │
└────────────────┘

```

### Deployment Strategy

ECS uses **rolling deployments**:

1. Start new tasks with updated image
2. Wait for health checks to pass
3. Route traffic to new tasks
4. Terminate old tasks

This provides **zero-downtime deployments**.

## Region Selection

**Chosen Region**: `eu-central-1` (Frankfurt, Germany)

| Region | Distance from Budapest | Latency | Decision |
| --- | --- | --- | --- |
| eu-central-1 (Frankfurt) | ~650 km | 10-20ms | ✅ Best |
| eu-west-1 (Ireland) | ~1,800 km | 30-40ms | ❌ |
| eu-south-1 (Milan) | ~700 km | 15-25ms | ❌ |

Frankfurt is closest to Budapest and keeps data in the EU for GDPR compliance.

## Security Implementation

### 1. Network Segmentation

* Public subnets: ALB only
* Private subnets: ECS tasks, RDS
* No direct internet access to application layer

### 2. Security Groups (Firewall Rules)

```text
ALB Security Group:
  Inbound: Port 80 from 0.0.0.0/0 (Internet)
  Outbound: All traffic

ECS Security Group:
  Inbound: Port 8080 from ALB Security Group only
  Outbound: All traffic

RDS Security Group:
  Inbound: Port 1433 from ECS Security Group only
  Outbound: All traffic

```

### 3. IAM Roles (Least Privilege)

* **ECS Execution Role**: Pull images from ECR, write logs to CloudWatch
* **ECS Task Role**: Minimal permissions (none needed currently)

### 4. Container Security

* Runs as non-root user
* No SSH access (Fargate doesn't allow it)
* Read-only root filesystem (could implement)

## Challenges & Solutions

### Challenge 1: Container Startup Failures

**Error**: "Invalid URI: The URI is empty"

**Root Cause**: Application expected Azure Key Vault when `ASPNETCORE_ENVIRONMENT=Production`

**Solution**:

* Set `ASPNETCORE_ENVIRONMENT=Docker`
* Added `UseOnlyInMemoryDatabase=true`
* Simplified configuration for cloud deployment

### Challenge 2: Docker Build Failures

**Error**: "Project file not found" errors during `dotnet restore`

**Root Cause**: Solution file referenced test projects not copied to Docker build context

**Solution**:

* Used .NET SDK 9.0 (backward compatible with .NET 8)
* Copied entire eShopOnWeb folder
* Changed restore command to target Web project only

### Challenge 3: ECR Authentication

**Error**: "400 Bad Request" when pushing to ECR

**Root Cause**:

1. IAM user lacked ECR permissions
2. Docker credential helper conflicts

**Solution**:

* Added `AmazonEC2ContainerRegistryPowerUser` policy
* Used direct password authentication:
```powershell
$PASSWORD = aws ecr get-login-password
docker login --username AWS --password $PASSWORD

```



### Challenge 4: GitHub Large Files

**Error**: Git rejected push due to 685MB Terraform provider binary

**Solution**:

* Added `.terraform/` to `.gitignore`
* Don't commit eShopOnWeb folder (clone during CI/CD)
* Kept repository under 100MB

### Challenge 5: Terraform State Loss

**Problem**: After cleaning `.terraform` folder, `terraform destroy` couldn't find resources

**Solution**: Created AWS CLI-based destroy script that deletes resources directly by querying AWS APIs

## What I Would Do Differently

If I had more time or for production:

### Immediate Improvements

1. **HTTPS/SSL** - Use ACM and custom domain
2. **Secrets Manager** - Store database credentials securely
3. **CloudWatch Alarms** - Alert on high CPU, errors
4. **WAF** - Web Application Firewall for security

### Architecture Enhancements

1. **Multi-AZ RDS** - High availability database
2. **Auto Scaling** - Scale tasks based on CPU/memory
3. **ElastiCache** - Redis for session management
4. **CloudFront CDN** - Cache static assets

### DevOps Improvements

1. **Terraform Remote State** - Store state in S3
2. **Separate environments** - Dev, staging, production
3. **Infrastructure testing** - Terratest or similar
4. **Monitoring dashboard** - CloudWatch or Datadog

## Key Takeaways

### Technical Lessons

1. **Read the application code** - Understanding the app's configuration requirements saved hours
2. **IAM permissions matter** - Most "mysterious" errors were permission issues
3. **Multi-stage Docker builds** - Significantly reduce image size
4. **Git LFS awareness** - Plan for large files early

### DevOps Insights

1. **Infrastructure as Code is powerful** - Can rebuild entire environment in 15 minutes
2. **CI/CD saves time** - After initial setup, deployments are automatic
3. **Monitoring is crucial** - CloudWatch Logs helped debug container crashes

### Cloud Architecture Principles Applied

1. **Security by layers** - Network segmentation, security groups, IAM
2. **High availability** - Multiple AZs, multiple tasks
3. **Scalability** - Can easily increase task count
4. **Managed services** - Focus on application, not infrastructure

## Conclusion

This project taught me that cloud infrastructure is complex but manageable with the right tools. Terraform makes infrastructure reproducible, Fargate eliminates server management, and CI/CD automates deployments.

The most challenging part was debugging the container startup issues, but it taught me to read application code carefully and understand environment-specific configurations.

The most satisfying moment was seeing the entire deployment work end-to-end: push to GitHub → automatic build → automatic deployment → live application. That's real DevOps!

Overall, choosing AWS over Azure was the right decision. It forced me to learn a new platform and demonstrated that cloud-native principles apply across providers.

