#!/bin/bash

# Log metrics exporter for Prometheus
METRICS_FILE="/tmp/log_metrics.prom"

# Generate metrics
cat > $METRICS_FILE << EOF
# HELP log_viewer_executions_total Total executions of log viewer
# TYPE log_viewer_executions_total counter
log_viewer_executions_total{command="$1"} $(date +%s)

# HELP log_lines_total Total log lines processed
# TYPE log_lines_total counter
log_lines_total{service="$1"} $(docker-compose -f docker/docker-compose.yml logs --tail=1000 $1-service 2>/dev/null | wc -l)

# HELP log_errors_total Total error lines in logs
# TYPE log_errors_total counter
log_errors_total{service="$1"} $(docker-compose -f docker/docker-compose.yml logs --tail=1000 $1-service 2>/dev/null | grep -i error | wc -l)
EOF

# Serve metrics on port 9101
python3 -m http.server 9101 --directory /tmp &