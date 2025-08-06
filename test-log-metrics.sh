#!/bin/bash

# Test script to generate log metrics
echo "Testing log metrics generation..."

# Run log viewer to generate usage
./log-viewer.sh python
./log-viewer.sh node
./log-viewer.sh postgres
./log-viewer.sh all

# Check if metrics are being generated
echo "Checking metrics endpoint..."
curl -s http://localhost:9101/metrics

echo ""
echo "Checking Prometheus targets..."
if command -v jq >/dev/null 2>&1; then
    curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="log-metrics")'
else
    curl -s http://localhost:9090/api/v1/targets | grep -o '"log-metrics"' || echo "log-metrics target not found"
fi