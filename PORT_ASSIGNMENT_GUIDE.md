# Port Assignment Guide

## 🎯 Overview

To enable **true multi-user isolation**, each SIT environment gets **dynamically assigned ports** based on the environment name. This prevents port conflicts when multiple users run environments simultaneously on the same self-hosted runner.

## 🔢 How Port Assignment Works

### Port Calculation Algorithm

```bash
# 1. Hash the environment name
HASH=$(echo -n "${ENVIRONMENT_NAME}" | shasum | cut -c1-4)

# 2. Calculate port offset (range: 100-999)
PORT_OFFSET=$((0x${HASH} % 900 + 100))

# 3. Calculate service ports
BENEFICIARIES_PORT=$((8000 + PORT_OFFSET))          # 8100-8999
PAYMENTPROCESSOR_PORT=$((8000 + PORT_OFFSET + 1))   # 8101-9000
PAYMENTCONSUMER_PORT=$((8000 + PORT_OFFSET + 2))    # 8102-9001
BENEFICIARIES_DB_PORT=$((5000 + PORT_OFFSET))       # 5100-5999
PAYMENTPROCESSOR_DB_PORT=$((5000 + PORT_OFFSET + 1))# 5101-6000
REDIS_PORT=$((6000 + PORT_OFFSET))                  # 6100-6999
```

### Why This Works

- **Deterministic:** Same environment name always gets the same ports
- **Distributed:** Hash function distributes port assignments evenly
- **Memorable:** Use consistent environment names and ports remain stable
- **Conflict-Free:** 900 possible port offsets minimize collision risk

## 📊 Port Assignment Examples

| Environment Name | Hash | Offset | Beneficiaries API | Payment Processor | Payment Consumer | Beneficiaries DB | Payment DB | Redis |
|------------------|------|--------|-------------------|-------------------|------------------|------------------|------------|-------|
| `john-dev` | `b27f` | 247 | 8247 | 8248 | 8249 | 5247 | 5248 | 6247 |
| `alice-test` | `1214` | 532 | 8532 | 8533 | 8534 | 5532 | 5533 | 6532 |
| `feature-auth` | `8ca3` | 163 | 8163 | 8164 | 8165 | 5163 | 5164 | 6163 |
| `sprint-23` | `f4d2` | 722 | 8722 | 8723 | 8724 | 5722 | 5723 | 6722 |
| `bugfix-login` | `3e91` | 401 | 8401 | 8402 | 8403 | 5401 | 5402 | 6401 |

## 🔍 Finding Your Ports

### Method 1: GitHub Actions Summary (Recommended)

After deploying, check the workflow summary which displays a table with all your ports:

```
Service Endpoints (Port Offset: 247)

| Service                        | Endpoint               | Port |
|--------------------------------|------------------------|------|
| Beneficiaries API              | http://localhost:8247  | 8247 |
| Payment Processor API          | http://localhost:8248  | 8248 |
| Payment Consumer API           | http://localhost:8249  | 8249 |
| PostgreSQL (Beneficiaries)     | localhost:5247         | 5247 |
| PostgreSQL (Payment Processor) | localhost:5248         | 5248 |
| Redis                          | localhost:6247         | 6247 |
```

### Method 2: Docker Inspect

```bash
# Check container port mappings
docker ps --filter "name=sit-YOUR-ENV" --format "table {{.Names}}\t{{.Ports}}"
```

### Method 3: Status Action

```bash
gh workflow run sit-environment.yml \
  -f action=status \
  -f environment_name=YOUR-NAME
```

The output will show all port mappings.

### Method 4: Calculate Manually

```bash
# Calculate your ports (macOS/Linux)
ENV_NAME="john-dev"
HASH=$(echo -n "${ENV_NAME}" | shasum | cut -c1-4)
OFFSET=$((0x${HASH} % 900 + 100))
echo "Your port offset: ${OFFSET}"
echo "Beneficiaries API: $((8000 + OFFSET))"
echo "Payment Processor: $((8000 + OFFSET + 1))"
echo "Payment Consumer: $((8000 + OFFSET + 2))"
```

## 🚀 Using Your Ports

### Accessing APIs

```bash
# Example for john-dev (ports 8247-8249)
curl http://localhost:8247/actuator/health
curl http://localhost:8248/actuator/health
curl http://localhost:8249/actuator/health
```

### Database Connections

```bash
# Beneficiaries DB (john-dev: port 5247)
psql -h localhost -p 5247 -U postgres -d beneficiaries

# Payment Processor DB (john-dev: port 5248)
psql -h localhost -p 5248 -U postgres -d paymentprocessor
```

