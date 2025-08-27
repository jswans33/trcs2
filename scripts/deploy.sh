#!/bin/bash

# TRCS Deployment Script
# Usage: ./deploy.sh [environment]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-production}
PROJECT_NAME="trcs"
AWS_REGION="us-east-1"

echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}TRCS Deployment Script${NC}"
echo -e "${GREEN}Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "${GREEN}==================================${NC}"

# Get EC2 IP from Terraform
cd terraform
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null)
cd ..

if [ -z "$EC2_IP" ]; then
    echo -e "${RED}Error: Could not get EC2 IP. Run 'terraform apply' first.${NC}"
    exit 1
fi

echo -e "${GREEN}Target server: ${EC2_IP}${NC}"

# Check SSH key exists
if [ ! -f ~/.ssh/trcs-key.pem ]; then
    echo -e "${RED}Error: SSH key not found at ~/.ssh/trcs-key.pem${NC}"
    exit 1
fi

# Build and push Docker images (when we have them)
echo -e "${YELLOW}Building application...${NC}"
# docker-compose build

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
tar -czf deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='terraform' \
    --exclude='*.log' \
    --exclude='deploy.tar.gz' \
    .

# Upload to server
echo -e "${YELLOW}Uploading to server...${NC}"
scp -i ~/.ssh/trcs-key.pem deploy.tar.gz ubuntu@${EC2_IP}:/tmp/

# Deploy on server
echo -e "${YELLOW}Deploying on server...${NC}"
ssh -i ~/.ssh/trcs-key.pem ubuntu@${EC2_IP} << 'ENDSSH'
    set -e
    
    # Extract deployment package
    cd /home/ubuntu/trcs
    tar -xzf /tmp/deploy.tar.gz
    rm /tmp/deploy.tar.gz
    
    # Pull latest secrets from Parameter Store
    export DB_PASSWORD=$(aws ssm get-parameter --name "/trcs/prod/db/password" --with-decryption --query 'Parameter.Value' --output text --region us-east-1)
    export JWT_SECRET=$(aws ssm get-parameter --name "/trcs/prod/jwt/secret" --with-decryption --query 'Parameter.Value' --output text --region us-east-1 2>/dev/null || echo "")
    
    # Update environment file
    sudo tee /etc/trcs/env > /dev/null <<EOF
PROJECT_NAME=trcs
DB_HOST=$(aws ssm get-parameter --name "/trcs/db/host" --query 'Parameter.Value' --output text --region us-east-1)
DB_NAME=$(aws ssm get-parameter --name "/trcs/db/name" --query 'Parameter.Value' --output text --region us-east-1)
DB_USERNAME=$(aws ssm get-parameter --name "/trcs/db/username" --query 'Parameter.Value' --output text --region us-east-1)
DB_PASSWORD=$DB_PASSWORD
S3_BUCKET=$(aws ssm get-parameter --name "/trcs/s3/bucket" --query 'Parameter.Value' --output text --region us-east-1)
JWT_SECRET=$JWT_SECRET
AWS_REGION=us-east-1
NODE_ENV=production
PORT=3000
EOF
    
    # Restart services
    if [ -f docker-compose.yml ]; then
        docker-compose down || true
        docker-compose up -d
    fi
    
    # Restart nginx
    sudo nginx -t && sudo systemctl reload nginx
    
    echo "Deployment completed successfully!"
ENDSSH

# Clean up
rm -f deploy.tar.gz

echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Application URL: http://${EC2_IP}${NC}"
echo -e "${GREEN}==================================${NC}"

# Show application status
echo -e "\n${YELLOW}Application Status:${NC}"
ssh -i ~/.ssh/trcs-key.pem ubuntu@${EC2_IP} "docker ps"