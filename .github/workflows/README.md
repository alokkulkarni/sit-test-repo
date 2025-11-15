# SIT Environment Management Workflow

This GitHub Actions workflow allows you to manage an on-demand System Integration Testing (SIT) environment using Docker Compose on a macOS self-hosted runner.

## Prerequisites

1. **Self-hosted macOS Runner**: You need a macOS runner configured with the `self-hosted` and `macOS` labels
2. **Docker Desktop**: Docker Desktop must be installed and running on the macOS runner
3. **Docker Compose**: Docker Compose must be available (comes with Docker Desktop)
4. **Network Access**: The runner must have access to pull images from GitHub Container Registry

## Workflow Features

The workflow supports four actions:

### 1. Deploy
Deploys a complete SIT environment with all services:
- Pulls latest Docker images
- Starts all containers defined in `docker-compose.yml`
- Waits for services to become healthy
- Performs health checks on all APIs
- Provides service endpoint information

### 2. Status
Checks the current status of the SIT environment:
- Lists all running containers
- Shows service endpoints
- Displays Docker volumes and networks
- Performs health checks on all APIs

### 3. Restart
Restarts all services in the SIT environment:
- Restarts containers without removing them
- Preserves data volumes
- Waits for services to restart

### 4. Teardown
Tears down the SIT environment:
- Stops all containers
- Removes containers
- **Note**: Data volumes are preserved by default (for safety)
- To remove volumes, uncomment the volume removal lines in the workflow

## How to Use

### Via GitHub UI

1. Navigate to your repository on GitHub
2. Click on **Actions** tab
3. Select **SIT Environment Management** workflow
4. Click **Run workflow** button
5. Select the desired action from the dropdown:
   - `deploy` - Deploy new environment
   - `teardown` - Remove environment
   - `restart` - Restart services
   - `status` - Check environment status
6. (Optional) Enter a custom environment name (default: `sit`)
7. Click **Run workflow**

### Via GitHub CLI

```bash
# Deploy SIT environment
gh workflow run sit-environment.yml -f action=deploy -f environment_name=sit

# Check status
gh workflow run sit-environment.yml -f action=status -f environment_name=sit

# Restart services
gh workflow run sit-environment.yml -f action=restart -f environment_name=sit

# Teardown environment
gh workflow run sit-environment.yml -f action=teardown -f environment_name=sit
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
