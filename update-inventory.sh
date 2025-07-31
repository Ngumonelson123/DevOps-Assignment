#!/bin/bash

# Get IPs from Terraform output
cd terraform
WEB_SERVER_IP=$(terraform output -raw web_server_ip)
PROXY_SERVER_IP=$(terraform output -raw proxy_server_ip)
cd ..

# Update Ansible inventory
cat > ansible/inventory.ini << EOF
[WebServer]
$WEB_SERVER_IP ansible_user=ubuntu ansible_ssh_private_key_file=/home/nelson-ngumo/.ssh/devops-key

[proxy]
$PROXY_SERVER_IP ansible_user=ubuntu ansible_ssh_private_key_file=/home/nelson-ngumo/.ssh/devops-key
EOF

echo "Inventory updated with:"
echo "Web Server: $WEB_SERVER_IP"
echo "Proxy Server: $PROXY_SERVER_IP"