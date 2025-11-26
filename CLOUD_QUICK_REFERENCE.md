# Cloud Deployment Quick Reference

## Command Syntax

```bash
./generate-k8s-from-score.sh <score-file> [output-dir] [platform] [enable-db-init] [deployment-target] [cloud-providers]
```

## Common Commands

### Local Development
```bash
# Full stack with database and Redis
./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes yes local
```

### Single Cloud

```bash
# AWS
./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes no cloud aws

# Azure
./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes no cloud azure

# GCP
./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes no cloud gcp
```

### Multi-Cloud

```bash
# AWS + Azure
./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes no cloud aws,azure

# All three clouds
./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes no cloud aws,azure,gcp
```

### Hybrid (Local + Cloud)

```bash
# Local + AWS
./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes yes both aws

# Local + All clouds
./generate-k8s-from-score.sh score-app.yaml k8s-manifests kubernetes yes both aws,azure,gcp
```

## Output Structure

### Local Only
```
k8s-manifests/
  app/
    local/
      [12 files including DB, Redis, and app]
```

### Cloud Only (Single)
```
k8s-manifests/
  app/
    cloud/
      aws/
        [8 files - app only, no infrastructure]
```

### Cloud Only (Multi)
```
k8s-manifests/
  app/
    cloud/
      aws/     [8 files]
      azure/   [8 files]
      gcp/     [8 files]
```

### Both (Hybrid)
```
k8s-manifests/
  app/
    local/     [12 files]
    cloud/
      aws/     [8 files]
      azure/   [8 files]
      gcp/     [8 files]
```

## Key Differences

| Feature | Local | Cloud |
|---------|-------|-------|
| Database | ✅ StatefulSet | ❌ Use RDS/Azure SQL/Cloud SQL |
| Redis | ✅ StatefulSet | ❌ Use ElastiCache/Azure Cache/Memorystore |
| Init Scripts | ✅ ConfigMap + InitContainer | ❌ Use migration tools |
| PVCs | ✅ For data persistence | ❌ Not needed |
| Files | 12-15 YAML files | 8 YAML files |

## Cloud-Specific Features

### AWS/EKS
- ALB Ingress Controller
- gp3 EBS volumes
- IRSA labels
- Health checks for ALB

### Azure/AKS
- Application Gateway Ingress
- managed-premium storage
- Workload Identity labels
- Health probe paths

### GCP/GKE
- GCE Ingress
- pd-ssd storage
- Workload Identity labels
- NEG annotations

## Typical Workflow

### Development
1. Generate local manifests
2. Deploy to minikube/kind
3. Test locally

### Production
1. Generate cloud manifests
2. Set up managed services (RDS, etc.)
3. Update connection strings in Secrets
4. Deploy to cloud cluster

## Prerequisites by Cloud

### AWS
- ✅ EKS cluster
- ✅ AWS Load Balancer Controller
- ✅ IRSA configured
- ✅ RDS database (if needed)
- ✅ ElastiCache (if needed)

### Azure
- ✅ AKS cluster
- ✅ Application Gateway Ingress Controller
- ✅ Workload Identity configured
- ✅ Azure SQL Database (if needed)
- ✅ Azure Cache for Redis (if needed)

### GCP
- ✅ GKE cluster
- ✅ HTTP(S) Load Balancing enabled
- ✅ Workload Identity configured
- ✅ Cloud SQL instance (if needed)
- ✅ Memorystore for Redis (if needed)

## Deployment Commands

### Local
```bash
kubectl apply -f k8s-manifests/app/local/
```

### Cloud
```bash
# AWS
kubectl apply -f k8s-manifests/app/cloud/aws/

# Azure
kubectl apply -f k8s-manifests/app/cloud/azure/

# GCP
kubectl apply -f k8s-manifests/app/cloud/gcp/
```

## Validation

### Check Generated Files
```bash
# Local
ls k8s-manifests/app/local/*.yaml

# Cloud
ls k8s-manifests/app/cloud/aws/*.yaml
```

### Verify Deployment
```bash
kubectl get all -n default
kubectl get ingress -n default
```

### Check Optimizations
```bash
# AWS - Check ALB annotations
grep -A5 "annotations:" k8s-manifests/app/cloud/aws/50-ingress.yaml

# Azure - Check Application Gateway
grep -A5 "annotations:" k8s-manifests/app/cloud/azure/50-ingress.yaml

# GCP - Check GCE ingress
grep -A5 "annotations:" k8s-manifests/app/cloud/gcp/50-ingress.yaml
```

## Troubleshooting

### No files generated for cloud
**Issue**: Database files still present in cloud deployment  
**Fix**: Ensure using `cloud` or `both` as deployment target

### Init scripts not working
**Issue**: ConfigMap not created for local  
**Fix**: Set `enable-db-init=yes` for local deployments

### Ingress not working
**Issue**: Cloud-specific ingress controller not installed  
**Fix**: Install required ingress controller for your cloud

### Can't connect to database
**Issue**: Connection string not updated  
**Fix**: Update `11-secret.yaml` with managed database endpoint

## Help

```bash
# Show help
./generate-k8s-from-score.sh
```

## More Information

- Full Guide: See `CLOUD_DEPLOYMENT_GUIDE.md`
- Implementation: See `CLOUD_FEATURE_SUMMARY.md`
- Score Spec: https://score.dev/
