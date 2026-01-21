#!/bin/bash

# Default values
LOG_FILE="indexing_logs.txt"
CMD="docker compose logs --tail=100 -f graph-node"

show_help() {
    echo "Usage: ./logs.sh [options]"
    echo ""
    echo "Options:"
    echo "  -e, --errors    Show only error logs"
    echo "  -x, --export    Export current logs to $LOG_FILE and exit"
    echo "  -h, --help      Show this help message"
}

export_logs() {
    echo "💾 Exporting logs to $LOG_FILE..."
    docker compose logs graph-node > "$LOG_FILE"
    echo "✅ Logs exported to $(pwd)/$LOG_FILE"
    exit 0
}

case "$1" in
    -e|--errors)
        echo "🧐 Showing error logs (follow mode)..."
        docker compose logs -f graph-node | grep -iE "error|fail|critical"
        ;;
    -x|--export)
        export_logs
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo "📺 Showing last 100 logs (follow mode)..."
        $CMD
        ;;
esac
