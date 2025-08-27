#!/bin/bash

# TRCS2 Development Manager Script
# Handles infrastructure status, deployment, costs, and troubleshooting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="trcs2"
AWS_REGION="us-east-1"
TERRAFORM_DIR="./terraform"
SSH_KEY="~/.ssh/trcs-key.pem"

# Function to print colored headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to check command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed${NC}"
        exit 1
    fi
}

# Main menu
show_menu() {
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       TRCS2 Development Manager          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) 📊 Show Infrastructure Status"
    echo "2) 💰 Check Costs (Current & Projected)"
    echo "3) 🚀 Deploy Infrastructure"
    echo "4) 📦 Deploy Application"
    echo "5) 🔍 Validate Everything"
    echo "6) 🔧 Troubleshoot Issues"
    echo "7) 🗑️  Destroy Infrastructure"
    echo "8) 📝 Show Logs"
    echo "9) 🔐 Manage Secrets"
    echo "10) 💾 Backup Database"
    echo "11) 📈 Show Monitoring Dashboard"
    echo "12) 🔌 SSH into EC2 Instance"
    echo "0) Exit"
    echo ""
    read -p "Select option: " choice
}

# 1. Infrastructure Status
show_status() {
    print_header "INFRASTRUCTURE STATUS"
    
    # EC2 Status
    echo -e "\n${YELLOW}EC2 Instances:${NC}"
    aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=TRCS2" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
        --output table 2>/dev/null || echo "No EC2 instances found"
    
    # RDS Status
    echo -e "\n${YELLOW}RDS Database:${NC}"
    aws rds describe-db-instances \
        --query 'DBInstances[?starts_with(DBInstanceIdentifier, `trcs`)].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address,DBInstanceClass]' \
        --output table 2>/dev/null || echo "No RDS instances found"
    
    # S3 Buckets
    echo -e "\n${YELLOW}S3 Buckets:${NC}"
    aws s3 ls | grep trcs || echo "No S3 buckets found"
    
    # VPC
    echo -e "\n${YELLOW}VPC & Networking:${NC}"
    aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" \
        --query 'Vpcs[*].[VpcId,CidrBlock,State]' \
        --output table 2>/dev/null || echo "No VPC found"
    
    # NAT Gateways (check if any exist - they're expensive!)
    echo -e "\n${YELLOW}NAT Gateways (Cost Alert!):${NC}"
    NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'length(NatGateways)' 2>/dev/null || echo "0")
    if [ "$NAT_COUNT" -gt 0 ]; then
        echo -e "${RED}⚠️  WARNING: $NAT_COUNT NAT Gateway(s) found - costing ~\$32.40/month each!${NC}"
        aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'NatGateways[*].[NatGatewayId,State]' --output table
    else
        echo -e "${GREEN}✅ No NAT Gateways (saving \$65/month!)${NC}"
    fi
    
    # Get Terraform Outputs
    if [ -d "$TERRAFORM_DIR" ]; then
        echo -e "\n${YELLOW}Terraform Outputs:${NC}"
        cd $TERRAFORM_DIR
        terraform output 2>/dev/null | head -20 || echo "No outputs available"
        cd - > /dev/null
    fi
}

# 2. Cost Analysis
check_costs() {
    print_header "COST ANALYSIS"
    
    echo -e "\n${YELLOW}Current Monthly Costs:${NC}"
    
    # EC2 Costs
    EC2_COUNT=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:Project,Values=TRCS2" --query 'length(Reservations[*].Instances[*])' --output text)
    EC2_COST=$(echo "$EC2_COUNT * 15.50" | bc)
    echo "EC2 Instances ($EC2_COUNT): \$$EC2_COST"
    
    # RDS Costs
    RDS_COUNT=$(aws rds describe-db-instances --query 'length(DBInstances[?starts_with(DBInstanceIdentifier, `trcs`)])' --output text)
    RDS_COST=$(echo "$RDS_COUNT * 13.50" | bc)
    echo "RDS Instances ($RDS_COUNT): \$$RDS_COST"
    
    # NAT Gateway Costs
    NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'length(NatGateways)' --output text)
    NAT_COST=$(echo "$NAT_COUNT * 32.40" | bc)
    if [ "$NAT_COUNT" -gt 0 ]; then
        echo -e "${RED}NAT Gateways ($NAT_COUNT): \$$NAT_COST ⚠️${NC}"
    else
        echo -e "${GREEN}NAT Gateways (0): \$0 ✅${NC}"
    fi
    
    # S3 Costs (estimate)
    S3_COST=5
    echo "S3 Storage (estimate): \$$S3_COST"
    
    # Total
    TOTAL=$(echo "$EC2_COST + $RDS_COST + $NAT_COST + $S3_COST" | bc)
    echo -e "\n${YELLOW}TOTAL MONTHLY: \$$TOTAL${NC}"
    
    if (( $(echo "$TOTAL > 40" | bc -l) )); then
        echo -e "${RED}⚠️  WARNING: Over budget! Target is \$40/month${NC}"
    else
        echo -e "${GREEN}✅ Within budget (\$40/month target)${NC}"
    fi
    
    # AWS Cost Explorer (last 7 days)
    echo -e "\n${YELLOW}Last 7 Days Actual Costs:${NC}"
    aws ce get-cost-and-usage \
        --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity DAILY \
        --metrics "UnblendedCost" \
        --group-by Type=DIMENSION,Key=SERVICE \
        --query 'ResultsByTime[*].[Groups[*].[Keys[0],Metrics.UnblendedCost.Amount]]' \
        --output table 2>/dev/null || echo "Cost data not available"
}

