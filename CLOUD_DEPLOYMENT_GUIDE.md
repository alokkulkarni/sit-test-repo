# Cloud Deployment Guide for Kubernetes Manifests

This guide explains how to use the enhanced `generate-k8s-from-score.sh` script to generate Kubernetes manifests optimized for cloud deployments.

## Overview

The script now supports three deployment targets:
- **Local**: Full-stack deployment including databases, Redis, and other infrastructure
- **Cloud**: Application-only deployment using cloud-managed services
- **Both**: Generate manifests for both local and cloud deployments

## Features

### Local Deployment
- ✅ Includes all infrastructure resources (databases, Redis, queues)
- ✅ Database init script support via ConfigMaps and InitContainers
- ✅ PersistentVolumeClaims for data storage
- ✅ StatefulSets for stateful services
- ✅ Suitable for development, on-premises, or self-hosted environments

### Cloud Deployment
- ✅ Application manifests only (Deployment, Service, Ingress, HPA, PDB)
- ✅ Skips database/Redis/queue infrastructure
- ✅ Cloud-specific optimizations per provider:
  - **AWS/EKS**: ALB ingress controller, gp3 storage class, IRSA labels
  - **Azure/AKS**: Application Gateway, managed-premium storage, Workload Identity
  - **GCP/GKE**: GCE ingress, pd-ssd storage, Workload Identity
- ✅ Assumes use of managed services (RDS, Azure SQL, Cloud SQL, etc.)

## Usage

### Basic Syntax

```bash
./generate-k8s-from-score.sh <score-file> [output-dir] [platform] [enable-db-init] [deployment-target] [cloud-providers]
```

### Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `score-file` | Path | Required | Score specification file |
| `output-dir` | Path | `k8s-manifests` | Output directory for manifests |
| `platform` | `kubernetes`, `openshift` | `kubernetes` | Target platform |
| `enable-db-init` | `yes`, `no` | `no` | Enable database init scripts |
| `deployment-target` | `local`, `cloud`, `both` | `local` | Deployment target |
| `cloud-providers` | `aws`, `azure`, `gcp` | - | Comma-separated cloud providers (required for `cloud`/`both`) |

## Examples

### 1. Local Development (Full Stack)

Generate complete manifests with database and Redis:

```bash
./generate-k8s-from-score.sh score-paymentprocessor-generated.yaml k8s-manifests kubernetes no local
```

**Output Structure:**
```
k8s-manifests/
  paymentprocessor/
    local/
      00-namespace.yaml
      10-configmap.yaml
      11-secret.yaml
      20-pvc-database.yaml           # Database storage
      30-statefulset-database.yaml   # Database StatefulSet
      31-service-database.yaml       # Database Service
      40-deployment.yaml             # App Deployment
      41-service.yaml                # App Service
      50-ingress.yaml                # Ingress
      60-hpa.yaml                    # HPA
      61-pdb.yaml                    # PDB
      README.md
```

### 2. AWS Cloud Deployment (App Only)

Generate manifests for AWS EKS with managed RDS:

```bash
./generate-k8s-from-score.sh score-paymentprocessor-generated.yaml k8s-manifests kubernetes no cloud aws
```

**Output Structure:**
```
k8s-manifests/
  paymentprocessor/
    cloud/
      aws/
        00-namespace.yaml
        10-configmap.yaml
        11-secret.yaml
        40-deployment.yaml           # App Deployment with AWS labels
        41-service.yaml              # App Service
        50-ingress.yaml              # Ingress with ALB annotations
        60-hpa.yaml                  # HPA
        61-pdb.yaml                  # PDB
        README.md
```

**AWS Optimizations Applied:**
- ALB Ingress Controller annotations
- gp3 StorageClass for EBS volumes
- EKS-specific labels
- Health check paths for ALB

### 3. Multi-Cloud Deployment

Generate manifests for multiple cloud providers:

```bash
./generate-k8s-from-score.sh score-paymentprocessor-generated.yaml k8s-manifests kubernetes no cloud aws,azure,gcp
```

**Output Structure:**
```
k8s-manifests/
  paymentprocessor/
    cloud/
      aws/       # AWS-optimized manifests
      azure/     # Azure-optimized manifests
      gcp/       # GCP-optimized manifests
```

### 4. Both Local and Cloud

Generate manifests for local development AND cloud deployments:

```bash
./generate-k8s-from-score.sh score-paymentprocessor-generated.yaml k8s-manifests kubernetes yes both aws,azure,gcp
```

**Output Structure:**
```
k8s-manifests/
  paymentprocessor/
    local/       # Full stack with DB/Redis
    cloud/
      aws/       # AWS-optimized, app only
      azure/     # Azure-optimized, app only
      gcp/       # GCP-optimized, app only
```

## Cloud-Specific Optimizations

### AWS/EKS

**Ingress (ALB):**
```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
```

**Deployment Labels:**
```yaml
labels:
  eks.amazonaws.com/component: application
```

**StorageClass:**
- Uses `gp3` for EBS volumes (better performance, lower cost)

**Prerequisites:**
- AWS Load Balancer Controller installed
- IRSA (IAM Roles for Service Accounts) configured
- RDS database created and connection string in Secret
- ElastiCache cluster created (if using Redis)

### Azure/AKS

**Ingress (Application Gateway):**
```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/health-probe-path: /actuator/health
```

**Deployment Labels:**
```yaml
labels:
  azure.workload.identity/use: "true"
```

**StorageClass:**
- Uses `managed-premium` for Azure Disk

**Prerequisites:**
- Application Gateway Ingress Controller installed
- Azure Workload Identity configured
- Azure SQL Database created
- Azure Cache for Redis created (if using Redis)

### GCP/GKE

**Ingress (GCE):**
```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: gce
    cloud.google.com/neg: '{"ingress": true}'
```

