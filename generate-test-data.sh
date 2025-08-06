#!/bin/bash

# Generate test data for log monitoring dashboard
echo "Generating test log data..."

# Create test metrics file
cat > /tmp/metrics.txt << EOF
# DevOps Application Metrics
# Generated at $(date)

# HELP log_viewer_executions_total Total executions of log viewer
# TYPE log_viewer_executions_total counter
log_viewer_executions_total{command="python"} 15
log_viewer_executions_total{command="node"} 12
log_viewer_executions_total{command="postgres"} 8
log_viewer_executions_total{command="all"} 5

# HELP log_lines_total Total log lines processed
# TYPE log_lines_total gauge
log_lines_total{service="python"} 245
log_lines_total{service="node"} 189
log_lines_total{service="postgres"} 156

# HELP log_errors_total Total error lines in logs
# TYPE log_errors_total gauge
log_errors_total{service="python"} 3
log_errors_total{service="node"} 1
log_errors_total{service="postgres"} 0

# HELP log_warnings_total Total warning lines in logs
# TYPE log_warnings_total gauge
log_warnings_total{service="python"} 7
log_warnings_total{service="node"} 4
log_warnings_total{service="postgres"} 2

# HELP postgres_connections_total Total PostgreSQL connection events
# TYPE postgres_connections_total gauge
postgres_connections_total{service="postgres"} 23
EOF

# Start metrics server if not running
if ! pgrep -f "python3.*9101" > /dev/null; then
    echo "Starting metrics server on port 9101..."
    cd /tmp && python3 -c "
import http.server
import socketserver
class MetricsHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            try:
                with open('/tmp/metrics.txt', 'r') as f:
                    self.wfile.write(f.read().encode())
            except:
                self.wfile.write(b'# No metrics available\n')
        else:
            super().do_GET()
with socketserver.TCPServer(('', 9101), MetricsHandler) as httpd:
    print('Serving metrics on port 9101...')
    httpd.serve_forever()
" &
    sleep 2
fi

echo "Test data generated. Check metrics at: http://localhost:9101/metrics"
echo "Dashboard should now show data in Grafana"