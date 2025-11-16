# Multi-User Environment Isolation - Visual Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         macOS Self-Hosted Runner                         │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     Docker Environment                           │   │
│  │                                                                   │   │
│  │  ┌──────────────────────┐      ┌──────────────────────┐        │   │
│  │  │  John's Environment  │      │  Alice's Environment │        │   │
│  │  │  (john-dev)          │      │  (alice-test)        │        │   │
│  │  │                      │      │                      │        │   │
│  │  │  Compose Project:    │      │  Compose Project:    │        │   │
│  │  │  sit-john-dev        │      │  sit-alice-test      │        │   │
│  │  │                      │      │                      │        │   │
│  │  │  ┌────────────────┐  │      │  ┌────────────────┐  │        │   │
│  │  │  │  Containers:   │  │      │  │  Containers:   │  │        │   │
│  │  │  │  • beneficiaries│  │      │  │  • beneficiaries│  │        │   │
│  │  │  │  • processor   │  │      │  │  • processor   │  │        │   │
│  │  │  │  • consumer    │  │      │  │  • consumer    │  │        │   │
│  │  │  │  • postgres x2 │  │      │  │  • postgres x2 │  │        │   │
│  │  │  │  • redis       │  │      │  │  • redis       │  │        │   │
│  │  │  └────────────────┘  │      │  └────────────────┘  │        │   │
│  │  │                      │      │                      │        │   │
│  │  │  ┌────────────────┐  │      │  ┌────────────────┐  │        │   │
│  │  │  │  Volumes:      │  │      │  │  Volumes:      │  │        │   │
│  │  │  │  • ben-db-data │  │      │  │  • ben-db-data │  │        │   │
│  │  │  │  • proc-db-data│  │      │  │  • proc-db-data│  │        │   │
│  │  │  │  • redis-data  │  │      │  │  • redis-data  │  │        │   │
│  │  │  └────────────────┘  │      │  └────────────────┘  │        │   │
│  │  │                      │      │                      │        │   │
│  │  │  Network:            │      │  Network:            │        │   │
│  │  │  payment-network     │      │  payment-network     │        │   │
│  │  └──────────────────────┘      └──────────────────────┘        │   │
│  │                                                                   │   │
│  │  ⚡ Complete Isolation - No Interference                        │   │
│  └───────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
```

## Container Naming Pattern

```
Pattern: sit-{environment-name}-{service}-{replica}

John's Environment (environment_name=john-dev):
Ports: 8247, 8248, 8249, 5247, 5248, 6247 (from hash of "john-dev")
├── sit-john-dev-beneficiaries-1 (port 8247)
├── sit-john-dev-paymentprocessor-1 (port 8248)
├── sit-john-dev-paymentconsumer-1 (port 8249)
├── sit-john-dev-beneficiaries-db-1 (port 5247)
├── sit-john-dev-paymentprocessor-db-1 (port 5248)
└── sit-john-dev-redis-1 (port 6247)

Alice's Environment (environment_name=alice-test):
Ports: 8532, 8533, 8534, 5532, 5533, 6532 (from hash of "alice-test")
├── sit-alice-test-beneficiaries-1 (port 8532)
├── sit-alice-test-paymentprocessor-1 (port 8533)
├── sit-alice-test-paymentconsumer-1 (port 8534)
├── sit-alice-test-beneficiaries-db-1 (port 5532)
├── sit-alice-test-paymentprocessor-db-1 (port 5533)
└── sit-alice-test-redis-1 (port 6532)

✓ Unique names prevent conflicts
✓ Environment name included for easy identification
✓ Dynamic ports prevent port conflicts
```
├── sit-john-dev-paymentconsumer-1
├── sit-john-dev-beneficiaries-db-1
├── sit-john-dev-paymentprocessor-db-1
└── sit-john-dev-redis-1

Alice's Environment (environment_name=alice-test):
├── sit-alice-test-beneficiaries-1
├── sit-alice-test-paymentprocessor-1
├── sit-alice-test-paymentconsumer-1
├── sit-alice-test-beneficiaries-db-1
├── sit-alice-test-paymentprocessor-db-1
└── sit-alice-test-redis-1
```

## Volume Naming Pattern

```
Pattern: sit-{environment-name}_{volume-name}

John's Volumes:
├── sit-john-dev_beneficiaries-db-data
├── sit-john-dev_paymentprocessor-db-data
└── sit-john-dev_redis-data

Alice's Volumes:
├── sit-alice-test_beneficiaries-db-data
├── sit-alice-test_paymentprocessor-db-data
└── sit-alice-test_redis-data
```

