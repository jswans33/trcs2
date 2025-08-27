# TRCS2 Deployment Notes & Issues

## Issues Encountered

### 1. ❌ NAT Gateway Cost Overrun
- **Problem**: 2 NAT gateways deployed = $65/month (way over $35-40 budget)
- **Solution**: Should use single NAT or remove entirely for cost savings
- **Status**: Currently deployed but needs fixing

### 2. ❌ PostGIS Extension Issue
- **Problem**: RDS parameter group rejected "postgis" in shared_preload_libraries
- **Error**: `Invalid parameter value: postgis for: shared_preload_libraries`
- **Solution**: Changed to "pg_stat_statements" instead
- **Note**: PostGIS must be installed via SQL after RDS creation

### 3. ⚠️ Parameter Group State Conflict
- **Problem**: Terraform tried to recreate existing parameter group
- **Error**: `DBParameterGroupAlreadyExists: Parameter group trcs2-postgres-params already exists`
- **Solution**: Removed from state and re-imported: 
  ```bash
  terraform state rm aws_db_parameter_group.main
  terraform import aws_db_parameter_group.main trcs2-postgres-params
  ```

## Current Infrastructure Status

### ✅ Deployed Successfully
- VPC with public/private subnets
- Security groups (web, RDS, ALB)
- Internet Gateway
- 2 NAT Gateways (needs reduction)
- S3 bucket: `trcs2-shapefiles-6efa8e5b`
- IAM roles and policies
- CloudWatch log groups
- Parameter Store entries

### 🚧 In Progress
- EC2 instance (t3.small)
- RDS PostgreSQL (t3.micro)
- CloudWatch alarms
- Elastic IP

### 💰 Cost Analysis
| Service | Monthly Cost | Status |
|---------|-------------|--------|
| NAT Gateways (2) | $65.00 | ❌ Over budget |
| EC2 t3.small | $15.50 | ✅ OK |
| RDS t3.micro | $13.50 | ✅ OK |
| S3 + Storage | $5.00 | ✅ OK |
| **Total** | **$99.00** | ❌ **2.5x over budget!** |

## Required Fixes

### Immediate (Cost Reduction)
1. Remove or reduce NAT gateways:
   ```hcl
   # Change in vpc.tf from:
   nat_gateway_count = 2
   # To:
   nat_gateway_count = 0  # Use public subnets instead
   ```

2. Alternative: Use NAT instance (t3.nano = $3/month) instead of NAT Gateway

### Post-Deployment
1. Install PostGIS on RDS:
   ```sql
   CREATE EXTENSION postgis;
   CREATE EXTENSION postgis_topology;
   ```

2. Configure SSL certificates for domain (when ready)

3. Set up automated backups

## Lessons Learned
1. **NAT Gateways are expensive**: $32.40/month each - avoid for budget builds
2. **PostGIS requires manual setup**: Not available in RDS parameter groups
3. **State management is critical**: Always check existing resources before apply
4. **Read the cost estimates**: Terraform shows estimated costs in outputs

## Next Steps
1. ⚠️ **CRITICAL**: Destroy NAT gateways to reduce costs
2. Complete EC2 and RDS deployment
3. Run validation script
4. Deploy application code
5. Configure monitoring

## Commands Reference
```bash
# Check current costs
aws ce get-cost-forecast \
  --time-period Start=$(date +%Y-%m-%d),End=$(date -d '+30 days' +%Y-%m-%d) \
  --metric UNBLENDED_COST \
  --granularity MONTHLY

# Remove NAT gateways
terraform destroy -target=aws_nat_gateway.main

# Check what's deployed
terraform state list

# Get outputs
terraform output
```

---
**Last Updated**: 2024-08-27 04:40
**Deployment ID**: bvqOWw
**AWS Account**: 762233756254