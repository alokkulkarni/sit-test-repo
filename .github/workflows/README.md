# SIT Environment Management Workflows

This directory contains GitHub Actions workflows for managing on-demand System Integration Testing (SIT) environments using Docker Compose on a macOS self-hosted runner. **Multiple users can safely run isolated environments simultaneously.**

## Available Workflows

### 1. `sit-environment.yml` - Standard SIT Environment
The original workflow designed specifically for the payment system docker-compose.yml with predefined services.

### 2. `sit-environment-generic.yml` - Generic SIT Environment ⭐ NEW
A fully **generic and reusable** workflow that can work with **ANY docker-compose.yml file**. Features automatic service discovery and dynamic port configuration.

## Quick Start

📖 **For detailed usage guide, see:** [ENVIRONMENT_MANAGEMENT_GUIDE.md](../../ENVIRONMENT_MANAGEMENT_GUIDE.md)

---

## Generic Workflow (sit-environment-generic.yml) ⭐

### Overview

The **generic workflow** is a powerful, reusable solution that can manage any docker-compose file without modification. It automatically:
- ✅ Discovers services from your compose file
- ✅ Detects port mappings with environment variables
- ✅ Calculates unique ports per environment to avoid conflicts
- ✅ Tests service health endpoints automatically
- ✅ Works with any docker-compose.yml structure

### Key Features

| Feature | Description |
|---------|-------------|
| **Docker-Compose Selection** | Choose which compose file to use via input parameter |
| **Auto Port Discovery** | Automatically finds and configures port mappings like `${SERVICE_PORT:-8080}` |
| **Service Discovery** | Detects all services defined in your compose file |
| **Port Conflict Avoidance** | Hash-based unique port offset per environment (range: 100-999) |
| **Health Check Discovery** | Automatically tries common health endpoints `/actuator/health`, `/health` |
| **Multi-Environment** | Run multiple isolated environments with different compose files |

### Usage

```bash
# Deploy with default docker-compose.yml
gh workflow run sit-environment-generic.yml \
  -f action=deploy \
  -f environment_name=john-dev

# Deploy with custom compose file
gh workflow run sit-environment-generic.yml \
  -f action=deploy \
  -f environment_name=alice-staging \
  -f compose_file=docker-compose-staging.yml

# Check status
gh workflow run sit-environment-generic.yml \
  -f action=status \
  -f environment_name=john-dev \
  -f compose_file=docker-compose.yml

# Stop environment
gh workflow run sit-environment-generic.yml \
  -f action=stop \
  -f environment_name=john-dev \
  -f compose_file=docker-compose.yml

# Restart environment
gh workflow run sit-environment-generic.yml \
  -f action=restart \
  -f environment_name=john-dev \
  -f compose_file=docker-compose.yml

# Teardown environment
gh workflow run sit-environment-generic.yml \
  -f action=teardown \
  -f environment_name=john-dev \
  -f compose_file=docker-compose.yml

# List all environments
gh workflow run sit-environment-generic.yml \
  -f action=list-all \
  -f environment_name=dummy
```

### How Port Discovery Works

The generic workflow parses your docker-compose file looking for port mappings with environment variables:

```yaml
# In your docker-compose.yml
services:
  my-service:
    ports:
      - "${MY_SERVICE_PORT:-8080}:8080"
```

**What happens:**
1. Workflow detects `MY_SERVICE_PORT` variable with default `8080`
2. Calculates unique offset based on environment name hash (e.g., `256`)
3. Sets `MY_SERVICE_PORT=8336` (8080 + 256)
4. Exports to environment before running docker-compose
5. Your service runs on unique port `8336` instead of `8080`

### Compose File Requirements

For the generic workflow to automatically manage ports, your docker-compose.yml should use environment variables for port mappings:

```yaml
services:
  api:
    ports:
      - "${API_PORT:-8080}:8080"  # ✅ Will be auto-discovered
  
  database:
    ports:
      - "${DB_PORT:-5432}:5432"   # ✅ Will be auto-discovered
  
  cache:
    ports:
      - "6379:6379"               # ⚠️ Fixed port, won't be adjusted
```

### Example: Using with Multiple Compose Files

