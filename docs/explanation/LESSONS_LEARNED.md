# TRCS2 Lessons Learned

## Critical Cost Issues Discovered

### 1. NAT Gateway Cost Bomb ($65/month saved!)

**The Problem:**
- Terraform deployed 2 NAT Gateways automatically
- Each NAT Gateway costs $32.40/month = $64.80/month total
- This was 65% of our entire $100 budget
- Original estimated cost: $99/month
- Budget target was $35-40/month

**The Fix:**
```bash
# Remove NAT Gateways entirely
terraform destroy -target=aws_nat_gateway.main -auto-approve
terraform destroy -target=aws_eip.nat -auto-approve
```

**Root Cause:**
- Default Terraform VPC modules often include NAT Gateways
- We assumed they were necessary but they're not for this architecture
- Database is in private subnet but doesn't need internet access
- EC2 is in public subnet and can route directly to internet

**Lesson:** Always review AWS cost estimates before deploying. NAT Gateways are luxury items for startups.

### 2. RDS Version Mismatch (15.4 → 15.7)

**The Problem:**
```
Error: creating RDS DB Instance: InvalidParameterValue: 
Invalid DB engine version 15.4
```

**The Solution:**
```hcl
# In rds.tf - changed from:
engine_version = "15.4"
# To:
engine_version = "15.7"
```

**Root Cause:**
- AWS deprecates older PostgreSQL versions
- 15.4 was no longer available in us-east-1
- Need to use `aws rds describe-db-engine-versions` to check available versions

**Lesson:** Pin to major versions (15.x) and let AWS choose the latest patch version.

### 3. PostGIS Parameter Group Issue

**The Problem:**
```
Error: Invalid parameter value: postgis 
for parameter: shared_preload_libraries
```

**The Solution:**
```hcl
# In rds.tf - changed parameter group from:
{
  name  = "shared_preload_libraries"
  value = "postgis"
}
# To:
{
  name  = "shared_preload_libraries"
  value = "pg_stat_statements"
}
```

**Root Cause:**
- PostGIS is not a shared library that can be preloaded
- PostGIS extensions are installed after database creation
- `pg_stat_statements` is the correct parameter for query statistics

**Lesson:** PostGIS extensions are installed via SQL, not parameter groups:
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
```

### 4. Terraform State Management Chaos

**The Problem:**
```
Error: DBParameterGroupAlreadyExists: 
Parameter group trcs2-postgres-params already exists
```

**Multiple Fixes Applied:**
```bash
# Remove from state and re-import
terraform state rm aws_db_parameter_group.main
terraform import aws_db_parameter_group.main trcs2-postgres-params

# Import existing RDS instance
terraform import aws_db_instance.main trcs2-postgres

# Clean up inconsistent state
terraform init -reconfigure
```

**Root Cause:**
- Multiple deployment attempts left orphaned resources
- Terraform tried to create resources that already existed
- State file got out of sync with actual AWS resources

**Lesson:** Use `terraform plan` religiously and consider using remote state storage.

## Why We Switched from CDK to Terraform

**Initial CDK Problems:**
1. **TypeScript Overhead**: Complex type definitions for simple infrastructure
2. **Debugging Difficulty**: CloudFormation stack errors were hard to trace
3. **Cost Visibility**: Harder to estimate costs before deployment
4. **Learning Curve**: Team more familiar with Terraform syntax

**Terraform Advantages:**
1. **Clear Syntax**: HCL is more readable for infrastructure
2. **Cost Planning**: Built-in cost estimation tools
3. **State Management**: Better handling of existing resources
4. **Community**: Larger ecosystem and examples
5. **Import Capability**: Easy to import existing AWS resources

## Infrastructure Design Decisions

### Decision: No Load Balancer Initially

**Reasoning:**
- Application Load Balancer costs ~$16/month minimum
- Single EC2 instance doesn't need load balancing
- Can use nginx for SSL termination and reverse proxy
- Easy to add ALB later when scaling

**Trade-offs:**
- No automatic SSL certificate management
- No health checks and automatic failover
- Single point of failure

### Decision: Database in Private Subnet

**Reasoning:**
- Security best practice
- Prevents direct internet access to database
- Forces all connections through application layer

**Trade-offs:**
- Can't connect directly from development machine
- Must use bastion host or VPN for maintenance
- Slightly more complex network setup

### Decision: Parameter Store over Secrets Manager

**Reasoning:**
- Parameter Store has a free tier (10,000 parameters)
- Secrets Manager costs $0.40 per secret per month
- For 10 secrets, that's $4/month vs free

**Trade-offs:**
- No automatic rotation capabilities
- Must handle rotation manually
- Less integrated with RDS password management

## Deployment Lessons

### Always Check These Before Deploy:

1. **NAT Gateway Count**: Confirm it's 0 for budget builds
2. **RDS Version**: Use latest stable minor version
3. **Instance Types**: Verify t3.micro/t3.small for cost control
4. **Existing Resources**: Run `terraform import` for existing resources
5. **Cost Estimate**: Review total monthly cost estimate

### Deployment Checklist:
```bash
# Pre-deployment validation
terraform validate
terraform fmt -check
terraform plan -out=tfplan

