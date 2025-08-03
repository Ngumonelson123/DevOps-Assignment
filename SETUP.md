# Quick Setup Guide

## Prerequisites Checklist
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform installed (`terraform --version`)
- [ ] Ansible installed (`ansible --version`)
- [ ] Docker and Docker Compose installed
- [ ] SSH key pair generated (`~/.ssh/devops-key`)
- [ ] jq installed for JSON processing

## Environment Setup
```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Generate SSH key if not exists
ssh-keygen -t rsa -b 4096 -f ~/.ssh/devops-key -N ""
```

## One-Command Deployment
```bash
./deploy.sh
```

## Manual Deployment Steps
```bash
# 1. Deploy infrastructure
cd terraform && terraform init && terraform apply -auto-approve

# 2. Get server IPs
WEB_IP=$(terraform output -raw web_server_ip)
PROXY_IP=$(terraform output -raw proxy_server_ip)

# 3. Configure servers
cd ../ansible
cat > inventory.ini << EOF
[WebServer]
$WEB_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devops-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[proxy]
$PROXY_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devops-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

ansible-playbook -i inventory.ini playbook.yml
```

## Quick Tests
```bash
# Test applications
curl -k https://$PROXY_IP/api/python/
curl -k https://$PROXY_IP/api/node/

# Access monitoring
open http://$WEB_IP:3001  # Grafana
open http://$WEB_IP:9090  # Prometheus
```

## Cleanup
```bash
cd terraform && terraform destroy -auto-approve
```