```bash
# Development environment
gh workflow run sit-environment-generic.yml \
  -f action=deploy \
  -f environment_name=john-dev \
  -f compose_file=docker-compose.yml

# Staging environment with different compose
gh workflow run sit-environment-generic.yml \
  -f action=deploy \
  -f environment_name=john-staging \
  -f compose_file=docker-compose-staging.yml

# Testing environment
gh workflow run sit-environment-generic.yml \
  -f action=deploy \
  -f environment_name=alice-test \
  -f compose_file=docker-compose-test.yml
```

Each environment gets:
- ✅ Unique container names (prefixed with `sit-<env-name>-`)
- ✅ Unique port assignments (based on hash + offset)
- ✅ Isolated volumes and networks
- ✅ Independent lifecycle management

### Port Mappings Output

After deployment or status check, the workflow shows all configured ports:

```
🌐 Configured Port Mappings:
export API_PORT=8256
export DB_PORT=5356
export CACHE_PORT=6279
export ADMIN_PORT=9156
```

These are saved to `port-mappings.env` file in the workflow for reference.

---

## Standard Workflow (sit-environment.yml)

## Prerequisites

1. **Self-hosted macOS Runner**: You need a macOS runner configured with the `self-hosted` and `macOS` labels
2. **Docker Desktop**: Docker Desktop must be installed and running on the macOS runner
3. **Docker Compose**: Docker Compose must be available (comes with Docker Desktop)
4. **Network Access**: The runner must have access to pull images from GitHub Container Registry

### Overview

The **standard workflow** is specifically designed for the payment system's docker-compose.yml with predefined services (beneficiaries, paymentprocessor, paymentconsumer, databases, redis).

### Available Actions

Both workflows support **six actions**:

### 1. 🚀 **deploy** - Create New Environment
Deploys a complete SIT environment with all services, pulls latest images, waits for health checks.

### 2. ⏸️ **stop** - Pause Environment *(NEW)*
Stops all containers but preserves data and configuration. Use when taking a break or freeing up resources temporarily.

### 3. 🔄 **restart** - Resume/Restart Environment
Restarts stopped containers or refreshes running ones. Use to resume work after `stop` or to recover from issues.

### 4. 📊 **status** - Check Environment Status
Shows detailed status, health checks, and service endpoints.

### 5. 🧹 **teardown** - Remove Environment
Completely removes containers (preserves volumes by default).

### 6. 📋 **list-all** - See All Environments *(NEW)*
Lists all SIT environments on the runner, showing containers, volumes, and networks.

## Multi-User Support

### Environment Isolation

Each user creates an **isolated environment** using a unique environment name:

```bash
# User: John
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev

# User: Alice  
gh workflow run sit-environment.yml -f action=deploy -f environment_name=alice-test
```

**Result:**
- ✅ Separate Docker containers: `sit-john-dev-*` and `sit-alice-test-*`
- ✅ Isolated data volumes
- ✅ Independent lifecycle (stop, restart, teardown)
- ✅ No port conflicts (managed automatically)

### Identifying Your Environment

**Method 1: Workflow Summary**
After running any action, check the GitHub Actions summary page for your environment details.

**Method 2: List All Environments**
```bash
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
```

**Method 3: Docker Commands (on runner)**
```bash
docker compose ls | grep sit-
docker ps --filter "name=sit-"
```

### Environment Naming Best Practices

**Good:**
- `john-dev` - User's development environment
- `alice-test` - User's testing environment  
- `sprint-23` - Sprint-specific testing
- `feature-auth` - Feature branch testing

**Avoid:**
- `sit` - Too generic
- `test123` - Not descriptive
- `my env` - Spaces (will be sanitized)

## How to Use

### Via GitHub UI

1. Navigate to your repository on GitHub
2. Click on **Actions** tab
3. Select **SIT Environment Management** workflow
4. Click **Run workflow** button
5. Select the desired action from the dropdown
6. **Enter your unique environment name** (e.g., `john-dev`, `alice-test`)
7. Click **Run workflow**

### Via GitHub CLI (Standard Workflow)

```bash
# Deploy new environment (standard workflow)
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev

# Stop environment (pause, keep data)
gh workflow run sit-environment.yml -f action=stop -f environment_name=john-dev

# Restart environment
gh workflow run sit-environment.yml -f action=restart -f environment_name=john-dev

# Check status
gh workflow run sit-environment.yml -f action=status -f environment_name=john-dev

# List all environments
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy

# Teardown environment (remove containers)
gh workflow run sit-environment.yml -f action=teardown -f environment_name=john-dev
```

