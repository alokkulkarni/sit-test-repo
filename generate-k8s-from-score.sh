#!/bin/bash
# Script to generate production-ready Kubernetes/OpenShift manifests from Score specifications
# Features: Non-root security contexts, resource limits, health checks, PVC management, cloud-optimized deployments
# Usage: ./generate-k8s-from-score.sh <score-file> [output-dir] [platform] [enable-db-init] [deployment-target] [cloud-providers]
# Platform: kubernetes (default) or openshift
# enable-db-init: yes to create ConfigMap and InitContainer for database init scripts, no (default) to skip
# deployment-target: local, cloud, or both (default: local)
# cloud-providers: aws, azure, gcp, or comma-separated list (e.g., aws,azure) - only used when target is cloud or both

set -e

SCORE_FILE="${1}"
OUTPUT_DIR="${2:-k8s-manifests}"
PLATFORM="${3:-kubernetes}"
ENABLE_DB_INIT="${4:-no}"
DEPLOYMENT_TARGET="${5:-local}"
CLOUD_PROVIDERS="${6:-}"

if [ -z "$SCORE_FILE" ]; then
    echo "❌ Error: Score file is required"
    echo "Usage: $0 <score-file> [output-dir] [platform] [enable-db-init] [deployment-target] [cloud-providers]"
    echo "Platform options: kubernetes, openshift"
    echo "enable-db-init: yes to create database init resources, no (default) to skip"
    echo "deployment-target: local (default), cloud, or both"
    echo "cloud-providers: aws, azure, gcp, or comma-separated (e.g., aws,azure) - required for cloud/both targets"
    echo ""
    echo "Examples:"
    echo "  Local deployment:  $0 score.yaml k8s-manifests kubernetes no local"
    echo "  AWS deployment:    $0 score.yaml k8s-manifests kubernetes no cloud aws"
    echo "  Multi-cloud:       $0 score.yaml k8s-manifests kubernetes no both aws,azure,gcp"
    exit 1
fi

if [ ! -f "$SCORE_FILE" ]; then
    echo "❌ Error: Score file '$SCORE_FILE' not found"
    exit 1
fi

if [ "$PLATFORM" != "kubernetes" ] && [ "$PLATFORM" != "openshift" ]; then
    echo "❌ Error: Platform must be 'kubernetes' or 'openshift'"
    exit 1
fi

# Validate deployment target
if [ "$DEPLOYMENT_TARGET" != "local" ] && [ "$DEPLOYMENT_TARGET" != "cloud" ] && [ "$DEPLOYMENT_TARGET" != "both" ]; then
    echo "❌ Error: Deployment target must be 'local', 'cloud', or 'both'"
    exit 1
fi

# Validate cloud providers if cloud deployment
if [ "$DEPLOYMENT_TARGET" = "cloud" ] || [ "$DEPLOYMENT_TARGET" = "both" ]; then
    if [ -z "$CLOUD_PROVIDERS" ]; then
        echo "❌ Error: Cloud providers must be specified for cloud/both deployment"
        echo "Valid options: aws, azure, gcp, or comma-separated (e.g., aws,azure)"
        exit 1
    fi
    
    # Parse and validate cloud providers
    IFS=',' read -ra CLOUD_ARRAY <<< "$CLOUD_PROVIDERS"
    for cloud in "${CLOUD_ARRAY[@]}"; do
        if [ "$cloud" != "aws" ] && [ "$cloud" != "azure" ] && [ "$cloud" != "gcp" ]; then
            echo "❌ Error: Invalid cloud provider '$cloud'. Must be aws, azure, or gcp"
            exit 1
        fi
    done
fi

# Check for required tools
if ! command -v yq &> /dev/null; then
    echo "❌ Error: yq is required but not installed"
    echo "Install with: brew install yq"
    exit 1
fi

# Extract workload name
WORKLOAD_NAME=$(yq eval '.metadata.name' "$SCORE_FILE")
NAMESPACE="${NAMESPACE:-default}"

