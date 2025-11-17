#!/bin/bash

# Quick Performance Test - finds the correct container name automatically

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Finding paymentConsumer container...${NC}"

# Find the container
CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep -i payment | grep -i consumer | head -1)

if [ -z "$CONTAINER_NAME" ]; then
    echo -e "${RED}Error: No running paymentConsumer container found${NC}"
    echo ""
    echo "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 1
fi

echo -e "${GREEN}Found container: ${CONTAINER_NAME}${NC}"
echo ""

# Find the port
PORT=$(docker port ${CONTAINER_NAME} 2>/dev/null | grep 8082 | cut -d':' -f2 | head -1)
if [ -z "$PORT" ]; then
    PORT="8785"  # fallback
fi

echo -e "${BLUE}Running performance analysis...${NC}"
echo "  Container: ${CONTAINER_NAME}"
echo "  Port: ${PORT}"
echo ""

# Update the performance-analysis.sh to use the correct container
sed -i.bak "s/CONTAINER_NAME=\"paymentconsumer\"/CONTAINER_NAME=\"${CONTAINER_NAME}\"/" performance-analysis.sh
sed -i.bak "s|SERVICE_URL=\"http://localhost:8785/api/v1/consumer/payments\"|SERVICE_URL=\"http://localhost:${PORT}/api/v1/consumer/payments\"|" performance-analysis.sh

# Run the analysis
./performance-analysis.sh "$@"

# Restore original
mv performance-analysis.sh.bak performance-analysis.sh
