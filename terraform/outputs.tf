# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

# EC2 Outputs
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_eip.web.public_ip
}

output "instance_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.web.private_ip
}

output "instance_public_dns" {
  description = "EC2 instance public DNS"
  value       = aws_eip.web.public_dns
}

# RDS Outputs
output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "RDS instance address"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

# S3 Outputs
output "s3_bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.main.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.main.arn
}

output "s3_bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

# Security Group Outputs
output "web_security_group_id" {
  description = "Web security group ID"
  value       = aws_security_group.web.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

# Connection Information
output "application_url" {
  description = "Application URL"
  value       = "http://${aws_eip.web.public_ip}:3000"
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_eip.web.public_ip}"
}

output "database_connection_string" {
  description = "Database connection string (without password)"
  value       = try("postgresql://${aws_db_instance.main.username}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}", "Database not yet created")
  sensitive   = false
}

# Cost Estimation Information
output "estimated_monthly_costs" {
  description = "Estimated monthly costs breakdown"
  value = {
    ec2_instance     = "~$15.50/month (t3.small)"
    rds_instance     = "~$13.50/month (db.t3.micro)"
    ebs_storage      = "~$2.40/month (20GB GP3)"
    rds_storage      = "~$2.30/month (20GB GP3)"
    nat_gateway      = "~$32.40/month (1 NAT Gateway)"
    data_transfer    = "~$1.00/month (estimated)"
    total_estimated  = "~$67/month"
    note            = "Costs may vary based on actual usage. NAT Gateway is the largest cost component."
  }
}