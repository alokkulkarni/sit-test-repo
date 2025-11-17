#!/bin/bash

# Performance Analysis Script for Payment Consumer
# Monitors CPU, Memory, and provides production recommendations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="paymentconsumer-app"
SERVICE_URL="http://localhost:8785/api/v1/consumer/payments"
PAYLOAD_FILE="payment-request.json"
DURATION=${1:-60}  # Test duration in seconds
CONCURRENCY=${2:-10}  # Concurrent users
RPS_TARGET=${3:-100}  # Target requests per second

echo -e "${BLUE}=========================================="
echo "Payment Consumer Performance Analysis"
echo "==========================================${NC}"
echo "Duration: ${DURATION}s"
echo "Concurrency: ${CONCURRENCY}"
echo "Target RPS: ${RPS_TARGET}"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Container '${CONTAINER_NAME}' is not running${NC}"
    echo "Please start the container first with: docker-compose up -d"
    exit 1
fi

# Get current container resource limits
echo -e "${BLUE}Current Container Configuration:${NC}"
CONTAINER_INFO=$(docker inspect ${CONTAINER_NAME})
CPU_LIMIT=$(echo $CONTAINER_INFO | jq -r '.[0].HostConfig.NanoCpus')
MEM_LIMIT=$(echo $CONTAINER_INFO | jq -r '.[0].HostConfig.Memory')

if [ "$CPU_LIMIT" = "0" ] || [ "$CPU_LIMIT" = "null" ]; then
    echo -e "  CPU Limit: ${YELLOW}Unlimited${NC}"
    CPU_LIMIT_CORES="unlimited"
else
    CPU_LIMIT_CORES=$(echo "scale=2; $CPU_LIMIT / 1000000000" | bc)
    echo -e "  CPU Limit: ${GREEN}${CPU_LIMIT_CORES} cores${NC}"
fi

if [ "$MEM_LIMIT" = "0" ] || [ "$MEM_LIMIT" = "null" ]; then
    echo -e "  Memory Limit: ${YELLOW}Unlimited${NC}"
    MEM_LIMIT_MB="unlimited"
else
    MEM_LIMIT_MB=$(echo "scale=0; $MEM_LIMIT / 1048576" | bc)
    echo -e "  Memory Limit: ${GREEN}${MEM_LIMIT_MB} MB${NC}"
fi
echo ""

# Create monitoring output directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="performance-results/${TIMESTAMP}"
mkdir -p ${OUTPUT_DIR}

# Function to monitor container stats
monitor_stats() {
    echo -e "${BLUE}Starting resource monitoring...${NC}"
    docker stats ${CONTAINER_NAME} --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" > ${OUTPUT_DIR}/stats_initial.txt
    
    # Continuous monitoring during test
    while [ -f ${OUTPUT_DIR}/test_running ]; do
        docker stats ${CONTAINER_NAME} --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}}" >> ${OUTPUT_DIR}/stats_continuous.csv
        sleep 2
    done
}

# Function to calculate statistics
calculate_stats() {
    local file=$1
    awk -F',' '{
        gsub(/%/, "", $1); cpu+=$1; 
        split($2, mem, " / "); 
        gsub(/MiB|GiB/, "", mem[1]); 
        if (index(mem[1], "GiB")) mem[1]*=1024;
        mem_used+=mem[1]; 
        gsub(/%/, "", $3); mem_percent+=$3;
        count++
    } 
    END {
        print "avg_cpu=" cpu/count;
        print "avg_mem_used=" mem_used/count;
        print "avg_mem_percent=" mem_percent/count
    }' $file
}

# Function to run load test with hey
run_hey_test() {
    echo -e "${BLUE}Running load test with hey...${NC}"
    
    if ! command -v hey &> /dev/null; then
        echo -e "${YELLOW}hey is not installed. Installing...${NC}"
        brew install hey
    fi
    
    hey -z ${DURATION}s -c ${CONCURRENCY} -m POST \
        -H "Content-Type: application/json" \
        -D ${PAYLOAD_FILE} \
        ${SERVICE_URL} > ${OUTPUT_DIR}/hey_results.txt 2>&1
}

