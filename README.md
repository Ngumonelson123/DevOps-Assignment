# DevOps Assignment - Scalable Web Application Infrastructure

## Overview
This project demonstrates a complete DevOps pipeline with Infrastructure as Code, CI/CD, containerization, and monitoring for a multi-service web application.

## Architecture
- **Backend**: Python Flask + Node.js applications
- **Database**: PostgreSQL
- **Reverse Proxy**: Nginx with SSL/TLS
- **Infrastructure**: AWS EC2 instances via Terraform
- **Configuration**: Ansible automation
- **Monitoring**: Prometheus + Grafana + cAdvisor
- **CI/CD**: GitHub Actions

## Project Structure
```
DevOps-Assignment/
├── .github/workflows/     # CI/CD pipeline configuration
├── ansible/              # Configuration management
├── app-nodejs/           # Node.js application
├── app-python/           # Python Flask application
├── docker/               # Application containers
├── monitoring/           # Monitoring stack
├── nginx/                # Reverse proxy configuration
├── terraform/            # Infrastructure as Code
├── deploy.sh             # Automated deployment script
└── README.md             # This documentation
```

## Prerequisites

### Required Software
- **AWS CLI** (v2.x) - configured with appropriate credentials
- **Terraform** (v1.5.0+) - for infrastructure provisioning
- **Ansible** (v2.9+) - for configuration management
- **Docker** (v20.x+) and **Docker Compose** (v2.x+)
- **Git** - for version control
- **jq** - for JSON processing in scripts
- **curl** - for testing endpoints

### AWS Requirements
- AWS account with programmatic access
- IAM user with permissions for:
  - EC2 (create/manage instances, security groups, key pairs)
  - S3 (create/manage buckets for Terraform state)
  - VPC (if using custom networking)

### SSH Key Setup
```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/devops-key -N ""

# Add to SSH agent
ssh-add ~/.ssh/devops-key
```

## Assumptions Made

### Infrastructure Assumptions
- **Region**: Deployment targets `us-east-1` (configurable in terraform/variables.tf)
- **Instance Type**: Uses `t2.micro` for cost optimization (free tier eligible)
- **Operating System**: Ubuntu 22.04 LTS for all EC2 instances
- **Network**: Uses default VPC with public subnets
- **Storage**: Uses default EBS storage (8GB gp2)

### Security Assumptions
- SSH access allowed from `0.0.0.0/0` (should be restricted in production)
- Self-signed SSL certificates used (replace with CA-signed in production)
- Default passwords used for demo purposes (use secrets management in production)

### Application Assumptions
- **Python Service**: Runs on port 5000
- **Node.js Service**: Runs on port 3000
- **PostgreSQL**: Uses port 5432 with default credentials
- **Nginx**: Terminates SSL and proxies to backend services

### Monitoring Assumptions
- **Prometheus**: Scrapes metrics every 15 seconds
- **Grafana**: Uses default admin credentials (admin/admin)
- **Resource Limits**: Applied to prevent resource exhaustion

## Setup Instructions

### Method 1: Automated Deployment (Recommended)

1. **Clone and Configure**
   ```bash
   git clone <repository-url>
   cd DevOps-Assignment
   
   # Configure Terraform variables
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Set Environment Variables**
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

3. **Run Automated Deployment**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

### Method 2: Manual Step-by-Step Deployment

#### Step 1: Infrastructure Deployment
```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Note the output IPs
terraform output
```

#### Step 2: Configure Ansible Inventory
```bash
cd ../ansible

# Update inventory.ini with your server IPs
# Replace the IPs with actual values from Terraform output
vim inventory.ini
```

#### Step 3: Server Configuration
```bash
# Run Ansible playbook
ansible-playbook -i inventory.ini playbook.yml

# Verify connectivity
ansible all -i inventory.ini -m ping
```

#### Step 4: Application Deployment
```bash
# Deploy applications on web server
ssh -i ~/.ssh/devops-key ubuntu@<WEB_SERVER_IP>
cd /opt/devops-app
sudo docker-compose up -d
```

#### Step 5: Monitoring Setup
```bash
# Deploy monitoring stack
cd /opt/monitoring
sudo docker-compose up -d
```

## Testing and Validation

### 1. Infrastructure Validation
```bash
# Verify EC2 instances are running
aws ec2 describe-instances --filters "Name=tag:Project,Values=DevOps" --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'

# Test SSH connectivity
ssh -i ~/.ssh/devops-key ubuntu@<SERVER_IP> "echo 'SSH connection successful'"
```

### 2. Application Testing
```bash
# Get server IPs from Terraform
WEB_IP=$(cd terraform && terraform output -raw web_server_ip)
PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip)

# Test Python service
curl -k https://$PROXY_IP/api/python/
# Expected: {"message": "Hello from Python Flask!", "timestamp": "..."}

# Test Node.js service
curl -k https://$PROXY_IP/api/node/
# Expected: {"message": "Hello from Node.js!", "timestamp": "..."}

# Test database connectivity
curl -k https://$PROXY_IP/api/python/db
# Expected: Database connection status

