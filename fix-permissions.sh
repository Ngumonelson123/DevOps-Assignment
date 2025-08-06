#!/bin/bash

# Fix permissions for all shell scripts in the DevOps project
echo "Fixing permissions for shell scripts..."

# Get server IPs from Terraform
if [ -f "terraform/terraform.tfstate" ]; then
    WEB_IP=$(cd terraform && terraform output -raw web_server_ip 2>/dev/null || echo "")
    
    if [ -n "$WEB_IP" ]; then
        echo "Fixing permissions on web server: $WEB_IP"
        ssh -i ~/.ssh/devops-key -o StrictHostKeyChecking=no ubuntu@$WEB_IP "
            cd /opt/devops-app
            sudo chmod +x *.sh
            sudo chmod +x monitoring/*.sh
            echo 'Permissions fixed successfully'
        "
    else
        echo "Could not get web server IP from Terraform"
        exit 1
    fi
else
    echo "Terraform state not found. Please deploy infrastructure first."
    exit 1
fi

echo "Permission fix completed!"