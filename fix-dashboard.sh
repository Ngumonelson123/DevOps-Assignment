#!/bin/bash

echo "Fixing log monitoring dashboard..."

# 1. Generate test data
chmod +x generate-test-data.sh
./generate-test-data.sh

# 2. Check if Prometheus is scraping the metrics
echo "Checking Prometheus configuration..."
if ! grep -q "log-metrics" monitoring/prometheus/prometheus.yml; then
    echo "Adding log-metrics job to Prometheus..."
    cat >> monitoring/prometheus/prometheus.yml << EOF
  - job_name: 'log-metrics'
    static_configs:
      - targets: ['localhost:9101']
    scrape_interval: 15s
    metrics_path: '/metrics'
EOF
fi

# 3. Restart Prometheus to pick up config
echo "Restarting Prometheus..."
docker-compose -f monitoring/docker-compose.yml restart prometheus

# 4. Wait and test
sleep 10
echo "Testing metrics endpoint..."
curl -s http://localhost:9101/metrics | head -10

echo ""
echo "Testing Prometheus scraping..."
curl -s "http://localhost:9090/api/v1/query?query=log_lines_total" | jq '.data.result[] | {metric: .metric, value: .value[1]}'

echo ""
echo "Dashboard should now show data at: http://localhost:3001/d/log-monitoring"