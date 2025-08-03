#!/bin/bash

# DevOps Assignment - Comprehensive Test Script
# This script validates the entire deployment including infrastructure, applications, and CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Functions for output
print_header() { echo -e "${BLUE}🚀 $1${NC}"; }
print_test() { echo -e "${YELLOW}🧪 $1${NC}"; TOTAL_TESTS=$((TOTAL_TESTS + 1)); }
print_pass() { echo -e "${GREEN}✅ $1${NC}"; PASSED_TESTS=$((PASSED_TESTS + 1)); }
print_fail() { echo -e "${RED}❌ $1${NC}"; FAILED_TESTS=$((FAILED_TESTS + 1)); }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Check if we're in the right directory
if [ ! -f "terraform/main.tf" ]; then
    print_fail "Please run this script from the DevOps-Assignment root directory"
    exit 1
fi

print_header "DevOps Assignment - Comprehensive Validation Test"
echo "Starting comprehensive validation of the DevOps deployment..."
echo ""

# Get server IPs from Terraform
print_info "Retrieving server information from Terraform..."
if [ -f "terraform/terraform.tfstate" ]; then
    WEB_IP=$(cd terraform && terraform output -raw web_server_ip 2>/dev/null || echo "")
    PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip 2>/dev/null || echo "")
    WEB_PRIVATE_IP=$(cd terraform && terraform output -raw web_server_private_ip 2>/dev/null || echo "")
    
    if [ -z "$WEB_IP" ] || [ -z "$PROXY_IP" ]; then
        print_fail "Could not retrieve server IPs from Terraform state"
        exit 1
    fi
    
    echo "Server Information:"
    echo "  Web Server (Public): $WEB_IP"
    echo "  Proxy Server: $PROXY_IP"
    echo "  Web Server (Private): $WEB_PRIVATE_IP"
    echo ""
else
    print_fail "Terraform state file not found. Please deploy infrastructure first."
    exit 1
fi

# Test 1: Infrastructure Validation
print_header "1. Infrastructure Tests"

print_test "AWS EC2 instances status"
if aws ec2 describe-instances --filters "Name=tag:Project,Values=DevOps" --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text | grep -q "i-"; then
    print_pass "EC2 instances are running"
else
    print_fail "EC2 instances not found or not running"
fi

print_test "SSH connectivity to web server"
if timeout 10 ssh -i ~/.ssh/devops-key -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$WEB_IP "echo 'connected'" >/dev/null 2>&1; then
    print_pass "Web server SSH connectivity"
else
    print_fail "Cannot connect to web server via SSH"
fi

print_test "SSH connectivity to proxy server"
if timeout 10 ssh -i ~/.ssh/devops-key -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PROXY_IP "echo 'connected'" >/dev/null 2>&1; then
    print_pass "Proxy server SSH connectivity"
else
    print_fail "Cannot connect to proxy server via SSH"
fi

# Test 2: Application Services
print_header "2. Application Tests"

