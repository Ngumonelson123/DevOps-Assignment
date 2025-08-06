#!/bin/bash

echo "=== Debug Log Metrics ==="

# Check if metrics server is running
echo "1. Checking metrics server on port 9101:"
if command -v netstat >/dev/null 2>&1; then
    if netstat -tuln | grep -q ":9101"; then
        echo "✓ Port 9101 is open"
    else
        echo "✗ Port 9101 is not open"
    fi
else
    if ss -tuln | grep -q ":9101" 2>/dev/null; then
        echo "✓ Port 9101 is open (using ss)"
    else
        echo "✗ Port 9101 is not open (using ss)"
    fi
fi

# Check metrics endpoint
echo ""
echo "2. Testing metrics endpoint:"
if curl -s http://localhost:9101/metrics > /dev/null; then
    echo "✓ Metrics endpoint responding"
    echo "Sample metrics:"
    curl -s http://localhost:9101/metrics | head -5
else
    echo "✗ Metrics endpoint not responding"
    echo "Starting metrics server..."
    ./generate-test-data.sh &
    sleep 3
fi

# Check Prometheus config
echo ""
echo "3. Checking Prometheus config:"
if grep -q "log-metrics" monitoring/prometheus/prometheus.yml; then
    echo "✓ log-metrics job found in prometheus.yml"
else
    echo "✗ log-metrics job missing from prometheus.yml"
    echo "Adding job..."
    cat >> monitoring/prometheus/prometheus.yml << EOF
  - job_name: 'log-metrics'
    static_configs:
      - targets: ['localhost:9101']
EOF
fi

# Check Prometheus targets
echo ""
echo "4. Checking Prometheus targets:"
TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null)
if echo "$TARGETS" | grep -q "log-metrics"; then
    echo "✓ log-metrics target found in Prometheus"
else
    echo "✗ log-metrics target not found in Prometheus"
    echo "Restarting Prometheus..."
    docker-compose -f monitoring/docker-compose.yml restart prometheus
    sleep 10
fi

# Test query
echo ""
echo "5. Testing Prometheus query:"
RESULT=$(curl -s "http://localhost:9090/api/v1/query?query=log_lines_total" 2>/dev/null)
if echo "$RESULT" | grep -q "result"; then
    echo "✓ Query successful"
    if command -v jq >/dev/null 2>&1; then
        echo "$RESULT" | jq '.data.result[0].metric // "No data"'
    else
        echo "Query result: $RESULT" | head -c 100
    fi
else
    echo "✗ Query failed"
fi

echo ""
echo "=== Debug Complete ==="