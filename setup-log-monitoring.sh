#!/bin/bash

# Automated log monitoring setup
echo "Setting up log monitoring..."

# Make scripts executable
chmod +x log-viewer.sh log-monitor.sh monitoring/log-exporter.sh generate-test-data.sh fix-dashboard.sh

# Create log directory
mkdir -p /tmp/logs

# Start log metrics exporter
echo "Starting log metrics exporter..."
nohup ./monitoring/log-exporter.sh > /tmp/logs/exporter.log 2>&1 &

# Import Grafana dashboard
echo "Importing log monitoring dashboard..."
GRAFANA_URL="http://localhost:3001"
curl -X POST \
  -H "Content-Type: application/json" \
  -d @monitoring/grafana/dashboards/log-monitoring.json \
  "$GRAFANA_URL/api/dashboards/db" \
  --user admin:admin 2>/dev/null

# Add Prometheus scrape config for log metrics
if ! grep -q "log-metrics" monitoring/prometheus/prometheus.yml; then
    cat >> monitoring/prometheus/prometheus.yml << EOF
  - job_name: 'log-metrics'
    static_configs:
      - targets: ['localhost:9101']
    scrape_interval: 15s
    metrics_path: '/metrics'
EOF
fi

# Restart Prometheus to pick up new config
docker-compose -f monitoring/docker-compose.yml restart prometheus

# Generate test data and fix dashboard
echo "Generating test data for dashboard..."
./generate-test-data.sh
sleep 5

echo "Log monitoring setup complete!"
echo "Access dashboard at: http://localhost:3001/d/log-monitoring"
echo "Start real-time monitor with: ./log-monitor.sh"
echo "Test metrics with: ./test-log-metrics.sh"