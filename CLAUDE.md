# TRCS2 Project - AI Assistant Instructions

## Project Overview

TRCS2 is a cost-optimized geospatial shapefile application with NestJS backend, React frontend, and PostGIS database on AWS infrastructure. **Budget constraint: $35-40/month total AWS costs.**

## Critical Project Knowledge

### 1. Cost Management is Paramount

- **Monthly budget**: $40 maximum
- **Current cost**: ~$34/month (under budget ✅)
- **Biggest past issue**: NAT Gateways ($65/month) - now removed
- **Always check costs** before suggesting new AWS resources

### 2. Infrastructure Architecture

```
Single Environment (Production):
- EC2 t3.small (public subnet) - $15.50/month
- RDS PostgreSQL t3.micro (private subnet) - $13.50/month
- S3 bucket - ~$5/month
- NO NAT Gateways (cost savings: $65/month)
- NO Load Balancer initially
```

### 3. Management Tool

**Primary tool**: `./dev-manager.sh` (interactive bash script)

- Use this for ALL infrastructure operations
- Never recommend manual AWS console operations
- Script handles: deployment, monitoring, troubleshooting, costs

### 4. Key Technical Constraints

- **Single environment only** until revenue justifies staging
- **Manual deployments** via dev-manager script
- **Parameter Store** (free) instead of Secrets Manager ($$$)
- **nginx + Docker** instead of ECS/Fargate ($$$)
- **Direct EC2 deployment** instead of container orchestration

## Development Guidelines

### Infrastructure Changes

1. **Always check cost impact first**

   ```bash
   terraform plan -out=tfplan
   terraform show -json tfplan | grep estimated_monthly_cost
   ```

2. **Use dev-manager.sh for all operations**

   ```bash
   ./dev-manager.sh  # Interactive menu
   ```

3. **Never suggest these expensive services**:
   - NAT Gateways ($32/month each)
   - Application Load Balancer ($16/month)
   - Secrets Manager ($0.40/secret/month)
   - ECS/Fargate (compute costs)
   - ElastiCache (unless absolutely needed)

### Application Development

- **Backend**: NestJS with clean architecture principles
- **Frontend**: React (served by nginx)
- **Database**: PostgreSQL 15.7 with PostGIS extensions
- **Deployment**: Docker containers managed by systemd

### Database Configuration

- **Engine Version**: "15.7" (not 15.4 - deprecated)
- **Parameter Group**: Use `pg_stat_statements`, NOT `postgis`
- **PostGIS Installation**: Via SQL after RDS creation:
  ```sql
  CREATE EXTENSION IF NOT EXISTS postgis;
  CREATE EXTENSION IF NOT EXISTS postgis_topology;
  ```

## Common Issues & Solutions

### 1. Cost Overrun

**Symptoms**: Monthly bill >$40
**Check**: NAT Gateways, instance sizes, unused Elastic IPs
**Fix**: Use dev-manager.sh option 2 (Check Costs)

### 2. Terraform State Issues

**Symptoms**: "Resource already exists" errors
**Fix**: Import existing resources instead of destroying:

```bash
terraform import aws_db_instance.main trcs2-postgres
```

### 3. PostGIS Extension Issues

**Symptoms**: Extension not available
**Fix**: Install via SQL, not parameter group:

```sql
CREATE EXTENSION postgis;
```

### 4. Database Connection Problems

**Symptoms**: Can't connect to RDS
**Check**: Security groups, VPC routing, parameter store secrets
**Tool**: dev-manager.sh option 5 (Validate Everything)

## File Structure Knowledge

```
/home/james/projects/trcs2/
├── dev-manager.sh           # Main management tool
├── terraform/               # Infrastructure code
│   ├── vpc.tf              # Network (NO NAT Gateways!)
│   ├── rds.tf              # Database config
│   ├── ec2.tf              # Application server
│   └── variables.tf        # Configuration
├── backend/                # NestJS application
├── frontend/               # React application
├── README.md              # Main documentation
├── LESSONS_LEARNED.md     # Cost issues & fixes
└── [other docs]           # Specialized documentation
```

## AI Assistant Behavior Rules

### DO:

1. **Always use dev-manager.sh** for infrastructure tasks
2. **Check cost implications** before suggesting changes
3. **Reference existing documentation** files
4. **Suggest manual operations** via SSH when appropriate
5. **Consider the $40/month budget** in all recommendations

### DON'T:

1. **Suggest expensive AWS services** without cost justification
2. **Recommend multi-environment setup** until revenue justifies it
3. **Propose container orchestration** (ECS/EKS) for single instance
4. **Ignore the lessons learned** in cost optimization
5. **Override the startup-friendly design principles**

### When Suggesting New Services:

1. Calculate monthly cost impact
2. Explain why it's necessary now vs later
3. Provide cost-effective alternatives
4. Consider the upgrade path timeline

## Scaling Decision Framework

### Add When Revenue Justifies Cost:

**$5K+ MRR**:

- Staging environment
- Load balancer for redundancy
- Automated deployment pipeline

**$15K+ MRR**:

- ECS/Fargate migration
- Multi-AZ database
- Advanced monitoring

**$50K+ MRR**:

- Full multi-environment pipeline
- Microservices architecture
- Dedicated DevOps tooling

## Emergency Procedures

### Cost Emergency (Bill >$60/month):

```bash
# 1. Check for expensive resources
./dev-manager.sh  # Option 2: Check Costs

# 2. Emergency resource removal
terraform destroy -target=aws_nat_gateway.main
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"

# 3. Scale down instances if needed
terraform apply -var="instance_type=t3.nano"
```

### Infrastructure Issues:

```bash
# 1. Use troubleshooting tool
./dev-manager.sh  # Option 6: Troubleshoot Issues

# 2. Validate infrastructure
./dev-manager.sh  # Option 5: Validate Everything

# 3. Check logs
./dev-manager.sh  # Option 8: Show Logs
```

## Key Contacts & Resources

- **Main Documentation**: `/home/james/projects/trcs2/README.md`
- **Cost Issues**: `/home/james/projects/trcs2/LESSONS_LEARNED.md`
- **Operations**: `/home/james/projects/trcs2/SOP.md`
- **Security**: `/home/james/projects/trcs2/SECURITY.md`

## Final Reminder

This is a **startup-budget project**. Every AWS resource costs money. The dev-manager.sh script exists because manual operations led to cost overruns. Always use it, always check costs, always question complexity.

**Project Motto**: "Build it simple, cheap, but with clear upgrade paths when revenue justifies it."
