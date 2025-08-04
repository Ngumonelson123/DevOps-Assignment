#!/bin/bash

set -e

echo "Starting DevOps Deployment Automation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${GREEN} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  $1${NC}"
}

print_error() {
    echo -e "${RED} $1${NC}"
}

# Check prerequisites
echo "🔍 Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { print_error "Terraform not installed"; exit 1; }
command -v ansible >/dev/null 2>&1 || { print_error "Ansible not installed"; exit 1; }
command -v docker >/dev/null 2>&1 || { print_error "Docker not installed"; exit 1; }
print_status "Prerequisites check passed"

# Create S3 bucket for Terraform state if it doesn't exist
echo "Setting up Terraform state bucket..."
BUCKET_NAME="devops-terraform-state-1754244313"
if ! aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    aws s3 mb "s3://$BUCKET_NAME" --region us-east-1
    print_status "S3 bucket created: $BUCKET_NAME"
else
    print_status "S3 bucket already exists: $BUCKET_NAME"
fi

# Deploy infrastructure
echo "Deploying infrastructure..."
cd terraform
terraform init -reconfigure
if terraform plan -out=tfplan; then
    terraform apply tfplan
    print_status "Infrastructure deployed"
else
    print_error "Infrastructure deployment failed"
    exit 1
fi

# Get server IPs using terraform state (works in GitHub Actions)
terraform state pull > state.json
WEB_SERVER_IP=$(grep -A 5 '"web_server_ip"' state.json | grep '"value"' | head -1 | cut -d'"' -f4 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
PROXY_SERVER_IP=$(grep -A 5 '"proxy_server_ip"' state.json | grep '"value"' | head -1 | cut -d'"' -f4 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
WEB_SERVER_PRIVATE_IP=$(grep -A 5 '"web_server_private_ip"' state.json | grep '"value"' | head -1 | cut -d'"' -f4 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')

# Ensure SSH key exists and has correct permissions
if [ ! -f ~/.ssh/devops-key ]; then
    echo "SSH key not found, creating from GitHub secret..."
    mkdir -p ~/.ssh
    # In GitHub Actions, the SSH key should be provided via secrets
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/devops-key 2>/dev/null || true
fi

echo "Server Information:"
echo "   Web Server: $WEB_SERVER_IP"
echo "   Proxy Server: $PROXY_SERVER_IP"
echo "   Web Private IP: $WEB_SERVER_PRIVATE_IP"

# Update Ansible inventory
cd ../ansible
cat > inventory.ini << EOF
[WebServer]
$WEB_SERVER_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devops-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[proxy]
$PROXY_SERVER_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devops-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "Generated inventory.ini:"
cat inventory.ini
print_status "Inventory updated"

# Wait for servers to be ready
echo "Waiting for servers to be ready..."
sleep 30

# Configure servers with Ansible
echo "Configuring servers..."
if ansible-playbook -i inventory.ini playbook.yml --forks=10; then
    print_status "Server configuration completed"
else
    print_error "Server configuration failed"
    exit 1
fi

# Restart monitoring and application stacks to pick up new configurations
echo "Restarting services to apply configuration changes..."
ssh -i ~/.ssh/devops-key -o StrictHostKeyChecking=no ubuntu@$WEB_SERVER_IP "cd /opt/monitoring && sudo docker-compose restart" || print_warning "Failed to restart monitoring stack"
ssh -i ~/.ssh/devops-key -o StrictHostKeyChecking=no ubuntu@$WEB_SERVER_IP "cd /opt/devops-app && sudo docker-compose restart" || print_warning "Failed to restart application stack"

# Push to GitHub
echo "Pushing to GitHub..."
cd ..
git config --global user.email "action@github.com"
git config --global user.name "GitHub Action"
git add . && git commit -m "Automated deployment update" && git push origin main || print_warning "Git push failed or no changes"

echo "Deployment completed successfully!"
echo ""
echo "Access your services:"
echo "   Applications: https://$PROXY_SERVER_IP/api/python/ | https://$PROXY_SERVER_IP/api/node/"
echo "   Grafana: http://$WEB_SERVER_IP:3001"
echo "   Prometheus: http://$WEB_SERVER_IP:9090"
echo "   cAdvisor: http://$WEB_SERVER_IP:8080"
echo ""
echo "Test your deployment:"
echo "   curl -k https://$PROXY_SERVER_IP/api/python/"
echo "   curl -k https://$PROXY_SERVER_IP/api/node/"
echo "   curl http://$WEB_SERVER_IP:3001"
echo "   curl http://$WEB_SERVER_IP:9090"
echo "   curl http://$WEB_SERVER_IP:8080"