## Network Naming Pattern

```
Pattern: sit-{environment-name}_payment-network

John's Network:
└── sit-john-dev_payment-network

Alice's Network:
└── sit-alice-test_payment-network
```

## Action Flow Diagram

```
┌─────────────┐
│   User      │
│   (John)    │
└──────┬──────┘
       │
       │ 1. Triggers workflow
       │    environment_name=john-dev
       │    action=deploy
       ↓
┌──────────────────────────────────────┐
│   GitHub Actions Workflow            │
│                                      │
│   • Sets COMPOSE_PROJECT_NAME=       │
│     sit-john-dev                     │
│   • Sanitizes environment name       │
│   • Adds metadata (actor, run ID)   │
└──────────────┬───────────────────────┘
               │
               │ 2. Executes docker compose
               ↓
┌──────────────────────────────────────┐
│   Docker Compose                     │
│                                      │
│   • Creates project: sit-john-dev   │
│   • Names containers with prefix    │
│   • Creates isolated volumes        │
│   • Sets up network                 │
└──────────────┬───────────────────────┘
               │
               │ 3. Returns status
               ↓
┌──────────────────────────────────────┐
│   GitHub Actions Summary             │
│                                      │
│   Environment: john-dev              │
│   Compose Project: sit-john-dev      │
│   Status: ✅ Success                 │
│   Deployed By: @john                 │
│                                      │
│   Service Endpoints:                 │
│   • http://localhost:8080            │
│   • http://localhost:8081            │
│   • http://localhost:8082            │
└──────────────────────────────────────┘
```

## Lifecycle State Diagram

```
                    ┌─────────────┐
                    │  Not Exists │
                    └──────┬──────┘
                           │
                           │ deploy
                           ↓
                    ┌─────────────┐
           ┌────────┤   Running   ├────────┐
           │        └──────┬──────┘        │
           │               │               │
      restart           stop          teardown
           │               │               │
           │               ↓               │
           │        ┌─────────────┐        │
           └───────→│   Stopped   │        │
                    └──────┬──────┘        │
                           │               │
                        restart            │
                           │               │
                           ↓               │
                    ┌─────────────┐        │
                    │   Running   │        │
                    └─────────────┘        │
                                           │
                                           ↓
                                    ┌─────────────┐
                                    │   Removed   │
                                    └─────────────┘

Legend:
├── Running: Containers up, consuming resources
├── Stopped: Containers exist but not running, data preserved
└── Removed: Containers deleted, volumes preserved (by default)
```

## Multi-User Timeline Example

```
Time →  09:00      10:00      11:00      12:00      13:00      14:00
        
John    [deploy]───[running]──[stop]────[stopped]──[restart]──[running]──[teardown]
        john-dev                                                          
        
Alice             [deploy]───[running]────────────[running]───[stop]────
                  alice-test

Bob                          [deploy]──[running]──[teardown]
                             bob-feat

Timeline:
09:00 - John deploys john-dev
10:00 - Alice deploys alice-test (no conflict!)
11:00 - John stops for lunch
        Bob deploys bob-feat (no conflict!)
12:00 - Bob finishes, tears down bob-feat
13:00 - John resumes after lunch
14:00 - John tears down
        Alice still running (no impact!)
```

## Resource View

```bash
$ gh workflow run sit-environment.yml -f action=list-all -f environment_name=dummy

Output:

🐳 Running SIT Containers:
NAMES                                    STATUS              PORTS
sit-john-dev-beneficiaries-1            Up 2 hours          0.0.0.0:8080->8080/tcp
sit-john-dev-paymentprocessor-1         Up 2 hours          0.0.0.0:8081->8081/tcp
sit-john-dev-paymentconsumer-1          Up 2 hours          0.0.0.0:8082->8082/tcp
sit-alice-test-beneficiaries-1          Up 30 minutes       0.0.0.0:9080->8080/tcp
sit-alice-test-paymentprocessor-1       Up 30 minutes       0.0.0.0:9081->8081/tcp

📦 SIT Volumes:
NAME                                           DRIVER
sit-john-dev_beneficiaries-db-data            local
sit-john-dev_paymentprocessor-db-data         local
sit-john-dev_redis-data                        local
sit-alice-test_beneficiaries-db-data          local
sit-alice-test_paymentprocessor-db-data       local
sit-alice-test_redis-data                      local

🔗 SIT Networks:
NAME                                      DRIVER
sit-john-dev_payment-network             bridge
sit-alice-test_payment-network           bridge

💡 Tip: Use the environment name from the container/volume names to manage specific environments
```

