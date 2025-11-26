#!/bin/bash
# Script to generate Score specification from Java project configuration
# Analyzes pom.xml/build.gradle and application properties/yaml files
# Usage: ./generate-score-from-project.sh <project-path> [output-score-file] [image-path] [init-script-path]

set -e

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${2:-score.yaml}"
IMAGE_PATH="${3:-}"
INIT_SCRIPT_PATH="${4:-}"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Error: Project path '$PROJECT_PATH' not found"
    exit 1
fi

echo "Analyzing project at: $PROJECT_PATH"
echo "Output Score file: $OUTPUT_FILE"

# Detect project type
BUILD_SYSTEM=""
if [ -f "$PROJECT_PATH/pom.xml" ]; then
    BUILD_SYSTEM="maven"
    BUILD_FILE="$PROJECT_PATH/pom.xml"
elif [ -f "$PROJECT_PATH/build.gradle" ] || [ -f "$PROJECT_PATH/build.gradle.kts" ]; then
    BUILD_SYSTEM="gradle"
    BUILD_FILE="$PROJECT_PATH/build.gradle"
    [ -f "$PROJECT_PATH/build.gradle.kts" ] && BUILD_FILE="$PROJECT_PATH/build.gradle.kts"
else
    echo "❌ Error: No pom.xml or build.gradle found in $PROJECT_PATH"
    exit 1
fi

echo "Detected build system: $BUILD_SYSTEM"

# Find property files
PROPERTY_FILES=$(find "$PROJECT_PATH/src/main/resources" -name "application*.properties" -o -name "application*.yml" -o -name "application*.yaml" 2>/dev/null || true)

if [ -z "$PROPERTY_FILES" ]; then
    echo "⚠️  Warning: No application property files found"
fi

# Initialize variables
SERVICE_NAME=""
SERVER_PORT=""
DATASOURCE_URL=""
DATASOURCE_USERNAME=""
DATASOURCE_PASSWORD=""
REDIS_HOST=""
REDIS_PORT=""
REDIS_PASSWORD=""
DB_TYPE=""
DB_NAME=""
HAS_POSTGRES=false
HAS_REDIS=false
HAS_MONGODB=false
HAS_MYSQL=false
SPRING_PROFILES=""

# Parse dependencies to detect technologies
echo "Analyzing dependencies..."

if [ "$BUILD_SYSTEM" = "maven" ]; then
    # Check for PostgreSQL
    if grep -q "postgresql" "$BUILD_FILE"; then
        HAS_POSTGRES=true
        echo "  ✓ Found PostgreSQL dependency"
    fi
    
    # Check for Redis
    if grep -q "spring-boot-starter-data-redis\|lettuce-core\|jedis" "$BUILD_FILE"; then
        HAS_REDIS=true
        echo "  ✓ Found Redis dependency"
    fi
    
    # Check for MongoDB
    if grep -q "spring-boot-starter-data-mongodb\|mongodb-driver" "$BUILD_FILE"; then
        HAS_MONGODB=true
        echo "  ✓ Found MongoDB dependency"
    fi
    
    # Check for MySQL
    if grep -q "mysql-connector" "$BUILD_FILE"; then
        HAS_MYSQL=true
        echo "  ✓ Found MySQL dependency"
    fi
    
    # Get artifact ID as service name (extract the project's artifactId, not parent's)
    SERVICE_NAME=$(awk '/<parent>/,/<\/parent>/{next} /<artifactId>/{gsub(/.*<artifactId>|<\/artifactId>.*/,""); print; exit}' "$BUILD_FILE")
    
elif [ "$BUILD_SYSTEM" = "gradle" ]; then
    # Check for PostgreSQL
    if grep -q "postgresql" "$BUILD_FILE"; then
        HAS_POSTGRES=true
        echo "  ✓ Found PostgreSQL dependency"
    fi
    
    # Check for Redis
    if grep -q "spring-boot-starter-data-redis\|lettuce-core\|jedis" "$BUILD_FILE"; then
        HAS_REDIS=true
        echo "  ✓ Found Redis dependency"
    fi
    
    # Check for MongoDB
    if grep -q "spring-boot-starter-data-mongodb\|mongodb-driver" "$BUILD_FILE"; then
        HAS_MONGODB=true
        echo "  ✓ Found MongoDB dependency"
    fi
    
    # Check for MySQL
    if grep -q "mysql-connector" "$BUILD_FILE"; then
        HAS_MYSQL=true
        echo "  ✓ Found MySQL dependency"
    fi
fi

# Parse property files
echo "Analyzing property files..."

