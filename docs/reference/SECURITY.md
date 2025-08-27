# TRCS2 Security Hardening Guide

## Current Security Measures

### Network Security
- **VPC Isolation**: Resources deployed in private VPC (10.0.0.0/16)
- **Security Groups**: Least-privilege access
  - Web: Only ports 80/443 open to internet
  - SSH: Restricted to your IP (174.29.109.20/32)
  - RDS: Only accessible from EC2 security group
- **NAT Gateways**: Secure outbound internet for private subnets

### Data Security
- **Encryption at Rest**:
  - RDS: Encrypted storage
  - S3: Server-side encryption (AES-256)
  - EBS: Encrypted volumes
- **Encryption in Transit**:
  - HTTPS/TLS for web traffic
  - SSL for database connections

### Access Control
- **IAM Roles**: EC2 uses role-based access (no hardcoded credentials)
- **Parameter Store**: Secrets stored securely
- **SSH Key**: RSA key pair authentication only

### Monitoring
- **CloudWatch Alarms**: CPU, memory, disk alerts
- **Logging**: Application and system logs to CloudWatch
- **Metrics Dashboard**: Real-time monitoring

## Additional Hardening Recommendations

### Immediate Actions (Do Now)
```bash
# 1. Enable MFA on AWS root account
aws iam create-virtual-mfa-device --virtual-mfa-device-name root-mfa

# 2. Create IAM user instead of using root
aws iam create-user --user-name admin-user
aws iam attach-user-policy --user-name admin-user --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 3. Rotate database password
NEW_PASS=$(openssl rand -base64 24)
aws ssm put-parameter --name "/trcs2/database/password" --value "$NEW_PASS" --type "SecureString" --overwrite
aws rds modify-db-instance --db-instance-identifier trcs2-db --master-user-password "$NEW_PASS" --apply-immediately

# 4. Enable GuardDuty for threat detection
aws guardduty create-detector --enable --finding-publishing-frequency FIFTEEN_MINUTES

# 5. Enable AWS Config for compliance monitoring
aws configservice put-configuration-recorder --configuration-recorder name=default,roleArn=arn:aws:iam::762233756254:role/aws-service-role
```

### Network Hardening
```bash
# 1. Enable VPC Flow Logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids $(terraform output -raw vpc_id) \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs

# 2. Add WAF for web protection
aws wafv2 create-web-acl \
  --name trcs2-waf \
  --scope REGIONAL \
  --default-action Block={} \
  --rules file://waf-rules.json

# 3. Restrict S3 bucket policies further
aws s3api put-bucket-policy --bucket $(terraform output -raw s3_bucket_id) \
  --policy file://restrictive-bucket-policy.json
```

### Application Hardening
```bash
# 1. Install fail2ban on EC2
ssh -i ~/.ssh/trcs-key.pem ubuntu@$(terraform output -raw web_server_public_ip) << 'EOF'
sudo apt-get update
sudo apt-get install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
EOF

# 2. Configure automatic security updates
ssh -i ~/.ssh/trcs-key.pem ubuntu@$(terraform output -raw web_server_public_ip) << 'EOF'
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
EOF

# 3. Harden SSH configuration
ssh -i ~/.ssh/trcs-key.pem ubuntu@$(terraform output -raw web_server_public_ip) << 'EOF'
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
EOF
```

### Database Hardening
```sql
-- 1. Create read-only user for reporting
CREATE USER readonly WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE trcs2 TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;

-- 2. Enable SSL enforcement
ALTER DATABASE trcs2 SET ssl = on;

-- 3. Set connection limits
ALTER DATABASE trcs2 CONNECTION LIMIT 50;

-- 4. Enable query logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_duration = on;
SELECT pg_reload_conf();
```

### Compliance & Auditing
```bash
# 1. Enable CloudTrail for audit logging
aws cloudtrail create-trail \
  --name trcs2-audit-trail \
  --s3-bucket-name $(terraform output -raw s3_bucket_id)

# 2. Enable Access Analyzer
aws accessanalyzer create-analyzer \
  --analyzer-name trcs2-analyzer \
  --type ACCOUNT

# 3. Run Security Hub assessment
aws securityhub enable-security-hub
aws securityhub enable-import-findings-for-product \
  --product-arn arn:aws:securityhub:us-east-1::product/aws/guardduty
```

