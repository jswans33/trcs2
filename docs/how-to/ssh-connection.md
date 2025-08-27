# SSH Connection Guide

## Quick Connect

### Using dev-manager (Recommended)
```bash
./dev-manager.sh
# Select option 12: 🔌 SSH into EC2 Instance
```

### Direct SSH Command
```bash
ssh -i ~/.ssh/trcs-key.pem ubuntu@18.210.234.220
```

## Connection Details

- **User**: `ubuntu`
- **Key**: `~/.ssh/trcs-key.pem`
- **IP**: Dynamic (check with dev-manager option 1)
- **Port**: 22 (SSH default)

## Get Current IP Address

### Method 1: Using dev-manager
```bash
./dev-manager.sh
# Select option 1 (Show Infrastructure Status)
# Look for EC2 public IP
```

### Method 2: Using Terraform
```bash
cd terraform
terraform output ssh_connection
```

### Method 3: Using AWS CLI
```bash
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=trcs2-web-server" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text
```

## Common SSH Tasks

### Check Application Status
```bash
ssh -i ~/.ssh/trcs-key.pem ubuntu@<IP> "sudo systemctl status trcs2"
```

### View Application Logs
```bash
ssh -i ~/.ssh/trcs-key.pem ubuntu@<IP> "tail -f /home/ubuntu/app/logs/application.log"
```

### Restart Nginx
```bash
ssh -i ~/.ssh/trcs-key.pem ubuntu@<IP> "sudo systemctl restart nginx"
```

### Check Disk Space
```bash
ssh -i ~/.ssh/trcs-key.pem ubuntu@<IP> "df -h"
```

## Database Connection from EC2

Once SSH'd into the EC2 instance:
```bash
# Set password (or export from parameter store)
export PGPASSWORD=$DB_PASSWORD

# Connect to RDS
psql -h trcs2-postgres.c12802osyzt6.us-east-1.rds.amazonaws.com \
     -U trcsuser \
     -d trcs2

# Or get connection details from config
cat /home/ubuntu/app/config.json | jq .database
```

## Troubleshooting

### Permission Denied
```bash
# Fix key permissions
chmod 400 ~/.ssh/trcs-key.pem
```

### Connection Timeout
- Check security group allows SSH from your IP
- Verify EC2 is running: `./dev-manager.sh` option 1
- Check your IP: `curl ifconfig.me`

### Host Key Verification Failed
```bash
# Remove old host key
ssh-keygen -R <IP-ADDRESS>

# Or connect with StrictHostKeyChecking disabled
ssh -i ~/.ssh/trcs-key.pem -o StrictHostKeyChecking=no ubuntu@<IP>
```

## Security Notes

- SSH is restricted to your IP only (configured in Terraform)
- Never share the private key file
- Rotate SSH keys periodically
- Use SSH agent for convenience:
  ```bash
  ssh-add ~/.ssh/trcs-key.pem
  ssh ubuntu@<IP>  # No need to specify -i
  ```