## Understanding Actions: stop vs teardown vs restart

| Action | Containers | Data | Use Case |
|--------|-----------|------|----------|
| **stop** | Stopped (preserved) | ✅ Kept | Taking a break, lunch, end of day |
| **restart** | Restarted | ✅ Kept | Resume after stop, refresh services |
| **teardown** | ❌ Removed | ⚠️ Volumes kept* | Finished testing, cleanup |

*Volumes are preserved by default for safety. To remove: `docker compose down -v`

## Choosing Between Workflows

| Use Case | Recommended Workflow |
|----------|---------------------|
| Payment system testing | `sit-environment.yml` (Standard) |
| Custom docker-compose file | `sit-environment-generic.yml` (Generic) |
| Multiple compose files | `sit-environment-generic.yml` (Generic) |
| Different projects in same repo | `sit-environment-generic.yml` (Generic) |
| Pre-configured services | `sit-environment.yml` (Standard) |
| Maximum flexibility | `sit-environment-generic.yml` (Generic) |

## Common Workflows

### Daily Development (Standard Workflow)
```bash
# Morning: Deploy
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev

# Lunch: Stop (optional)
gh workflow run sit-environment.yml -f action=stop -f environment_name=john-dev

# After lunch: Restart
gh workflow run sit-environment.yml -f action=restart -f environment_name=john-dev

# End of day: Teardown
gh workflow run sit-environment.yml -f action=teardown -f environment_name=john-dev
```

### Testing a Feature
```bash
# 1. Deploy for feature
gh workflow run sit-environment.yml -f action=deploy -f environment_name=feature-auth

# 2. Run tests (your code)

# 3. Check status if issues
gh workflow run sit-environment.yml -f action=status -f environment_name=feature-auth

# 4. Cleanup when done
gh workflow run sit-environment.yml -f action=teardown -f environment_name=feature-auth
```

### Finding Your Environment
```bash
# List all to see what's running (works with both workflows)
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
# OR
gh workflow run sit-environment-generic.yml -f action=list-all -f environment_name=dummy

# Check your specific environment
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME
```

### Using Generic Workflow for Different Projects
```bash
# Deploy microservices compose
gh workflow run sit-environment-generic.yml \
  -f action=deploy \
  -f environment_name=john-microservices \
  -f compose_file=docker-compose-microservices.yml

# Deploy data pipeline compose
gh workflow run sit-environment-generic.yml \
  -f action=deploy \
  -f environment_name=alice-pipeline \
  -f compose_file=docker-compose-pipeline.yml

# Both run simultaneously with unique ports!
```

## Service Endpoints

### Standard Workflow (sit-environment.yml)

Once deployed, the following services are available with **unique ports per environment**:

| Service | Endpoint | Description |
|---------|----------|-------------|
| Beneficiaries API | http://localhost:${BENEFICIARIES_PORT} | Beneficiaries management service |
| Payment Processor API | http://localhost:${PAYMENTPROCESSOR_PORT} | Payment processing service |
| Payment Consumer API | http://localhost:${PAYMENTCONSUMER_PORT} | Payment consumer service |
| PostgreSQL (Beneficiaries) | localhost:${BENEFICIARIES_DB_PORT} | Database for beneficiaries |
| PostgreSQL (Payment Processor) | localhost:${PAYMENTPROCESSOR_DB_PORT} | Database for payment processor |
| Redis | localhost:${REDIS_PORT} | Redis cache for beneficiaries |

**Note:** Port numbers are calculated as `BASE_PORT + OFFSET` where OFFSET is unique per environment (range: 100-999).

Example for environment `john-dev` (offset might be 256):
- Beneficiaries API: http://localhost:8256 (8000 + 256)
- Payment Processor API: http://localhost:8257 (8001 + 256)
- Beneficiaries DB: localhost:5256 (5000 + 256)

### Generic Workflow (sit-environment-generic.yml)

Port assignments are **automatically discovered** from your docker-compose file. After deployment, check the workflow summary or `port-mappings.env` for exact port numbers.

### Health Check Endpoints

**Standard Workflow:**
- Beneficiaries: http://localhost:${BENEFICIARIES_PORT}/actuator/health
- Payment Processor: http://localhost:${PAYMENTPROCESSOR_PORT}/actuator/health
- Payment Consumer: http://localhost:${PAYMENTCONSUMER_PORT}/actuator/health

