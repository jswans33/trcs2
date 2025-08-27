# ========================================
# RDS PARAMETER GROUP - POSTGRESQL 15 WITH POSTGIS SUPPORT
# ========================================
#
# IMPORTANT NOTES:
# 1. PostGIS is NOT installed via parameter group
# 2. PostGIS must be installed via SQL after RDS creation:
#    CREATE EXTENSION IF NOT EXISTS postgis;
#    CREATE EXTENSION IF NOT EXISTS postgis_topology;
# 
# PARAMETER EXPLANATION:
# - pg_stat_statements: Enables query performance tracking
# - NOT "postgis": PostGIS is not a shared library parameter
#
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project_name}-postgres-params"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"  # NOT "postgis" - that would fail
  }

  tags = {
    Name = "${var.project_name}-postgres-params"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-postgres"

  # Engine options
  engine         = "postgres"
  engine_version = "15.7"  # FIXED: Was 15.4 (deprecated), now using latest stable
  instance_class = var.db_instance_class  # t3.micro = $13.50/month

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # Network & Security
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup & Maintenance
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  # Monitoring
  performance_insights_enabled = false
  monitoring_interval         = 0

  # Deletion protection
  deletion_protection = false
  skip_final_snapshot = true

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-postgres"
    Type = "Database"
  }
}

# Store database connection details in Parameter Store
resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/database/host"
  type  = "String"
  value = aws_db_instance.main.address

  tags = {
    Name = "${var.project_name}-db-host"
  }
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project_name}/database/port"
  type  = "String"
  value = tostring(aws_db_instance.main.port)

  tags = {
    Name = "${var.project_name}-db-port"
  }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/database/name"
  type  = "String"
  value = aws_db_instance.main.db_name

  tags = {
    Name = "${var.project_name}-db-name"
  }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.project_name}/database/username"
  type  = "String"
  value = aws_db_instance.main.username

  tags = {
    Name = "${var.project_name}-db-username"
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/database/password"
  type  = "SecureString"
  value = var.db_password

  tags = {
    Name = "${var.project_name}-db-password"
  }
}