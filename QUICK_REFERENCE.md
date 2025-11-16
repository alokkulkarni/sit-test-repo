# SIT Environment Quick Reference Card

## 🚀 Quick Command Reference

### Deploy New Environment
```bash
gh workflow run sit-environment.yml -f action=deploy -f environment_name=YOUR-NAME
```
**Use when:** Starting new testing session, need fresh environment  
**Result:** Creates isolated environment with unique ports (check GitHub Actions summary for port assignments!)  
**Ports:** Automatically assigned based on environment name (see below)

---

### ⏸️ Stop Environment (Pause)
```bash
gh workflow run sit-environment.yml -f action=stop -f environment_name=YOUR-NAME
```
**Use when:** Taking a break, end of day, need to free resources temporarily  
**Result:** Containers stopped, data preserved, can restart later

---

### 🔄 Restart Environment
```bash
gh workflow run sit-environment.yml -f action=restart -f environment_name=YOUR-NAME
```
**Use when:** Resuming after stop, recovering from issues  
**Result:** Containers restarted with all data intact

---

### 📊 Check Status
```bash
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME
```
**Use when:** Want to see if environment is running and healthy  
**Shows:** Container status, health checks, service endpoints

---

### 📋 List All Environments
```bash
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
```
**Use when:** Want to see all active environments on the runner  
**Shows:** All containers, volumes, networks for all users

---

### 🧹 Teardown (Remove)
```bash
gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME
```
**Use when:** Completely done with environment, cleaning up  
**Result:** Containers removed, volumes preserved (safe)

---

## 📊 Action Comparison Matrix

| Action | Containers | Data | Resource Use | Resume With |
|--------|-----------|------|--------------|-------------|
| **deploy** | ✅ Created | 🆕 Fresh | 🔴 High | N/A |
| **stop** | ⏸️ Stopped | ✅ Kept | 🟢 None | restart |
| **restart** | 🔄 Running | ✅ Kept | 🔴 High | N/A |
| **status** | N/A | N/A | 🟢 None | N/A |
| **teardown** | ❌ Removed | ⚠️ Volumes only | 🟢 None | deploy |
| **list-all** | N/A | N/A | 🟢 None | N/A |

---

## 🎯 Common Scenarios

### Scenario 1: Daily Work
```bash
# Morning
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev

# Work, test, develop...

# End of day
gh workflow run sit-environment.yml -f action=teardown -f environment_name=john-dev
```

---

### Scenario 2: Multi-Day Testing
```bash
# Day 1: Start
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-test

# End of Day 1: Pause
gh workflow run sit-environment.yml -f action=stop -f environment_name=john-test

# Day 2 Morning: Resume
gh workflow run sit-environment.yml -f action=restart -f environment_name=john-test

# End of testing: Cleanup
gh workflow run sit-environment.yml -f action=teardown -f environment_name=john-test
```

---

### Scenario 3: "What's My Environment?"
```bash
# List everything
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy

# Check specific environment
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME
```

---

### Scenario 4: Emergency Cleanup
```bash
# See what exists
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy

# Teardown old environments
gh workflow run sit-environment.yml -f action=teardown -f environment_name=old-env-1
gh workflow run sit-environment.yml -f action=teardown -f environment_name=old-env-2
```

---

## 🌐 Service Endpoints

Once deployed, **check the GitHub Actions summary for your unique ports!**

### 🔢 Port Assignment

Ports are **automatically calculated** from your environment name to prevent conflicts:

**Example Port Assignments:**

| Environment | Hash | Offset | Beneficiaries | Processor | Consumer | Ben-DB | Proc-DB | Redis |
|-------------|------|--------|---------------|-----------|----------|--------|---------|-------|
| john-dev | b27f | 247 | 8247 | 8248 | 8249 | 5247 | 5248 | 6247 |
| alice-test | 1214 | 532 | 8532 | 8533 | 8534 | 5532 | 5533 | 6532 |
| feature-auth | 8ca3 | 163 | 8163 | 8164 | 8165 | 5163 | 5164 | 6163 |

