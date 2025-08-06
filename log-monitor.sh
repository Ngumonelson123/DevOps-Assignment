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
    docker-compose -f docker/docker-compose.yml logs --tail=50 | grep -i error | tail -5
}

# Run monitoring loop
while true; do
    show_stats
    sleep 5
done