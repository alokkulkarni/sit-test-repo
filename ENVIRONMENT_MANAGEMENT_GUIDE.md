# SIT Environment Management Guide

## Overview

This guide explains how to use the SIT Environment Management workflow to create, manage, and tear down isolated testing environments. Multiple users can safely use this workflow simultaneously without conflicts.

## 🎯 Key Concepts

### Environment Isolation

Each user creates their own **isolated environment** using a unique environment name. This ensures:
- ✅ No port conflicts between users
- ✅ Separate Docker containers for each environment
- ✅ Isolated data volumes
- ✅ Independent lifecycle management

### Environment Naming

Your environment name is your **unique identifier**. Use a name that identifies you or your purpose:

**Good Examples:**
- `john-dev` - John's development environment
- `alice-test` - Alice's testing environment
- `sprint-23` - Sprint 23 testing environment
- `feature-auth` - Feature branch for authentication
- `qa-regression` - QA regression testing

**Bad Examples:**
- `sit` - Too generic, may conflict with others
- `test123` - Not descriptive
- `my env` - Contains spaces (will be sanitized to `my-env`)

## 📋 Available Actions

### 1. **deploy** - Create a New Environment

Deploys a complete SIT environment with all services running.

**What it does:**
- Pulls latest Docker images
- Creates containers with unique project name
- Waits for all services to become healthy
- Performs health checks
- Shows service endpoints

**When to use:**
- Starting a new testing session
- Setting up an environment for the first time
- Need a fresh environment with latest code

**Example:**
```bash
# Via GitHub UI
Action: deploy
Environment Name: john-dev

# Via GitHub CLI
gh workflow run sit-environment.yml \
  -f action=deploy \
  -f environment_name=john-dev
```

**What you'll get:**
- Beneficiaries API at http://localhost:8080
- Payment Processor API at http://localhost:8081
- Payment Consumer API at http://localhost:8082
- PostgreSQL databases on ports 5432 and 5433
- Redis on port 6379

---

### 2. **stop** - Pause Your Environment

Stops all containers but preserves data and configuration.

**What it does:**
- Stops running containers
- Keeps data volumes intact
- Maintains container configuration
- Frees up system resources

**When to use:**
- Taking a lunch break
- End of work day but want to resume tomorrow
- Need to free up resources temporarily
- Want to preserve data but not actively testing

**Example:**
```bash
# Via GitHub UI
Action: stop
Environment Name: john-dev

# Via GitHub CLI
gh workflow run sit-environment.yml \
  -f action=stop \
  -f environment_name=john-dev
```

**After stopping:**
- Containers exist but are stopped
- Data is preserved
- Use `restart` to resume work
- Use `teardown` to remove completely

---

### 3. **restart** - Resume a Stopped Environment

Restarts stopped containers or refreshes running containers.

**What it does:**
- Starts previously stopped containers
- Or restarts running containers
- Preserves all data and state
- Waits for services to be ready

**When to use:**
- After using `stop` action
- Resume testing after a break
- Refresh containers after configuration change
- Recover from service issues

**Example:**
```bash
# Via GitHub UI
Action: restart
Environment Name: john-dev

# Via GitHub CLI
gh workflow run sit-environment.yml \
  -f action=restart \
  -f environment_name=john-dev
```

---

### 4. **status** - Check Environment Status

Shows detailed status of your environment.

**What it does:**
- Lists all containers and their status
- Performs health checks on APIs
- Shows service endpoints
- Displays resource usage

**When to use:**
- Check if your environment is running
- Verify services are healthy
- Get endpoint URLs
- Troubleshoot issues

**Example:**
```bash
# Via GitHub UI
Action: status
Environment Name: john-dev

# Via GitHub CLI
gh workflow run sit-environment.yml \
  -f action=status \
  -f environment_name=john-dev
```

---

### 5. **teardown** - Remove Your Environment

Completely removes containers (but preserves volumes by default).

**What it does:**
- Stops all running containers
- Removes containers
- Preserves data volumes (for safety)
- Cleans up resources

**When to use:**
- Finished testing
- Need a completely fresh start
- Cleaning up old environments
- Reclaiming system resources

**Example:**
```bash
# Via GitHub UI
Action: teardown
Environment Name: john-dev

# Via GitHub CLI
gh workflow run sit-environment.yml \
  -f action=teardown \
  -f environment_name=john-dev
```

**⚠️ Note:** Data volumes are preserved by default. To remove data, you'll need to manually run:
```bash
cd sit-test-repo
COMPOSE_PROJECT_NAME=sit-john-dev docker compose down -v
```

---