for prop_file in $PROPERTY_FILES; do
    echo "  Processing: $prop_file"
    
    if [[ "$prop_file" == *.properties ]]; then
        # Parse .properties format
        [ -z "$SERVICE_NAME" ] && SERVICE_NAME=$(grep "^spring.application.name=" "$prop_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r')
        [ -z "$SERVER_PORT" ] && SERVER_PORT=$(grep "^server.port=" "$prop_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r')
        [ -z "$DATASOURCE_URL" ] && DATASOURCE_URL=$(grep "^spring.datasource.url=" "$prop_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r')
        [ -z "$DATASOURCE_USERNAME" ] && DATASOURCE_USERNAME=$(grep "^spring.datasource.username=" "$prop_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r')
        [ -z "$DATASOURCE_PASSWORD" ] && DATASOURCE_PASSWORD=$(grep "^spring.datasource.password=" "$prop_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r')
        [ -z "$REDIS_HOST" ] && REDIS_HOST=$(grep "^spring.redis.host=" "$prop_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r')
        [ -z "$REDIS_PORT" ] && REDIS_PORT=$(grep "^spring.redis.port=" "$prop_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r')
        [ -z "$REDIS_PASSWORD" ] && REDIS_PASSWORD=$(grep "^spring.redis.password=" "$prop_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r')
        
    elif [[ "$prop_file" == *.yml ]] || [[ "$prop_file" == *.yaml ]]; then
        # Parse YAML format (basic parsing - works for most common cases)
        if command -v yq &> /dev/null; then
            [ -z "$SERVICE_NAME" ] && SERVICE_NAME=$(yq eval '.spring.application.name' "$prop_file" 2>/dev/null | grep -v "^null$" || true)
            [ -z "$SERVER_PORT" ] && SERVER_PORT=$(yq eval '.server.port' "$prop_file" 2>/dev/null | grep -v "^null$" || true)
            [ -z "$DATASOURCE_URL" ] && DATASOURCE_URL=$(yq eval '.spring.datasource.url' "$prop_file" 2>/dev/null | grep -v "^null$" || true)
            [ -z "$DATASOURCE_USERNAME" ] && DATASOURCE_USERNAME=$(yq eval '.spring.datasource.username' "$prop_file" 2>/dev/null | grep -v "^null$" || true)
            [ -z "$DATASOURCE_PASSWORD" ] && DATASOURCE_PASSWORD=$(yq eval '.spring.datasource.password' "$prop_file" 2>/dev/null | grep -v "^null$" || true)
            [ -z "$REDIS_HOST" ] && REDIS_HOST=$(yq eval '.spring.redis.host // .spring.data.redis.host' "$prop_file" 2>/dev/null | grep -v "^null$" || true)
            [ -z "$REDIS_PORT" ] && REDIS_PORT=$(yq eval '.spring.redis.port // .spring.data.redis.port' "$prop_file" 2>/dev/null | grep -v "^null$" || true)
            [ -z "$REDIS_PASSWORD" ] && REDIS_PASSWORD=$(yq eval '.spring.redis.password // .spring.data.redis.password' "$prop_file" 2>/dev/null | grep -v "^null$" || true)
        else
            # Fallback to grep-based parsing
            [ -z "$SERVICE_NAME" ] && SERVICE_NAME=$(grep -A1 "application:" "$prop_file" 2>/dev/null | grep "name:" | sed 's/.*name:[[:space:]]*//' | tr -d '\r')
            [ -z "$SERVER_PORT" ] && SERVER_PORT=$(grep -A1 "server:" "$prop_file" 2>/dev/null | grep "port:" | sed 's/.*port:[[:space:]]*//' | tr -d '\r')
            [ -z "$DATASOURCE_URL" ] && DATASOURCE_URL=$(grep -A3 "datasource:" "$prop_file" 2>/dev/null | grep "url:" | sed 's/.*url:[[:space:]]*//' | tr -d '\r')
            [ -z "$DATASOURCE_USERNAME" ] && DATASOURCE_USERNAME=$(grep -A3 "datasource:" "$prop_file" 2>/dev/null | grep "username:" | sed 's/.*username:[[:space:]]*//' | tr -d '\r')
            [ -z "$REDIS_HOST" ] && REDIS_HOST=$(grep -A2 "redis:" "$prop_file" 2>/dev/null | grep "host:" | sed 's/.*host:[[:space:]]*//' | tr -d '\r')
            [ -z "$REDIS_PORT" ] && REDIS_PORT=$(grep -A2 "redis:" "$prop_file" 2>/dev/null | grep "port:" | sed 's/.*port:[[:space:]]*//' | tr -d '\r')
        fi
    fi
done

# Extract default values from Spring Boot property syntax ${VAR:default}
extract_default_value() {
    local value="$1"
    # Check if value contains Spring Boot property placeholder with default
    if [[ "$value" =~ \$\{[^:}]+:([^}]+)\} ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$value"
    fi
}

# Apply default value extraction to all parsed values
[ -n "$SERVER_PORT" ] && SERVER_PORT=$(extract_default_value "$SERVER_PORT")
[ -n "$DATASOURCE_URL" ] && DATASOURCE_URL=$(extract_default_value "$DATASOURCE_URL")
[ -n "$DATASOURCE_USERNAME" ] && DATASOURCE_USERNAME=$(extract_default_value "$DATASOURCE_USERNAME")
[ -n "$DATASOURCE_PASSWORD" ] && DATASOURCE_PASSWORD=$(extract_default_value "$DATASOURCE_PASSWORD")
[ -n "$REDIS_HOST" ] && REDIS_HOST=$(extract_default_value "$REDIS_HOST")
[ -n "$REDIS_PORT" ] && REDIS_PORT=$(extract_default_value "$REDIS_PORT")
[ -n "$REDIS_PASSWORD" ] && REDIS_PASSWORD=$(extract_default_value "$REDIS_PASSWORD")

# Extract external service URLs from property files
EXTERNAL_SERVICES=()
for prop_file in $PROPERTY_FILES; do
    if command -v yq &> /dev/null && [[ "$prop_file" == *.yml || "$prop_file" == *.yaml ]]; then
        # Extract all external.services entries
        services=$(yq eval '.external.services | keys | .[]' "$prop_file" 2>/dev/null || true)
        if [ -n "$services" ]; then
            while IFS= read -r service; do
                if [ -n "$service" ] && [ "$service" != "null" ]; then
                    url=$(yq eval ".external.services.$service.url" "$prop_file" 2>/dev/null | grep -v "^null$" || true)
                    base_path=$(yq eval ".external.services.$service.base-path" "$prop_file" 2>/dev/null | grep -v "^null$" || true)
                    if [ -n "$url" ]; then
                        url=$(extract_default_value "$url")
                        env_var_name=$(echo "$service" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
                        EXTERNAL_SERVICES+=("$service|$env_var_name|$url|$base_path")
                        echo "  ✓ Found external service: $service"
                    fi
                fi
            done <<< "$services"
        fi
    fi
done

# Extract database name from JDBC URL if present
if [ -n "$DATASOURCE_URL" ]; then
    if [[ "$DATASOURCE_URL" == *"postgresql"* ]]; then
        HAS_POSTGRES=true
        DB_TYPE="postgres"
        DB_NAME=$(echo "$DATASOURCE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
    elif [[ "$DATASOURCE_URL" == *"mysql"* ]]; then
        HAS_MYSQL=true
        DB_TYPE="mysql"
        DB_NAME=$(echo "$DATASOURCE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
    fi
    echo "  ✓ Detected database: $DB_TYPE, database name: $DB_NAME"
fi

# Set defaults
[ -z "$SERVICE_NAME" ] && SERVICE_NAME=$(basename "$PROJECT_PATH")
[ -z "$SERVER_PORT" ] && SERVER_PORT="8080"
[ -z "$DATASOURCE_USERNAME" ] && DATASOURCE_USERNAME="postgres"
[ -z "$DATASOURCE_PASSWORD" ] && DATASOURCE_PASSWORD="postgres"
[ -z "$REDIS_PORT" ] && REDIS_PORT="6379"
[ -z "$REDIS_PASSWORD" ] && REDIS_PASSWORD='""'
[ -z "$DB_NAME" ] && DB_NAME="$SERVICE_NAME"

echo ""
echo "Configuration Summary:"
echo "  Service Name: $SERVICE_NAME"
echo "  Server Port: $SERVER_PORT"
if [ "$HAS_POSTGRES" = true ] || [ "$HAS_MYSQL" = true ]; then
    echo "  Database Type: $DB_TYPE"
    echo "  Database Name: $DB_NAME"
    echo "  Database User: $DATASOURCE_USERNAME"
fi
if [ "$HAS_REDIS" = true ]; then
    echo "  Redis: enabled"
    echo "  Redis Port: $REDIS_PORT"
fi
if [ ${#EXTERNAL_SERVICES[@]} -gt 0 ]; then
    echo "  External Services:"
    for service_info in "${EXTERNAL_SERVICES[@]}"; do
        IFS='|' read -r service_name env_var_name url base_path <<< "$service_info"
        echo "    - $service_name: $url"
    done
fi

# Generate Score file
echo ""
echo "Generating Score specification..."

# Normalize service name for Score (lowercase with hyphens)
SCORE_SERVICE_NAME=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

# Prompt for image path if not provided
if [ -z "$IMAGE_PATH" ]; then
    echo ""
    echo "Enter the container image path for $SERVICE_NAME"
    echo "Examples:"
    echo "  - ghcr.io/alokkulkarni/$SERVICE_NAME:latest"
    echo "  - docker.io/myorg/$SERVICE_NAME:v1.0.0"
    echo "  - myregistry.azurecr.io/$SERVICE_NAME:latest"
    read -p "Image path [ghcr.io/alokkulkarni/$SERVICE_NAME:latest]: " IMAGE_PATH
    IMAGE_PATH="${IMAGE_PATH:-ghcr.io/alokkulkarni/$SERVICE_NAME:latest}"
fi

echo "Using image: $IMAGE_PATH"

cat > "$OUTPUT_FILE" << EOF
apiVersion: score.dev/v1b1

metadata:
  name: $SCORE_SERVICE_NAME

containers:
  app:
    image: $IMAGE_PATH
    variables:
      SERVER_PORT: "$SERVER_PORT"
EOF

# Add database configuration if detected
if [ "$HAS_POSTGRES" = true ]; then
    cat >> "$OUTPUT_FILE" << EOF
      SPRING_DATASOURCE_URL: "jdbc:postgresql://\${resources.db.host}:\${resources.db.port}/\${resources.db.name}"
      SPRING_DATASOURCE_USERNAME: \${resources.db.username}
      SPRING_DATASOURCE_PASSWORD: \${resources.db.password}
EOF
elif [ "$HAS_MYSQL" = true ]; then
    cat >> "$OUTPUT_FILE" << EOF
      SPRING_DATASOURCE_URL: "jdbc:mysql://\${resources.db.host}:\${resources.db.port}/\${resources.db.name}"
      SPRING_DATASOURCE_USERNAME: \${resources.db.username}
      SPRING_DATASOURCE_PASSWORD: \${resources.db.password}
EOF
fi

# Add Redis configuration if detected
if [ "$HAS_REDIS" = true ]; then
    cat >> "$OUTPUT_FILE" << EOF
      SPRING_DATA_REDIS_HOST: \${resources.redis.host}
      SPRING_DATA_REDIS_PORT: \${resources.redis.port}
      REDIS_PASSWORD: \$\${resources.redis.password}
EOF
fi

# Add external service URLs if detected
if [ ${#EXTERNAL_SERVICES[@]} -gt 0 ]; then
    for service_info in "${EXTERNAL_SERVICES[@]}"; do
        IFS='|' read -r service_name env_var_name url base_path <<< "$service_info"
        cat >> "$OUTPUT_FILE" << EOF
      ${env_var_name}_SERVICE_URL: $url
EOF
    done
fi

# Add common Spring Boot properties
cat >> "$OUTPUT_FILE" << EOF
      HEALTH_DETAILS: always
      LOG_LEVEL_ROOT: INFO
      LOG_LEVEL_APP: INFO
      LOG_LEVEL_JDBC: INFO
      HIBERNATE_DDL_AUTO: update
      TIMEZONE: UTC

service:
  ports:
    app:
      port: $SERVER_PORT
      targetPort: $SERVER_PORT
      protocol: TCP

resources:
EOF

# Add database resource if detected
if [ "$HAS_POSTGRES" = true ]; then
    cat >> "$OUTPUT_FILE" << EOF
  db:
    type: postgres
    metadata:
      annotations:
        database: $DB_NAME
        username: $DATASOURCE_USERNAME
        password: $DATASOURCE_PASSWORD
EOF
    
    # Prompt for init script path
    echo ""
    echo "Database init script detection:"
    INIT_SCRIPT=""
    
    # Use provided parameter or auto-detect
    if [ -n "$INIT_SCRIPT_PATH" ]; then
        INIT_SCRIPT="$INIT_SCRIPT_PATH"
        echo "  Using provided: $INIT_SCRIPT"
    else
        # Auto-detect potential init scripts
        if [ -f "$PROJECT_PATH/init.sql" ]; then
            echo "  Found: $PROJECT_PATH/init.sql"
            DEFAULT_INIT="./$(basename $PROJECT_PATH)/init.sql"
        elif [ -f "$PROJECT_PATH/init.db" ]; then
            echo "  Found: $PROJECT_PATH/init.db"
            DEFAULT_INIT="./$(basename $PROJECT_PATH)/init.db"
        elif [ -f "$PROJECT_PATH/src/main/resources/schema.sql" ]; then
            echo "  Found: $PROJECT_PATH/src/main/resources/schema.sql"
            DEFAULT_INIT="./$(basename $PROJECT_PATH)/src/main/resources/schema.sql"
        else
            DEFAULT_INIT=""
        fi
        
        echo ""
        echo "Enter database init script path (can be local or git repo path):"
        echo "  Examples:"
        echo "    - Local: ./paymentprocessor/init.sql"
        echo "    - Git: https://raw.githubusercontent.com/user/repo/main/init.sql"
        echo "    - Leave empty if no init script needed"
        
        if [ -n "$DEFAULT_INIT" ]; then
            read -p "Init script path [$DEFAULT_INIT]: " INIT_SCRIPT
            INIT_SCRIPT="${INIT_SCRIPT:-$DEFAULT_INIT}"
        else
            read -p "Init script path [none]: " INIT_SCRIPT
        fi
    fi
    
    if [ -n "$INIT_SCRIPT" ]; then
        cat >> "$OUTPUT_FILE" << EOF
        init-script: $INIT_SCRIPT
EOF
    fi
    echo ""
elif [ "$HAS_MYSQL" = true ]; then
    cat >> "$OUTPUT_FILE" << EOF
  db:
    type: mysql
    metadata:
      annotations:
        database: $DB_NAME
        username: $DATASOURCE_USERNAME
        password: $DATASOURCE_PASSWORD
EOF
    
    # Prompt for init script path for MySQL too
    echo ""
    echo "Database init script detection:"
    INIT_SCRIPT=""
    
    # Use provided parameter or auto-detect
    if [ -n "$INIT_SCRIPT_PATH" ]; then
        INIT_SCRIPT="$INIT_SCRIPT_PATH"
        echo "  Using provided: $INIT_SCRIPT"
    else
        # Auto-detect potential init scripts
        if [ -f "$PROJECT_PATH/init.sql" ]; then
            echo "  Found: $PROJECT_PATH/init.sql"
            DEFAULT_INIT="./$(basename $PROJECT_PATH)/init.sql"
        elif [ -f "$PROJECT_PATH/init.db" ]; then
            echo "  Found: $PROJECT_PATH/init.db"
            DEFAULT_INIT="./$(basename $PROJECT_PATH)/init.db"
        elif [ -f "$PROJECT_PATH/src/main/resources/schema.sql" ]; then
            echo "  Found: $PROJECT_PATH/src/main/resources/schema.sql"
            DEFAULT_INIT="./$(basename $PROJECT_PATH)/src/main/resources/schema.sql"
        else
            DEFAULT_INIT=""
        fi
        
        echo ""
        echo "Enter database init script path (can be local or git repo path):"
        echo "  Examples:"
        echo "    - Local: ./service/init.sql"
        echo "    - Git: https://raw.githubusercontent.com/user/repo/main/init.sql"
        echo "    - Leave empty if no init script needed"
        
        if [ -n "$DEFAULT_INIT" ]; then
            read -p "Init script path [$DEFAULT_INIT]: " INIT_SCRIPT
            INIT_SCRIPT="${INIT_SCRIPT:-$DEFAULT_INIT}"
        else
            read -p "Init script path [none]: " INIT_SCRIPT
        fi
    fi
    
    if [ -n "$INIT_SCRIPT" ]; then
        cat >> "$OUTPUT_FILE" << EOF
        init-script: $INIT_SCRIPT
EOF
    fi
    echo ""
fi

# Add Redis resource if detected
if [ "$HAS_REDIS" = true ]; then
    cat >> "$OUTPUT_FILE" << EOF
  redis:
    type: redis
EOF
fi

echo "✓ Score specification generated: $OUTPUT_FILE"
echo ""
echo "Configuration extracted:"
echo "  - Service name: $SERVICE_NAME"
echo "  - Port: $SERVER_PORT"
[ "$HAS_POSTGRES" = true ] && echo "  - PostgreSQL database: $DB_NAME"
[ "$HAS_MYSQL" = true ] && echo "  - MySQL database: $DB_NAME"
[ "$HAS_REDIS" = true ] && echo "  - Redis cache"
echo ""
echo "Next steps:"
echo "  1. Review and customize $OUTPUT_FILE"
echo "  2. Update the image reference with your actual registry"
echo "  3. Generate docker-compose: ./generate-compose-with-network.sh $OUTPUT_FILE docker-compose.yml"
