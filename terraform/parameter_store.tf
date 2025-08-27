# Application Configuration Parameters

# Application Environment
resource "aws_ssm_parameter" "app_environment" {
  name  = "/${var.project_name}/app/environment"
  type  = "String"
  value = var.environment

  tags = {
    Name = "${var.project_name}-app-environment"
  }
}

# Application Port
resource "aws_ssm_parameter" "app_port" {
  name  = "/${var.project_name}/app/port"
  type  = "String"
  value = "3000"

  tags = {
    Name = "${var.project_name}-app-port"
  }
}

# AWS Region
resource "aws_ssm_parameter" "aws_region" {
  name  = "/${var.project_name}/aws/region"
  type  = "String"
  value = var.aws_region

  tags = {
    Name = "${var.project_name}-aws-region"
  }
}

# Domain Name (if provided)
resource "aws_ssm_parameter" "domain_name" {
  count = var.domain_name != "" ? 1 : 0
  name  = "/${var.project_name}/app/domain"
  type  = "String"
  value = var.domain_name

  tags = {
    Name = "${var.project_name}-domain-name"
  }
}

# JWT Secret (placeholder - should be updated with actual secret)
resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${var.project_name}/app/jwt_secret"
  type  = "SecureString"
  value = "changeme-${random_id.bucket_suffix.hex}" # Temporary value

  tags = {
    Name = "${var.project_name}-jwt-secret"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# API Keys (placeholders)
resource "aws_ssm_parameter" "api_key_encryption" {
  name  = "/${var.project_name}/app/api_key_encryption"
  type  = "SecureString"
  value = "changeme-${random_id.bucket_suffix.hex}" # Temporary value

  tags = {
    Name = "${var.project_name}-api-key-encryption"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# Session Secret
resource "aws_ssm_parameter" "session_secret" {
  name  = "/${var.project_name}/app/session_secret"
  type  = "SecureString"
  value = "changeme-${random_id.bucket_suffix.hex}" # Temporary value

  tags = {
    Name = "${var.project_name}-session-secret"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# Maximum Upload Size
resource "aws_ssm_parameter" "max_upload_size" {
  name  = "/${var.project_name}/app/max_upload_size"
  type  = "String"
  value = "100MB"

  tags = {
    Name = "${var.project_name}-max-upload-size"
  }
}

# Logging Level
resource "aws_ssm_parameter" "log_level" {
  name  = "/${var.project_name}/app/log_level"
  type  = "String"
  value = var.environment == "production" ? "info" : "debug"

  tags = {
    Name = "${var.project_name}-log-level"
  }
}

# CORS Origins
resource "aws_ssm_parameter" "cors_origins" {
  name  = "/${var.project_name}/app/cors_origins"
  type  = "StringList"
  value = var.domain_name != "" ? "https://${var.domain_name},http://localhost:3000" : "http://localhost:3000"

  tags = {
    Name = "${var.project_name}-cors-origins"
  }
}