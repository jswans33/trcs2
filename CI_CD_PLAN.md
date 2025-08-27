# CI/CD Implementation Plan for TRCS2

## Overview
Based on the startup budget constraints ($35-40/month target), this is a phased approach to get CI/CD integrated and the application deployed online.

## Phase 1: Minimal Viable CI/CD (Immediate - $0 additional cost)

### 1. Create the Application Structure
```
/backend (NestJS API)
  - Dockerfile
  - package.json
  - src/
    - main.ts
    - app.module.ts
    - shapefile/
      - shapefile.controller.ts
      - shapefile.service.ts
    - database/
      - entities/
      - migrations/

/frontend (React App)
  - Dockerfile
  - package.json
  - src/
    - App.tsx
    - components/
    - services/

/docker-compose.yml (for local dev)
/.github/workflows/deploy.yml (GitHub Actions)
```

### 2. GitHub Actions for Simple Deploy ($0)
- **Trigger**: Push to main branch
- **Process**:
  1. Build Docker image locally
  2. Create tarball of app
  3. SCP to EC2
  4. SSH to restart services
- **No Docker registry initially** (saves money)

### 3. Deployment Script Enhancement
- Update `dev-manager.sh` option 4 to handle:
  - Git pull on EC2
  - npm install/build
  - PM2 restart
  - Zero-downtime deployment

## Phase 2: Production Application Setup

### 1. Backend (NestJS)
- PostgreSQL with TypeORM + PostGIS
- Shapefile upload to S3
- JWT authentication
- Health check endpoint
- Swagger documentation

### 2. Frontend (React)
- Shapefile upload interface
- Map visualization (Leaflet/Mapbox)
- User authentication
- File management dashboard

### 3. nginx Configuration
- Serve React build from `/var/www/html`
- Proxy `/api/*` to NestJS on port 3000
- Let's Encrypt SSL (Certbot)

## Phase 3: CI/CD Pipeline Files

### `.github/workflows/deploy.yml`
```yaml
name: Deploy to EC2
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Build Frontend
        run: |
          cd frontend
          npm ci
          npm run build
      
      - name: Build Backend
        run: |
          cd backend
          npm ci
          npm run build
      
      - name: Create Deployment Package
        run: |
          tar -czf deploy.tar.gz \
            --exclude='node_modules' \
            --exclude='.git' \
            backend/ frontend/
      
      - name: Deploy to EC2
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          source: "deploy.tar.gz"
          target: "/tmp"
      
      - name: Restart Services
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd /home/ubuntu/app
            tar -xzf /tmp/deploy.tar.gz
            cd backend && npm ci --only=production
            pm2 restart trcs2-backend
            sudo nginx -s reload
```

### `Dockerfile.backend`
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "run", "start:prod"]
```

### `Dockerfile.frontend`
```dockerfile
FROM node:18-alpine as builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

## Phase 4: Monitoring & Rollback

### 1. Health Checks
- CloudWatch alarms on application health
- Auto-restart via systemd if unhealthy
- Endpoint monitoring: `/api/health`

### 2. Simple Rollback Strategy
- Tag Docker images with git SHA
- Keep last 3 versions on EC2
- Quick rollback script in dev-manager.sh:
```bash
# Rollback function
rollback_deployment() {
    echo "Rolling back to previous version..."
    ssh -i ~/.ssh/trcs-key.pem ubuntu@$EC2_IP << 'EOF'
        cd /home/ubuntu/app
        if [ -d "backup.previous" ]; then
            rm -rf current
            mv backup.previous current
            cd current/backend && pm2 restart trcs2-backend
            sudo nginx -s reload
            echo "Rollback completed"
        else
            echo "No backup found"
        fi
    EOF
}
```

## Phase 5: Future Upgrades (When Revenue Justifies)

### At $5K MRR (~125 customers)
- Add staging environment
- Docker registry (ECR) - $10/month
- AWS Secrets Manager - $1/month per secret
- Estimated additional cost: +$20/month

### At $15K MRR (~375 customers)
- Move to ECS/Fargate
- Application Load Balancer
- Blue-green deployments
- CloudFront CDN
- Estimated additional cost: +$150/month

### At $50K MRR (~1250 customers)
- Full GitOps with ArgoCD
- Multi-region deployment
- Dedicated DevOps tooling
- DataDog or New Relic monitoring
- Estimated additional cost: +$500/month

## Immediate Actions Required

1. **Create NestJS Backend**
   ```bash
   npx @nestjs/cli new backend --package-manager npm
   cd backend
   npm install @nestjs/typeorm typeorm pg
   npm install @nestjs/swagger
   npm install multer @types/multer
   npm install @aws-sdk/client-s3
   ```

2. **Create React Frontend**
   ```bash
   npx create-react-app frontend --template typescript
   cd frontend
   npm install axios react-router-dom
   npm install leaflet react-leaflet
   npm install @types/leaflet
   ```

3. **Set up GitHub Secrets**
   - EC2_HOST: 18.210.234.220
   - EC2_SSH_KEY: Contents of ~/.ssh/trcs-key.pem

4. **Configure nginx on EC2**
   ```nginx
   server {
       listen 80;
       server_name _;
       
       root /var/www/html;
       index index.html;
       
       location / {
           try_files $uri $uri/ /index.html;
       }
       
       location /api {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

5. **Update dev-manager.sh**
   - Add option 13: Deploy from GitHub
   - Add option 14: Rollback deployment
   - Add option 15: View deployment logs

## Cost Impact Summary

### Current Infrastructure: $34/month
- EC2 t3.small: $15.50
- RDS t3.micro: $13.50
- Storage: ~$5

### CI/CD Additions: $0
- GitHub Actions: Free (2000 min/month private)
- Let's Encrypt SSL: Free
- PM2: Free
- nginx: Free

### Total: Still $34/month ✅

## Security Considerations

1. **Secrets Management**
   - Use GitHub Secrets for CI/CD
   - AWS Parameter Store for runtime config
   - Never commit .env files

2. **Network Security**
   - Keep RDS in private subnet
   - Restrict SSH to your IP only
   - Use security groups properly

3. **Application Security**
   - Implement JWT authentication
   - Rate limiting on API
   - Input validation for shapefiles
   - CORS configuration

## Success Metrics

- **Deploy Time**: < 5 minutes
- **Rollback Time**: < 2 minutes
- **Uptime Target**: 99.5% (allows ~3.5 hours/month downtime)
- **Response Time**: < 500ms for API calls
- **Cost**: Stay under $40/month

## Next Steps

1. Review this plan
2. Create the NestJS backend with basic shapefile handling
3. Create React frontend with upload interface
4. Set up GitHub Actions workflow
5. Configure SSL with Let's Encrypt
6. Test end-to-end deployment
7. Document the deployment process

---

This plan provides a pragmatic, budget-conscious approach to getting your shapefile application online with basic CI/CD, following the "simple, cheap, but with clear upgrade paths" philosophy from your requirements.