### Redis Connection

```bash
# Redis (john-dev: port 6247)
redis-cli -h localhost -p 6247
```

## 💡 Best Practices

### 1. Use Consistent Environment Names

```bash
# ✅ Good: Always use the same name
john-dev → Always ports 8247, 8248, 8249...

# ❌ Bad: Different names each time
john-dev-1 → Ports 8xxx
john-dev-2 → Different ports 8yyy
john-dev-new → Different ports 8zzz
```

### 2. Document Your Ports

Save your port assignment for quick reference:

```bash
# ~/.sit-ports
export SIT_ENV="john-dev"
export SIT_BENEFICIARIES_PORT=8247
export SIT_PAYMENTPROCESSOR_PORT=8248
export SIT_PAYMENTCONSUMER_PORT=8249
```

### 3. Use Port Forwarding for Standard Ports

If you prefer working with standard ports (8080, 8081, etc.):

```bash
# SSH port forwarding
ssh -L 8080:localhost:8247 \
    -L 8081:localhost:8248 \
    -L 8082:localhost:8249 \
    runner-host
```

### 4. Configure Your Tools

Update your development tools with correct ports:

**Postman Environment:**
```json
{
  "beneficiaries_url": "http://localhost:8247",
  "paymentprocessor_url": "http://localhost:8248",
  "paymentconsumer_url": "http://localhost:8249"
}
```

**application.yml (local development):**
```yaml
beneficiaries:
  url: http://localhost:8247
paymentprocessor:
  url: http://localhost:8248
```

## 🔧 Troubleshooting

### "Cannot connect to service"

1. **Verify ports from GitHub Actions summary**
2. **Check if containers are running:**
   ```bash
   docker ps --filter "name=sit-YOUR-ENV"
   ```
3. **Test port connectivity:**
   ```bash
   curl -v http://localhost:YOUR-PORT/actuator/health
   ```

### "Port already in use"

This should rarely happen due to hash distribution, but if it does:

1. **Choose a different environment name:**
   ```bash
   # Instead of: john-dev
   # Try: john-dev-v2, john-dev-sit, etc.
   ```

2. **Check for conflicts:**
   ```bash
   lsof -i :8247  # Check what's using the port
   ```

### "Lost my port assignments"

1. **Check GitHub Actions run history** - Port assignments are in the summary
2. **Run status action** - Shows current ports
3. **Calculate from environment name** - Use the calculation script above

## 📋 Port Range Summary

| Service Type | Port Range | Formula |
|--------------|------------|---------|
| Application APIs | 8100-9001 | 8000 + offset + service# |
| PostgreSQL DBs | 5100-6000 | 5000 + offset + db# |
| Redis | 6100-6999 | 6000 + offset |

**Total Possible Environments:** 900 (offset range: 100-999)

## 🎓 Advanced Topics

### Port Collision Probability

With 900 possible offsets and assuming random environment names:

- **2 environments:** ~0.1% collision risk
- **10 environments:** ~5% collision risk
- **50 environments:** ~70% collision risk

**Mitigation:** Use descriptive, unique environment names (e.g., `username-feature` instead of `test1`, `test2`)

### Custom Port Assignment

If you need specific ports, you can run docker-compose manually:

```bash
export COMPOSE_PROJECT_NAME=sit-myenv
export BENEFICIARIES_PORT=9000
export PAYMENTPROCESSOR_PORT=9001
export PAYMENTCONSUMER_PORT=9002
export BENEFICIARIES_DB_PORT=15432
export PAYMENTPROCESSOR_DB_PORT=15433
export REDIS_PORT=16379

docker compose up -d
```

### Port Reservation

For long-running environments, document reserved ports:

```bash
# Reserved Ports (team shared document)
john-dev: 8247-8249, 5247-5248, 6247
alice-test: 8532-8534, 5532-5533, 6532
feature-auth: 8163-8165, 5163-5164, 6163
```

## 🆘 Need Help?

1. Check GitHub Actions summary for your port assignments
2. Run `list-all` action to see all active environments and their ports
3. Use `status` action to see current environment details
4. Contact DevOps team if you need reserved port ranges

---

**Quick Command Reference:**

```bash
# Find your ports
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME

# Calculate ports
ENV_NAME="YOUR-NAME"
HASH=$(echo -n "${ENV_NAME}" | shasum | cut -c1-4)
OFFSET=$((0x${HASH} % 900 + 100))
echo "Beneficiaries: $((8000 + OFFSET))"

# Test connectivity
curl http://localhost:PORT/actuator/health
```