# Function to run load test with wrk
run_wrk_test() {
    echo -e "${BLUE}Running load test with wrk...${NC}"
    
    if ! command -v wrk &> /dev/null; then
        echo -e "${YELLOW}wrk is not installed. Installing...${NC}"
        brew install wrk
    fi
    
    wrk -t${CONCURRENCY} -c${CONCURRENCY} -d${DURATION}s \
        -s wrk-script.lua \
        ${SERVICE_URL} > ${OUTPUT_DIR}/wrk_results.txt 2>&1
}

# Start monitoring in background
touch ${OUTPUT_DIR}/test_running
monitor_stats &
MONITOR_PID=$!

# Wait a bit for monitoring to start
sleep 2

# Run load test
if command -v hey &> /dev/null; then
    run_hey_test
elif command -v wrk &> /dev/null; then
    run_wrk_test
else
    echo -e "${YELLOW}Neither hey nor wrk found. Installing hey...${NC}"
    brew install hey
    run_hey_test
fi

# Stop monitoring
rm ${OUTPUT_DIR}/test_running
wait $MONITOR_PID

# Collect final stats
docker stats ${CONTAINER_NAME} --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" > ${OUTPUT_DIR}/stats_final.txt

echo ""
echo -e "${GREEN}=========================================="
echo "Performance Test Complete!"
echo "==========================================${NC}"
echo ""

# Analyze results
echo -e "${BLUE}Analyzing results...${NC}"
echo ""

# Parse load test results
if [ -f ${OUTPUT_DIR}/hey_results.txt ]; then
    echo -e "${BLUE}Load Test Results (hey):${NC}"
    grep -E "Requests/sec|Average|Fastest|Slowest|Status code" ${OUTPUT_DIR}/hey_results.txt | head -10
    
    RPS=$(grep "Requests/sec" ${OUTPUT_DIR}/hey_results.txt | awk '{print $2}')
    AVG_LATENCY=$(grep "Average:" ${OUTPUT_DIR}/hey_results.txt | awk '{print $2}')
    P95_LATENCY=$(grep "95%" ${OUTPUT_DIR}/hey_results.txt | awk '{print $2}')
    P99_LATENCY=$(grep "99%" ${OUTPUT_DIR}/hey_results.txt | awk '{print $2}')
    SUCCESS_RATE=$(grep "200" ${OUTPUT_DIR}/hey_results.txt | awk '{print $3}')
elif [ -f ${OUTPUT_DIR}/wrk_results.txt ]; then
    echo -e "${BLUE}Load Test Results (wrk):${NC}"
    grep -E "Latency|Req/Sec|requests in" ${OUTPUT_DIR}/wrk_results.txt
    
    RPS=$(grep "Requests/sec:" ${OUTPUT_DIR}/wrk_results.txt | awk '{print $2}')
    AVG_LATENCY=$(grep "Latency" ${OUTPUT_DIR}/wrk_results.txt | awk '{print $2}')
fi

echo ""
echo -e "${BLUE}Resource Usage During Test:${NC}"

# Calculate average stats
if [ -f ${OUTPUT_DIR}/stats_continuous.csv ]; then
    STATS=$(calculate_stats ${OUTPUT_DIR}/stats_continuous.csv)
    eval $STATS
    
    echo "  Average CPU: ${avg_cpu}%"
    echo "  Average Memory Used: ${avg_mem_used} MiB"
    echo "  Average Memory %: ${avg_mem_percent}%"
    
    # Find peak usage
    MAX_CPU=$(awk -F',' '{gsub(/%/, "", $1); if($1>max) max=$1} END {print max}' ${OUTPUT_DIR}/stats_continuous.csv)
    MAX_MEM_PERCENT=$(awk -F',' '{gsub(/%/, "", $3); if($3>max) max=$3} END {print max}' ${OUTPUT_DIR}/stats_continuous.csv)
    
    echo "  Peak CPU: ${MAX_CPU}%"
    echo "  Peak Memory %: ${MAX_MEM_PERCENT}%"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Production Recommendations"
