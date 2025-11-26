#!/bin/bash
# Script to generate docker-compose from Score and add network configuration
# Usage: ./generate-compose-with-network.sh [score-file] [output-compose-file]
# Example: ./generate-compose-with-network.sh score-complete.yaml docker-compose-dev.yml

set -e

# Parse arguments with defaults
SCORE_FILE="${1:-score-complete.yaml}"
OUTPUT_FILE="${2:-docker-compose-dev.yml}"

# Validate score file exists
if [ ! -f "$SCORE_FILE" ]; then
    echo "❌ Error: Score file '$SCORE_FILE' not found"
    exit 1
fi

echo "Generating docker-compose from Score specification..."
echo "  Score file: $SCORE_FILE"
echo "  Output file: $OUTPUT_FILE"

# Clean state directory to avoid mixing workloads from different Score files
if [ -d ".score-compose" ]; then
    echo "Cleaning previous Score compose state..."
    rm -rf .score-compose
fi

# Initialize with custom provisioner if it exists
if [ -f "custom.provisioners.yaml" ]; then
    echo "Installing custom provisioners..."
    score-compose init --no-sample --provisioners custom.provisioners.yaml
fi

score-compose generate "$SCORE_FILE" -o "$OUTPUT_FILE"

echo "Post-processing $OUTPUT_FILE to add network configuration and ports..."

# Replace ${GITHUB_USER} placeholder with actual username as a safety fallback
if grep -q '${GITHUB_USER}' "$OUTPUT_FILE" 2>/dev/null; then
    echo "Replacing \${GITHUB_USER} placeholder with alokkulkarni..."
    sed -i '' 's/\${GITHUB_USER}/alokkulkarni/g' "$OUTPUT_FILE"
fi

# Use yq to modify the docker-compose file (install with: brew install yq)
if command -v yq &> /dev/null; then
    # Find all application services (exclude databases, redis, nginx, wait-for-resources)
    APP_SERVICES=$(yq eval '.services | to_entries | .[] | select(.key != "wait-for-resources" and .value.image != null and (.value.image | contains("postgres") | not) and (.value.image | contains("redis") | not) and (.value.image | contains("nginx") | not)) | .key' "$OUTPUT_FILE")
    
    # Find Redis service name dynamically (looks for service with redis label or redis in name)
    REDIS_SERVICE=$(yq eval '.services | to_entries | .[] | select(.key | test("redis")) | .key' "$OUTPUT_FILE" 2>/dev/null | head -1 || echo "")
    
    # Extract Redis password from redis config if service exists
    if [ -n "$REDIS_SERVICE" ]; then
        # Find the redis.conf file path from volume mount
        REDIS_CONFIG_PATH=$(yq eval ".services.$REDIS_SERVICE.volumes[] | select(. | type == \"!!map\") | select(.target == \"/usr/local/etc/redis/redis.conf\") | .source" "$OUTPUT_FILE" 2>/dev/null || echo "")
        
        if [ -n "$REDIS_CONFIG_PATH" ] && [ -f "$REDIS_CONFIG_PATH" ]; then
            REDIS_PASSWORD=$(grep "requirepass" "$REDIS_CONFIG_PATH" 2>/dev/null | awk '{print $2}' || echo "")
            
            # Update Redis password in all app services that have REDIS_PASSWORD env var
            while IFS= read -r service; do
                HAS_REDIS_VAR=$(yq eval ".services.$service.environment | has(\"REDIS_PASSWORD\")" "$OUTPUT_FILE" 2>/dev/null || echo "false")
                if [ "$HAS_REDIS_VAR" = "true" ]; then
                    yq eval ".services.$service.environment.REDIS_PASSWORD = \"$REDIS_PASSWORD\"" -i "$OUTPUT_FILE"
                fi
            done <<< "$APP_SERVICES"
        fi
        
        # Add healthcheck for Redis
        yq eval ".services.$REDIS_SERVICE.healthcheck.test = [\"CMD\", \"redis-cli\", \"ping\"]" -i "$OUTPUT_FILE"
        yq eval ".services.$REDIS_SERVICE.healthcheck.interval = \"10s\"" -i "$OUTPUT_FILE"
        yq eval ".services.$REDIS_SERVICE.healthcheck.timeout = \"5s\"" -i "$OUTPUT_FILE"
        yq eval ".services.$REDIS_SERVICE.healthcheck.retries = 5" -i "$OUTPUT_FILE"
        
        # Update wait-for-resources to wait for redis health if wait-for-resources exists
        if yq eval '.services.wait-for-resources' "$OUTPUT_FILE" &>/dev/null; then
            yq eval ".services.wait-for-resources.depends_on.$REDIS_SERVICE.condition = \"service_healthy\"" -i "$OUTPUT_FILE"
        fi
    fi
    
    # Add network to all services
    yq eval '.services.*.networks = ["app-network"]' -i "$OUTPUT_FILE"
    
    # Remove network_mode from services (conflicts with networks)
    yq eval 'del(.services.[].network_mode)' -i "$OUTPUT_FILE"
    
    # Add port mappings for application services dynamically
    while IFS= read -r service; do
        PORT=$(yq eval ".services.$service.environment.SERVER_PORT" "$OUTPUT_FILE" 2>/dev/null || echo "")
        if [ -n "$PORT" ] && [ "$PORT" != "null" ]; then
            yq eval ".services.$service.ports = [\"$PORT:$PORT\"]" -i "$OUTPUT_FILE"
        fi
    done <<< "$APP_SERVICES"
    
    # Add nginx port if it exists
    if yq eval '.services | has("payment-system-nginx")' "$OUTPUT_FILE" 2>/dev/null | grep -q "true"; then
        yq eval '.services.payment-system-nginx.ports = ["80:80"]' -i "$OUTPUT_FILE"
    fi
    
    # Add external network definition
    yq eval '.networks.app-network.external = true' -i "$OUTPUT_FILE"
    yq eval '.networks.app-network.name = "app-network"' -i "$OUTPUT_FILE"
    
    echo "✓ Network configuration, port mappings, Redis password, and health checks added successfully"
