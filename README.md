# SIT Test Repository

System Integration Testing (SIT) environment management using GitHub Actions and Docker Compose.

## 🎯 Purpose

This repository provides an automated workflow to deploy, manage, and teardown complete SIT environments on a macOS self-hosted runner. Multiple users can safely run isolated environments simultaneously.

## 📚 Documentation

| Document | Description | When to Read |
|----------|-------------|--------------|
| **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** | Quick commands and common scenarios | ⭐ **Start here!** |
| **[PORT_ASSIGNMENT_GUIDE.md](./PORT_ASSIGNMENT_GUIDE.md)** | How dynamic port assignment works | Understanding port allocation |
| **[ENVIRONMENT_MANAGEMENT_GUIDE.md](./ENVIRONMENT_MANAGEMENT_GUIDE.md)** | Complete user guide with detailed explanations | For in-depth understanding |
| **[MULTI_USER_ISOLATION_GUIDE.md](./MULTI_USER_ISOLATION_GUIDE.md)** | Visual guide showing how multi-user isolation works | Understanding the architecture |
| **[CHANGES_SUMMARY.md](./CHANGES_SUMMARY.md)** | What's new in version 2.0 | For existing users |
| **[.github/workflows/README.md](./.github/workflows/README.md)** | Technical workflow documentation | For maintainers |

## 🚀 Quick Start

### 1. Choose Your Unique Environment Name
Use your username or a descriptive identifier:
- `john-dev`
- `alice-test`
- `feature-auth`
- `sprint-23`

### 2. Deploy Your Environment
```bash
gh workflow run sit-environment.yml \
  -f action=deploy \
  -f environment_name=YOUR-NAME
```

### 3. Access Services
Once deployed, **check the GitHub Actions summary** for your unique port assignments. Ports are automatically assigned based on your environment name to prevent conflicts.

Example port ranges:
- **Beneficiaries API:** http://localhost:8XXX
- **Payment Processor API:** http://localhost:8XXX+1
- **Payment Consumer API:** http://localhost:8XXX+2

💡 **Your specific ports will be displayed in the workflow summary after deployment!**

### 4. Manage Your Environment
```bash
# Check status
gh workflow run sit-environment.yml -f action=status -f environment_name=YOUR-NAME

# Stop (pause) for break
gh workflow run sit-environment.yml -f action=stop -f environment_name=YOUR-NAME

# Resume working
gh workflow run sit-environment.yml -f action=restart -f environment_name=YOUR-NAME

# Cleanup when done
gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME
```

## 🎬 Available Actions

| Action | Purpose | Use Case |
|--------|---------|----------|
| **deploy** | Create new environment | Starting testing session |
| **stop** | Pause environment | Taking a break, freeing resources |
| **restart** | Resume/refresh | Continue after stop, recover from issues |
| **status** | Check health | Verify services are running |
| **list-all** | See all environments | Find your environment, check resources |
| **teardown** | Remove environment | Finished testing, cleanup |

## 🏗️ Architecture

```
sit-test-repo/
├── docker-compose.yml              # Multi-container orchestration (6 services)
├── .github/workflows/
│   ├── sit-environment.yml        # GitHub Actions workflow
│   └── README.md                  # Technical documentation
├── QUICK_REFERENCE.md             # Quick command reference
├── ENVIRONMENT_MANAGEMENT_GUIDE.md # Complete user guide
├── MULTI_USER_ISOLATION_GUIDE.md  # Multi-user architecture
└── CHANGES_SUMMARY.md             # Version 2.0 changes
```

## 🔐 Multi-User Isolation

Each user's environment is completely isolated:

**John's Environment (environment_name=john-dev):**
- Compose Project: `sit-john-dev`
- Containers: `sit-john-dev-beneficiaries-1`, etc.
- Volumes: `sit-john-dev_beneficiaries-db-data`, etc.
- Network: `sit-john-dev_payment-network`
- **Ports: 8247, 8248, 8249, 5247, 5248, 6247** (calculated from "john-dev" hash)

