#!/bin/bash

# Log metrics exporter for Prometheus
METRICS_FILE="/tmp/metrics.txt"

# Function to generate metrics
generate_metrics() {
    local service=$1
    local container_name="${service}-service"
    
    # Handle postgres container name
    if [ "$service" = "postgres" ]; then
        container_name="postgres"
    fi
    
    # Count log lines and errors
    local log_lines=0
    local error_lines=0
    local warning_lines=0
    local connection_lines=0
    
    if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
        log_lines=$(docker logs "$container_name" 2>/dev/null | wc -l || echo 0)
        error_lines=$(docker logs "$container_name" 2>/dev/null | grep -i "error\|fatal\|panic" | wc -l || echo 0)
        warning_lines=$(docker logs "$container_name" 2>/dev/null | grep -i "warning\|warn" | wc -l || echo 0)
        
        # PostgreSQL specific metrics
        if [ "$service" = "postgres" ]; then
            connection_lines=$(docker logs "$container_name" 2>/dev/null | grep -i "connection" | wc -l || echo 0)
        fi
    fi
    
    cat >> $METRICS_FILE << EOF
# HELP log_viewer_executions_total Total executions of log viewer
# TYPE log_viewer_executions_total counter
log_viewer_executions_total{command="$service"} 1

# HELP log_lines_total Total log lines processed
# TYPE log_lines_total gauge
log_lines_total{service="$service"} $log_lines

# HELP log_errors_total Total error lines in logs
# TYPE log_errors_total gauge
log_errors_total{service="$service"} $error_lines

# HELP log_warnings_total Total warning lines in logs
# TYPE log_warnings_total gauge
log_warnings_total{service="$service"} $warning_lines

EOF

    # Add PostgreSQL specific metrics
    if [ "$service" = "postgres" ]; then
        cat >> $METRICS_FILE << EOF
# HELP postgres_connections_total Total PostgreSQL connection events
# TYPE postgres_connections_total gauge
postgres_connections_total{service="$service"} $connection_lines

EOF
    fi
}

# Initialize metrics file
echo "# DevOps Application Metrics" > $METRICS_FILE
echo "# Generated at $(date)" >> $METRICS_FILE
echo "" >> $METRICS_FILE

# Generate metrics for the service
if [ -n "$1" ]; then
    generate_metrics "$1"
else
    # Generate for all services including postgres
    generate_metrics "python"
    generate_metrics "node"
    generate_metrics "postgres"
fi

# Start simple HTTP server if not running
if ! pgrep -f "python3.*9101" > /dev/null; then
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
    httpd.serve_forever()
" &
fi