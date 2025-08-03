# Testing and Validation Guide

## Infrastructure Tests

### 1. AWS Resources Validation
```bash
# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=DevOps" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress,Type:InstanceType}'

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=DevOps" \
  --query 'SecurityGroups[].{ID:GroupId,Name:GroupName,Rules:IpPermissions}'
```

### 2. Network Connectivity Tests
```bash
# Get server IPs
WEB_IP=$(cd terraform && terraform output -raw web_server_ip)
PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip)

# Test SSH connectivity
ssh -i ~/.ssh/devops-key -o ConnectTimeout=10 ubuntu@$WEB_IP "echo 'Web server SSH OK'"
ssh -i ~/.ssh/devops-key -o ConnectTimeout=10 ubuntu@$PROXY_IP "echo 'Proxy server SSH OK'"

# Test port connectivity
nc -zv $WEB_IP 22    # SSH
nc -zv $WEB_IP 3001  # Grafana
nc -zv $WEB_IP 9090  # Prometheus
nc -zv $PROXY_IP 80  # HTTP
nc -zv $PROXY_IP 443 # HTTPS
```

## Application Tests

### 1. Service Health Checks
```bash
# Check container status
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/devops-app && sudo docker-compose ps"

# Check service logs
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "cd /opt/devops-app && sudo docker-compose logs --tail=20"
```

### 2. API Endpoint Tests
```bash
# Python Flask service
echo "Testing Python service..."
curl -k -w "\\nStatus: %{http_code}\\nTime: %{time_total}s\\n" https://$PROXY_IP/api/python/

# Node.js service
echo "Testing Node.js service..."
curl -k -w "\\nStatus: %{http_code}\\nTime: %{time_total}s\\n" https://$PROXY_IP/api/node/

# Database connectivity test
echo "Testing database connection..."
curl -k -w "\\nStatus: %{http_code}\\n" https://$PROXY_IP/api/python/db
```

### 3. Load Testing
```bash
# Install Apache Bench if not available
sudo apt-get update && sudo apt-get install -y apache2-utils

# Basic load test - Python service
echo "Load testing Python service..."
ab -n 100 -c 5 -k https://$PROXY_IP/api/python/

# Basic load test - Node.js service
echo "Load testing Node.js service..."
ab -n 100 -c 5 -k https://$PROXY_IP/api/node/
```

## Security Tests

### 1. SSL/TLS Validation
```bash
# Check SSL certificate
echo "Checking SSL certificate..."
echo | openssl s_client -connect $PROXY_IP:443 -servername $PROXY_IP 2>/dev/null | openssl x509 -noout -text | grep -E "(Subject|Issuer|Not After)"

# Test SSL strength
nmap --script ssl-enum-ciphers -p 443 $PROXY_IP

# Verify HTTPS redirect
echo "Testing HTTP to HTTPS redirect..."
curl -I http://$PROXY_IP 2>/dev/null | grep -E "(HTTP|Location)"
```

### 2. Security Group Tests
```bash
# Test blocked ports (should fail)
echo "Testing blocked ports (should timeout)..."
timeout 5 nc -zv $WEB_IP 22 2>/dev/null || echo "SSH properly blocked from external access"
timeout 5 nc -zv $WEB_IP 5432 2>/dev/null || echo "PostgreSQL properly blocked"
```

## Monitoring Tests

### 1. Prometheus Validation
```bash
# Check Prometheus health
curl -s http://$WEB_IP:9090/-/healthy

# Check targets status
curl -s http://$WEB_IP:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastScrape: .lastScrape}'

# Query sample metrics
curl -s "http://$WEB_IP:9090/api/v1/query?query=up" | jq '.data.result[] | {instance: .metric.instance, value: .value[1]}'
```

### 2. Grafana Validation
```bash
# Check Grafana health
curl -I http://$WEB_IP:3001/api/health

# Test login (default admin/admin)
curl -c cookies.txt -d "user=admin&password=admin" -X POST http://$WEB_IP:3001/login

# List dashboards
curl -b cookies.txt http://$WEB_IP:3001/api/search | jq '.[].title'
```

### 3. cAdvisor Validation
```bash
# Check cAdvisor metrics
curl -s http://$WEB_IP:8085/metrics | grep -E "container_cpu_usage_seconds_total|container_memory_usage_bytes" | head -5
```

