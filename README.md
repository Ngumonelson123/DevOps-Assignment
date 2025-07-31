# DevOps Assignment - Scalable Web Application Infrastructure

## Overview
This project demonstrates a complete DevOps pipeline with Infrastructure as Code, CI/CD, containerization, and monitoring for a multi-service web application.

## Architecture
- **Backend**: Python Flask + Node.js applications
- **Database**: PostgreSQL
- **Reverse Proxy**: Nginx with SSL/TLS
- **Infrastructure**: AWS EC2 instances via Terraform
- **Configuration**: Ansible automation
- **Monitoring**: Prometheus + Grafana + ELK Stack
- **CI/CD**: GitHub Actions

## Quick Start

### Prerequisites
- AWS CLI configured
- Terraform installed
- Ansible installed
- Docker and Docker Compose
- SSH key pair generated

### 1. Infrastructure Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Configuration Management
```bash
cd ansible
# Update inventory.ini with your server IPs
ansible-playbook -i inventory.ini playbook.yml
```

### 3. Application Deployment
```bash
cd docker
docker-compose up -d
```

### 4. Monitoring Setup
```bash
cd monitoring
docker-compose up -d
```

## Services Access
- **Applications**: http://your-proxy-server
- **Grafana**: http://your-server:3000
- **Prometheus**: http://your-server:9090
- **Kibana**: http://your-server:5601

## Testing
```bash
# Test Python service
curl http://your-server/python/hello

# Test Node.js service  
curl http://your-server/node/

# Check service health
docker-compose ps
```

## CI/CD Pipeline
- Automated testing on pull requests
- Docker image building
- Deployment to staging/production on main branch merge

## Security Features
- SSL/TLS encryption
- Security groups with restricted access
- Environment variable management
- Container health checks

## Monitoring & Logging
- System metrics via Prometheus
- Application dashboards in Grafana
- Centralized logging with ELK Stack
- Container monitoring with cAdvisor