# Review costs
terraform show -json tfplan | jq '.resource_changes[] | select(.change.after.estimated_monthly_cost != null)'

# Check for expensive resources
grep -i "nat_gateway\|load_balancer" *.tf

# Deploy with safeguards
terraform apply tfplan
```

## Operational Lessons

### Cost Monitoring is Critical

**Setup Monthly Budgets:**
```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "TRCS2-Monthly",
    "BudgetLimit": {"Amount": "40", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

### Use dev-manager.sh for Everything

The custom management script prevents costly mistakes:
- Shows cost analysis before deployments
- Validates infrastructure state
- Provides troubleshooting guidance
- Handles common operations safely

### Database Maintenance

**PostGIS Installation After RDS Creation:**
```sql
-- Connect to RDS and run:
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Verify installation:
SELECT PostGIS_Version();
```

## Security Lessons

### SSH Key Management

**Problem**: Easy to lock yourself out of EC2 instances
**Solution**: Always have backup access methods:
- AWS Systems Manager Session Manager
- Secondary SSH key in authorized_keys
- EC2 Instance Connect for emergency access

### Security Group Configuration

**Problem**: Overly permissive rules for development convenience
**Solution**: Use least-privilege principle:
```hcl
# Good: Specific IP for SSH
ingress {
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["YOUR_IP/32"]  # Not 0.0.0.0/0
}
```

## Scaling Lessons

### When to Add Complexity:

1. **Staging Environment**: When you have >$5K MRR
2. **Load Balancer**: When you need >1 instance
3. **NAT Gateway**: When private services need internet access
4. **Secrets Manager**: When you have >25 secrets to manage
5. **ECS/Fargate**: When Docker management becomes a burden

### Upgrade Path Validation:

The current infrastructure can scale by:
1. Changing instance types (t3.small → t3.medium)
2. Adding read replicas to RDS
3. Adding Application Load Balancer
4. Moving to multi-AZ deployments

## Final Recommendations

### For Future Projects:

1. **Start with Terraform**, not CDK for infrastructure
2. **Budget alerts** are mandatory, not optional
3. **Always question NAT Gateways** - they're expensive
4. **Use Parameter Store free tier** instead of Secrets Manager
5. **Single environment first**, add complexity with revenue
6. **Create management scripts** like dev-manager.sh early

### Cost Control Rules:

1. Never deploy without cost estimation
2. Set up billing alerts at 80% of budget
3. Review AWS Cost Explorer weekly
4. Question any service >$10/month for startups
5. Consider spot instances for non-production workloads

### Development Workflow:

1. Always `terraform plan` before apply
2. Import existing resources instead of recreating
3. Use descriptive resource names and tags
4. Keep Terraform state in version control (or remote)
5. Document every infrastructure decision

---

**Total Cost Savings**: $65/month ($780/year)
**Final Monthly Cost**: $34/month (15% under budget)
**Time to Deployment**: 2 hours (after learning these lessons!)

**Key Takeaway**: Infrastructure complexity should match revenue, not ambition.