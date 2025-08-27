# TRCS2 Terraform Infrastructure

This directory contains Terraform configuration files for deploying a cost-effective AWS infrastructure for the TRCS2 shapefile application.

## Architecture Overview

The infrastructure includes:
- **VPC** with public and private subnets across 2 availability zones
- **EC2 t3.small instance** in public subnet for the web application
- **RDS PostgreSQL t3.micro** with PostGIS extension in private subnet
- **S3 bucket** for shapefile storage with lifecycle policies
- **Security groups** with minimal required access
- **CloudWatch** monitoring and logging
- **Parameter Store** for configuration management

## Cost Estimate

**ACTUAL Monthly Cost: ~$34/month** ✅ (Under budget!)

Breakdown:
- EC2 t3.small (24/7): ~$15.50/month
- RDS db.t3.micro (24/7): ~$13.50/month
- EBS GP3 20GB: ~$2.40/month
- RDS Storage 20GB: ~$2.30/month
- ~~NAT Gateway: ~$65.00/month~~ ❌ **REMOVED** (saved $65/month!)
- ~~Elastic IP: ~$3.60/month~~ ❌ **REMOVED** 
- Data Transfer: ~$1.00/month (estimated)

**COST OPTIMIZATION LESSONS:**
- NAT Gateways cost $32.40/month EACH (2 AZs = $65/month total)
- This was 65% of our entire infrastructure budget
- **Solution**: Disabled NAT Gateways, private subnets are fully isolated
- RDS doesn't need internet access, EC2 uses Internet Gateway directly

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **SSH Key Pair** created in AWS (named `trcs-key` by default)
4. **jq** installed for validation script

### Create SSH Key Pair

```bash
# Create key pair in AWS
aws ec2 create-key-pair --key-name trcs-key --query 'KeyMaterial' --output text > ~/.ssh/trcs-key.pem

# Set correct permissions
chmod 400 ~/.ssh/trcs-key.pem
```

## Quick Start

**RECOMMENDED: Use the dev-manager script for all operations:**
```bash
cd /home/james/projects/trcs2
./dev-manager.sh
```

**Manual Terraform Operations:**

1. **Validate Configuration**:
   ```bash
   chmod +x validate.sh
   ./validate.sh
   ```

2. **Deploy Infrastructure**:
   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

3. **Get Connection Information**:
   ```bash
   terraform output
   ```

## File Structure

```
terraform/
├── main.tf                 # Provider and data sources
├── variables.tf            # Variable definitions
├── terraform.tfvars        # Variable values (customize this)
├── vpc.tf                  # VPC, subnets, gateways
├── security.tf             # Security groups
├── ec2.tf                  # EC2 instance and IAM
├── rds.tf                  # PostgreSQL database
├── s3.tf                   # S3 bucket configuration
├── parameter_store.tf      # AWS Parameter Store
├── cloudwatch.tf           # Monitoring and alarms
├── outputs.tf              # Terraform outputs
├── user_data.sh           # EC2 initialization script
├── validate.sh            # Validation script
├── .gitignore             # Git ignore rules
└── README.md              # This file
```

## Configuration

### Key Variables (terraform.tfvars)

```hcl
# AWS Configuration
aws_region = "us-east-1"
project_name = "trcs2"

# Network
vpc_cidr = "10.0.0.0/16"

# Security
key_name = "trcs-key"
allowed_ssh_ip = "174.29.109.20/32"  # Your IP address

# Database
db_password = "YourSecurePassword123!"  # Change this!

# Optional
domain_name = "your-domain.com"  # If you have a domain
```

### Important Security Notes

1. **Change the database password** in `terraform.tfvars`
2. **Update SSH IP address** to your current IP
3. **Review security groups** before deployment
4. **Enable MFA** on your AWS account

## Deployment Commands

### Initialize Terraform
```bash
terraform init
```

### Plan Deployment
```bash
terraform plan -out=tfplan
```

### Apply Changes
```bash
terraform apply tfplan
```

### Destroy Infrastructure
```bash
terraform destroy
```

## Post-Deployment Steps

1. **Connect to EC2 Instance**:
   ```bash
   ssh -i ~/.ssh/trcs-key.pem ubuntu@$(terraform output -raw instance_public_ip)
   ```

2. **Test Database Connection**:
   ```bash
   # From EC2 instance
   psql -h $(terraform output -raw db_instance_address) -U trcsuser -d trcs2
   ```

3. **Deploy Application**:
   - Upload your application code to `/home/ubuntu/app/`
   - The user data script sets up Nginx, PM2, and systemd service
   - Application should run on port 3000, proxied through Nginx on port 80

## Monitoring

- **CloudWatch Dashboard**: Available in AWS Console
- **Log Groups**: 
  - `/aws/ec2/trcs2/application` - Application logs
  - `/aws/ec2/trcs2/system` - System logs
- **Alarms**: CPU, Memory, Storage, and Connection monitoring

## Security Features

- **Encrypted storage** for both EBS and RDS
- **Security groups** with minimal required access
- **Private subnets** for database isolation
- **IAM roles** with least-privilege access
- **Parameter Store** for secure configuration storage

## Backup and Recovery

- **RDS automated backups** with 7-day retention
- **S3 versioning** enabled for shapefile storage
- **EBS snapshots** can be enabled for additional backup

## Customization

### Adding SSL/HTTPS
1. Obtain SSL certificate (AWS Certificate Manager or Let's Encrypt)
2. Update security groups to allow HTTPS (port 443)
3. Configure Nginx with SSL settings

### Scaling Considerations
- **Application**: Add Application Load Balancer and Auto Scaling Group
- **Database**: Consider read replicas for read-heavy workloads
- **Storage**: S3 automatically scales

### Cost Optimization
- **Remove NAT Gateway** if private subnet internet access isn't needed
- **Use Spot Instances** for development environments
- **Enable S3 Intelligent Tiering** for automatic cost optimization

## Troubleshooting

### Common Issues

1. **Cost Overrun (Bill >$40/month)**:
   ```bash
   # Check for expensive NAT Gateways
   aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
   # Fix: Remove them
   terraform destroy -target=aws_nat_gateway.main -auto-approve
   ```

2. **RDS Version Error**: 
   ```
   Error: Invalid DB engine version 15.4
   ```
   **Fix**: Use version 15.7 or latest stable version

3. **PostGIS Parameter Error**:
   ```
   Error: Invalid parameter value: postgis for: shared_preload_libraries
   ```
   **Fix**: Use `pg_stat_statements` in parameter group, install PostGIS via SQL:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```

4. **Terraform State Conflicts**:
   ```
   Error: DBParameterGroupAlreadyExists
   ```
   **Fix**: Import existing resources:
   ```bash
   terraform import aws_db_instance.main trcs2-postgres
   terraform import aws_db_parameter_group.main trcs2-postgres-params
   ```

5. **SSH Key Not Found**:
   - Ensure the key pair exists in AWS
   - Update `key_name` variable if using a different key

6. **Database Connection Failed**:
   - Check security groups allow port 5432
   - Verify database is in running state
   - Check Parameter Store for correct credentials

### Getting Help

- **AWS Documentation**: https://docs.aws.amazon.com/
- **Terraform Documentation**: https://registry.terraform.io/providers/hashicorp/aws/
- **PostgreSQL + PostGIS**: https://postgis.net/documentation/

## Cleanup

To avoid ongoing charges, destroy the infrastructure when not needed:

```bash
terraform destroy
```

This will remove all AWS resources created by Terraform.

---

**Note**: Always test deployments in a development environment before applying to production.