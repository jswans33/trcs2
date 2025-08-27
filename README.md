# TRCS2 Shapefile Application

A cost-optimized AWS infrastructure for a shapefile processing application built with NestJS backend, React frontend, and PostgreSQL/PostGIS database.

## Quick Start

**Use the dev-manager script for all operations:**

```bash
./dev-manager.sh
```

The dev-manager provides an interactive menu for:
- Infrastructure status monitoring
- Cost analysis and tracking
- Deployment management
- Troubleshooting assistance
- Database backups
- Log management

## Project Overview

TRCS2 is a geospatial shapefile processing application designed with startup-friendly infrastructure costs. The system processes and manages geographical data using PostGIS extensions in PostgreSQL.

### Architecture

- **Frontend**: React application (served via nginx)
- **Backend**: NestJS API server
- **Database**: PostgreSQL 15.7 with PostGIS extensions
- **Storage**: S3 bucket for shapefile data
- **Infrastructure**: Single-environment AWS deployment

### Cost-Optimized Design

**Target Cost: $35-40/month**

| Service | Cost | Notes |
|---------|------|-------|
| EC2 t3.small | $15.50 | Web application server |
| RDS t3.micro | $13.50 | PostgreSQL database |
| S3 Storage | ~$5.00 | Shapefile storage |
| Data Transfer | ~$2.00 | Estimated |
| **Total** | **~$36/month** | ✅ Under budget |

**Key Cost Optimizations:**
- ❌ No NAT Gateways (saves $65/month)
- ❌ No Load Balancers initially
- ❌ No multiple environments initially
- ✅ Single EC2 instance with Docker
- ✅ Parameter Store (free tier) instead of Secrets Manager

## Infrastructure

### AWS Services Used

- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **EC2**: Single t3.small instance in public subnet
- **RDS**: PostgreSQL t3.micro with automated backups
- **S3**: Single bucket with lifecycle policies
- **Security Groups**: Minimal required access
- **Parameter Store**: Secure configuration storage
- **CloudWatch**: Monitoring and logging

### Network Architecture

```
Internet Gateway
       |
   Public Subnets (2 AZs)
       |
   EC2 Instance
       |
   Private Subnets (2 AZs)
       |
   RDS Database
```

**Security Features:**
- Database in private subnet (no internet access)
- Security groups with least-privilege access
- Encrypted storage (EBS + RDS)
- SSH access restricted to specific IP

## Getting Started

### Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- SSH key pair in AWS
- Docker (for local development)
- Node.js >= 18 (for development)

### 1. Infrastructure Deployment

```bash
# Use the development manager
./dev-manager.sh

# Select option 3: Deploy Infrastructure
# The script handles:
# - Terraform initialization
# - Cost estimation
# - Deployment confirmation
# - Resource validation
```

### 2. Application Deployment

```bash
# Use the development manager
./dev-manager.sh

# Select option 4: Deploy Application
# The script handles:
# - Package creation
# - Upload to EC2
# - Service configuration
# - Health checks
```

### 3. Access Your Application

After deployment:
- **Web Interface**: `http://<EC2-PUBLIC-IP>`
- **API**: `http://<EC2-PUBLIC-IP>/api`
- **SSH Access**: `ssh -i ~/.ssh/trcs-key.pem ubuntu@<EC2-PUBLIC-IP>`

## Development

### Local Development Setup

```bash
# Install dependencies
npm install

# Start database (Docker)
docker run -d \
  --name postgres-local \
  -e POSTGRES_USER=trcsuser \
  -e POSTGRES_PASSWORD=localdev \
  -e POSTGRES_DB=trcs2 \
  -p 5432:5432 \
  postgis/postgis:15-3.3

# Start backend
cd backend
npm run start:dev

# Start frontend (in another terminal)
cd frontend
npm start
```

### Environment Variables

Configuration is managed through AWS Parameter Store:
- `/trcs2/database/host`
- `/trcs2/database/password`
- `/trcs2/jwt/secret`
- `/trcs2/s3/bucket`

## Monitoring & Maintenance

### Health Checks

Use the dev-manager script:
```bash
./dev-manager.sh
# Select option 1: Show Infrastructure Status
# Select option 5: Validate Everything
```

### Cost Monitoring

```bash
./dev-manager.sh
# Select option 2: Check Costs
```

**Cost Alerts Setup:**
- Monthly budget: $40
- Alert threshold: $35 (87.5% of budget)
- Emergency threshold: $50

### Backup Strategy

- **Automated RDS Backups**: 7-day retention
- **Manual Snapshots**: On-demand via dev-manager
- **S3 Versioning**: Enabled for shapefile data

## Troubleshooting

### Common Issues

1. **High Costs (>$40/month)**
   ```bash
   # Check for expensive NAT Gateways
   ./dev-manager.sh
   # Select option 6: Troubleshoot Issues
   ```

2. **Database Connection Issues**
   ```bash
   # Validate security groups and endpoints
   ./dev-manager.sh
   # Select option 5: Validate Everything
   ```

3. **Application Not Responding**
   ```bash
   # Check logs and restart services
   ./dev-manager.sh
   # Select option 8: Show Logs
   ```

### Emergency Procedures

**Infrastructure Lock Down:**
```bash
# Stop all non-critical resources
aws ec2 stop-instances --instance-ids <instance-id>
```

**Cost Emergency:**
```bash
# Remove expensive resources
terraform destroy -target=aws_nat_gateway.main
```

## Documentation

- **[Lessons Learned](LESSONS_LEARNED.md)** - Cost issues and fixes
- **[Terraform README](terraform/README.md)** - Infrastructure details  
- **[Security Guide](SECURITY.md)** - Hardening checklist
- **[Standard Operating Procedures](SOP.md)** - Operational tasks
- **[Deployment Notes](DEPLOYMENT_NOTES.md)** - Known issues and fixes

## Upgrade Path

The infrastructure is designed for easy scaling:

### Phase 1: Initial ($0-5K MRR)
- Current single-environment setup
- Manual deployments via dev-manager
- Basic monitoring

### Phase 2: Growth ($5K-15K MRR)
- Add staging environment
- Implement CI/CD pipeline
- Add Application Load Balancer

### Phase 3: Scale ($15K+ MRR)
- Multi-environment setup
- ECS/Fargate migration
- Advanced monitoring and alerting

## Support

For issues or questions:
1. Check the troubleshooting section
2. Run diagnostic with dev-manager script
3. Review CloudWatch logs
4. Check [known issues](DEPLOYMENT_NOTES.md)

## License

MIT License - see LICENSE file for details.

---

**Last Updated**: August 27, 2024
**Infrastructure Cost**: ~$36/month
**Management Tool**: `./dev-manager.sh`