# Function to generate manifests for a specific deployment target
generate_manifests() {
    local TARGET_TYPE=$1  # local, aws, azure, gcp
    local TARGET_DIR=$2
    local SKIP_INFRA=$3   # true for cloud, false for local
    
    echo ""
    echo "================================================================"
    echo "Generating manifests for: $TARGET_TYPE"
    echo "================================================================"
    
    # Create target output directory
    mkdir -p "$TARGET_DIR"
    
    # Set APP_OUTPUT_DIR for this target
    APP_OUTPUT_DIR="$TARGET_DIR"

echo "Generating $PLATFORM manifests from Score specification..."
echo "  Score file: $SCORE_FILE"
echo "  Workload: $WORKLOAD_NAME"
echo "  Output directory: $APP_OUTPUT_DIR"
echo "  Platform: $PLATFORM"

echo ""
echo "Workload: $WORKLOAD_NAME"
echo "Namespace: $NAMESPACE"

# Parse Score file to extract resources
echo ""
echo "Analyzing Score specification..."

# Extract container info
CONTAINER_NAME=$(yq eval '.containers | keys | .[0]' "$SCORE_FILE")
IMAGE=$(yq eval ".containers.$CONTAINER_NAME.image" "$SCORE_FILE")
# Replace ${GITHUB_USER} with alokkulkarni in image reference
IMAGE=$(echo "$IMAGE" | sed 's/${GITHUB_USER}/alokkulkarni/g')
SERVER_PORT=$(yq eval ".containers.$CONTAINER_NAME.variables.SERVER_PORT" "$SCORE_FILE" 2>/dev/null || echo "8080")

# Extract resources
RESOURCES=$(yq eval '.resources | keys' "$SCORE_FILE" 2>/dev/null || echo "[]")
HAS_DB=false
HAS_REDIS=false
DB_TYPE=""
DB_NAME=""

# Check for database
if echo "$RESOURCES" | grep -q "db"; then
    HAS_DB=true
    DB_TYPE=$(yq eval '.resources.db.type' "$SCORE_FILE")
    DB_NAME=$(yq eval '.resources.db.metadata.annotations.database' "$SCORE_FILE")
    echo "  ✓ Found $DB_TYPE database: $DB_NAME"
    
    # Check for init script if enabled
    if [ "$ENABLE_DB_INIT" = "yes" ]; then
        DB_INIT_SCRIPT=$(yq eval '.resources.db.metadata.annotations.init-script' "$SCORE_FILE" 2>/dev/null || echo "null")
        if [ "$DB_INIT_SCRIPT" != "null" ] && [ -n "$DB_INIT_SCRIPT" ]; then
            echo "  ✓ Found database init script: $DB_INIT_SCRIPT"
            HAS_DB_INIT=true
        else
            HAS_DB_INIT=false
        fi
    else
        HAS_DB_INIT=false
    fi
fi

# Check for Redis
if echo "$RESOURCES" | grep -q "redis"; then
    HAS_REDIS=true
    echo "  ✓ Found Redis cache"
fi

# Extract all environment variables
ENV_VARS=$(yq eval ".containers.$CONTAINER_NAME.variables | to_entries | .[] | .key" "$SCORE_FILE" 2>/dev/null || echo "")

echo ""
echo "Generating Kubernetes manifests..."

# ============================================================================
# Generate Namespace
# ============================================================================
if [ "$PLATFORM" = "openshift" ]; then
    # OpenShift uses Project instead of Namespace
    cat > "$APP_OUTPUT_DIR/00-namespace.yaml" << EOF
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: $NAMESPACE
  annotations:
    openshift.io/description: "$WORKLOAD_NAME application"
    openshift.io/display-name: "$WORKLOAD_NAME"
EOF
else
    cat > "$APP_OUTPUT_DIR/00-namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    name: $NAMESPACE
    app.kubernetes.io/part-of: $WORKLOAD_NAME
EOF
fi

echo "  ✓ Generated: 00-namespace.yaml"

# ============================================================================
# Generate ConfigMap for non-sensitive configurations
# ============================================================================
cat > "$APP_OUTPUT_DIR/10-configmap.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $WORKLOAD_NAME-config
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: config
data:
EOF

# Add non-sensitive environment variables to ConfigMap
while IFS= read -r var; do
    value=$(yq eval ".containers.$CONTAINER_NAME.variables.$var" "$SCORE_FILE" 2>/dev/null)
    # Skip sensitive variables (passwords, secrets, URLs with credentials)
    if [[ ! "$var" =~ PASSWORD|SECRET|TOKEN|KEY ]] && [[ ! "$value" =~ \$\{resources\. ]]; then
        # Remove quotes if present
        value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
        echo "  $var: \"$value\"" >> "$APP_OUTPUT_DIR/10-configmap.yaml"
    fi
done <<< "$ENV_VARS"

echo "  ✓ Generated: 10-configmap.yaml"

# ============================================================================
# Generate Secret for sensitive data
# ============================================================================
cat > "$APP_OUTPUT_DIR/11-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: $WORKLOAD_NAME-secret
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: secret
type: Opaque
stringData:
EOF

# Add database credentials if database exists
if [ "$HAS_DB" = true ]; then
    DB_USER=$(yq eval '.resources.db.metadata.annotations.username' "$SCORE_FILE")
    DB_PASSWORD=$(yq eval '.resources.db.metadata.annotations.password' "$SCORE_FILE")
    cat >> "$APP_OUTPUT_DIR/11-secret.yaml" << EOF
  DB_USERNAME: "$DB_USER"
  DB_PASSWORD: "$DB_PASSWORD"
  DB_NAME: "$DB_NAME"
EOF
fi

# Add Redis password if Redis exists
if [ "$HAS_REDIS" = true ]; then
    # Generate a random Redis password
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    cat >> "$APP_OUTPUT_DIR/11-secret.yaml" << EOF
  REDIS_PASSWORD: "$REDIS_PASSWORD"
EOF
fi

echo "  ✓ Generated: 11-secret.yaml"

# ============================================================================
# Generate ConfigMap for Database Init Script (if enabled and exists)
# ============================================================================
if [ "$HAS_DB_INIT" = true ]; then
    # Resolve the init script path (handle relative paths from project root)
    if [[ "$DB_INIT_SCRIPT" == ./* ]]; then
        # Remove leading ./
        INIT_SCRIPT_PATH="${DB_INIT_SCRIPT#./}"
    else
        INIT_SCRIPT_PATH="$DB_INIT_SCRIPT"
    fi
    
    # Check if file exists
    if [ -f "$INIT_SCRIPT_PATH" ]; then
        cat > "$APP_OUTPUT_DIR/12-configmap-db-init.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $WORKLOAD_NAME-db-init
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: database
data:
  init.sql: |
EOF
        # Indent the SQL content with 4 spaces
        sed 's/^/    /' "$INIT_SCRIPT_PATH" >> "$APP_OUTPUT_DIR/12-configmap-db-init.yaml"
        
        echo "  ✓ Generated: 12-configmap-db-init.yaml"
    else
        echo "  ⚠️  Warning: Init script not found at $INIT_SCRIPT_PATH, skipping ConfigMap generation"
        HAS_DB_INIT=false
    fi
fi

# ============================================================================
# Generate PersistentVolumeClaim for Database (if exists)
# ============================================================================
# Skip infrastructure resources for cloud deployments
if [ "$SKIP_INFRA" = false ] && [ "$HAS_DB" = true ]; then
    cat > "$APP_OUTPUT_DIR/20-pvc-database.yaml" << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $WORKLOAD_NAME-db-pvc
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: database
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
EOF

    echo "  ✓ Generated: 20-pvc-database.yaml"
fi

# ============================================================================
# Generate PersistentVolumeClaim for Redis (if exists)
# ============================================================================
# Skip infrastructure resources for cloud deployments
if [ "$SKIP_INFRA" = false ] && [ "$HAS_REDIS" = true ]; then
    cat > "$APP_OUTPUT_DIR/21-pvc-redis.yaml" << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $WORKLOAD_NAME-redis-pvc
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: cache
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
EOF

    echo "  ✓ Generated: 21-pvc-redis.yaml"
fi

# ============================================================================
# Generate StatefulSet for Database (if exists)
# ============================================================================
# Skip infrastructure resources for cloud deployments
if [ "$SKIP_INFRA" = false ] && [ "$HAS_DB" = true ]; then
    # Check if custom provisioner is used OR if it's a standard postgres/mysql type
    if [[ "$DB_TYPE" == *"template://custom-provisioners/"* ]]; then
        # Extract the provisioner name (e.g., "postgres" from "template://custom-provisioners/postgres")
        PROVISIONER_NAME="${DB_TYPE##*/}"
        DB_TYPE="$PROVISIONER_NAME"
    fi
    
    # For postgres or mysql, try to read image from custom provisioner file
    if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "mysql" ]; then
        if [ -f "custom.provisioners.yaml" ]; then
            # Try to read image from custom provisioner
            DB_IMAGE=$(yq eval ".[] | select(.type == \"$DB_TYPE\") | .services | to_entries | .[0].value.image" custom.provisioners.yaml 2>/dev/null || echo "")
        fi
    fi
    
    # Set database-specific configurations with defaults
    if [ "$DB_TYPE" = "postgres" ]; then
        [ -z "$DB_IMAGE" ] && DB_IMAGE="postgres:16-alpine"
        DB_PORT="5432"
        DB_HEALTH_CMD="pg_isready -U \$DB_USERNAME -d \$DB_NAME"
    elif [ "$DB_TYPE" = "mysql" ]; then
        [ -z "$DB_IMAGE" ] && DB_IMAGE="mysql:8.0"
        DB_PORT="3306"
        DB_HEALTH_CMD="mysqladmin ping -h localhost -u \$DB_USERNAME -p\$DB_PASSWORD"
    else
        [ -z "$DB_IMAGE" ] && DB_IMAGE="$DB_TYPE:latest"
        DB_PORT="5432"
        DB_HEALTH_CMD="echo 'Database health check not configured'"
    fi

    cat > "$APP_OUTPUT_DIR/30-statefulset-database.yaml" << EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $WORKLOAD_NAME-db
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: database
spec:
  serviceName: $WORKLOAD_NAME-db
  replicas: 1
  selector:
    matchLabels:
      app: $WORKLOAD_NAME
      component: database
  template:
    metadata:
      labels:
        app: $WORKLOAD_NAME
        component: database
        app.kubernetes.io/name: $WORKLOAD_NAME
        app.kubernetes.io/component: database
    spec:
      securityContext:
        fsGroup: 999
        runAsUser: 999
        seccompProfile:
          type: RuntimeDefault
EOF

    # Add InitContainer if init script exists
    if [ "$HAS_DB_INIT" = true ]; then
        cat >> "$APP_OUTPUT_DIR/30-statefulset-database.yaml" << EOF
      initContainers:
      - name: init-db-schema
        image: $DB_IMAGE
        imagePullPolicy: IfNotPresent
        command:
        - /bin/sh
        - -c
        - |
          echo "Waiting for database to be ready..."
          until pg_isready -U \$POSTGRES_USER -d \$POSTGRES_DB; do
            echo "Database not ready, waiting..."
            sleep 2
          done
          echo "Database ready, running init script..."
          psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /docker-entrypoint-initdb.d/init.sql
          echo "Init script completed successfully"
        env:
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_NAME
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_USERNAME
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_PASSWORD
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_PASSWORD
        volumeMounts:
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
          readOnly: true
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false
EOF
    fi

    cat >> "$APP_OUTPUT_DIR/30-statefulset-database.yaml" << EOF
      containers:
      - name: database
        image: $DB_IMAGE
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: $DB_PORT
          name: db
          protocol: TCP
        env:
EOF

    if [ "$DB_TYPE" = "postgres" ]; then
        cat >> "$APP_OUTPUT_DIR/30-statefulset-database.yaml" << EOF
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_NAME
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_USERNAME
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_PASSWORD
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
EOF
    elif [ "$DB_TYPE" = "mysql" ]; then
        cat >> "$APP_OUTPUT_DIR/30-statefulset-database.yaml" << EOF
        - name: MYSQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_NAME
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_USERNAME
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_PASSWORD
        - name: MYSQL_RANDOM_ROOT_PASSWORD
          value: "yes"
EOF
    fi

    cat >> "$APP_OUTPUT_DIR/30-statefulset-database.yaml" << EOF
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - $DB_HEALTH_CMD
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - $DB_HEALTH_CMD
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: $WORKLOAD_NAME-db-pvc
EOF

    # Add init script volume if exists
    if [ "$HAS_DB_INIT" = true ]; then
        cat >> "$APP_OUTPUT_DIR/30-statefulset-database.yaml" << EOF
      - name: init-script
        configMap:
          name: $WORKLOAD_NAME-db-init
EOF
    fi

    echo "  ✓ Generated: 30-statefulset-database.yaml"

    # Generate Database Service
    cat > "$APP_OUTPUT_DIR/31-service-database.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $WORKLOAD_NAME-db
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: database
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - port: $DB_PORT
    targetPort: $DB_PORT
    protocol: TCP
    name: db
  selector:
    app: $WORKLOAD_NAME
    component: database
EOF

    echo "  ✓ Generated: 31-service-database.yaml"
fi

# ============================================================================
# Generate StatefulSet for Redis (if exists)
# ============================================================================
# Skip infrastructure resources for cloud deployments
if [ "$SKIP_INFRA" = false ] && [ "$HAS_REDIS" = true ]; then
    cat > "$APP_OUTPUT_DIR/32-statefulset-redis.yaml" << EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $WORKLOAD_NAME-redis
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: cache
spec:
  serviceName: $WORKLOAD_NAME-redis
  replicas: 1
  selector:
    matchLabels:
      app: $WORKLOAD_NAME
      component: redis
  template:
    metadata:
      labels:
        app: $WORKLOAD_NAME
        component: redis
        app.kubernetes.io/name: $WORKLOAD_NAME
        app.kubernetes.io/component: cache
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        imagePullPolicy: IfNotPresent
        command:
        - redis-server
        - --requirepass
        - \$(REDIS_PASSWORD)
        - --appendonly
        - "no"
        ports:
        - containerPort: 6379
          name: redis
          protocol: TCP
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: REDIS_PASSWORD
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        volumeMounts:
        - name: data
          mountPath: /data
      securityContext:
        fsGroup: 999
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: $WORKLOAD_NAME-redis-pvc
EOF

    echo "  ✓ Generated: 32-statefulset-redis.yaml"

    # Generate Redis Service
    cat > "$APP_OUTPUT_DIR/33-service-redis.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $WORKLOAD_NAME-redis
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: cache
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  selector:
    app: $WORKLOAD_NAME
    component: redis
EOF

    echo "  ✓ Generated: 33-service-redis.yaml"
fi

# ============================================================================
# Generate Deployment for Application
# ============================================================================
cat > "$APP_OUTPUT_DIR/40-deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $WORKLOAD_NAME
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: application
    app.kubernetes.io/version: "1.0.0"
EOF

if [ "$PLATFORM" = "openshift" ]; then
    cat >> "$APP_OUTPUT_DIR/40-deployment.yaml" << EOF
  annotations:
    app.openshift.io/connects-to: '$WORKLOAD_NAME-db,$WORKLOAD_NAME-redis'
EOF
fi

cat >> "$APP_OUTPUT_DIR/40-deployment.yaml" << EOF
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: $WORKLOAD_NAME
      component: application
  template:
    metadata:
      labels:
        app: $WORKLOAD_NAME
        component: application
        app.kubernetes.io/name: $WORKLOAD_NAME
        app.kubernetes.io/component: application
        app.kubernetes.io/version: "1.0.0"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      serviceAccountName: default
      containers:
      - name: app
        image: $IMAGE
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: $SERVER_PORT
          name: http
          protocol: TCP
        env:
        - name: SERVER_PORT
          value: "$SERVER_PORT"
EOF

# Add database connection environment variables
if [ "$HAS_DB" = true ]; then
    if [ "$DB_TYPE" = "postgres" ]; then
        cat >> "$APP_OUTPUT_DIR/40-deployment.yaml" << EOF
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_NAME
        - name: SPRING_DATASOURCE_URL
          value: "jdbc:postgresql://$WORKLOAD_NAME-db:5432/\$(DB_NAME)"
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_USERNAME
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_PASSWORD
EOF
    elif [ "$DB_TYPE" = "mysql" ]; then
        cat >> "$APP_OUTPUT_DIR/40-deployment.yaml" << EOF
        - name: SPRING_DATASOURCE_URL
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_NAME
          value: "jdbc:mysql://$WORKLOAD_NAME-db:3306/\$(DB_NAME)"
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_USERNAME
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: DB_PASSWORD
EOF
    fi
fi

# Add Redis connection environment variables
if [ "$HAS_REDIS" = true ]; then
    cat >> "$APP_OUTPUT_DIR/40-deployment.yaml" << EOF
        - name: SPRING_DATA_REDIS_HOST
          value: "$WORKLOAD_NAME-redis"
        - name: SPRING_DATA_REDIS_PORT
          value: "6379"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $WORKLOAD_NAME-secret
              key: REDIS_PASSWORD
EOF
fi

# Add other environment variables from ConfigMap
cat >> "$APP_OUTPUT_DIR/40-deployment.yaml" << EOF
        envFrom:
        - configMapRef:
            name: $WORKLOAD_NAME-config
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: $SERVER_PORT
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: $SERVER_PORT
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /actuator/health/liveness
            port: $SERVER_PORT
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 30
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
EOF

echo "  ✓ Generated: 40-deployment.yaml"

# ============================================================================
# Generate Service for Application
# ============================================================================
cat > "$APP_OUTPUT_DIR/41-service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $WORKLOAD_NAME
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: application
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: $SERVER_PORT
    protocol: TCP
    name: http
  selector:
    app: $WORKLOAD_NAME
    component: application
EOF

echo "  ✓ Generated: 41-service.yaml"

# ============================================================================
# Generate Ingress/Route
# ============================================================================
if [ "$PLATFORM" = "openshift" ]; then
    # Generate OpenShift Route
    cat > "$APP_OUTPUT_DIR/50-route.yaml" << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: $WORKLOAD_NAME
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: application
spec:
  to:
    kind: Service
    name: $WORKLOAD_NAME
    weight: 100
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
EOF
    echo "  ✓ Generated: 50-route.yaml (OpenShift Route)"
else
    # Generate Kubernetes Ingress
    cat > "$APP_OUTPUT_DIR/50-ingress.yaml" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $WORKLOAD_NAME
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: application
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $WORKLOAD_NAME.example.com
    secretName: $WORKLOAD_NAME-tls
  rules:
  - host: $WORKLOAD_NAME.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $WORKLOAD_NAME
            port:
              number: 80
EOF
    echo "  ✓ Generated: 50-ingress.yaml (Kubernetes Ingress)"
fi

# ============================================================================
# Generate HorizontalPodAutoscaler
# ============================================================================
cat > "$APP_OUTPUT_DIR/60-hpa.yaml" << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: $WORKLOAD_NAME
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: application
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: $WORKLOAD_NAME
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 2
        periodSeconds: 30
      selectPolicy: Max
EOF

echo "  ✓ Generated: 60-hpa.yaml"

# ============================================================================
# Generate PodDisruptionBudget
# ============================================================================
cat > "$APP_OUTPUT_DIR/61-pdb.yaml" << EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: $WORKLOAD_NAME
  namespace: $NAMESPACE
  labels:
    app: $WORKLOAD_NAME
    app.kubernetes.io/name: $WORKLOAD_NAME
    app.kubernetes.io/component: application
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: $WORKLOAD_NAME
      component: application
EOF

echo "  ✓ Generated: 61-pdb.yaml"

# ============================================================================
# Generate NetworkPolicy
# ============================================================================
# NOTE: NetworkPolicy is commented out as it can block database connections
# Uncomment and customize if needed for your environment
# cat > "$APP_OUTPUT_DIR/70-networkpolicy.yaml" << EOF
# apiVersion: networking.k8s.io/v1
# kind: NetworkPolicy
# metadata:
#   name: $WORKLOAD_NAME
#   namespace: $NAMESPACE
#   labels:
#     app: $WORKLOAD_NAME
#     app.kubernetes.io/name: $WORKLOAD_NAME
# spec:
#   podSelector:
#     matchLabels:
#       app: $WORKLOAD_NAME
#   policyTypes:
#   - Ingress
#   - Egress
#   ingress:
#   - from:
#     - namespaceSelector: {}
#     ports:
#     - protocol: TCP
#       port: $SERVER_PORT
#   egress:
#   - to:
#     - podSelector:
#         matchLabels:
#           app: $WORKLOAD_NAME
#           component: database
#     ports:
#     - protocol: TCP
#       port: 5432
# EOF
# 
# if [ "$HAS_REDIS" = true ]; then
#     cat >> "$APP_OUTPUT_DIR/70-networkpolicy.yaml" << EOF
#   - to:
#     - podSelector:
#         matchLabels:
#           app: $WORKLOAD_NAME
#           component: redis
#     ports:
#     - protocol: TCP
#       port: 6379
# EOF
# fi
# 
# cat >> "$APP_OUTPUT_DIR/70-networkpolicy.yaml" << EOF
#   - to:
#     - namespaceSelector:
#         matchLabels:
#           name: kube-system
#     ports:
#     - protocol: UDP
#       port: 53
#   - to:
#     - namespaceSelector: {}
# EOF
# 
# echo "  ✓ Generated: 70-networkpolicy.yaml"

# ============================================================================
# Generate README with deployment instructions
# ============================================================================
cat > "$APP_OUTPUT_DIR/README.md" << EOF
# Kubernetes/OpenShift Manifests for $WORKLOAD_NAME

Generated from Score specification: \`$SCORE_FILE\`
Platform: **$PLATFORM**

## Prerequisites

- Kubernetes cluster (1.24+) or OpenShift cluster (4.10+)
- kubectl or oc CLI configured
- Storage class \`standard\` available for PVCs

## Files Generated

- \`00-namespace.yaml\` - Namespace/Project definition
- \`10-configmap.yaml\` - Application configuration
- \`11-secret.yaml\` - Sensitive data (passwords, tokens)
- \`20-pvc-database.yaml\` - Database persistent storage
- \`21-pvc-redis.yaml\` - Redis persistent storage (if applicable)
- \`30-statefulset-database.yaml\` - Database StatefulSet
- \`31-service-database.yaml\` - Database Service
- \`32-statefulset-redis.yaml\` - Redis StatefulSet (if applicable)
- \`33-service-redis.yaml\` - Redis Service (if applicable)
- \`40-deployment.yaml\` - Application Deployment
- \`41-service.yaml\` - Application Service
- \`50-ingress.yaml\` or \`50-route.yaml\` - External access
- \`60-hpa.yaml\` - Horizontal Pod Autoscaler
- \`61-pdb.yaml\` - Pod Disruption Budget
- \`70-networkpolicy.yaml\` - Network policies

## Security Features

✅ **Non-root containers**: All containers run as non-root users (UID 999/1000)
✅ **Read-only root filesystem**: Application containers use read-only root filesystem
✅ **Dropped capabilities**: All Linux capabilities dropped
✅ **SeccompProfile**: Runtime default seccomp profile applied
✅ **Resource limits**: CPU and memory limits defined
✅ **Network policies**: Egress and ingress traffic controlled
✅ **Secrets management**: Sensitive data stored in Kubernetes Secrets

## Deployment

### Quick Start

\`\`\`bash
# Deploy all manifests
kubectl apply -f $APP_OUTPUT_DIR/

# Or for OpenShift
oc apply -f $APP_OUTPUT_DIR/
\`\`\`

### Step-by-Step Deployment

\`\`\`bash
# 1. Create namespace
kubectl apply -f 00-namespace.yaml

# 2. Create configurations and secrets
kubectl apply -f 10-configmap.yaml
kubectl apply -f 11-secret.yaml

# 3. Create persistent volume claims
kubectl apply -f 20-pvc-database.yaml
EOF

if [ "$HAS_REDIS" = true ]; then
    cat >> "$APP_OUTPUT_DIR/README.md" << EOF
kubectl apply -f 21-pvc-redis.yaml
EOF
fi

cat >> "$APP_OUTPUT_DIR/README.md" << EOF

# 4. Deploy database
kubectl apply -f 30-statefulset-database.yaml
kubectl apply -f 31-service-database.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l component=database -n $NAMESPACE --timeout=300s
EOF

if [ "$HAS_REDIS" = true ]; then
    cat >> "$APP_OUTPUT_DIR/README.md" << EOF

# 5. Deploy Redis
kubectl apply -f 32-statefulset-redis.yaml
kubectl apply -f 33-service-redis.yaml

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l component=redis -n $NAMESPACE --timeout=300s
EOF
fi

cat >> "$APP_OUTPUT_DIR/README.md" << EOF

# 6. Deploy application
kubectl apply -f 40-deployment.yaml
kubectl apply -f 41-service.yaml

# Wait for application to be ready
kubectl wait --for=condition=available deployment/$WORKLOAD_NAME -n $NAMESPACE --timeout=300s

# 7. Create ingress/route
kubectl apply -f 50-*.yaml

# 8. Apply HPA and PDB
kubectl apply -f 60-hpa.yaml
kubectl apply -f 61-pdb.yaml

# 9. Apply network policies
kubectl apply -f 70-networkpolicy.yaml
\`\`\`

## Verification

\`\`\`bash
# Check all resources
kubectl get all -n $NAMESPACE

# Check pod status
kubectl get pods -n $NAMESPACE

# Check application logs
kubectl logs -f deployment/$WORKLOAD_NAME -n $NAMESPACE

# Check database logs
kubectl logs -f statefulset/$WORKLOAD_NAME-db -n $NAMESPACE
EOF

if [ "$HAS_REDIS" = true ]; then
    cat >> "$APP_OUTPUT_DIR/README.md" << EOF

# Check Redis logs
kubectl logs -f statefulset/$WORKLOAD_NAME-redis -n $NAMESPACE
EOF
fi

cat >> "$APP_OUTPUT_DIR/README.md" << EOF
\`\`\`

## Accessing the Application

### Port Forward (for testing)

\`\`\`bash
kubectl port-forward svc/$WORKLOAD_NAME $SERVER_PORT:80 -n $NAMESPACE
# Access at http://localhost:$SERVER_PORT
\`\`\`

### Via Ingress/Route

EOF

if [ "$PLATFORM" = "openshift" ]; then
    cat >> "$APP_OUTPUT_DIR/README.md" << EOF
\`\`\`bash
# Get the route URL
oc get route $WORKLOAD_NAME -n $NAMESPACE -o jsonpath='{.spec.host}'
\`\`\`
EOF
else
    cat >> "$APP_OUTPUT_DIR/README.md" << EOF
Update the hostname in \`50-ingress.yaml\` to match your domain, then access via:
\`\`\`
https://$WORKLOAD_NAME.example.com
\`\`\`
EOF
fi

cat >> "$APP_OUTPUT_DIR/README.md" << EOF

## Configuration Updates

### Update ConfigMap

\`\`\`bash
kubectl edit configmap $WORKLOAD_NAME-config -n $NAMESPACE
# Restart pods to pick up changes
kubectl rollout restart deployment/$WORKLOAD_NAME -n $NAMESPACE
\`\`\`

### Update Secrets

\`\`\`bash
kubectl edit secret $WORKLOAD_NAME-secret -n $NAMESPACE
# Restart pods to pick up changes
kubectl rollout restart deployment/$WORKLOAD_NAME -n $NAMESPACE
\`\`\`

## Scaling

### Manual Scaling

\`\`\`bash
kubectl scale deployment/$WORKLOAD_NAME --replicas=5 -n $NAMESPACE
\`\`\`

### Auto-scaling

HPA is already configured and will automatically scale between 2-10 replicas based on CPU/memory usage.

## Monitoring

\`\`\`bash
# Watch HPA
kubectl get hpa $WORKLOAD_NAME -n $NAMESPACE --watch

# Check resource usage
kubectl top pods -n $NAMESPACE

# Check events
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'
\`\`\`

## Cleanup

\`\`\`bash
# Delete all resources
kubectl delete -f $APP_OUTPUT_DIR/

# Or delete namespace (removes everything)
kubectl delete namespace $NAMESPACE
\`\`\`

## Production Checklist

- [ ] Update image registry in \`40-deployment.yaml\`
- [ ] Configure proper hostname in \`50-ingress.yaml\` or \`50-route.yaml\`
- [ ] Review and adjust resource requests/limits
- [ ] Configure backup for PVCs
- [ ] Set up monitoring and alerting
- [ ] Configure log aggregation
- [ ] Review and adjust HPA settings
- [ ] Set up SSL/TLS certificates
- [ ] Configure network policies for your environment
- [ ] Review security contexts and policies
- [ ] Set up proper RBAC if needed
- [ ] Configure proper storage class for your cluster

## Notes

- All containers run as non-root users for security
- Database and Redis use StatefulSets with persistent storage
- Application uses Deployment with rolling updates
- Health checks are configured for all services
- Resource limits prevent resource exhaustion
- Network policies restrict traffic flow
- HPA provides automatic scaling based on load
- PDB ensures availability during voluntary disruptions

EOF

echo "  ✓ Generated: README.md"

# End of generate_manifests function
}

# Main orchestration logic
echo ""
echo "================================================================"
echo "Starting manifest generation"
echo "================================================================"
echo "Workload: $WORKLOAD_NAME"
echo "Deployment Target: $DEPLOYMENT_TARGET"
echo "Cloud Providers: ${CLOUD_PROVIDERS:-N/A}"
echo "================================================================"

# Generate manifests based on deployment target
if [ "$DEPLOYMENT_TARGET" = "local" ]; then
    # Local deployment - full stack with DB, Redis, init scripts
    TARGET_DIR="$OUTPUT_DIR/$WORKLOAD_NAME/local"
    generate_manifests "local" "$TARGET_DIR" false
    
elif [ "$DEPLOYMENT_TARGET" = "cloud" ]; then
    # Cloud-only deployment - no infrastructure resources
    IFS=',' read -ra CLOUD_ARRAY <<< "$CLOUD_PROVIDERS"
    for cloud in "${CLOUD_ARRAY[@]}"; do
        TARGET_DIR="$OUTPUT_DIR/$WORKLOAD_NAME/cloud/$cloud"
        generate_manifests "$cloud" "$TARGET_DIR" true
    done
    
elif [ "$DEPLOYMENT_TARGET" = "both" ]; then
    # Both local and cloud deployments
    
    # Generate local manifests
    TARGET_DIR="$OUTPUT_DIR/$WORKLOAD_NAME/local"
    generate_manifests "local" "$TARGET_DIR" false
    
    # Generate cloud manifests for each provider
    IFS=',' read -ra CLOUD_ARRAY <<< "$CLOUD_PROVIDERS"
    for cloud in "${CLOUD_ARRAY[@]}"; do
        TARGET_DIR="$OUTPUT_DIR/$WORKLOAD_NAME/cloud/$cloud"
        generate_manifests "$cloud" "$TARGET_DIR" true
    done
fi

echo ""
echo "✅ Successfully generated $PLATFORM manifests!"
echo ""
echo "Output directory structure:"
if [ "$DEPLOYMENT_TARGET" = "local" ] || [ "$DEPLOYMENT_TARGET" = "both" ]; then
    echo "  📁 $OUTPUT_DIR/$WORKLOAD_NAME/local/ - Local deployment (full stack)"
fi
if [ "$DEPLOYMENT_TARGET" = "cloud" ] || [ "$DEPLOYMENT_TARGET" = "both" ]; then
    IFS=',' read -ra CLOUD_ARRAY <<< "$CLOUD_PROVIDERS"
    for cloud in "${CLOUD_ARRAY[@]}"; do
        echo "  ☁️  $OUTPUT_DIR/$WORKLOAD_NAME/cloud/$cloud/ - $cloud deployment (app only)"
    done
fi
echo ""
echo "Next steps:"
echo "  1. Review the generated manifests"
echo "  2. Update image references and hostnames"
if [ "$DEPLOYMENT_TARGET" = "local" ] || [ "$DEPLOYMENT_TARGET" = "both" ]; then
    echo "  3. For local: kubectl apply -f $OUTPUT_DIR/$WORKLOAD_NAME/local/"
fi
if [ "$DEPLOYMENT_TARGET" = "cloud" ] || [ "$DEPLOYMENT_TARGET" = "both" ]; then
    echo "  4. For cloud: Set up managed services first (database, cache, queues)"
    echo "  5. For cloud: kubectl apply -f $OUTPUT_DIR/$WORKLOAD_NAME/cloud/<provider>/"
fi
echo ""
echo "For detailed instructions, see README.md in each deployment folder"
