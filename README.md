Readme · MD
Copy

# Multi-Region Disaster Recovery on AWS 🌎
 
A production-style disaster recovery project built on AWS using S3 cross-region replication, Route 53 failover, and Terraform. Demonstrates warm standby architecture across two AWS regions with automated infrastructure as code.
 
---
 
## Architecture Diagram
 
```
                        ┌─────────────────────┐
                        │       User           │
                        │   (Browser Request)  │
                        └────────┬────────────┘
                                 │
                                 ▼
                        ┌─────────────────────┐
                        │      Route 53        │
                        │  Failover DNS +      │
                        │   Health Check       │
                        └────────┬────────────┘
                                 │
                ┌────────────────┴────────────────┐
                │ Normal traffic                   │ Failover traffic
                ▼                                  ▼
┌───────────────────────────┐      ┌───────────────────────────┐
│   PRIMARY S3 BUCKET       │      │   SECONDARY S3 BUCKET     │
│   us-east-1 (Virginia)    │      │   us-west-2 (Oregon)      │
│                           │      │                           │
│  ✅ Static website        │      │  ✅ Static website        │
│  ✅ Versioning enabled    │      │  ✅ Versioning enabled    │
│  ✅ Public bucket policy  │      │  ✅ Public bucket policy  │
│  ✅ index.html            │      │  ✅ index.html (replicated│
│  ✅ error.html            │      │  ✅ error.html (replicated│
└───────────┬───────────────┘      └───────────────────────────┘
            │                                   ▲
            │     S3 Cross-Region Replication   │
            │     (automatic, near real-time)   │
            └───────────────────────────────────┘
                        │
            ┌───────────▼───────────┐
            │   IAM Replication     │
            │       Role            │
            │  (least privilege)    │
            └───────────────────────┘
```
 
---
 
## What This Project Demonstrates
 
- Multi-region AWS architecture design
- S3 static website hosting
- S3 versioning and cross-region replication
- IAM role design with least privilege
- Terraform multi-region deployments using provider aliases
- Infrastructure as Code (IaC) best practices
- Disaster recovery concepts: RTO and RPO
- Optional Route 53 DNS failover
---
 
## Recovery Targets
 
| Target | Goal |
|--------|------|
| RTO (Recovery Time Objective) | Minutes — time for Route 53 health check and DNS propagation |
| RPO (Recovery Point Objective) | Near-zero — S3 replication runs near real-time |
| DR Pattern | Warm standby |
| Primary Region | `us-east-1` (N. Virginia) |
| Secondary Region | `us-west-2` (Oregon) |
 
---
 
## Repository Structure
 
```
aws-multi-region-dr/
├── .gitignore
├── README.md
├── terraform/
│   ├── main.tf                    # All AWS resources
│   ├── providers.tf               # AWS provider + region aliases
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Website URLs and resource info
│   └── terraform.tfvars.example  # Config template
└── website/
    ├── index.html                 # Primary demo page
    └── error.html                 # 404 error page
```
 
---
 
## Prerequisites
 
- AWS account
- AWS CLI configured locally
- Terraform v1.3.0 or higher
Verify AWS access:
 
```bash
aws sts get-caller-identity
```
 
---
 
## Deploy With Terraform
 
**1. Clone the repo:**
 
```bash
git clone https://github.com/eopong87/aws-multi-region-dr.git
cd aws-multi-region-dr
```
 
**2. Set up your variables:**
 
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
 
Edit `terraform.tfvars` and set your unique bucket prefix:
 
```hcl
bucket_prefix = "yourname"
```
 
**3. Initialize Terraform:**
 
```bash
terraform init
```
 
**4. Preview what will be created:**
 
```bash
terraform plan
```
 
**5. Deploy:**
 
```bash
terraform apply
```
 
**6. Upload website files to the primary bucket:**
 
```bash
cd ..
aws s3 cp website/index.html s3://yourname-dr-primary/
aws s3 cp website/error.html s3://yourname-dr-primary/
```
 
**7. Open your website URLs from the Terraform outputs.**
 
---
 
## How to Enable Route 53 Failover
 
Route 53 failover requires a registered domain. When you have one, set these values in `terraform.tfvars`:
 
```hcl
enable_route53_failover = true
hosted_zone_id          = "YOUR_HOSTED_ZONE_ID"
domain_name             = "dr-demo.yourdomain.com"
```
 
Then run:
 
```bash
terraform plan
terraform apply
```
 
---
 
## Test Disaster Recovery
 
**Test replication:**
1. Modify `website/index.html` locally
2. Upload to the primary bucket: `aws s3 cp website/index.html s3://yourname-dr-primary/`
3. Wait 60 seconds
4. Check the secondary bucket: `aws s3 ls s3://yourname-dr-secondary/`
5. Confirm the updated file appears automatically
**Test failover (requires Route 53):**
1. Go to the primary bucket → Properties → Static website hosting
2. Change the index document to a file that doesn't exist (e.g. `missing.html`)
3. Wait for the Route 53 health check to go unhealthy (~2-3 minutes)
4. Confirm traffic routes to the secondary endpoint
5. Restore: change the index document back to `index.html`
---
 
## Clean Up
 
Empty both buckets first, then destroy:
 
```bash
aws s3 rm s3://yourname-dr-primary --recursive
aws s3 rm s3://yourname-dr-secondary --recursive
cd terraform
terraform destroy
```
 
---
 
## Key Concepts
 
**RTO vs RPO**
- RTO (Recovery Time Objective) — how long does it take to recover? Here: minutes.
- RPO (Recovery Point Objective) — how much data could you lose? Here: near-zero because replication is near real-time.
**Why versioning is required**
S3 cross-region replication only works on buckets with versioning enabled. It also protects against accidental overwrites.
 
**Warm standby vs cold standby**
Warm means the secondary is already running and receiving replicated data. Cold means you'd rebuild from scratch — much slower RTO.
 
**Why this uses static files**
Static content keeps the lab cost near zero. The same DR concepts apply to real applications — you would additionally need database replication, secrets management, and application health checks.
 
---
 
## Portfolio Notes
 
This project is part of a cloud engineering portfolio demonstrating AWS infrastructure and disaster recovery patterns. For a real production application the same pattern would also require:
 
- RDS Multi-AZ or Aurora Global for database replication
- Secrets Manager with cross-region secret replication
- ECS or EC2 application layer in both regions
- CloudWatch alarms driving automated failover
- Tested failback procedures and runbooks
- CI/CD deployment strategy (blue/green or canary)
---
 
## Built With
 
![AWS](https://img.shields.io/badge/AWS-S3%20%7C%20Route%2053%20%7C%20IAM-orange?logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-v1.3%2B-purple?logo=terraform)
![HTML](https://img.shields.io/badge/HTML-Static%20Website-blue?logo=html5)