You are building a shapefile application with SMART infrastructure choices for a startup budget.

INFRASTRUCTURE STRATEGY:

- Single environment initially (production-ready but not over-engineered)
- Add dev/staging ONLY when revenue justifies the cost
- Use cost-effective AWS services with upgrade paths built-in
- Manual deployments initially, automate when it becomes a bottleneck

COST-EFFECTIVE AWS STACK:

- Single RDS PostgreSQL t3.micro with PostGIS
- Single EC2 t3.small for backend (Docker + nginx)
- S3 for file storage (single bucket with prefixes)
- Route 53 for DNS
- CloudWatch for basic monitoring
- NO: Load balancers, NAT gateways, multiple environments initially
- NO: ECS/Fargate (too expensive for startup)
- NO: Secrets Manager (use Parameter Store free tier)

APPLICATION REQUIREMENTS:

- Single Docker container with both frontend and backend
- nginx serves React build + proxies to NestJS API
- Direct EC2 deployment with systemd services
- Environment variables for configuration
- Let's Encrypt for SSL (free)

UPGRADE PATH PLANNED:

- When you hit $5K+ MRR: Add staging environment
- When you hit $15K+ MRR: Move to ECS/ALB setup
- When you hit $50K+ MRR: Add full multi-environment pipeline

Build it simple, cheap, but with clear upgrade paths when revenue justifies it.

---

Create cost-effective AWS infrastructure for a shapefile application:

SINGLE ENVIRONMENT SETUP:

1. EC2 t3.small instance (Ubuntu 22.04)
2. RDS PostgreSQL t3.micro with PostGIS
3. S3 bucket for shapefile storage
4. Elastic IP for static IP address
5. Route 53 hosted zone for domain
6. Security groups (SSH, HTTP/HTTPS only)

DEPLOYMENT APPROACH:

- Docker Compose on EC2
- nginx for SSL termination and static file serving
- Systemd services for container management
- Let's Encrypt for free SSL certificates
- Basic CloudWatch monitoring

CONFIGURATION:

- AWS Parameter Store (free tier) for configuration
- Environment variables for secrets (rotate manually)
- S3 bucket with lifecycle policies to manage costs
- CloudWatch logs with retention policies

SECURITY:

- Security groups with minimal open ports
- SSH key-based access only
- Regular security updates via unattended-upgrades
- S3 bucket policies for public read on uploads

Total estimated cost: $35-40/month for basic usage.
