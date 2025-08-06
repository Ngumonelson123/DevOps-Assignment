#!/bin/bash

# Setup log monitoring for DevOps application
echo "Setting up log monitoring..."

# Install dependencies
sudo apt-get update -qq
sudo apt-get install -y net-tools jq curl

# Make scripts executable
sudo chmod +x *.sh monitoring/*.sh 2>/dev/null || true

# Start simple metrics server
echo "Starting simple metrics server..."
./simple-metrics.sh &
sleep 2

# Wait for Grafana
echo "Waiting for Grafana..."
sleep 10

# Import dashboard with retry
echo "Importing log monitoring dashboard..."
for i in {1..3}; do
    if curl -X POST \
      http://admin:admin@localhost:3001/api/dashboards/db \
      -H 'Content-Type: application/json' \
      -d @monitoring/grafana/dashboards/log-monitoring.json 2>/dev/null; then
        echo "Dashboard imported"
        break
    fi
    sleep 5
done

# Restart Prometheus
echo "Restarting Prometheus..."
cd monitoring && docker-compose restart prometheus

echo "Log monitoring setup complete!"
echo "Access dashboard at: http://localhost:3001/d/log-monitoring"