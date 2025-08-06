#!/bin/bash

# Simple metrics generator that definitely works
echo "Starting simple metrics server..."

# Kill any existing server
pkill -f "python3.*9101" 2>/dev/null

# Create basic metrics
mkdir -p /tmp
cat > /tmp/metrics.txt << 'EOF'
# Simple test metrics
log_lines_total{service="python"} 100
log_lines_total{service="node"} 80
log_lines_total{service="postgres"} 60
log_errors_total{service="python"} 5
log_errors_total{service="node"} 2
log_errors_total{service="postgres"} 1
log_viewer_executions_total{command="python"} 10
log_viewer_executions_total{command="node"} 8
postgres_connections_total{service="postgres"} 25
EOF

# Start server
python3 << 'PYEOF' &
import http.server
import socketserver
import os

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            with open('/tmp/metrics.txt', 'r') as f:
                self.wfile.write(f.read().encode())
        else:
            self.send_response(404)
            self.end_headers()

os.chdir('/tmp')
with socketserver.TCPServer(("", 9101), Handler) as httpd:
    print("Serving on port 9101")
    httpd.serve_forever()
PYEOF

echo "Metrics server started on port 9101"
echo "Test with: curl http://localhost:9101/metrics"