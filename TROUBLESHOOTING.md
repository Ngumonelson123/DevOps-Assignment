# Troubleshooting Guide

## Common Issues and Solutions

### Infrastructure Issues

#### 1. Terraform Deployment Failures

**Issue**: `Error: Error locking state`
```bash
# Solution: Force unlock the state
cd terraform
terraform force-unlock <LOCK_ID>

# Or wait for automatic timeout (usually 20 minutes)
```

**Issue**: `Error: InvalidKeyPair.NotFound`
```bash
# Solution: Ensure SSH key exists and is properly configured
ssh-keygen -t rsa -b 4096 -f ~/.ssh/devops-key -N ""
# Update terraform.tfvars with correct key path
```

**Issue**: `Error: UnauthorizedOperation`
```bash
# Solution: Check AWS credentials and permissions
aws sts get-caller-identity
aws iam get-user
# Ensure IAM user has EC2, S3, and VPC permissions
```

#### 2. AWS Connectivity Issues

**Issue**: Cannot connect to EC2 instances
```bash
# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=DevOps"

# Verify instance status
aws ec2 describe-instances --filters "Name=tag:Project,Values=DevOps" --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'

# Test connectivity
nc -zv <SERVER_IP> 22
```

**Issue**: SSH connection refused
```bash
# Wait for instance to fully boot (2-3 minutes)
# Check SSH key permissions
chmod 600 ~/.ssh/devops-key

# Test with verbose output
ssh -i ~/.ssh/devops-key -v ubuntu@<SERVER_IP>
```

### Application Issues

#### 1. Container Startup Problems

**Issue**: Containers not starting
```bash
# Check container status
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/devops-app && sudo docker-compose ps"

# Check logs
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/devops-app && sudo docker-compose logs"

# Restart services
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/devops-app && sudo docker-compose restart"
```

**Issue**: Database connection errors
```bash
# Check PostgreSQL container
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "sudo docker-compose logs postgres"

# Verify environment variables
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/devops-app && cat .env"

# Test database connectivity
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "sudo docker-compose exec postgres psql -U devops -d devopsdb -c '\\l'"
```

#### 2. Application Response Issues

**Issue**: 502 Bad Gateway errors
```bash
# Check nginx configuration
ssh -i ~/.ssh/devops-key ubuntu@<PROXY_IP> "sudo nginx -t"

# Check nginx logs
ssh -i ~/.ssh/devops-key ubuntu@<PROXY_IP> "sudo tail -f /var/log/nginx/error.log"

# Verify upstream services
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "curl localhost:5000"
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "curl localhost:3000"
```

**Issue**: SSL certificate errors
```bash
# Regenerate self-signed certificates
ssh -i ~/.ssh/devops-key ubuntu@<PROXY_IP> "cd /etc/nginx/certs && sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj '/CN=localhost'"

# Restart nginx
ssh -i ~/.ssh/devops-key ubuntu@<PROXY_IP> "sudo systemctl restart nginx"
```

### Monitoring Issues

#### 1. Prometheus Not Collecting Metrics

**Issue**: Targets showing as down
```bash
# Check Prometheus configuration
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/monitoring && cat prometheus.yml"

# Check Prometheus logs
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/monitoring && sudo docker-compose logs prometheus"

# Verify target connectivity
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "curl localhost:9100/metrics"
```

**Issue**: Grafana not accessible
```bash
# Check Grafana container status
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/monitoring && sudo docker-compose ps grafana"

# Check Grafana logs
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/monitoring && sudo docker-compose logs grafana"

# Reset Grafana admin password
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/monitoring && sudo docker-compose exec grafana grafana-cli admin reset-admin-password admin"
```

### CI/CD Pipeline Issues

#### 1. GitHub Actions Failures

**Issue**: AWS credentials not working
```bash
# Verify secrets are set in GitHub repository
# Go to Settings → Secrets and variables → Actions
# Ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set

# Test credentials locally
aws sts get-caller-identity
```

