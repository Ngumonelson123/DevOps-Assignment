#!/bin/bash

set -e

echo "🚀 Starting DevOps Deployment Automation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
echo "🔍 Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { print_error "Terraform not installed"; exit 1; }
command -v ansible >/dev/null 2>&1 || { print_error "Ansible not installed"; exit 1; }
command -v docker >/dev/null 2>&1 || { print_error "Docker not installed"; exit 1; }
print_status "Prerequisites check passed"

# Deploy infrastructure
echo "🏗️  Deploying infrastructure..."
cd terraform
terraform init
if terraform plan -out=tfplan; then
    terraform apply tfplan
    print_status "Infrastructure deployed"
else
    print_error "Infrastructure deployment failed"
    exit 1
fi

# Get server IPs
WEB_SERVER_IP=$(terraform output -raw web_server_ip)
PROXY_SERVER_IP=$(terraform output -raw proxy_server_ip)
WEB_SERVER_PRIVATE_IP=$(terraform output -raw web_server_private_ip)

echo "📋 Server Information:"
echo "   Web Server: $WEB_SERVER_IP"
echo "   Proxy Server: $PROXY_SERVER_IP"
echo "   Web Private IP: $WEB_SERVER_PRIVATE_IP"

# Update Ansible inventory
cd ../ansible
cat > inventory.ini << EOF
[WebServer]
$WEB_SERVER_IP ansible_user=ubuntu ansible_ssh_private_key_file=/home/nelson-ngumo/.ssh/devops-key ansible_ssh_common_args='-o IdentitiesOnly=yes'

[proxy]
$PROXY_SERVER_IP ansible_user=ubuntu ansible_ssh_private_key_file=/home/nelson-ngumo/.ssh/devops-key ansible_ssh_common_args='-o IdentitiesOnly=yes'
EOF

print_status "Inventory updated"

# Wait for servers to be ready
echo "⏳ Waiting for servers to be ready..."
sleep 60

# Configure servers with Ansible
echo "⚙️  Configuring servers..."
if ansible-playbook -i inventory.ini playbook.yml; then
    print_status "Server configuration completed"
else
    print_error "Server configuration failed"
    exit 1
fi

# Push to GitHub
echo "📤 Pushing to GitHub..."
cd ..
ssh-agent bash -c 'ssh-add ~/.ssh/ngumonelson123_key; git add . && git commit -m "Automated deployment update" && git push origin main' || print_warning "Git push failed or no changes"

echo "🎉 Deployment completed successfully!"
echo ""
echo "🌐 Access your services:"
echo "   Applications: https://$PROXY_SERVER_IP/api/python/ | https://$PROXY_SERVER_IP/api/node/"
echo "   Grafana: http://$WEB_SERVER_IP:3001"
echo "   Prometheus: http://$WEB_SERVER_IP:9090"
echo "   cAdvisor: http://$WEB_SERVER_IP:8085"
echo ""
echo "🧪 Test your deployment:"
echo "   curl -k https://$PROXY_SERVER_IP/api/python/"
echo "   curl -k https://$PROXY_SERVER_IP/api/node/"
echo "   curl http://$WEB_SERVER_IP:3001"
echo "   curl http://$WEB_SERVER_IP:9090"