# 3. Deploy Infrastructure
deploy_infrastructure() {
    print_header "DEPLOYING INFRASTRUCTURE"
    
    cd $TERRAFORM_DIR
    
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init
    
    echo -e "${YELLOW}Planning deployment...${NC}"
    terraform plan -out=tfplan
    
    # Show cost estimate
    echo -e "${YELLOW}Estimated costs:${NC}"
    terraform show -json tfplan | jq -r '
        .resource_changes[] | 
        select(.change.after.estimated_monthly_cost != null) | 
        "\(.address): $\(.change.after.estimated_monthly_cost)/month"
    ' 2>/dev/null || echo "Cost estimation not available"
    
    read -p "Continue with deployment? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
        echo -e "${GREEN}✅ Infrastructure deployed!${NC}"
    else
        echo -e "${YELLOW}Deployment cancelled${NC}"
    fi
    
    cd - > /dev/null
}

# 4. Deploy Application
deploy_application() {
    print_header "DEPLOYING APPLICATION"
    
    # Get EC2 IP
    EC2_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=TRCS2" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null)
    
    if [ "$EC2_IP" == "None" ] || [ -z "$EC2_IP" ]; then
        echo -e "${RED}❌ No running EC2 instance found. Deploy infrastructure first.${NC}"
        return
    fi
    
    echo -e "${YELLOW}Deploying to EC2: $EC2_IP${NC}"
    
    # Check if application exists
    if [ ! -d "./backend" ] && [ ! -d "./frontend" ]; then
        echo -e "${RED}❌ No application code found. Create backend and frontend first.${NC}"
        return
    fi
    
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
    scp -i $SSH_KEY -o StrictHostKeyChecking=no deploy.tar.gz ubuntu@${EC2_IP}:/tmp/
    
    # Deploy on server
    echo -e "${YELLOW}Deploying on server...${NC}"
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@${EC2_IP} << 'ENDSSH'
        # Create app directory
        sudo mkdir -p /opt/trcs2
        cd /opt/trcs2
        
        # Extract deployment
        sudo tar -xzf /tmp/deploy.tar.gz
        sudo rm /tmp/deploy.tar.gz
        
        # Install dependencies if needed
        if [ -f "package.json" ]; then
            sudo npm install --production
        fi
        
        # Restart services
        sudo systemctl restart nginx
        
        echo "Deployment completed!"
ENDSSH
    
    rm -f deploy.tar.gz
    echo -e "${GREEN}✅ Application deployed to http://$EC2_IP${NC}"
}

# 5. Validate Everything
validate_all() {
    print_header "VALIDATION"
    
    cd $TERRAFORM_DIR
    if [ -f "./validate.sh" ]; then
        ./validate.sh
    else
        echo -e "${YELLOW}No validation script found. Running basic checks...${NC}"
        
        # Check EC2
        echo -n "EC2 Instance: "
        EC2_STATE=$(aws ec2 describe-instances \
            --filters "Name=tag:Project,Values=TRCS2" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text 2>/dev/null)
        if [ "$EC2_STATE" == "running" ]; then
            echo -e "${GREEN}✅ Running${NC}"
        else
            echo -e "${RED}❌ Not running ($EC2_STATE)${NC}"
        fi
        
        # Check RDS
        echo -n "RDS Database: "
        RDS_STATE=$(aws rds describe-db-instances \
            --db-instance-identifier ${PROJECT_NAME}-postgres \
            --query 'DBInstances[0].DBInstanceStatus' \
            --output text 2>/dev/null)
        if [ "$RDS_STATE" == "available" ]; then
            echo -e "${GREEN}✅ Available${NC}"
        else
            echo -e "${YELLOW}⏳ $RDS_STATE${NC}"
        fi
        
        # Check S3
        echo -n "S3 Bucket: "
        if aws s3 ls | grep -q $PROJECT_NAME; then
            echo -e "${GREEN}✅ Exists${NC}"
        else
            echo -e "${RED}❌ Not found${NC}"
        fi
    fi
    
    cd - > /dev/null
}