**Issue**: SSH key authentication failures
```bash
# Verify SSH_PRIVATE_KEY secret contains the full private key
cat ~/.ssh/devops-key
# Copy entire content including -----BEGIN OPENSSH PRIVATE KEY----- and -----END OPENSSH PRIVATE KEY-----
```

**Issue**: Terraform state conflicts
```bash
# Check S3 bucket for state file
aws s3 ls s3://devops-terraform-state-1754244313/

# If needed, remove state lock
cd terraform
terraform force-unlock <LOCK_ID>
```

#### 2. Deployment Script Failures

**Issue**: Ansible playbook fails
```bash
# Check inventory file
cat ansible/inventory.ini

# Test Ansible connectivity
cd ansible
ansible all -i inventory.ini -m ping

# Run playbook with verbose output
ansible-playbook -i inventory.ini playbook.yml -vvv
```

**Issue**: Docker build failures
```bash
# Check Docker daemon status
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "sudo systemctl status docker"

# Check disk space
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "df -h"

# Clean up Docker resources
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "sudo docker system prune -a"
```

### Performance Issues

#### 1. High Resource Usage

**Issue**: High CPU usage
```bash
# Check system resources
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "top -bn1"

# Check Docker container resources
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "sudo docker stats --no-stream"

# Restart resource-intensive containers
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/devops-app && sudo docker-compose restart"
```

**Issue**: Memory issues
```bash
# Check memory usage
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "free -h"

# Check for memory leaks in applications
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/devops-app && sudo docker-compose logs | grep -i 'memory\\|oom'"

# Restart services to free memory
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/devops-app && sudo docker-compose restart"
```

#### 2. Slow Response Times

**Issue**: Application responding slowly
```bash
# Test response times
time curl -k https://<PROXY_IP>/api/python/

# Check database performance
ssh -i ~/.ssh/devops-key ubuntu@<WEB_IP> "cd /opt/devops-app && sudo docker-compose exec postgres psql -U devops -d devopsdb -c 'SELECT * FROM pg_stat_activity;'"

# Check network latency
ping <PROXY_IP>
```

### Security Issues

#### 1. SSL/TLS Problems

**Issue**: Certificate warnings
```bash
# Check certificate validity
echo | openssl s_client -connect <PROXY_IP>:443 -servername <PROXY_IP> 2>/dev/null | openssl x509 -noout -dates

# Regenerate certificate with proper CN
ssh -i ~/.ssh/devops-key ubuntu@<PROXY_IP> "sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/server.key -out /etc/nginx/certs/server.crt -subj '/CN=<PROXY_IP>'"
```

#### 2. Access Control Issues

**Issue**: Services accessible from wrong ports
```bash
# Check security group rules
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=DevOps" --query 'SecurityGroups[].IpPermissions'

# Update security groups if needed
aws ec2 authorize-security-group-ingress --group-id <SG_ID> --protocol tcp --port 443 --cidr 0.0.0.0/0
```

## Diagnostic Commands

### System Health Check
```bash
#!/bin/bash
# Save as health-check.sh

WEB_IP=$(cd terraform && terraform output -raw web_server_ip)
PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip)

echo "=== System Health Check ==="
echo "Web Server: $WEB_IP"
echo "Proxy Server: $PROXY_IP"
echo ""

echo "1. Server Connectivity:"
ssh -i ~/.ssh/devops-key -o ConnectTimeout=5 ubuntu@$WEB_IP "echo 'Web server: OK'" || echo "Web server: FAILED"
ssh -i ~/.ssh/devops-key -o ConnectTimeout=5 ubuntu@$PROXY_IP "echo 'Proxy server: OK'" || echo "Proxy server: FAILED"

echo ""
echo "2. Application Status:"
curl -k -s https://$PROXY_IP/api/python/ | grep -q "Hello" && echo "Python service: OK" || echo "Python service: FAILED"
curl -k -s https://$PROXY_IP/api/node/ | grep -q "Hello" && echo "Node.js service: OK" || echo "Node.js service: FAILED"

echo ""
echo "3. Monitoring Status:"
curl -s http://$WEB_IP:9090/-/healthy | grep -q "Prometheus" && echo "Prometheus: OK" || echo "Prometheus: FAILED"
curl -s -I http://$WEB_IP:3001 | grep -q "200 OK" && echo "Grafana: OK" || echo "Grafana: FAILED"

echo ""
echo "4. Container Status:"
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/devops-app && sudo docker-compose ps --services --filter status=running | wc -l" | xargs echo "Running containers:"
```

