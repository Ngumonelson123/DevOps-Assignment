#!/bin/bash

# Real-time log monitoring dashboard
echo "=== Real-time Log Monitor ==="

# Function to show live stats
show_stats() {
    clear
    echo "=== Log Viewer Statistics ($(date)) ==="
    echo ""
    
    # Usage stats
    if [ -f /tmp/log-viewer-usage.log ]; then
        echo "Recent Usage:"
        tail -10 /tmp/log-viewer-usage.log
        echo ""
        
        echo "Command Usage Count (last hour):"
        grep "$(date '+%Y-%m-%d %H')" /tmp/log-viewer-usage.log | awk '{print $4}' | sort | uniq -c
    fi
    
    echo ""
    echo "Current Container Status:"
    docker-compose -f docker/docker-compose.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo "Recent Errors (last 50 lines):"
    docker-compose -f docker/docker-compose.yml logs --tail=50 | grep -i "error\|fatal\|panic" | tail -5
    
    echo ""
    echo "PostgreSQL Status:"
    if docker ps --format "{{.Names}}" | grep -q "postgres"; then
        echo "  Container: Running"
        echo "  Connections: $(docker logs postgres 2>/dev/null | grep -i connection | wc -l)"
        echo "  Errors: $(docker logs postgres 2>/dev/null | grep -i "error\|fatal" | wc -l)"
    else
        echo "  Container: Not running"
    fi
}

# Run monitoring loop
echo "Press Ctrl+C to stop monitoring..."
while true; do
    show_stats
    sleep 5
done