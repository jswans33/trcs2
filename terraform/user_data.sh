#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    nginx \
    postgresql-client \
    awscli \
    python3 \
    python3-pip \
    nodejs \
    npm \
    htop \
    jq

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/syslog",
                        "log_group_name": "/aws/ec2/${project_name}/system",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/home/ubuntu/app/logs/application.log",
                        "log_group_name": "/aws/ec2/${project_name}/application",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Create application user
useradd -m -s /bin/bash appuser
usermod -aG sudo appuser

# Create application directories
mkdir -p /home/ubuntu/app
mkdir -p /home/ubuntu/app/logs
mkdir -p /home/ubuntu/app/uploads
chown -R ubuntu:ubuntu /home/ubuntu/app

# Install PM2 for process management
npm install -g pm2

# Configure Nginx
cat > /etc/nginx/sites-available/trcs2 << 'EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/trcs2 /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t && systemctl restart nginx
systemctl enable nginx

# Set up environment variables
cat > /home/ubuntu/.bashrc_app << EOF
# Application Environment Variables
export NODE_ENV=production
export AWS_DEFAULT_REGION=${aws_region}
export DB_HOST=${db_host}
export DB_NAME=${db_name}
export DB_USER=${db_username}
export DB_PASSWORD=${db_password}
export S3_BUCKET=${s3_bucket}
export PORT=3000
EOF

# Make it available for ubuntu user
cat >> /home/ubuntu/.bashrc << EOF
source ~/.bashrc_app
EOF

# Create systemd service for the application
cat > /etc/systemd/system/trcs2.service << 'EOF'
[Unit]
Description=TRCS2 Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/app
Environment=NODE_ENV=production
EnvironmentFile=/home/ubuntu/.bashrc_app
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=append:/home/ubuntu/app/logs/application.log
StandardError=append:/home/ubuntu/app/logs/application.log

[Install]
WantedBy=multi-user.target
EOF

# Create a simple health check script
cat > /home/ubuntu/health_check.sh << 'EOF'
#!/bin/bash

# Check if application is responding
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "$(date): Application is healthy"
    exit 0
else
    echo "$(date): Application is not responding, restarting..."
    sudo systemctl restart trcs2
    exit 1
fi
EOF

chmod +x /home/ubuntu/health_check.sh

# Add health check to crontab
echo "*/5 * * * * /home/ubuntu/health_check.sh >> /home/ubuntu/app/logs/health_check.log 2>&1" | crontab -u ubuntu -

# Create startup script for the application
cat > /home/ubuntu/start_app.sh << 'EOF'
#!/bin/bash

cd /home/ubuntu/app

# Install dependencies if package.json exists
if [ -f "package.json" ]; then
    npm install
fi

# Start the application
sudo systemctl enable trcs2
sudo systemctl start trcs2
EOF

chmod +x /home/ubuntu/start_app.sh

# Install Docker (for potential future use)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install PostgreSQL client tools and PostGIS tools
apt-get install -y postgresql-client-common postgresql-client postgis

# Test database connection
echo "Testing database connection..."
export PGPASSWORD=${db_password}
if psql -h ${db_host} -U ${db_username} -d ${db_name} -c "SELECT version();" > /tmp/db_test.log 2>&1; then
    echo "Database connection successful"
else
    echo "Database connection failed. Check logs at /tmp/db_test.log"
fi

# Create application configuration file
cat > /home/ubuntu/app/config.json << EOF
{
  "database": {
    "host": "${db_host}",
    "port": 5432,
    "database": "${db_name}",
    "username": "${db_username}",
    "password": "${db_password}"
  },
  "aws": {
    "region": "${aws_region}",
    "s3Bucket": "${s3_bucket}"
  },
  "app": {
    "port": 3000,
    "environment": "production"
  }
}
EOF

chown ubuntu:ubuntu /home/ubuntu/app/config.json

# Final system setup
systemctl daemon-reload

# Log completion
echo "$(date): User data script completed" >> /var/log/user-data.log

# Reboot to ensure all changes take effect
reboot