### 6. **list-all** - See All Active Environments

Lists all SIT environments on the runner.

**What it does:**
- Shows all running SIT containers
- Lists all SIT volumes
- Displays SIT networks
- Shows active compose projects

**When to use:**
- See what environments exist
- Find your environment name
- Check for orphaned resources
- Before creating a new environment

**Example:**
```bash
# Via GitHub UI
Action: list-all
Environment Name: dummy  # Any value works for list-all

# Via GitHub CLI
gh workflow run sit-environment.yml \
  -f action=list-all \
  -f environment_name=dummy
```

**Sample Output:**
```
🐳 Running SIT Containers:
NAMES                              STATUS          PORTS
sit-john-dev-beneficiaries-1      Up 2 hours      0.0.0.0:8080->8080/tcp
sit-john-dev-paymentprocessor-1   Up 2 hours      0.0.0.0:8081->8081/tcp
sit-alice-test-beneficiaries-1    Up 30 minutes   0.0.0.0:9080->8080/tcp

📦 SIT Volumes:
NAME                                    DRIVER
sit-john-dev_beneficiaries-db-data     local
sit-john-dev_redis-data                 local
sit-alice-test_beneficiaries-db-data   local
```

---

## 🔄 Common Workflows

### Daily Development Workflow

**Morning:**
```bash
# Start fresh
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev
```

**During the day:**
```bash
# Check status
gh workflow run sit-environment.yml -f action=status -f environment_name=john-dev

# Restart if needed
gh workflow run sit-environment.yml -f action=restart -f environment_name=john-dev
```

**End of day:**
```bash
# Option 1: Stop (resume tomorrow)
gh workflow run sit-environment.yml -f action=stop -f environment_name=john-dev

# Option 2: Teardown (start fresh tomorrow)
gh workflow run sit-environment.yml -f action=teardown -f environment_name=john-dev
```

---

### Testing a Feature Branch

```bash
# 1. Deploy environment for your feature
gh workflow run sit-environment.yml -f action=deploy -f environment_name=feature-auth

# 2. Run your tests
# ... test your feature ...

# 3. If tests fail, check logs
gh workflow run sit-environment.yml -f action=status -f environment_name=feature-auth

# 4. Restart if needed
gh workflow run sit-environment.yml -f action=restart -f environment_name=feature-auth

# 5. Clean up when done
gh workflow run sit-environment.yml -f action=teardown -f environment_name=feature-auth
```

---

### Emergency Troubleshooting

```bash
# 1. List all environments
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy

# 2. Check your environment status
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME

# 3. Try restarting
gh workflow run sit-environment.yml -f action=restart -f environment_name=YOUR-NAME

# 4. If all else fails, teardown and redeploy
gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME
gh workflow run sit-environment.yml -f action=deploy -f environment_name=YOUR-NAME
```

---

## 🤝 Multi-User Scenarios

### Scenario 1: Two Users Testing Simultaneously

**User: John**
```bash
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev
# Gets: sit-john-dev project
# Containers: sit-john-dev-beneficiaries-1, sit-john-dev-paymentprocessor-1, etc.
```

**User: Alice**
```bash
gh workflow run sit-environment.yml -f action=deploy -f environment_name=alice-test
# Gets: sit-alice-test project
# Containers: sit-alice-test-beneficiaries-1, sit-alice-test-paymentprocessor-1, etc.
```

**Result:**
- Both environments run **independently**
- No conflicts or interference
- Each has separate data volumes
- Each can be managed independently

---

### Scenario 2: Identifying Your Environment

**Problem:** "I deployed an environment yesterday, what was it called?"

**Solution:**
```bash
# 1. List all environments
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy

# 2. Look for containers with your name or pattern
# Example output shows: sit-john-dev-beneficiaries-1

# 3. Extract environment name from container name
# Container: sit-john-dev-beneficiaries-1
# Environment name: john-dev
```

---

### Scenario 3: Taking Over Someone's Environment

**⚠️ Important:** Only do this if coordinated with the team!

```bash
# 1. Find the environment
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy

# 2. Check its status
gh workflow run sit-environment.yml -f action=status -f environment_name=alice-test

# 3. Stop it (if running)
gh workflow run sit-environment.yml -f action=stop -f environment_name=alice-test

# 4. Teardown to clean up
gh workflow run sit-environment.yml -f action=teardown -f environment_name=alice-test

# 5. Create your own instead
gh workflow run sit-environment.yml -f action=deploy -f environment_name=your-name
```

---

## 🔍 How to Know Which Environment You're Using

### Method 1: Via Workflow Summary