**Generic Workflow:**
- Automatically discovers and tests common health endpoints
- Tries: `/actuator/health`, `/health`
- Results shown in workflow output

## Troubleshooting

### Services Not Starting

If services fail to start:
1. Check the workflow logs in GitHub Actions
2. Review the uploaded logs artifact (available on failure)
3. Manually check Docker on the runner:
   ```bash
   cd sit-test-repo
   docker-compose ps
   docker-compose logs
   ```

### Health Checks Failing

If health checks fail but containers are running:
1. Services may need more time to start (default wait is 5 minutes)
2. Check individual service logs:
   ```bash
   docker-compose logs beneficiaries
   docker-compose logs paymentprocessor
   docker-compose logs paymentconsumer
   ```

### Port Conflicts

If you see port binding errors:
1. Check if ports are already in use on the runner
2. Stop any conflicting services
3. Or modify port mappings in `docker-compose.yml`

### Docker Not Running

If Docker is not running on the runner:
1. Start Docker Desktop on the macOS runner
2. Ensure Docker is configured to start automatically

## Workflow Outputs

### On Success
- Container status listing
- Service endpoints
- Health check results
- Summary in GitHub Actions UI

### On Failure
- Detailed error logs
- Container logs (last 200 lines)
- Container status
- Docker information
- Logs uploaded as artifacts (retained for 7 days)

## Data Persistence

By default, the following volumes are created and persisted:
- `beneficiaries-db-data` - Beneficiaries database data
- `paymentprocessor-db-data` - Payment processor database data
- `redis-data` - Redis cache data

**Important**: The teardown action does NOT remove these volumes by default. To remove volumes during teardown, uncomment the volume removal lines in the workflow file.

## Security Considerations

1. **Credentials**: Default database credentials are used (`postgres/postgres`). For production-like environments, use secrets
2. **Network Exposure**: Services are exposed on localhost. Ensure firewall rules are appropriate
3. **Self-hosted Runner**: Ensure the runner is secured and not publicly accessible

## Maintenance

### Updating Images

To update to the latest images:
1. Run the workflow with `deploy` action
2. The workflow automatically pulls the latest images before starting

### Cleaning Up

To completely clean up:
1. Run teardown action
2. Manually remove volumes if needed:
   ```bash
   docker volume rm beneficiaries-db-data paymentprocessor-db-data redis-data
   ```

## Customization

### Timeout

The workflow has a 30-minute timeout. To change:
```yaml
timeout-minutes: 30  # Adjust as needed
```

### Health Check Wait Time

Default wait time is 300 seconds (5 minutes). To change, modify:
```yaml
timeout=300  # Change to desired seconds
```

### Log Retention

Logs are retained for 7 days. To change:
```yaml
retention-days: 7  # Adjust as needed
```

## Summary: Generic vs Standard Workflow

| Feature | Generic Workflow | Standard Workflow |
|---------|------------------|-------------------|
| Docker-compose file | ✅ Any file via parameter | ❌ Fixed to docker-compose.yml |
| Port discovery | ✅ Automatic | ✅ Predefined variables |
| Service discovery | ✅ Automatic from compose | ❌ Hardcoded services |
| Health checks | ✅ Auto-detects endpoints | ✅ Predefined endpoints |
| Flexibility | ⭐ Maximum | ⭐ Optimized for payment system |
| Setup required | None | None |
| Use case | Any project/compose file | Payment system specific |

## Benefits Summary

✅ **Zero configuration** - Just point it at any docker-compose file  
✅ **Multi-environment support** - Run dev, test, staging simultaneously  
✅ **Port conflict prevention** - Each environment gets unique ports  
✅ **Complete isolation** - Separate containers, volumes, networks per environment  
✅ **Service discovery** - Automatically finds and tests endpoints  
✅ **Flexibility** - Generic workflow works with any docker-compose structure  
✅ **Multi-user safe** - Multiple users can run isolated environments  

---

## Getting Started

1. **For payment system testing** → Use `sit-environment.yml`
2. **For any other docker-compose file** → Use `sit-environment-generic.yml`
3. **Not sure?** → Start with `sit-environment-generic.yml` (works everywhere!)

📖 **For detailed usage guide, see:** [ENVIRONMENT_MANAGEMENT_GUIDE.md](../../ENVIRONMENT_MANAGEMENT_GUIDE.md)