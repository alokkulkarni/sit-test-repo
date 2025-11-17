#!/bin/bash

# Real-time Dashboard for monitoring during load tests
# Run this in a separate terminal while running performance-analysis.sh

CONTAINER_NAME="paymentconsumer"
REFRESH_INTERVAL=2

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Container '${CONTAINER_NAME}' is not running"
    exit 1
fi

# Function to get container stats
get_stats() {
    docker stats ${CONTAINER_NAME} --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}"
}

# Function to get JVM metrics
get_jvm_metrics() {
    curl -s http://localhost:8785/actuator/metrics/jvm.memory.used 2>/dev/null | jq -r '.measurements[0].value' || echo "N/A"
}

# Function to get HTTP metrics
get_http_metrics() {
    curl -s http://localhost:8785/actuator/metrics/http.server.requests 2>/dev/null | jq -r '.measurements[] | select(.statistic=="COUNT") | .value' || echo "0"
}

# Clear screen and show header
clear
echo "========================================"
echo "Real-Time Performance Dashboard"
echo "Container: ${CONTAINER_NAME}"
echo "========================================"
echo ""

while true; do
    # Move cursor to top
    tput cup 4 0
    
    # Get current stats
    STATS=$(get_stats)
    CPU=$(echo $STATS | cut -d',' -f1)
    MEM=$(echo $STATS | cut -d',' -f2)
    MEM_PERCENT=$(echo $STATS | cut -d',' -f3)
    NET_IO=$(echo $STATS | cut -d',' -f4)
    BLOCK_IO=$(echo $STATS | cut -d',' -f5)
    
    # Get JVM metrics
    JVM_MEM=$(get_jvm_metrics)
    if [ "$JVM_MEM" != "N/A" ]; then
        JVM_MEM_MB=$(echo "scale=2; $JVM_MEM / 1048576" | bc)
        JVM_MEM="${JVM_MEM_MB} MB"
    fi
    
    # Get HTTP request count
    HTTP_REQUESTS=$(get_http_metrics)
    
    # Display stats
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Container Resources:"
    echo "  CPU Usage:     ${CPU}"
    echo "  Memory Usage:  ${MEM} (${MEM_PERCENT})"
    echo "  Network I/O:   ${NET_IO}"
    echo "  Block I/O:     ${BLOCK_IO}"
    echo ""
    echo "Application Metrics:"
    echo "  JVM Memory:    ${JVM_MEM}"
    echo "  HTTP Requests: ${HTTP_REQUESTS}"
    echo ""
    echo "Press Ctrl+C to exit"
    echo "                                                    "
    
    sleep $REFRESH_INTERVAL
done