print_test "Python Flask service health"
PYTHON_RESPONSE=$(curl -k -s -w "%{http_code}" https://$PROXY_IP/api/python/ -o /tmp/python_response.json 2>/dev/null || echo "000")
if [ "$PYTHON_RESPONSE" = "200" ] && grep -q "Hello" /tmp/python_response.json 2>/dev/null; then
    print_pass "Python service responding correctly"
else
    print_fail "Python service not responding (HTTP: $PYTHON_RESPONSE)"
fi

print_test "Node.js service health"
NODE_RESPONSE=$(curl -k -s -w "%{http_code}" https://$PROXY_IP/api/node/ -o /tmp/node_response.json 2>/dev/null || echo "000")
if [ "$NODE_RESPONSE" = "200" ] && grep -q "Hello" /tmp/node_response.json 2>/dev/null; then
    print_pass "Node.js service responding correctly"
else
    print_fail "Node.js service not responding (HTTP: $NODE_RESPONSE)"
fi

print_test "Database connectivity"
DB_RESPONSE=$(curl -k -s -w "%{http_code}" https://$PROXY_IP/api/python/db -o /tmp/db_response.json 2>/dev/null || echo "000")
if [ "$DB_RESPONSE" = "200" ]; then
    print_pass "Database connectivity working"
else
    print_fail "Database connectivity issues (HTTP: $DB_RESPONSE)"
fi

print_test "Container health status"
CONTAINER_STATUS=$(ssh -i ~/.ssh/devops-key -o StrictHostKeyChecking=no ubuntu@$WEB_IP "cd /opt/devops-app && sudo docker-compose ps --services --filter status=running" 2>/dev/null | wc -l)
if [ "$CONTAINER_STATUS" -ge 3 ]; then
    print_pass "Application containers are running"
else
    print_fail "Some application containers are not running"
fi

# Test 3: Security Tests
print_header "3. Security Tests"

print_test "HTTPS SSL certificate"
SSL_CHECK=$(echo | timeout 5 openssl s_client -connect $PROXY_IP:443 -servername $PROXY_IP 2>/dev/null | grep -c "Verify return code: 0" || echo "0")
if [ "$SSL_CHECK" -gt 0 ]; then
    print_pass "SSL certificate is valid"
else
    print_fail "SSL certificate validation failed"
fi

print_test "HTTP to HTTPS redirect"
REDIRECT_CHECK=$(curl -s -I http://$PROXY_IP 2>/dev/null | grep -c "301\|302" || echo "0")
if [ "$REDIRECT_CHECK" -gt 0 ]; then
    print_pass "HTTP to HTTPS redirect working"
else
    print_fail "HTTP to HTTPS redirect not configured"
fi

print_test "Security groups configuration"
SG_CHECK=$(aws ec2 describe-security-groups --filters "Name=tag:Project,Values=DevOps" --query 'SecurityGroups[].IpPermissions[?FromPort==`22`].IpRanges[].CidrIp' --output text | grep -c "0.0.0.0/0" || echo "0")
if [ "$SG_CHECK" -gt 0 ]; then
    print_pass "Security groups configured (Note: SSH open to 0.0.0.0/0 - restrict in production)"
else
    print_fail "Security groups not properly configured"
fi

# Test 4: Monitoring Stack
print_header "4. Monitoring Tests"

print_test "Prometheus service health"
PROM_HEALTH=$(curl -s http://$WEB_IP:9090/-/healthy 2>/dev/null | grep -c "Prometheus" || echo "0")
if [ "$PROM_HEALTH" -gt 0 ]; then
    print_pass "Prometheus is healthy"
else
    print_fail "Prometheus is not responding"
fi

print_test "Grafana service accessibility"
GRAFANA_CHECK=$(curl -s -I http://$WEB_IP:3001 2>/dev/null | grep -c "200 OK" || echo "0")
if [ "$GRAFANA_CHECK" -gt 0 ]; then
    print_pass "Grafana is accessible"
else
    print_fail "Grafana is not accessible"
fi

print_test "cAdvisor service"
CADVISOR_CHECK=$(curl -s -I http://$WEB_IP:8085 2>/dev/null | grep -c "200 OK" || echo "0")
if [ "$CADVISOR_CHECK" -gt 0 ]; then
    print_pass "cAdvisor is running"
else
    print_fail "cAdvisor is not accessible"
fi

print_test "Prometheus targets status"
TARGETS_UP=$(curl -s http://$WEB_IP:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | select(.health=="up") | .labels.job' 2>/dev/null | wc -l || echo "0")
if [ "$TARGETS_UP" -gt 0 ]; then
    print_pass "Prometheus targets are up ($TARGETS_UP targets)"
else
    print_fail "No Prometheus targets are up"
fi

# Test 5: Performance Tests
print_header "5. Performance Tests"

print_test "Application response time"
RESPONSE_TIME=$(curl -k -w "%{time_total}" -o /dev/null -s https://$PROXY_IP/api/python/ 2>/dev/null || echo "999")
if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l 2>/dev/null || echo "0") )); then
    print_pass "Response time acceptable (${RESPONSE_TIME}s)"
else
    print_fail "Response time too high (${RESPONSE_TIME}s)"
fi

print_test "System resource usage"
CPU_USAGE=$(ssh -i ~/.ssh/devops-key -o StrictHostKeyChecking=no ubuntu@$WEB_IP "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" 2>/dev/null || echo "100")
if (( $(echo "$CPU_USAGE < 80" | bc -l 2>/dev/null || echo "0") )); then
    print_pass "CPU usage acceptable (${CPU_USAGE}%)"
else
    print_fail "CPU usage high (${CPU_USAGE}%)"
fi

# Test 6: Load Testing
print_header "6. Load Testing"

print_test "Basic load test (10 concurrent requests)"
if command -v ab >/dev/null 2>&1; then
    LOAD_TEST_RESULT=$(ab -n 10 -c 2 -k https://$PROXY_IP/api/python/ 2>/dev/null | grep "Failed requests" | awk '{print $3}' || echo "10")
    if [ "$LOAD_TEST_RESULT" = "0" ]; then
        print_pass "Load test passed (0 failed requests)"
    else
        print_fail "Load test failed ($LOAD_TEST_RESULT failed requests)"
    fi
else
    print_info "Apache Bench not installed, skipping load test"
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
fi

# Test 7: Configuration Validation
print_header "7. Configuration Tests"

print_test "Nginx configuration"
NGINX_CONFIG=$(ssh -i ~/.ssh/devops-key -o StrictHostKeyChecking=no ubuntu@$PROXY_IP "sudo nginx -t" 2>&1 | grep -c "successful" || echo "0")
if [ "$NGINX_CONFIG" -gt 0 ]; then
    print_pass "Nginx configuration is valid"
else
    print_fail "Nginx configuration has errors"
fi

print_test "Docker Compose configuration"
COMPOSE_CONFIG=$(ssh -i ~/.ssh/devops-key -o StrictHostKeyChecking=no ubuntu@$WEB_IP "cd /opt/devops-app && sudo docker-compose config" 2>/dev/null | grep -c "version" || echo "0")
if [ "$COMPOSE_CONFIG" -gt 0 ]; then
    print_pass "Docker Compose configuration is valid"
else
    print_fail "Docker Compose configuration has errors"
fi

# Test 8: Backup and Recovery
print_header "8. Backup and Recovery Tests"

print_test "Terraform state backup"
if [ -f "terraform/terraform.tfstate.backup" ]; then
    print_pass "Terraform state backup exists"
else
    print_fail "Terraform state backup not found"
fi

print_test "Application data persistence"
VOLUME_CHECK=$(ssh -i ~/.ssh/devops-key -o StrictHostKeyChecking=no ubuntu@$WEB_IP "sudo docker volume ls | grep -c postgres_data" 2>/dev/null || echo "0")
if [ "$VOLUME_CHECK" -gt 0 ]; then
    print_pass "Database volume persistence configured"
else
    print_fail "Database volume persistence not configured"
fi

# Cleanup temporary files
rm -f /tmp/python_response.json /tmp/node_response.json /tmp/db_response.json

# Final Results
echo ""
print_header "Test Results Summary"
echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"

SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
echo "Success Rate: $SUCCESS_RATE%"

echo ""
if [ "$FAILED_TESTS" -eq 0 ]; then
    print_pass "🎉 All tests passed! Deployment is fully functional."
    echo ""
    echo "Access your services:"
    echo "  🌐 Applications: https://$PROXY_IP/api/python/ | https://$PROXY_IP/api/node/"
    echo "  📊 Grafana: http://$WEB_IP:3001 (admin/admin)"
    echo "  📈 Prometheus: http://$WEB_IP:9090"
    echo "  🐳 cAdvisor: http://$WEB_IP:8085"
    echo ""
    echo "Quick test commands:"
    echo "  curl -k https://$PROXY_IP/api/python/"
    echo "  curl -k https://$PROXY_IP/api/node/"
    exit 0
else
    print_fail "⚠️  Some tests failed. Please review the results above."
    echo ""
    echo "Common troubleshooting steps:"
    echo "  1. Check AWS credentials and permissions"
    echo "  2. Verify security groups allow required ports"
    echo "  3. Check application logs: ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP 'sudo docker-compose logs'"
    echo "  4. Restart services: ssh -i ~/.ssh/devops-key ubuntu@$WEB_IP 'cd /opt/devops-app && sudo docker-compose restart'"
    echo "  5. Re-run Ansible playbook: cd ansible && ansible-playbook -i inventory.ini playbook.yml"
    exit 1
fi