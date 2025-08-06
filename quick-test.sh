#!/bin/bash

# Quick test script to validate deployment
set -e

echo "🚀 Quick Deployment Test"

# Get server IPs
if [ -f "terraform/terraform.tfstate" ]; then
    WEB_IP=$(cd terraform && terraform output -raw web_server_ip 2>/dev/null)
    PROXY_IP=$(cd terraform && terraform output -raw proxy_server_ip 2>/dev/null)
    
    echo "Testing servers:"
    echo "  Web Server: $WEB_IP"
    echo "  Proxy Server: $PROXY_IP"
    echo ""
    
    # Test applications
    echo "🧪 Testing Python service..."
    if curl -k -s https://$PROXY_IP/api/python/ | grep -q "Hello"; then
        echo "✅ Python service OK"
    else
        echo "❌ Python service failed"
    fi
    
    echo "🧪 Testing Node.js service..."
    if curl -k -s https://$PROXY_IP/api/node/ | grep -q "Hello"; then
        echo "✅ Node.js service OK"
    else
        echo "❌ Node.js service failed"
    fi
    
    echo "🧪 Testing Grafana..."
    if curl -s -I http://$WEB_IP:3001 | grep -q "200 OK"; then
        echo "✅ Grafana OK"
    else
        echo "❌ Grafana failed"
    fi
    
    echo "🧪 Testing Prometheus..."
    if curl -s -I http://$WEB_IP:9090 | grep -q "200 OK"; then
        echo "✅ Prometheus OK"
    else
        echo "❌ Prometheus failed"
    fi
    
    echo ""
    echo "🌐 Access URLs:"
    echo "  Applications: https://$PROXY_IP/api/python/ | https://$PROXY_IP/api/node/"
    echo "  Grafana: http://$WEB_IP:3001"
    echo "  Prometheus: http://$WEB_IP:9090"
    
else
    echo "❌ Terraform state not found. Deploy infrastructure first."
    exit 1
fi