**Alice's Environment (environment_name=alice-test):**
- Compose Project: `sit-alice-test`
- Containers: `sit-alice-test-beneficiaries-1`, etc.
- Volumes: `sit-alice-test_beneficiaries-db-data`, etc.
- Network: `sit-alice-test_payment-network`
- **Ports: 8532, 8533, 8534, 5532, 5533, 6532** (calculated from "alice-test" hash)

**Result:** ✅ No conflicts, independent lifecycle, isolated data, **unique ports**

## 📦 Services Included

The SIT environment includes:

1. **Beneficiaries Service** (Dynamic Port: 8XXX)
   - PostgreSQL database (Dynamic Port: 5XXX)
   - Redis cache (Dynamic Port: 6XXX)

2. **Payment Processor Service** (Dynamic Port: 8XXX+1)
   - PostgreSQL database (Dynamic Port: 5XXX+1)

3. **Payment Consumer Service** (Dynamic Port: 8XXX+2)

**Port Assignment:** Each environment gets unique ports calculated from the environment name hash. This enables multiple users to run environments simultaneously without conflicts.

All services include:
- Health checks
- Actuator endpoints
- Automatic startup sequencing

## 🔍 How to Find Your Environment

### Method 1: List All Environments
```bash
gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy
```

Shows all containers, volumes, and networks across all users.

### Method 2: Check GitHub Actions Summary
After running any action, view the workflow summary for your environment details.

### Method 3: Remember Your Name
Use the same environment name consistently (e.g., always use `john-dev`).

## 💡 Best Practices

1. **Use Unique Names:** Always use your username or unique identifier
2. **Clean Up:** Teardown environments when finished
3. **Use Stop vs Teardown:** 
   - Use `stop` for short breaks (preserves everything)
   - Use `teardown` when completely done
4. **Check Before Deploy:** Run `list-all` to see existing environments
5. **Consistent Naming:** Use the same pattern for your environments

## 🐛 Troubleshooting

### "Environment not found"
Run `list-all` to see all environments and find yours.

### "Services not healthy"
Check GitHub Actions logs and uploaded artifacts for detailed error information.

### "Forgot my environment name"
Run `list-all` and look for containers matching your username pattern.

### "Need fresh start"
Teardown and redeploy:
```bash
gh workflow run sit-environment.yml -f action=teardown -f environment_name=YOUR-NAME
gh workflow run sit-environment.yml -f action=deploy -f environment_name=YOUR-NAME
```

## 🆘 Support

1. Read the [QUICK_REFERENCE.md](./QUICK_REFERENCE.md)
2. Check [ENVIRONMENT_MANAGEMENT_GUIDE.md](./ENVIRONMENT_MANAGEMENT_GUIDE.md)
3. Review GitHub Actions logs
4. Check uploaded artifacts for detailed logs
5. Contact DevOps team

## 📋 Prerequisites

- Access to the repository
- GitHub CLI (`gh`) installed (or use GitHub UI)
- Permissions to trigger workflows
- Access to the self-hosted macOS runner (for service access)

## 🔗 Related Repositories

This SIT environment is designed to test:
- `beneficiaries` - Beneficiaries management service
- `paymentprocessor` - Payment processing service
- `paymentconsumer` - Payment consumer service

## 📝 Version History

### Version 2.0 (Current)
- ✅ Added `stop` action (pause environment)
- ✅ Added `list-all` action (discover environments)
- ✅ Multi-user isolation improvements
- ✅ Required unique environment names
- ✅ Enhanced tracking and metadata
- ✅ Comprehensive documentation

### Version 1.0
- Initial release with deploy, restart, status, teardown

---

**Quick Links:**
- [Quick Reference](./QUICK_REFERENCE.md) - ⭐ Start here!
- [Port Assignment Guide](./PORT_ASSIGNMENT_GUIDE.md) - Understand port allocation
- [Complete Guide](./ENVIRONMENT_MANAGEMENT_GUIDE.md) - Detailed documentation
- [Multi-User Guide](./MULTI_USER_ISOLATION_GUIDE.md) - Architecture details
- [What's New](./CHANGES_SUMMARY.md) - Version 2.0 changes

**Need Help?** Start with [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) for common commands and scenarios.