## Conflict Scenario (Anti-Pattern)

```
⚠️ AVOID: Multiple users using the same environment name

User John:
gh workflow run sit-environment.yml -f action=deploy -f environment_name=shared

User Alice (1 hour later):
gh workflow run sit-environment.yml -f action=deploy -f environment_name=shared

Result:
┌──────────────────────────────────────────────┐
│  ⚠️ CONFLICT!                                │
│                                               │
│  Both manage: sit-shared                     │
│  Alice's deploy RECREATES John's containers  │
│  John's work is LOST                         │
│  Confusion about ownership                   │
└──────────────────────────────────────────────┘

✅ CORRECT: Use unique names

User John:
gh workflow run sit-environment.yml -f action=deploy -f environment_name=john-dev

User Alice:
gh workflow run sit-environment.yml -f action=deploy -f environment_name=alice-test

Result:
┌──────────────────────────────────────────────┐
│  ✅ ISOLATED!                                │
│                                               │
│  John: sit-john-dev                          │
│  Alice: sit-alice-test                       │
│  No interference                             │
│  Clear ownership                             │
└──────────────────────────────────────────────┘
```

## Discovery Methods Visualized

```
Question: "Which environments exist?"

Method 1: list-all action
┌──────────────────────────────────────┐
│ gh workflow run sit-environment.yml  │
│   -f action=list-all                 │
│   -f environment_name=dummy          │
└────────────┬─────────────────────────┘
             │
             ↓
┌──────────────────────────────────────┐
│ Shows:                               │
│ • All containers                     │
│ • All volumes                        │
│ • All networks                       │
│ • Active projects                    │
└──────────────────────────────────────┘

Method 2: Workflow Summary
┌──────────────────────────────────────┐
│ After ANY action, check:             │
│ GitHub Actions → Workflow Run →      │
│ Summary Tab                          │
└────────────┬─────────────────────────┘
             │
             ↓
┌──────────────────────────────────────┐
│ Shows:                               │
│ • Environment name                   │
│ • Compose project                    │
│ • Deployed by                        │
│ • Quick reference commands           │
└──────────────────────────────────────┘

Method 3: Docker CLI (on runner)
┌──────────────────────────────────────┐
│ docker compose ls | grep sit-        │
│ docker ps --filter "name=sit-"       │
└────────────┬─────────────────────────┘
             │
             ↓
┌──────────────────────────────────────┐
│ Shows:                               │
│ • Running containers                 │
│ • Compose projects                   │
│ • Container status                   │
└──────────────────────────────────────┘
```

## Summary: Isolation Guarantees

| Isolation Aspect | Mechanism | Benefit |
|------------------|-----------|---------|
| **Container Names** | `sit-{env-name}-{service}` prefix | No name collisions |
| **Networks** | `sit-{env-name}_payment-network` | Network isolation |
| **Volumes** | `sit-{env-name}_{service}-data` | Data isolation |
| **Compose Projects** | `sit-{env-name}` | Grouped management |
| **Host Ports** | Dynamic assignment (hash-based) | **No port conflicts** |

### Port Conflict Resolution

**Problem:** Multiple environments sharing the same host would conflict on ports (8080, 8081, etc.)

**Solution:** Dynamic port assignment based on environment name hash

```
john-dev  → Hash: b27f → Offset: 247 → Ports: 8247, 8248, 8249...
alice-test → Hash: 1214 → Offset: 532 → Ports: 8532, 8533, 8534...
```

**Key Points:**
- ✅ Same environment name = same ports (deterministic)
- ✅ Different environment names = different ports
- ✅ 900 possible port offsets (range: 100-999)
- ✅ Hash function distributes ports evenly
- ✅ Low collision probability with reasonable naming

**See [PORT_ASSIGNMENT_GUIDE.md](./PORT_ASSIGNMENT_GUIDE.md) for complete details**

```
✅ What's Isolated per User:
├── Container instances (unique names)
├── Data volumes (separate databases, cache)
├── Networks (isolated communication)
├── Lifecycle (independent start/stop/teardown)
└── Resources (CPU, memory per environment)

⚠️ What's Shared:
├── Docker host (same runner machine)
├── Images (pulled once, used by all)
└── Port space (currently all use same ports)*

* Note: Current implementation uses same ports.
  For true multi-user simultaneous access, 
  ports would need to be dynamically allocated.
  
🎯 Recommendation:
   Use one environment at a time per runner,
   or coordinate port usage between teams.
```