echo "==========================================${NC}"
echo ""

# Calculate recommendations
if [ ! -z "$avg_cpu" ] && [ ! -z "$RPS" ]; then
    # CPU recommendations
    CPU_USAGE_PERCENT=$(printf "%.0f" $avg_cpu)
    PEAK_CPU_PERCENT=$(printf "%.0f" $MAX_CPU)
    
    if [ $PEAK_CPU_PERCENT -gt 80 ]; then
        CPU_STATUS="${RED}⚠️  HIGH${NC}"
        RECOMMENDED_CPU_INCREASE="2x"
    elif [ $PEAK_CPU_PERCENT -gt 60 ]; then
        CPU_STATUS="${YELLOW}⚠️  MODERATE${NC}"
        RECOMMENDED_CPU_INCREASE="1.5x"
    else
        CPU_STATUS="${GREEN}✓ GOOD${NC}"
        RECOMMENDED_CPU_INCREASE="1x (current is sufficient)"
    fi
    
    # Memory recommendations
    MEM_USAGE_PERCENT=$(printf "%.0f" $avg_mem_percent)
    PEAK_MEM_PERCENT=$(printf "%.0f" $MAX_MEM_PERCENT)
    
    if [ $PEAK_MEM_PERCENT -gt 80 ]; then
        MEM_STATUS="${RED}⚠️  HIGH${NC}"
        RECOMMENDED_MEM_INCREASE="2x"
    elif [ $PEAK_MEM_PERCENT -gt 60 ]; then
        MEM_STATUS="${YELLOW}⚠️  MODERATE${NC}"
        RECOMMENDED_MEM_INCREASE="1.5x"
    else
        MEM_STATUS="${GREEN}✓ GOOD${NC}"
        RECOMMENDED_MEM_INCREASE="1x (current is sufficient)"
    fi
    
    echo -e "${BLUE}Current Performance:${NC}"
    echo "  Throughput: ${RPS} requests/second"
    echo "  CPU Usage: ${CPU_USAGE_PERCENT}% (Peak: ${PEAK_CPU_PERCENT}%) - ${CPU_STATUS}"
    echo "  Memory Usage: ${MEM_USAGE_PERCENT}% (Peak: ${PEAK_MEM_PERCENT}%) - ${MEM_STATUS}"
    echo ""
    
    echo -e "${BLUE}For Production (with safety margins):${NC}"
    echo ""
    
    # Calculate recommended resources
    if [ "$CPU_LIMIT_CORES" != "unlimited" ]; then
        RECOMMENDED_CPU=$(echo "scale=1; $CPU_LIMIT_CORES * ${RECOMMENDED_CPU_INCREASE%x}" | bc)
        echo -e "  ${GREEN}CPU:${NC}"
        echo "    Current: ${CPU_LIMIT_CORES} cores"
        echo "    Recommended: ${RECOMMENDED_CPU} cores (${RECOMMENDED_CPU_INCREASE})"
    else
        # Estimate based on peak usage
        ESTIMATED_CORES=$(echo "scale=1; $PEAK_CPU_PERCENT / 100 * 2" | bc)  # Assume 2 cores baseline
        RECOMMENDED_CPU=$(echo "scale=1; $ESTIMATED_CORES * 1.5" | bc)  # Add 50% buffer
        echo -e "  ${GREEN}CPU:${NC}"
        echo "    Current: Unlimited (Peak usage suggests ~${ESTIMATED_CORES} cores)"
        echo "    Recommended: ${RECOMMENDED_CPU} cores with 50% buffer"
    fi
    
    if [ "$MEM_LIMIT_MB" != "unlimited" ]; then
        RECOMMENDED_MEM=$(echo "scale=0; $MEM_LIMIT_MB * ${RECOMMENDED_MEM_INCREASE%x}" | bc)
        echo -e "  ${GREEN}Memory:${NC}"
        echo "    Current: ${MEM_LIMIT_MB} MB"
        echo "    Recommended: ${RECOMMENDED_MEM} MB (${RECOMMENDED_MEM_INCREASE})"
    else
        # Estimate based on peak usage
        ESTIMATED_MEM=$(printf "%.0f" $avg_mem_used)
        RECOMMENDED_MEM=$(echo "scale=0; $ESTIMATED_MEM * 2" | bc)  # Add 100% buffer
        echo -e "  ${GREEN}Memory:${NC}"
        echo "    Current: Unlimited (Average usage: ${ESTIMATED_MEM} MB)"
        echo "    Recommended: ${RECOMMENDED_MEM} MB with 100% buffer"
    fi
    
    echo ""
    echo -e "${BLUE}Scaling Recommendations:${NC}"
    echo ""
    
    # Calculate how many instances needed for different loads
    CURRENT_RPS=$(printf "%.0f" $RPS)
    
    echo "  To handle different load levels:"
    echo ""
    for TARGET_RPS in 100 500 1000 5000 10000; do
        INSTANCES=$(echo "scale=0; ($TARGET_RPS / $CURRENT_RPS) + 0.5" | bc)
        if [ $INSTANCES -lt 1 ]; then
            INSTANCES=1
        fi
        INSTANCES=$(printf "%.0f" $INSTANCES)
        
        # Add 50% buffer for redundancy
        RECOMMENDED_INSTANCES=$(echo "scale=0; $INSTANCES * 1.5 + 0.5" | bc)
        RECOMMENDED_INSTANCES=$(printf "%.0f" $RECOMMENDED_INSTANCES)
        
        if [ $RECOMMENDED_INSTANCES -lt 2 ]; then
            RECOMMENDED_INSTANCES=2  # Minimum 2 for HA
        fi
        
        echo "    ${TARGET_RPS} req/s → ${RECOMMENDED_INSTANCES} instances (min 2 for HA)"
    done
    
    echo ""
    echo -e "${BLUE}Docker Compose Configuration:${NC}"
    echo ""
    echo "  Add to docker-compose.yml for paymentconsumer service:"
    echo ""
    echo "    deploy:"
    echo "      resources:"
    echo "        limits:"
    echo "          cpus: '${RECOMMENDED_CPU}'"
    echo "          memory: ${RECOMMENDED_MEM}M"
    echo "        reservations:"
    echo "          cpus: '$(echo "scale=1; $RECOMMENDED_CPU * 0.5" | bc)'"
    echo "          memory: $(echo "scale=0; $RECOMMENDED_MEM * 0.5" | bc)M"
    echo ""
    
    echo -e "${BLUE}Kubernetes Configuration:${NC}"
    echo ""
    echo "  resources:"
    echo "    requests:"
    echo "      cpu: \"$(echo "scale=0; $RECOMMENDED_CPU * 1000 * 0.5" | bc)m\""
    echo "      memory: \"$(echo "scale=0; $RECOMMENDED_MEM * 0.5" | bc)Mi\""
    echo "    limits:"
    echo "      cpu: \"$(echo "scale=0; $RECOMMENDED_CPU * 1000" | bc)m\""
    echo "      memory: \"${RECOMMENDED_MEM}Mi\""
    echo ""
    echo "  autoscaling:"
    echo "    minReplicas: 2"
    echo "    maxReplicas: 10"
    echo "    targetCPUUtilizationPercentage: 70"
    echo "    targetMemoryUtilizationPercentage: 70"
    echo ""
fi

echo -e "${BLUE}Detailed results saved to: ${OUTPUT_DIR}${NC}"
echo ""
echo -e "${GREEN}✓ Analysis complete!${NC}"