# 6. Troubleshoot
troubleshoot() {
    print_header "TROUBLESHOOTING"
    
    echo -e "${YELLOW}Common Issues & Fixes:${NC}"
    echo ""
    echo "1. Terraform state locked:"
    echo "   terraform force-unlock <LOCK_ID>"
    echo ""
    echo "2. RDS already exists:"
    echo "   terraform import aws_db_instance.main ${PROJECT_NAME}-postgres"
    echo ""
    echo "3. NAT Gateway too expensive:"
    echo "   terraform destroy -target=aws_nat_gateway.main"
    echo ""
    echo "4. Can't SSH to EC2:"
    echo "   - Check security group allows your IP"
    echo "   - Verify key permissions: chmod 400 $SSH_KEY"
    echo ""
    echo "5. Application not running:"
    echo "   ssh ubuntu@<IP> 'sudo docker ps'"
    echo "   ssh ubuntu@<IP> 'sudo systemctl status nginx'"
    
    echo -e "\n${YELLOW}Current Issues:${NC}"
    
    # Check for expensive resources
    NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'length(NatGateways)' --output text)
    if [ "$NAT_COUNT" -gt 0 ]; then
        echo -e "${RED}⚠️  NAT Gateways detected - costing \$32.40/month each!${NC}"
        echo "   Fix: terraform destroy -target=aws_nat_gateway.main"
    fi
    
    # Check Terraform state
    cd $TERRAFORM_DIR
    if terraform plan &>/dev/null; then
        echo -e "${GREEN}✅ Terraform state is clean${NC}"
    else
        echo -e "${RED}❌ Terraform state has issues${NC}"
        echo "   Fix: terraform init -reconfigure"
    fi
    cd - > /dev/null
}

# 7. Destroy Infrastructure
destroy_infrastructure() {
    print_header "DESTROY INFRASTRUCTURE"
    
    echo -e "${RED}⚠️  WARNING: This will destroy all infrastructure!${NC}"
    read -p "Are you sure? Type 'destroy' to confirm: " confirm
    
    if [ "$confirm" == "destroy" ]; then
        cd $TERRAFORM_DIR
        terraform destroy -auto-approve
        cd - > /dev/null
        echo -e "${GREEN}✅ Infrastructure destroyed${NC}"
    else
        echo -e "${YELLOW}Destruction cancelled${NC}"
    fi
}

# 8. Show Logs
show_logs() {
    print_header "LOGS"
    
    echo "1) CloudWatch Logs (Application)"
    echo "2) CloudWatch Logs (System)"
    echo "3) EC2 Instance Logs (SSH)"
    echo "4) RDS Logs"
    echo "5) Terraform Logs"
    read -p "Select log type: " log_choice
    
    case $log_choice in
        1)
            aws logs tail /aws/ec2/${PROJECT_NAME}/application --follow
            ;;
        2)
            aws logs tail /aws/ec2/${PROJECT_NAME}/system --follow
            ;;
        3)
            EC2_IP=$(aws ec2 describe-instances \
                --filters "Name=tag:Project,Values=TRCS2" "Name=instance-state-name,Values=running" \
                --query 'Reservations[0].Instances[0].PublicIpAddress' \
                --output text)
            ssh -i $SSH_KEY ubuntu@${EC2_IP} "sudo journalctl -f"
            ;;
        4)
            aws rds describe-db-log-files --db-instance-identifier ${PROJECT_NAME}-postgres
            ;;
        5)
            cd $TERRAFORM_DIR
            cat terraform.log 2>/dev/null || echo "No terraform logs found"
            cd - > /dev/null
            ;;
    esac
}

