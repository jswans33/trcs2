# TRCS Infrastructure - Standard Operating Procedures

## 🔐 Secrets Management

### Initial Setup - Store Secrets in AWS Parameter Store
```bash
# Store database password securely
aws ssm put-parameter \
    --name "/trcs/prod/db/password" \
    --value "$DB_PASSWORD" \
    --type "SecureString" \
    --overwrite

# Store JWT secret
aws ssm put-parameter \
    --name "/trcs/prod/jwt/secret" \
    --value "$(openssl rand -base64 32)" \
    --type "SecureString" \
    --overwrite

# Store other sensitive configs
aws ssm put-parameter \
    --name "/trcs/prod/api/key" \
    --value "your-api-key" \
    --type "SecureString" \
    --overwrite
```

### Retrieve Secrets
```bash
# Get a single parameter
aws ssm get-parameter --name "/trcs/prod/db/password" --with-decryption --query 'Parameter.Value' --output text

# Get all parameters for environment
aws ssm get-parameters-by-path --path "/trcs/prod/" --with-decryption
```

## 📦 Initial Deployment

### 1. Prerequisites Checklist
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform installed (1.0+)
- [ ] SSH key created in AWS
- [ ] Your IP whitelisted for SSH access

### 2. Deploy Infrastructure
```bash
cd terraform

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy (takes ~10-15 minutes)
terraform apply -auto-approve

# Save outputs
terraform output > ../infrastructure-outputs.txt
```

### 3. Validate Deployment
```bash
# Run validation script
./validate.sh

# Should see all green checkmarks
```

## 🚀 Daily Operations

### SSH Access
```bash
# Connect to server
ssh -i ~/.ssh/trcs-key.pem ubuntu@$(terraform output -raw ec2_public_ip)

# Check application status
sudo systemctl status trcs
docker ps
```

### Deploy Application Updates
```bash
# From local machine
cd /path/to/trcs2
./scripts/deploy.sh production

# Or manually from server
ssh -i ~/.ssh/trcs-key.pem ubuntu@<EC2-IP>
cd /home/ubuntu/trcs
git pull origin main
docker-compose build
docker-compose down
docker-compose up -d
```

### View Logs
```bash
# From AWS CloudWatch
aws logs tail /aws/ec2/trcs --follow

# From server
ssh -i ~/.ssh/trcs-key.pem ubuntu@<EC2-IP>
docker-compose logs -f
tail -f /home/ubuntu/trcs/logs/app.log
```

## 🔧 Maintenance Tasks

### Weekly Tasks
1. **Check disk space**
   ```bash
   ssh ubuntu@<EC2-IP> df -h
   ```

2. **Review CloudWatch metrics**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/EC2 \
     --metric-name CPUUtilization \
     --dimensions Name=InstanceId,Value=<instance-id> \
     --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 3600 \
     --statistics Average
   ```

3. **Check for security updates**
   ```bash
   ssh ubuntu@<EC2-IP> sudo apt update && sudo apt list --upgradable
   ```

### Monthly Tasks
1. **Rotate database password**
   ```bash
   # Generate new password
   NEW_PASS=$(openssl rand -base64 24)
   
   # Update in Parameter Store
   aws ssm put-parameter \
     --name "/trcs/prod/db/password" \
     --value "$NEW_PASS" \
     --type "SecureString" \
     --overwrite
   
   # Update RDS
   aws rds modify-db-instance \
     --db-instance-identifier trcs-postgres \
     --master-user-password "$NEW_PASS" \
     --apply-immediately
   
   # Restart application to use new password
   ssh ubuntu@<EC2-IP> sudo systemctl restart trcs
   ```

2. **Database backup verification**
   ```bash
   aws rds describe-db-snapshots \
     --db-instance-identifier trcs-postgres \
     --query 'DBSnapshots[0]'
   ```

3. **SSL certificate renewal (if using domain)**
   ```bash
   ssh ubuntu@<EC2-IP> sudo certbot renew --dry-run
   ```

## 🚨 Troubleshooting

### Application Won't Start
```bash
# Check logs
docker-compose logs --tail=100

# Check environment variables
docker-compose config

