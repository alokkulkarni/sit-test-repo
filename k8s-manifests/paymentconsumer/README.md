# Kubernetes/OpenShift Manifests for paymentconsumer

Generated from Score specification: `score-paymentconsumer-generated.yaml`
Platform: **kubernetes**

## Prerequisites

- Kubernetes cluster (1.24+) or OpenShift cluster (4.10+)
- kubectl or oc CLI configured
- Storage class `standard` available for PVCs

## Files Generated

- `00-namespace.yaml` - Namespace/Project definition
- `10-configmap.yaml` - Application configuration
- `11-secret.yaml` - Sensitive data (passwords, tokens)
- `20-pvc-database.yaml` - Database persistent storage
- `21-pvc-redis.yaml` - Redis persistent storage (if applicable)
- `30-statefulset-database.yaml` - Database StatefulSet
- `31-service-database.yaml` - Database Service
- `32-statefulset-redis.yaml` - Redis StatefulSet (if applicable)
- `33-service-redis.yaml` - Redis Service (if applicable)
- `40-deployment.yaml` - Application Deployment
- `41-service.yaml` - Application Service
- `50-ingress.yaml` or `50-route.yaml` - External access
- `60-hpa.yaml` - Horizontal Pod Autoscaler
- `61-pdb.yaml` - Pod Disruption Budget
- `70-networkpolicy.yaml` - Network policies

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

```bash
# Deploy all manifests
kubectl apply -f k8s-manifests/paymentconsumer/paymentconsumer/

# Or for OpenShift
oc apply -f k8s-manifests/paymentconsumer/paymentconsumer/
```

### Step-by-Step Deployment

```bash
# 1. Create namespace
kubectl apply -f 00-namespace.yaml

# 2. Create configurations and secrets
kubectl apply -f 10-configmap.yaml
kubectl apply -f 11-secret.yaml

# 3. Create persistent volume claims
kubectl apply -f 20-pvc-database.yaml

# 4. Deploy database
kubectl apply -f 30-statefulset-database.yaml
kubectl apply -f 31-service-database.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l component=database -n default --timeout=300s

# 6. Deploy application
kubectl apply -f 40-deployment.yaml
kubectl apply -f 41-service.yaml

# Wait for application to be ready
kubectl wait --for=condition=available deployment/paymentconsumer -n default --timeout=300s

# 7. Create ingress/route
kubectl apply -f 50-*.yaml

# 8. Apply HPA and PDB
kubectl apply -f 60-hpa.yaml
kubectl apply -f 61-pdb.yaml

# 9. Apply network policies
kubectl apply -f 70-networkpolicy.yaml
```

## Verification

```bash
# Check all resources
kubectl get all -n default

# Check pod status
kubectl get pods -n default

# Check application logs
kubectl logs -f deployment/paymentconsumer -n default

# Check database logs
kubectl logs -f statefulset/paymentconsumer-db -n default
```

## Accessing the Application

### Port Forward (for testing)

```bash
kubectl port-forward svc/paymentconsumer 8082:80 -n default
# Access at http://localhost:8082
```

### Via Ingress/Route

Update the hostname in `50-ingress.yaml` to match your domain, then access via:
```
https://paymentconsumer.example.com
```

## Configuration Updates

### Update ConfigMap

```bash
kubectl edit configmap paymentconsumer-config -n default
# Restart pods to pick up changes
kubectl rollout restart deployment/paymentconsumer -n default
```

### Update Secrets

```bash
kubectl edit secret paymentconsumer-secret -n default
# Restart pods to pick up changes
kubectl rollout restart deployment/paymentconsumer -n default
```

## Scaling

### Manual Scaling

```bash
kubectl scale deployment/paymentconsumer --replicas=5 -n default
```

### Auto-scaling

HPA is already configured and will automatically scale between 2-10 replicas based on CPU/memory usage.

## Monitoring

```bash
# Watch HPA
kubectl get hpa paymentconsumer -n default --watch

# Check resource usage
kubectl top pods -n default

# Check events
kubectl get events -n default --sort-by='.lastTimestamp'
```

## Cleanup

```bash
# Delete all resources
kubectl delete -f k8s-manifests/paymentconsumer/paymentconsumer/

# Or delete namespace (removes everything)
kubectl delete namespace default
```

## Production Checklist

- [ ] Update image registry in `40-deployment.yaml`
- [ ] Configure proper hostname in `50-ingress.yaml` or `50-route.yaml`
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