else
    echo "⚠️  yq not found. Installing via brew..."
    brew install yq
    
    # Retry after installation
    # Find all application services (exclude databases, redis, nginx, wait-for-resources)
    APP_SERVICES=$(yq eval '.services | to_entries | .[] | select(.key != "wait-for-resources" and .value.image != null and (.value.image | contains("postgres") | not) and (.value.image | contains("redis") | not) and (.value.image | contains("nginx") | not)) | .key' "$OUTPUT_FILE")
    
    REDIS_SERVICE=$(yq eval '.services | to_entries | .[] | select(.key | test("redis")) | .key' "$OUTPUT_FILE" 2>/dev/null | head -1 || echo "")
    
    if [ -n "$REDIS_SERVICE" ]; then
        REDIS_CONFIG_PATH=$(yq eval ".services.$REDIS_SERVICE.volumes[] | select(. | type == \"!!map\") | select(.target == \"/usr/local/etc/redis/redis.conf\") | .source" "$OUTPUT_FILE" 2>/dev/null || echo "")
        
        if [ -n "$REDIS_CONFIG_PATH" ] && [ -f "$REDIS_CONFIG_PATH" ]; then
            REDIS_PASSWORD=$(grep "requirepass" "$REDIS_CONFIG_PATH" 2>/dev/null | awk '{print $2}' || echo "")
            
            while IFS= read -r service; do
                HAS_REDIS_VAR=$(yq eval ".services.$service.environment | has(\"REDIS_PASSWORD\")" "$OUTPUT_FILE" 2>/dev/null || echo "false")
                if [ "$HAS_REDIS_VAR" = "true" ]; then
                    yq eval ".services.$service.environment.REDIS_PASSWORD = \"$REDIS_PASSWORD\"" -i "$OUTPUT_FILE"
                fi
            done <<< "$APP_SERVICES"
        fi
        
        yq eval ".services.$REDIS_SERVICE.healthcheck.test = [\"CMD\", \"redis-cli\", \"ping\"]" -i "$OUTPUT_FILE"
        yq eval ".services.$REDIS_SERVICE.healthcheck.interval = \"10s\"" -i "$OUTPUT_FILE"
        yq eval ".services.$REDIS_SERVICE.healthcheck.timeout = \"5s\"" -i "$OUTPUT_FILE"
        yq eval ".services.$REDIS_SERVICE.healthcheck.retries = 5" -i "$OUTPUT_FILE"
        
        if yq eval '.services.wait-for-resources' "$OUTPUT_FILE" &>/dev/null; then
            yq eval ".services.wait-for-resources.depends_on.$REDIS_SERVICE.condition = \"service_healthy\"" -i "$OUTPUT_FILE"
        fi
    fi
    
    yq eval '.services.*.networks = ["app-network"]' -i "$OUTPUT_FILE"
    yq eval 'del(.services.[].network_mode)' -i "$OUTPUT_FILE"
    
    while IFS= read -r service; do
        PORT=$(yq eval ".services.$service.environment.SERVER_PORT" "$OUTPUT_FILE" 2>/dev/null || echo "")
        if [ -n "$PORT" ] && [ "$PORT" != "null" ]; then
            yq eval ".services.$service.ports = [\"$PORT:$PORT\"]" -i "$OUTPUT_FILE"
        fi
    done <<< "$APP_SERVICES"
    
    if yq eval '.services | has("payment-system-nginx")' "$OUTPUT_FILE" 2>/dev/null | grep -q "true"; then
        yq eval '.services.payment-system-nginx.ports = ["80:80"]' -i "$OUTPUT_FILE"
    fi
    
    yq eval '.networks.app-network.external = true' -i "$OUTPUT_FILE"
    yq eval '.networks.app-network.name = "app-network"' -i "$OUTPUT_FILE"
    
    echo "✓ Network configuration, port mappings, Redis password, and health checks added successfully"
fi

echo ""
echo "Docker Compose file generated and configured:"
echo "  - Input: $SCORE_FILE"
echo "  - Output: $OUTPUT_FILE"
echo "  - Network: app-network (external)"
echo ""
echo "To start services:"
echo "  docker-compose -f $OUTPUT_FILE up"