# Restart services
docker-compose down
docker-compose up -d
```

### Database Connection Issues
```bash
# Test connection from EC2
ssh ubuntu@<EC2-IP>
PGPASSWORD=$(aws ssm get-parameter --name "/trcs/prod/db/password" --with-decryption --query 'Parameter.Value' --output text) \
  psql -h <RDS-ENDPOINT> -U trcs_admin -d trcs_db -c "SELECT 1"

# Check security group
aws ec2 describe-security-groups --group-ids <sg-id>
```

### High CPU/Memory Usage
```bash
# Check processes
ssh ubuntu@<EC2-IP> htop

# Check Docker stats
docker stats

# Scale up if needed
aws ec2 modify-instance-attribute \
  --instance-id <instance-id> \
  --instance-type "{\"Value\": \"t3.medium\"}"
```

## 📊 Monitoring & Alerts

### Set Up Email Notifications
```bash
# Create SNS topic
aws sns create-topic --name trcs-alerts

# Subscribe email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:<ACCOUNT>:trcs-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Attach to CloudWatch alarms
aws cloudwatch put-metric-alarm \
  --alarm-name trcs-high-cpu \
  --alarm-actions arn:aws:sns:us-east-1:<ACCOUNT>:trcs-alerts \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold
```

## 💰 Cost Optimization

### Monitor Costs
```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE
```

### Reduce Costs When Not in Use
```bash
# Stop EC2 instance (evenings/weekends)
aws ec2 stop-instances --instance-ids <instance-id>

# Start EC2 instance
aws ec2 start-instances --instance-ids <instance-id>

# Schedule RDS to stop at night (Dev only)
aws rds stop-db-instance --db-instance-identifier trcs-postgres
```

## 🔄 Backup & Recovery

### Manual Backup
```bash
# Database backup
ssh ubuntu@<EC2-IP>
PGPASSWORD=<password> pg_dump -h <RDS-ENDPOINT> -U trcs_admin trcs_db > backup_$(date +%Y%m%d).sql
aws s3 cp backup_*.sql s3://trcs-shapefiles-<ACCOUNT>/backups/

# Application files backup
tar -czf app_backup_$(date +%Y%m%d).tar.gz /home/ubuntu/trcs
aws s3 cp app_backup_*.tar.gz s3://trcs-shapefiles-<ACCOUNT>/backups/
```

### Restore from Backup
```bash
# Restore database
aws s3 cp s3://trcs-shapefiles-<ACCOUNT>/backups/backup_20240101.sql .
PGPASSWORD=<password> psql -h <RDS-ENDPOINT> -U trcs_admin trcs_db < backup_20240101.sql

# Restore from RDS snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier trcs-postgres-restored \
  --db-snapshot-identifier <snapshot-id>
```

## 🔄 Infrastructure Updates

### Update Terraform
```bash
cd terraform
terraform plan
terraform apply

# If issues, rollback
terraform plan -destroy
terraform destroy
```

### Scale Resources
```bash
# Edit terraform.tfvars
# Change instance_type = "t3.medium"
# Change db_instance_class = "db.t3.small"

terraform plan
terraform apply
```

## 📋 Important Commands Reference

```bash
# Get all infrastructure info
cd terraform && terraform output

# SSH to server
ssh -i ~/.ssh/trcs-key.pem ubuntu@$(terraform output -raw ec2_public_ip)

# View application logs
aws logs tail /aws/ec2/trcs --follow

# Check costs
aws ce get-cost-forecast \
  --time-period Start=$(date -u +%Y-%m-%d),End=$(date -u -d '+1 month' +%Y-%m-%d) \
  --metric UNBLENDED_COST \
  --granularity MONTHLY

# Emergency stop all resources
aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text)
```

## 🔐 Security Checklist

- [ ] Rotate passwords quarterly
- [ ] Review security group rules monthly
- [ ] Check for AWS security recommendations
- [ ] Update OS packages monthly
- [ ] Review IAM permissions quarterly
- [ ] Enable MFA on AWS root account
- [ ] Use Parameter Store for all secrets
- [ ] Never commit secrets to Git

## 📞 Support Escalation

1. **Level 1**: Check CloudWatch logs and dashboards
2. **Level 2**: SSH to server and check Docker/nginx logs
3. **Level 3**: Check RDS and networking configurations
4. **Level 4**: Review Terraform state and AWS Console

---

**Last Updated**: 2024-08-27
**Version**: 1.0
**Owner**: DevOps Team