## CI/CD Pipeline Tests

### 1. GitHub Actions Validation
```bash
# Create test branch and trigger pipeline
git checkout -b test-$(date +%s)
echo "# Test change $(date)" >> test-change.md
git add test-change.md
git commit -m "Test CI/CD pipeline"
git push origin $(git branch --show-current)

# Check workflow status (requires GitHub CLI)
gh workflow list
gh run list --limit 5
```

### 2. Deployment Validation
```bash
# After pipeline completion, verify services
echo "Verifying post-deployment services..."
curl -k https://$PROXY_IP/api/python/ | jq .
curl -k https://$PROXY_IP/api/node/ | jq .

# Check deployment logs
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "sudo docker-compose -f /opt/devops-app/docker-compose.yml logs --tail=10"
```

## Performance Tests

### 1. Resource Usage Monitoring
```bash
# Check system resources
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "top -bn1 | head -20"
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "df -h"
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "free -h"

# Check Docker stats
ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP "sudo docker stats --no-stream"
```

### 2. Response Time Tests
```bash
# Measure response times
for i in {1..10}; do
  echo "Request $i:"
  curl -k -w "Time: %{time_total}s\\n" -o /dev/null -s https://$PROXY_IP/api/python/
  sleep 1
done
```

## Automated Test Script

Create a comprehensive test script:

```bash
#!/bin/bash
# Save as test-deployment.sh

set -e

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

print_test() { echo -e "${YELLOW}🧪 $1${NC}"; }
print_pass() { echo -e "${GREEN}✅ $1${NC}"; }
print_fail() { echo -e "${RED}❌ $1${NC}"; }

# Get server IPs
WEB_IP=$(cd terraform && terraform output -raw web_server_ip)
PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip)

echo "Testing deployment with:"
echo "  Web Server: $WEB_IP"
echo "  Proxy Server: $PROXY_IP"
echo ""

# Test 1: Infrastructure
print_test "Testing infrastructure..."
if ssh -i ~/.ssh/devops-key -o ConnectTimeout=10 ubuntu@$WEB_IP "echo 'connected'" >/dev/null 2>&1; then
  print_pass "Web server SSH connectivity"
else
  print_fail "Web server SSH connectivity"
fi

# Test 2: Applications
print_test "Testing applications..."
if curl -k -s https://$PROXY_IP/api/python/ | grep -q "Hello"; then
  print_pass "Python service responding"
else
  print_fail "Python service not responding"
fi

if curl -k -s https://$PROXY_IP/api/node/ | grep -q "Hello"; then
  print_pass "Node.js service responding"
else
  print_fail "Node.js service not responding"
fi

# Test 3: Monitoring
print_test "Testing monitoring..."
if curl -s http://$WEB_IP:9090/-/healthy | grep -q "Prometheus"; then
  print_pass "Prometheus healthy"
else
  print_fail "Prometheus not healthy"
fi

if curl -I http://$WEB_IP:3001 2>/dev/null | grep -q "200 OK"; then
  print_pass "Grafana accessible"
else
  print_fail "Grafana not accessible"
fi

# Test 4: SSL
print_test "Testing SSL..."
if curl -k -I https://$PROXY_IP 2>/dev/null | grep -q "200 OK"; then
  print_pass "HTTPS working"
else
  print_fail "HTTPS not working"
fi

echo ""
echo "Test completed! Check individual results above."
```

## Expected Results

### Successful Deployment Indicators
- All EC2 instances in "running" state
- SSH connectivity to all servers
- HTTP 200 responses from all API endpoints
- Prometheus targets showing "UP" status
- Grafana dashboard accessible
- SSL certificate valid and HTTPS working
- Container health checks passing
- No error logs in application containers

### Performance Benchmarks
- API response time: < 200ms average
- CPU usage: < 70% under normal load
- Memory usage: < 80% of available
- Container startup time: < 30 seconds
- SSL handshake time: < 100ms

### Troubleshooting Common Issues
1. **Connection timeouts**: Check security groups and network ACLs
2. **SSL errors**: Verify certificate generation and nginx configuration
3. **Application errors**: Check container logs and environment variables
4. **Monitoring issues**: Verify Prometheus configuration and targets
5. **CI/CD failures**: Check GitHub secrets and workflow permissions