**Deployment Labels:**
```yaml
labels:
  cloud.google.com/gke-nodepool: default-pool
```

**StorageClass:**
- Uses `pd-ssd` for Persistent Disk (SSD)

**Prerequisites:**
- GKE cluster with HTTP(S) Load Balancer enabled
- Workload Identity configured
- Cloud SQL instance created
- Memorystore for Redis created (if using Redis)

## Database Init Scripts

When using `enable-db-init=yes` with local deployments:

```bash
./generate-k8s-from-score.sh score-paymentprocessor-generated.yaml k8s-manifests kubernetes yes local
```

**Additional Files Generated:**
- `12-configmap-db-init.yaml` - Contains SQL init script
- StatefulSet includes InitContainer that:
  - Waits for database to be ready (`pg_isready`)
  - Executes init script with `psql`
  - Mounts ConfigMap to `/docker-entrypoint-initdb.d/`

**Note:** Init scripts are NOT generated for cloud deployments (use managed service migration tools instead).

## Deployment Workflow

### Local Deployment

1. Generate manifests:
   ```bash
   ./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes yes local
   ```

2. Review generated files:
   ```bash
   ls k8s-manifests/app/local/
   ```

3. Deploy to cluster:
   ```bash
   kubectl apply -f k8s-manifests/app/local/
   ```

4. Verify deployment:
   ```bash
   kubectl get all -n default
   ```

### Cloud Deployment (AWS Example)

1. **Create managed services first:**
   ```bash
   # Create RDS database
   aws rds create-db-instance \
     --db-instance-identifier myapp-db \
     --engine postgres \
     --master-username admin \
     --master-user-password SecurePassword \
     --allocated-storage 20

   # Create ElastiCache (if needed)
   aws elasticache create-cache-cluster \
     --cache-cluster-id myapp-redis \
     --engine redis \
     --cache-node-type cache.t3.micro
   ```

2. **Update Secret with managed service endpoints:**
   ```yaml
   # Edit k8s-manifests/app/cloud/aws/11-secret.yaml
   stringData:
     DB_HOST: "myapp-db.xxxxxx.us-east-1.rds.amazonaws.com"
     DB_PORT: "5432"
     REDIS_HOST: "myapp-redis.xxxxxx.cache.amazonaws.com"
   ```

3. **Generate cloud manifests:**
   ```bash
   ./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes no cloud aws
   ```

4. **Deploy to EKS cluster:**
   ```bash
   kubectl apply -f k8s-manifests/app/cloud/aws/
   ```

5. **Verify deployment:**
   ```bash
   kubectl get ingress -n default
   kubectl get pods -n default
   ```

## Migration Path

### Development → Production

1. **Start with local deployment** for development:
   ```bash
   ./generate-k8s-from-score.sh score.yaml dev-manifests kubernetes yes local
   ```

2. **Test locally** with minikube/kind:
   ```bash
   kubectl apply -f dev-manifests/app/local/
   ```

3. **Generate cloud manifests** for production:
   ```bash
   ./generate-k8s-from-score.sh score.yaml prod-manifests kubernetes no cloud aws
   ```

4. **Set up managed services** (RDS, ElastiCache, etc.)

5. **Update connection strings** in Secrets

6. **Deploy to cloud cluster**:
   ```bash
   kubectl apply -f prod-manifests/app/cloud/aws/
   ```

## Best Practices

### General
- ✅ Use `local` target for development and testing
- ✅ Use `cloud` target for production deployments
- ✅ Always review generated manifests before applying
- ✅ Update image tags and hostnames in manifests
- ✅ Store sensitive data in Kubernetes Secrets

### Cloud Deployments
- ✅ Use managed databases (RDS, Azure SQL, Cloud SQL)
- ✅ Use managed caches (ElastiCache, Azure Cache, Memorystore)
- ✅ Configure backups for managed services
- ✅ Enable encryption at rest and in transit
- ✅ Use Private Link/VNet integration for security
- ✅ Set up monitoring and alerting
- ✅ Configure autoscaling for databases
- ✅ Use connection pooling (PgBouncer, ProxySQL)

### Security
- ✅ Use IRSA (AWS) / Workload Identity (Azure/GCP)
- ✅ Enable Pod Security Standards
- ✅ Configure Network Policies
- ✅ Use private subnets for databases
- ✅ Rotate database credentials regularly
- ✅ Enable audit logging

## Troubleshooting

### Issue: Cloud manifests include database resources

**Solution:** Ensure you're using `cloud` or `both` as deployment target:
```bash
./generate-k8s-from-score.sh score.yaml k8s-manifests kubernetes no cloud aws
```

### Issue: Init scripts not generated

**Cause:** Init scripts are only generated for local deployments.

**Solution:** For cloud, use managed service migration tools:
- AWS: Database Migration Service (DMS)
- Azure: Azure Database Migration Service
- GCP: Database Migration Service

### Issue: Ingress not working

**Cause:** Cloud-specific ingress controllers not installed.

**Solution:**
- **AWS**: Install AWS Load Balancer Controller
- **Azure**: Install Application Gateway Ingress Controller
- **GCP**: Enable HTTP(S) Load Balancing

### Issue: Application can't connect to database

**Cause:** Database connection string not updated in Secret.

**Solution:** Update `11-secret.yaml` with managed database endpoint:
```yaml
stringData:
  DB_HOST: "your-rds-endpoint.amazonaws.com"
  DB_PORT: "5432"
  DB_USERNAME: "admin"
  DB_PASSWORD: "SecurePassword"
  DB_NAME: "mydb"
```

## Additional Resources

- [Score Specification](https://score.dev/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Azure AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)

## Contributing

Issues and pull requests are welcome! See the main README for contribution guidelines.
