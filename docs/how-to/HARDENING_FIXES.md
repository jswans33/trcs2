# Infrastructure Hardening & Fix Guide

## IMMEDIATE FIXES FOR CURRENT MESS

### 1. Clean Up Terraform State Issues
```bash
# Check what's actually deployed
aws ec2 describe-instances --filters "Name=tag:Project,Values=TRCS2" --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'
aws rds describe-db-instances --query 'DBInstances[?starts_with(DBInstanceIdentifier, `trcs2`)].[DBInstanceIdentifier,DBInstanceStatus]'

# Import existing resources instead of recreating
terraform import aws_db_instance.main trcs2-postgres
terraform import aws_instance.web <instance-id-if-exists>

# Or nuclear option - destroy and start fresh
terraform destroy -auto-approve
```

### 2. Remove Expensive NAT Gateways ($65/month!)
```bash
# Destroy NAT gateways only
terraform destroy -target=aws_nat_gateway.main -auto-approve
terraform destroy -target=aws_eip.nat -auto-approve
```

## HARDENED TERRAFORM SETUP

### 1. Use Terraform Cloud for State Management
```hcl
# backend.tf
terraform {
  backend "remote" {
    organization = "your-org"
    workspaces {
      name = "trcs2-prod"
    }
  }
}
```

### 2. Add Pre-Checks to Prevent Issues
```hcl
# checks.tf
data "external" "pre_checks" {
  program = ["bash", "${path.module}/pre-checks.sh"]
}

resource "null_resource" "validate_costs" {
  lifecycle {
    precondition {
      condition     = tonumber(var.estimated_monthly_cost) <= 40
      error_message = "Monthly costs exceed $40 budget!"
    }
  }
}
```

### 3. Create Idempotent Resources
```hcl
# Use data sources to check if resources exist
data "aws_db_instance" "existing" {
  db_instance_identifier = "${var.project_name}-postgres"
  count                   = 1
  
  lifecycle {
    ignore_errors = true
  }
}

# Only create if doesn't exist
resource "aws_db_instance" "main" {
  count = length(data.aws_db_instance.existing) == 0 ? 1 : 0
  # ... rest of config
}
```

## DEPLOYMENT SCRIPT WITH SAFEGUARDS

```bash
#!/bin/bash
# deploy-safe.sh

set -e

# Cost check
ESTIMATED_COST=$(terraform plan -json | jq '.resource_changes[] | select(.change.after.estimated_monthly_cost != null) | .change.after.estimated_monthly_cost' | awk '{sum += $1} END {print sum}')
if (( $(echo "$ESTIMATED_COST > 40" | bc -l) )); then
  echo "ERROR: Estimated monthly cost ($ESTIMATED_COST) exceeds budget!"
  exit 1
fi

# Check for existing resources
echo "Checking for existing resources..."
EXISTING_RDS=$(aws rds describe-db-instances --db-instance-identifier trcs2-postgres 2>/dev/null || echo "")
if [ ! -z "$EXISTING_RDS" ]; then
  echo "RDS already exists, importing..."
  terraform import aws_db_instance.main trcs2-postgres || true
fi

# Validate before apply
terraform validate
terraform fmt -check

# Plan with cost estimate
terraform plan -out=tfplan
terraform show -json tfplan | jq '.resource_changes[] | {resource: .address, action: .change.actions[], cost: .change.after.estimated_monthly_cost}'

# Confirm before apply
read -p "Continue with deployment? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  terraform apply tfplan
fi
```

## COST-OPTIMIZED CONFIGURATION

```hcl
# variables.tf - with sane defaults
variable "use_nat_gateway" {
  default = false  # Save $65/month!
}

variable "nat_instance_type" {
  default = "t3.nano"  # $3/month alternative to NAT gateway
}

# vpc.tf - conditional NAT
resource "aws_nat_gateway" "main" {
  count = var.use_nat_gateway ? 2 : 0
  # ...
}

resource "aws_instance" "nat" {
  count         = var.use_nat_gateway ? 0 : 1
  instance_type = var.nat_instance_type
  ami           = data.aws_ami.nat.id
  # ... configure as NAT instance
}
```

## PREVENT THESE ISSUES

### 1. Version Lock Everything
```hcl
# versions.tf
terraform {
  required_version = "~> 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"  # Pin exact version
    }
  }
}

# RDS version check
data "aws_rds_engine_version" "postgresql" {
  engine             = "postgres"
  preferred_versions = ["15.7", "15.8", "15.10"]
}

resource "aws_db_instance" "main" {
  engine_version = data.aws_rds_engine_version.postgresql.version
  # ...
}
```

### 2. Add Import Scripts
```bash
# import-existing.sh
#!/bin/bash

# Import all existing resources
terraform import aws_vpc.main $(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=TRCS2" --query 'Vpcs[0].VpcId' --output text)
terraform import aws_db_instance.main trcs2-postgres
# ... etc
```

### 3. Use Workspaces for Clean Separation
```bash
# Create workspace
terraform workspace new prod

# Switch workspace
terraform workspace select prod

# Deploy to workspace
terraform apply -var-file="prod.tfvars"
```

## MONITORING & ALERTS

```bash
# Set up cost alerts
aws ce create-anomaly-monitor \
  --anomaly-monitor '{"MonitorName":"TRCS2-Cost-Monitor","MonitorType":"CUSTOM","MonitorDimension":"SERVICE"}'

aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "TRCS2-Monthly",
    "BudgetLimit": {"Amount": "40", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

## QUICK FIX FOR RIGHT NOW

```bash
# 1. Check what's actually running
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value]' --output table
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]' --output table

# 2. Import existing RDS if it exists
terraform import aws_db_instance.main trcs2-postgres 2>/dev/null || echo "No RDS to import"

# 3. Remove NAT gateways to save money
terraform destroy -target=aws_nat_gateway.main -auto-approve

# 4. Apply remaining resources
terraform apply -auto-approve -parallelism=1
```

---

This deployment has been a disaster because:
1. NAT Gateways = $65/month (way over budget)
2. RDS version mismatch (15.4 doesn't exist)
3. PostGIS parameter issue
4. State conflicts with existing resources

Run the Quick Fix section to clean this up!