# Check service health
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/devops-app && sudo docker-compose ps"
```

### 3. Monitoring Validation
```bash
# Access Grafana (default: admin/admin)
curl -I http://$WEB_IP:3001
# Expected: HTTP/1.1 200 OK

# Access Prometheus
curl -I http://$WEB_IP:9090
# Expected: HTTP/1.1 200 OK

# Access cAdvisor
curl -I http://$WEB_IP:8085
# Expected: HTTP/1.1 200 OK

# Check Prometheus targets
curl -s http://$WEB_IP:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### 4. SSL/TLS Validation
```bash
# Check SSL certificate
echo | openssl s_client -connect $PROXY_IP:443 -servername $PROXY_IP 2>/dev/null | openssl x509 -noout -dates

# Test HTTPS redirect
curl -I http://$PROXY_IP
# Expected: HTTP/1.1 301 Moved Permanently
```

### 5. Load Testing (Optional)
```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Basic load test
ab -n 100 -c 10 https://$PROXY_IP/api/python/
ab -n 100 -c 10 https://$PROXY_IP/api/node/
```

## CI/CD Pipeline Validation

### GitHub Actions Setup
1. **Configure Repository Secrets**
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
   - `SSH_PRIVATE_KEY`: Contents of your private SSH key

2. **Test Pipeline Triggers**
   ```bash
   # Create a test branch
   git checkout -b test-pipeline
   
   # Make a small change
   echo "# Test change" >> test-file.md
   git add test-file.md
   git commit -m "Test CI/CD pipeline"
   git push origin test-pipeline
   
   # Create pull request (triggers test job)
   # Merge to main (triggers full deployment)
   ```

3. **Monitor Pipeline Execution**
   - Check GitHub Actions tab in your repository
   - Verify all jobs complete successfully
   - Check deployment logs for any errors

### Pipeline Validation Tests
```bash
# After successful pipeline run, verify deployment
curl -k https://$PROXY_IP/api/python/
curl -k https://$PROXY_IP/api/node/

# Check application logs
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "sudo docker-compose -f /opt/devops-app/docker-compose.yml logs --tail=50"
```

## Troubleshooting

### Common Issues

1. **Terraform State Lock**
   ```bash
   # Force unlock if needed
   terraform force-unlock <LOCK_ID>
   ```

2. **Ansible Connection Issues**
   ```bash
   # Test connectivity
   ansible all -i inventory.ini -m ping -vvv
   
   # Check SSH key permissions
   chmod 600 ~/.ssh/devops-key
   ```

3. **Docker Service Issues**
   ```bash
   # Check service status
   sudo docker-compose ps
   sudo docker-compose logs <service-name>
   
   # Restart services
   sudo docker-compose restart
   ```

4. **SSL Certificate Issues**
   ```bash
   # Regenerate certificates
   cd nginx/certs
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt
   ```

### Monitoring and Logs
```bash
# System logs
sudo journalctl -u docker -f

# Application logs
sudo docker-compose logs -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Cleanup

### Destroy Infrastructure
```bash
# Remove all AWS resources
cd terraform
terraform destroy

# Clean up local state
rm -rf .terraform terraform.tfstate*
```

### Clean Docker Resources
```bash
# Remove containers and images
docker-compose down --rmi all --volumes
docker system prune -a
```

## Security Considerations

### Production Recommendations
- Use AWS Secrets Manager for sensitive data
- Implement proper IAM roles and policies
- Restrict SSH access to specific IP ranges
- Use CA-signed SSL certificates
- Enable AWS CloudTrail for audit logging
- Implement network segmentation with private subnets
- Use AWS Systems Manager for secure server access

## Performance Optimization

### Monitoring Metrics
- **Application Response Time**: < 200ms average
- **CPU Utilization**: < 70% average
- **Memory Usage**: < 80% of available
- **Disk I/O**: Monitor for bottlenecks
- **Network Latency**: < 50ms between services

### Scaling Considerations
- Implement Auto Scaling Groups for horizontal scaling
- Use Application Load Balancer for traffic distribution
- Consider RDS for managed database service
- Implement caching with Redis/ElastiCache
- Use CloudFront CDN for static content

## Documentation

This project includes comprehensive documentation:

- **[SETUP.md](SETUP.md)** - Quick setup guide and one-command deployment
- **[TESTING.md](TESTING.md)** - Comprehensive testing and validation procedures
- **[CICD.md](CICD.md)** - CI/CD pipeline documentation and validation
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[test-deployment.sh](test-deployment.sh)** - Automated test script for full validation

## Quick Commands

```bash
# One-command deployment
./deploy.sh

# Fix permissions if needed
./fix-permissions.sh

# Quick validation test
./quick-test.sh

# Comprehensive testing
./test-deployment.sh

# Quick health check
curl -k https://$(cd terraform && terraform output -raw proxy_server_ip)/api/python/
```

## Support and Maintenance

### Regular Tasks
- Update system packages monthly
- Rotate SSL certificates annually
- Review and update security groups quarterly
- Monitor and optimize costs monthly
- Backup database and configurations weekly

### Monitoring Alerts
Configure alerts for:
- High CPU/Memory usage (>80%)
- Application errors (>5% error rate)
- SSL certificate expiration (30 days)
- Disk space usage (>85%)
- Service downtime (>1 minute)