## Verification Scripts

### Daily Security Check
```bash
#!/bin/bash
# save as /home/james/projects/trcs2/scripts/security-check.sh

echo "=== TRCS2 Security Check ==="

# Check for exposed ports
echo "Checking security groups..."
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=trcs2-*" \
  --query 'SecurityGroups[*].[GroupName,IpPermissions[?FromPort==`22`]]'

# Check for public S3 objects
echo "Checking S3 bucket public access..."
aws s3api get-public-access-block \
  --bucket $(terraform output -raw s3_bucket_id)

# Check SSL certificates
echo "Checking SSL status..."
openssl s_client -connect $(terraform output -raw web_server_public_ip):443 \
  -servername $(terraform output -raw web_server_public_ip) < /dev/null

# Check for package updates
ssh -i ~/.ssh/trcs-key.pem ubuntu@$(terraform output -raw web_server_public_ip) \
  "sudo apt list --upgradable"

# Check fail2ban status
ssh -i ~/.ssh/trcs-key.pem ubuntu@$(terraform output -raw web_server_public_ip) \
  "sudo fail2ban-client status"

echo "Security check complete!"
```

### Penetration Test Script
```bash
#!/bin/bash
# save as /home/james/projects/trcs2/scripts/pentest.sh

# Basic security scanning
echo "Running security scan..."

# Port scan
nmap -sV $(terraform output -raw web_server_public_ip)

# SSL/TLS check
testssl.sh https://$(terraform output -raw web_server_public_ip)

# OWASP dependency check
docker run --rm \
  -v $(pwd):/src \
  owasp/dependency-check \
  --scan /src \
  --format "HTML" \
  --out /src/security-report

# SQL injection test (basic)
sqlmap -u "http://$(terraform output -raw web_server_public_ip)/api/test" \
  --batch --random-agent

echo "Security scan complete. Review results in security-report/"
```

## Incident Response Plan

### 1. Suspected Breach
```bash
# Immediate actions
terraform apply -var="enable_emergency_lockdown=true"  # Closes all ports except SSH from specific IP

# Snapshot for forensics
aws ec2 create-snapshot --volume-id $(terraform output -raw ebs_volume_id)
aws rds create-db-snapshot --db-instance-identifier trcs2-db

# Rotate all credentials
./scripts/rotate-all-credentials.sh
```

### 2. DDoS Attack
```bash
# Enable AWS Shield Advanced
aws shield subscribe --subscription Shield

# Scale up resources
terraform apply -var="instance_type=t3.large"

# Enable rate limiting
aws wafv2 update-web-acl --add-rate-limit-rule
```

### 3. Data Breach
```bash
# Disable public access immediately
aws s3api put-public-access-block \
  --bucket $(terraform output -raw s3_bucket_id) \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Audit access logs
aws s3api get-bucket-logging --bucket $(terraform output -raw s3_bucket_id)
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=trcs2
```

## Cost of Security Services
- GuardDuty: ~$15-30/month
- WAF: ~$6/month + $0.60 per million requests
- Shield Standard: Free
- Shield Advanced: $3000/month (only for high-value targets)
- Security Hub: ~$10-15/month
- Total Additional Security Cost: ~$35-50/month

## Regular Maintenance Schedule

### Daily
- Check CloudWatch alarms
- Review access logs

### Weekly
- Run security-check.sh script
- Review AWS Security Hub findings
- Check for package updates

### Monthly
- Rotate database password
- Review IAM permissions
- Update security groups if needed
- Run penetration test

### Quarterly
- Full security audit
- Update incident response plan
- Review and update WAF rules
- Disaster recovery drill

## Compliance Certifications
This setup helps meet:
- PCI DSS (with additional controls)
- HIPAA (with BAA and additional encryption)
- SOC 2 Type II (with audit trails)
- GDPR (with data residency controls)

---
**Security Contact**: security@trcs2.example.com
**Last Updated**: 2024-08-27
**Next Review**: 2024-09-27