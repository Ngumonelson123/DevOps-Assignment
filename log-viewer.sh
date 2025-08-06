#!/bin/bash

# Log access script for all applications with monitoring
echo "=== DevOps Application Log Viewer ==="
echo ""

# Auto-enable monitoring
export ENABLE_MONITORING=true

# Log usage metrics
log_usage() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Command: $1" >> /tmp/log-viewer-usage.log
    # Auto-export metrics
    ./monitoring/log-exporter.sh "$1" 2>/dev/null &
}

# Function to show logs
show_logs() {
    local service=$1
    echo "--- $service Logs ---"
    docker-compose -f docker/docker-compose.yml logs --tail=50 $service
    echo ""
}

# Function to follow logs
follow_logs() {
    local service=$1
    echo "Following $service logs (Ctrl+C to stop)..."
    docker-compose -f docker/docker-compose.yml logs -f $service
}

# Function to show all structured logs
show_structured_logs() {
    echo "--- All Application Events (JSON) ---"
    docker-compose -f docker/docker-compose.yml logs --tail=100 python-service node-service | grep -E '^\{.*\}$' | jq '.'
}

case "$1" in
    "python")
        log_usage "python"
        show_logs "python-service"
        ;;
    "node")
        log_usage "node"
        show_logs "node-service"
        ;;
    "postgres")
        show_logs "postgres"
        ;;
    "all")
        log_usage "all"
        show_logs "python-service"
        show_logs "node-service"
        show_logs "postgres"
        ;;
    "follow")
        if [ -z "$2" ]; then
            echo "Usage: $0 follow [python|node|postgres]"
            exit 1
        fi
        log_usage "follow-$2"
        if [ "$2" = "postgres" ]; then
            follow_logs "postgres"
        else
            follow_logs "$2-service"
        fi
        ;;
    "events")
        log_usage "events"
        show_structured_logs
        ;;
    *)
        echo "Usage: $0 [python|node|postgres|all|events|follow <service>]"
        echo ""
        echo "Commands:"
        echo "  python  - Show Python app logs"
        echo "  node    - Show Node.js app logs"
        echo "  postgres - Show PostgreSQL logs"
        echo "  all     - Show all service logs"
        echo "  events  - Show structured application events"
        echo "  follow  - Follow logs in real-time"
        echo ""
        echo "Examples:"
        echo "  $0 python"
        echo "  $0 events"
        echo "  $0 follow python"
        ;;
esac