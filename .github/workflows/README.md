# SIT Environment Management Workflow

This GitHub Actions workflow allows you to manage on-demand System Integration Testing (SIT) environments using Docker Compose on a macOS self-hosted runner. **Multiple users can safely run isolated environments simultaneously.**

## Quick Start

📖 **For detailed usage guide, see:** [ENVIRONMENT_MANAGEMENT_GUIDE.md](../../ENVIRONMENT_MANAGEMENT_GUIDE.md)

## Prerequisites

1. **Self-hosted macOS Runner**: You need a macOS runner configured with the `self-hosted` and `macOS` labels
2. **Docker Desktop**: Docker Desktop must be installed and running on the macOS runner
3. **Docker Compose**: Docker Compose must be available (comes with Docker Desktop)
4. **Network Access**: The runner must have access to pull images from GitHub Container Registry

## Available Actions

The workflow supports **six actions**:

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

### Via GitHub CLI

```bash
# Deploy new environment
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

## Common Workflows

### Daily Development
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
# List all to see what's running
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy

# Check your specific environment
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME
```

## Service Endpoints

Once deployed, the following services are available:

| Service | Endpoint | Description |
|---------|----------|-------------|
| Beneficiaries API | http://localhost:8080 | Beneficiaries management service |
| Payment Processor API | http://localhost:8081 | Payment processing service |
| Payment Consumer API | http://localhost:8082 | Payment consumer service |
| PostgreSQL (Beneficiaries) | localhost:5432 | Database for beneficiaries |
| PostgreSQL (Payment Processor) | localhost:5433 | Database for payment processor |
| Redis | localhost:6379 | Redis cache for beneficiaries |

### Health Check Endpoints

- Beneficiaries: http://localhost:8080/actuator/health
- Payment Processor: http://localhost:8081/actuator/health
- Payment Consumer: http://localhost:8082/actuator/health

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