After running any action, check the **GitHub Actions Summary** page:
- Environment Name: `john-dev`
- Compose Project: `sit-john-dev`
- Deployed By: `@john`

### Method 2: Via Docker Commands on Runner

```bash
# List all compose projects
docker compose ls

# List containers with environment name
docker ps --filter "name=sit-john-dev"

# Check specific project
cd sit-test-repo
COMPOSE_PROJECT_NAME=sit-john-dev docker compose ps
```

### Method 3: Via list-all Action

```bash
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
```

Then look for containers/volumes with your environment name pattern.

---

## 🎯 Best Practices

### 1. Use Descriptive Names
```bash
✅ john-dev, alice-feature-123, qa-sprint-5
❌ sit, test, env1
```

### 2. Clean Up After Yourself
```bash
# At end of testing session
gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME
```

### 3. Check Before Deploy
```bash
# See what's already running
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
```

### 4. Use stop vs teardown Appropriately
```bash
# Short break (lunch, meetings) → stop
gh workflow run sit-environment.yml -f action=stop -f environment_name=YOUR-NAME

# Done for the day → teardown
gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME
```

### 5. Document Your Environment
Keep track of your active environments in a team doc or chat:
```
John: Using 'john-dev' for auth feature testing (ETA: 2 days)
Alice: Using 'alice-regression' for QA (ETA: End of sprint)
```

---

## 🐛 Troubleshooting

### "Environment not found"
```bash
# Solution: List all environments
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
```

### "Containers not starting"
```bash
# Solution: Check logs (they're uploaded as artifacts on failure)
# Or check manually on runner:
docker compose logs
```

### "Port already in use"
This shouldn't happen with unique environment names, but if it does:
```bash
# Check what's using the port
lsof -i :8080

# Use a different environment name
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev-v2
```

### "How do I access my environment?"
Your environment runs on the **self-hosted macOS runner**, so:
- If you have access to the runner machine → Use localhost URLs
- If remote → You need VPN/tunnel access to the runner
- Services: http://localhost:8080, http://localhost:8081, http://localhost:8082

---

## 📞 Quick Reference Card

| Action | Use When | Preserves Data | Command |
|--------|----------|----------------|---------|
| **deploy** | Starting new environment | N/A (creates new) | `gh workflow run sit-environment.yml -f action=deploy -f environment_name=YOUR-NAME` |
| **stop** | Taking a break | ✅ Yes | `gh workflow run sit-environment.yml -f action=stop -f environment_name=YOUR-NAME` |
| **restart** | Resuming work | ✅ Yes | `gh workflow run sit-environment.yml -f action=restart -f environment_name=YOUR-NAME` |
| **status** | Checking health | N/A (read-only) | `gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME` |
| **teardown** | Finished testing | ⚠️ Volumes only | `gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME` |
| **list-all** | See all environments | N/A (read-only) | `gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy` |

---

## 💡 Pro Tips

1. **Alias common commands** in your shell:
   ```bash
   alias sit-deploy='gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev'
   alias sit-stop='gh workflow run sit-environment.yml -f action=stop -f environment_name=john-dev'
   alias sit-status='gh workflow run sit-environment.yml -f action=status -f environment_name=john-dev'
   ```

2. **Set up notifications** for workflow completion in GitHub

3. **Create a team convention** for environment naming

4. **Schedule cleanup jobs** to remove old environments automatically

5. **Document active environments** in your team's wiki or chat

---

## ❓ FAQ

**Q: Can I run multiple environments at the same time?**  
A: Yes! Each environment is completely isolated by its name.

**Q: How do I know what my environment name was?**  
A: Run the `list-all` action to see all active environments.

**Q: What happens if I use the same name as someone else?**  
A: Docker Compose will manage the same project, potentially causing conflicts. Always use unique names!

**Q: Can I access someone else's environment?**  
A: Technically yes, if you know their environment name, but please coordinate with your team first!

**Q: What's the difference between stop and teardown?**  
A: `stop` keeps containers (can restart later), `teardown` removes containers completely (data volumes still preserved).

**Q: How do I completely remove everything including data?**  
A: After teardown, manually run: `COMPOSE_PROJECT_NAME=sit-YOUR-NAME docker compose down -v`

**Q: Where are the logs if my deployment fails?**  
A: Check the GitHub Actions artifacts - logs are automatically uploaded on failure.

---

## 🆘 Support

If you encounter issues:
1. Check this guide first
2. Run `list-all` to see environment status
3. Check GitHub Actions logs
4. Review uploaded artifacts for detailed logs
5. Contact your team's DevOps support