# 9. Manage Secrets
manage_secrets() {
    print_header "SECRETS MANAGEMENT"
    
    echo "1) List all secrets"
    echo "2) Get specific secret"
    echo "3) Update secret"
    echo "4) Rotate database password"
    read -p "Select option: " secret_choice
    
    case $secret_choice in
        1)
            aws ssm get-parameters-by-path --path "/${PROJECT_NAME}/" --query 'Parameters[*].[Name,Type]' --output table
            ;;
        2)
            read -p "Enter parameter name (e.g., /${PROJECT_NAME}/database/password): " param_name
            aws ssm get-parameter --name "$param_name" --with-decryption --query 'Parameter.Value' --output text
            ;;
        3)
            read -p "Enter parameter name: " param_name
            read -p "Enter new value: " param_value
            aws ssm put-parameter --name "$param_name" --value "$param_value" --overwrite
            ;;
        4)
            NEW_PASS=$(openssl rand -base64 24)
            aws ssm put-parameter --name "/${PROJECT_NAME}/database/password" --value "$NEW_PASS" --type "SecureString" --overwrite
            echo -e "${GREEN}✅ Password rotated. Remember to update RDS and restart application.${NC}"
            ;;
    esac
}

# 10. Backup Database
backup_database() {
    print_header "DATABASE BACKUP"
    
    # Get RDS endpoint
    RDS_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier ${PROJECT_NAME}-postgres \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text 2>/dev/null)
    
    if [ -z "$RDS_ENDPOINT" ]; then
        echo -e "${RED}❌ No RDS instance found${NC}"
        return
    fi
    
    # Create snapshot
    SNAPSHOT_ID="${PROJECT_NAME}-snapshot-$(date +%Y%m%d-%H%M%S)"
    echo -e "${YELLOW}Creating snapshot: $SNAPSHOT_ID${NC}"
    
    aws rds create-db-snapshot \
        --db-instance-identifier ${PROJECT_NAME}-postgres \
        --db-snapshot-identifier $SNAPSHOT_ID
    
    echo -e "${GREEN}✅ Snapshot initiated: $SNAPSHOT_ID${NC}"
    echo "Check status: aws rds describe-db-snapshots --db-snapshot-identifier $SNAPSHOT_ID"
}

# 11. Monitoring Dashboard
show_monitoring() {
    print_header "MONITORING DASHBOARD"
    
    # CPU Utilization
    echo -e "${YELLOW}EC2 CPU Utilization (last hour):${NC}"
    aws cloudwatch get-metric-statistics \
        --namespace AWS/EC2 \
        --metric-name CPUUtilization \
        --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 300 \
        --statistics Average \
        --query 'Datapoints[*].[Timestamp,Average]' \
        --output table
    
    # RDS Connections
    echo -e "\n${YELLOW}RDS Database Connections (last hour):${NC}"
    aws cloudwatch get-metric-statistics \
        --namespace AWS/RDS \
        --metric-name DatabaseConnections \
        --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 300 \
        --statistics Average \
        --query 'Datapoints[*].[Timestamp,Average]' \
        --output table
    
    # Alarms
    echo -e "\n${YELLOW}CloudWatch Alarms:${NC}"
    aws cloudwatch describe-alarms \
        --alarm-name-prefix ${PROJECT_NAME} \
        --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
        --output table
}

# 12. SSH to EC2
ssh_to_ec2() {
    print_header "SSH CONNECTION"
    
    # Get EC2 public IP
    EC2_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-web-server" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null)
    
    if [ "$EC2_IP" = "None" ] || [ -z "$EC2_IP" ]; then
        echo -e "${RED}❌ No running EC2 instance found${NC}"
        echo ""
        echo "To create EC2 instance:"
        echo "  ./dev-manager.sh → Option 3 (Deploy Infrastructure)"
        return
    fi
    
    echo -e "${GREEN}EC2 Instance IP: $EC2_IP${NC}"
    echo ""
    echo "Connecting to EC2 instance..."
    echo "Command: ssh -i $SSH_KEY ubuntu@$EC2_IP"
    echo ""
    
    # SSH into the instance
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$EC2_IP
}

# Main script
main() {
    # Check prerequisites
    check_command aws
    check_command terraform
    check_command jq
    
    while true; do
        show_menu
        case $choice in
            1) show_status ;;
            2) check_costs ;;
            3) deploy_infrastructure ;;
            4) deploy_application ;;
            5) validate_all ;;
            6) troubleshoot ;;
            7) destroy_infrastructure ;;
            8) show_logs ;;
            9) manage_secrets ;;
            10) backup_database ;;
            11) show_monitoring ;;
            12) ssh_to_ec2 ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main