**Key Points:**
- Same environment name = same ports (consistent across deploys)
- Different names = different ports (no conflicts)
- Port ranges: 8100-9001 (APIs), 5100-6000 (DBs), 6100-6999 (Redis)
- **Always check GitHub Actions summary after deploy for your specific ports!**

### How to Find Your Ports

1. **GitHub Actions Summary** (after deploy/status) - Best method!
2. Run status action: `gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME`
3. Calculate manually: See [PORT_ASSIGNMENT_GUIDE.md](./PORT_ASSIGNMENT_GUIDE.md)

### Health Check URLs (example for john-dev)
- Beneficiaries: http://localhost:8247/actuator/health
- Payment Processor: http://localhost:8248/actuator/health
- Payment Consumer: http://localhost:8249/actuator/health

---

## 🔑 Environment Naming Guide

### ✅ Good Names
```
john-dev          # Personal dev environment
alice-test        # Personal test environment
sprint-23         # Sprint-specific
feature-auth      # Feature branch
qa-regression     # QA testing
bugfix-1234       # Bug fix testing
```

### ❌ Bad Names
```
sit               # Too generic
test              # Not descriptive
my environment    # Has spaces (becomes my-environment)
123               # Only numbers
```

**Rule:** Use a unique, descriptive name that identifies you or your purpose

---

## 🚨 Troubleshooting

### Problem: "Environment not found"
```bash
# Solution: List all to find it
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
```

### Problem: "Containers not healthy"
```bash
# Solution: Check status and logs
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME
# Check GitHub Actions artifacts for detailed logs
```

### Problem: "Forgot my environment name"
```bash
# Solution: List all environments
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
# Look for containers with your username pattern
```

### Problem: "Need fresh start"
```bash
# Solution: Teardown and redeploy
gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME
gh workflow run sit-environment.yml -f action=deploy -f environment_name=YOUR-NAME
```

---

## 💡 Pro Tips

1. **Create shell aliases:**
   ```bash
   alias sit-deploy='gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev'
   alias sit-stop='gh workflow run sit-environment.yml -f action=stop -f environment_name=john-dev'
   alias sit-status='gh workflow run sit-environment.yml -f action=status -f environment_name=john-dev'
   alias sit-teardown='gh workflow run sit-environment.yml -f action=teardown -f environment_name=john-dev'
   ```

2. **Use consistent naming:** Always use the same pattern (e.g., `yourname-purpose`)

3. **Check before deploy:** Run `list-all` to see what already exists

4. **Clean up regularly:** Don't leave old environments running

5. **Use stop for breaks:** Save resources when not actively testing

---

## 📝 Cheat Sheet

```bash
# Most common commands (replace YOUR-NAME with your environment name)

# Start working
gh workflow run sit-environment.yml -f action=deploy -f environment_name=YOUR-NAME

# Pause for lunch/break
gh workflow run sit-environment.yml -f action=stop -f environment_name=YOUR-NAME

# Resume working
gh workflow run sit-environment.yml -f action=restart -f environment_name=YOUR-NAME

# Check if healthy
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME

# All done, cleanup
gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME

# See everything
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
```

---

## 🔗 More Information

- **Full Guide:** [ENVIRONMENT_MANAGEMENT_GUIDE.md](./ENVIRONMENT_MANAGEMENT_GUIDE.md)
- **Changes Summary:** [CHANGES_SUMMARY.md](./CHANGES_SUMMARY.md)
- **Multi-User Guide:** [MULTI_USER_ISOLATION_GUIDE.md](./MULTI_USER_ISOLATION_GUIDE.md)
- **Technical Docs:** [.github/workflows/README.md](./.github/workflows/README.md)

---

**Last Updated:** November 16, 2025  
**Workflow Version:** 2.0 (with stop and list-all actions)
