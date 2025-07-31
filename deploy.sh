#!/bin/bash
set -e

echo "🚀 Starting DevOps Assignment Deployment"

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "Terraform required but not installed."; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo "Ansible required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker required but not installed."; exit 1; }

# Deploy infrastructure
echo "📦 Deploying infrastructure..."
cd terraform
terraform init
terraform apply -auto-approve
cd ..

# Update inventory with dynamic IPs
echo "📝 Updating inventory..."
./update-inventory.sh

# Configure servers
echo "⚙️ Configuring servers..."
cd ansible
ansible-playbook -i inventory.ini playbook.yml
cd ..

# Start applications
echo "🐳 Starting applications..."
cd docker
docker-compose up -d
cd ..

# Start monitoring
echo "📊 Starting monitoring..."
cd monitoring
docker-compose up -d
cd ..

echo "✅ Deployment complete!"
echo "Access your application at: http://your-proxy-server"