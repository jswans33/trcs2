#!/bin/bash

# TRCS2 Terraform Infrastructure Validation Script
# This script validates the Terraform configuration and deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "ℹ $1"
}

# Check if terraform is installed
check_terraform() {
    print_info "Checking Terraform installation..."
    if command -v terraform &> /dev/null; then
        TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
        print_success "Terraform $TERRAFORM_VERSION is installed"
    else
        print_error "Terraform is not installed"
        exit 1
    fi
}

# Check if AWS CLI is configured
check_aws_cli() {
    print_info "Checking AWS CLI configuration..."
    if command -v aws &> /dev/null; then
        if aws sts get-caller-identity &> /dev/null; then
            AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
            AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
            print_success "AWS CLI is configured for account $AWS_ACCOUNT"
            print_info "Current user: $AWS_USER"
        else
            print_error "AWS CLI is not configured or credentials are invalid"
            exit 1
        fi
    else
        print_error "AWS CLI is not installed"
        exit 1
    fi
}

# Validate terraform files
validate_terraform_files() {
    print_info "Validating Terraform files..."
    
    # Check if required files exist
    REQUIRED_FILES=(
        "main.tf"
        "variables.tf"
        "vpc.tf"
        "security.tf"
        "ec2.tf"
        "rds.tf"
        "s3.tf"
        "parameter_store.tf"
        "cloudwatch.tf"
        "outputs.tf"
        "terraform.tfvars"
        "user_data.sh"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "$file exists"
        else
            print_error "$file is missing"
            exit 1
        fi
    done
}

# Run terraform fmt
format_terraform() {
    print_info "Formatting Terraform files..."
    if terraform fmt -check; then
        print_success "All files are properly formatted"
    else
        print_warning "Some files need formatting. Running terraform fmt..."
        terraform fmt
        print_success "Files have been formatted"
    fi
}

# Initialize terraform
init_terraform() {
    print_info "Initializing Terraform..."
    if terraform init; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
}

# Validate terraform configuration
validate_terraform() {
    print_info "Validating Terraform configuration..."
    if terraform validate; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform configuration is invalid"
        exit 1
    fi
}

# Plan terraform deployment
plan_terraform() {
    print_info "Creating Terraform plan..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan created successfully"
        print_info "Plan saved as 'tfplan'"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
}

# Check for sensitive values in tfvars
check_sensitive_values() {
    print_info "Checking for sensitive values..."
    
    if grep -q "db_password.*changeme\|db_password.*password\|db_password.*123" terraform.tfvars 2>/dev/null; then
        print_warning "Default or weak database password detected in terraform.tfvars"
        print_warning "Please use a strong password for production deployment"
    fi
    
    if grep -q "SecurePassword123!" terraform.tfvars 2>/dev/null; then
        print_warning "Example password found in terraform.tfvars"
        print_warning "Please change the database password before deployment"
    fi
}

# Check AWS resource limits
check_aws_limits() {
    print_info "Checking AWS service limits..."
    
    # Check VPC limit
    VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)')
    VPC_LIMIT=5 # Default limit
    if (( VPC_COUNT >= VPC_LIMIT )); then
        print_warning "VPC count ($VPC_COUNT) is at or near the limit ($VPC_LIMIT)"
    else
        print_success "VPC limit check passed ($VPC_COUNT/$VPC_LIMIT)"
    fi
    
    # Check Elastic IP limit
    EIP_COUNT=$(aws ec2 describe-addresses --query 'length(Addresses)')
    EIP_LIMIT=5 # Default limit
    if (( EIP_COUNT >= EIP_LIMIT )); then
        print_warning "Elastic IP count ($EIP_COUNT) is at or near the limit ($EIP_LIMIT)"
    else
        print_success "Elastic IP limit check passed ($EIP_COUNT/$EIP_LIMIT)"
    fi
}

# Estimate costs
estimate_costs() {
    print_info "Estimated monthly costs:"
    echo "  • EC2 t3.small (24/7): ~$15.50/month"
    echo "  • RDS db.t3.micro (24/7): ~$13.50/month"
    echo "  • EBS GP3 20GB: ~$2.40/month"
    echo "  • RDS Storage 20GB: ~$2.30/month"
    echo "  • NAT Gateway: ~$32.40/month"
    echo "  • Elastic IP: ~$3.60/month"
    echo "  • Data Transfer: ~$1.00/month (estimated)"
    echo "  ────────────────────────────────"
    echo "  Total estimated: ~$70/month"
    print_warning "Costs may vary based on actual usage"
    print_info "NAT Gateway is the largest cost component"
}

# Check SSH key
check_ssh_key() {
    print_info "Checking SSH key configuration..."
    
    KEY_NAME=$(grep 'key_name.*=' terraform.tfvars | cut -d'"' -f2)
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" &> /dev/null; then
        print_success "SSH key '$KEY_NAME' exists in AWS"
    else
        print_error "SSH key '$KEY_NAME' not found in AWS"
        print_info "Create the key with: aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ~/.ssh/$KEY_NAME.pem"
        exit 1
    fi
}

# Main validation flow
main() {
    echo "======================================"
    echo "TRCS2 Infrastructure Validation"
    echo "======================================"
    echo
    
    check_terraform
    echo
    
    check_aws_cli
    echo
    
    validate_terraform_files
    echo
    
    format_terraform
    echo
    
    init_terraform
    echo
    
    validate_terraform
    echo
    
    check_sensitive_values
    echo
    
    check_ssh_key
    echo
    
    check_aws_limits
    echo
    
    plan_terraform
    echo
    
    estimate_costs
    echo
    
    print_success "All validations passed!"
    echo
    print_info "To deploy the infrastructure, run:"
    echo "  terraform apply tfplan"
    echo
    print_info "To destroy the infrastructure, run:"
    echo "  terraform destroy"
    echo
}

# Run main function
main "$@"