### Log Collection Script
```bash
#!/bin/bash
# Save as collect-logs.sh

WEB_IP=$(cd terraform && terraform output -raw web_server_ip)
PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="logs_$TIMESTAMP"

mkdir -p $LOG_DIR

echo "Collecting logs from deployment..."

# System logs
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "sudo journalctl -u docker --since '1 hour ago'" > $LOG_DIR/web_docker.log
ssh -i ~/.ssh/devops-key ubuntu@$PROXY_IP "sudo journalctl -u nginx --since '1 hour ago'" > $LOG_DIR/proxy_nginx.log

# Application logs
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/devops-app && sudo docker-compose logs --tail=100" > $LOG_DIR/application.log
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/monitoring && sudo docker-compose logs --tail=100" > $LOG_DIR/monitoring.log

# Configuration files
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/devops-app && cat docker-compose.yml" > $LOG_DIR/docker-compose.yml
ssh -i ~/.ssh/devops-key ubuntu@$PROXY_IP "sudo cat /etc/nginx/sites-available/default" > $LOG_DIR/nginx.conf

echo "Logs collected in $LOG_DIR/"
```

## Emergency Procedures

### Complete Service Restart
```bash
#!/bin/bash
# Emergency restart of all services

WEB_IP=$(cd terraform && terraform output -raw web_server_ip)
PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip)

echo "Performing emergency restart..."

# Restart application services
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/devops-app && sudo docker-compose restart"

# Restart monitoring services
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/monitoring && sudo docker-compose restart"

# Restart nginx
ssh -i ~/.ssh/devops-key ubuntu@$PROXY_IP "sudo systemctl restart nginx"

echo "Services restarted. Waiting 30 seconds for startup..."
sleep 30

# Test services
curl -k https://$PROXY_IP/api/python/ && echo "Python service: OK"
curl -k https://$PROXY_IP/api/node/ && echo "Node.js service: OK"
curl -s http://$WEB_IP:9090/-/healthy && echo "Prometheus: OK"
```

### Infrastructure Recovery
```bash
#!/bin/bash
# Recover infrastructure from backup

echo "Starting infrastructure recovery..."

# Restore from Terraform state backup
cd terraform
cp terraform.tfstate.backup terraform.tfstate

# Re-apply infrastructure
terraform plan
terraform apply -auto-approve

# Re-run configuration
cd ../ansible
ansible-playbook -i inventory.ini playbook.yml

echo "Infrastructure recovery completed"
```

## Getting Help

### Log Analysis
- Check application logs: `sudo docker-compose logs <service-name>`
- Check system logs: `sudo journalctl -u <service-name>`
- Check nginx logs: `sudo tail -f /var/log/nginx/error.log`

### Resource Monitoring
- System resources: `top`, `htop`, `free -h`, `df -h`
- Docker resources: `sudo docker stats`
- Network: `netstat -tulpn`, `ss -tulpn`

### Configuration Validation
- Nginx: `sudo nginx -t`
- Docker Compose: `sudo docker-compose config`
- Terraform: `terraform validate`

### Contact Information
For additional support:
1. Check GitHub Issues in the repository
2. Review AWS CloudTrail logs for API calls
3. Check AWS CloudWatch for system metrics
4. Consult AWS documentation for service-specific issues