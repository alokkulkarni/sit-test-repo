# Humanitec Platform Orchestrator - Architecture & Deployment Flow

## 📋 Overview

Humanitec Platform Orchestrator is a **platform engineering tool** that acts as an intelligent intermediary between developers and infrastructure, managing the entire deployment lifecycle through a sophisticated system of **Resource Definitions**, **Matching Rules**, and **Driver-based provisioning**.

## 🏗️ Core Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         HUMANITEC PLATFORM ORCHESTRATOR                       │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    1. SCORE WORKLOAD DEFINITION                      │    │
│  │  (Platform-agnostic application specification)                       │    │
│  └────────────────────────────────┬─────────────────────────────────────┘    │
│                                   │                                           │
│                                   ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    2. RESOURCE GRAPH RESOLUTION                      │    │
│  │                                                                       │    │
│  │  Score Workload declares:                                            │    │
│  │  - "I need a postgres database"                                      │    │
│  │  - "I need a redis cache"                                            │    │
│  │  - "I need to run in environment: dev"                               │    │
│  │                                                                       │    │
│  │  Orchestrator builds dependency graph                                │    │
│  └────────────────────────────────┬─────────────────────────────────────┘    │
│                                   │                                           │
│                                   ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    3. MATCHING RULES ENGINE                          │    │
│  │                                                                       │    │
│  │  For each resource, find the best Resource Definition by matching:  │    │
│  │  ┌─────────────────────────────────────────────────────────────┐   │    │
│  │  │  Match Criteria:                                             │   │    │
│  │  │  • Environment (dev/stage/prod)                              │   │    │
│  │  │  • Application ID                                            │   │    │
│  │  │  • Resource Type (postgres, redis, k8s-cluster)              │   │    │
│  │  │  • Resource Class (default, large, enterprise)               │   │    │
│  │  │  • Context (cloud provider, region, team)                    │   │    │
│  │  └─────────────────────────────────────────────────────────────┘   │    │
│  │                                                                       │    │
│  │  Rule Priority: Most specific match wins                             │    │
│  │  Example:                                                             │    │
│  │    1. app=payments + env=prod + type=postgres → RDS Production      │    │
│  │    2. env=prod + type=postgres → RDS Standard                        │    │
│  │    3. type=postgres → Container Postgres (fallback)                 │    │
│  └────────────────────────────────┬─────────────────────────────────────┘    │
│                                   │                                           │
│                                   ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    4. RESOURCE DEFINITIONS                           │    │
│  │                                                                       │    │
│  │  Selected Definition contains:                                       │    │
│  │  ┌────────────────────────────────────────────────────────────┐    │    │
│  │  │  {                                                          │    │    │
│  │  │    "type": "postgres",                                      │    │    │
│  │  │    "driver_type": "humanitec/terraform",                    │    │    │
│  │  │    "driver_inputs": {                                       │    │    │
│  │  │      "source": {                                            │    │    │
│  │  │        "path": "modules/aws-rds-postgres",                  │    │    │
│  │  │        "rev": "v1.2.0"                                       │    │    │
│  │  │      },                                                      │    │    │
│  │  │      "variables": {                                          │    │    │
│  │  │        "instance_class": "db.t3.medium",                     │    │    │
│  │  │        "allocated_storage": 100,                             │    │    │
│  │  │        "engine_version": "14.7"                              │    │    │
│  │  │      },                                                      │    │    │
│  │  │      "credentials": "${resources.aws-credentials.outputs}"  │    │    │
│  │  │    },                                                        │    │    │
│  │  │    "provision": {                                            │    │    │
│  │  │      "is_dependent": false                                   │    │    │
│  │  │    }                                                         │    │    │
│  │  │  }                                                           │    │    │
│  │  └────────────────────────────────────────────────────────────┘    │    │
│  └────────────────────────────────┬─────────────────────────────────────┘    │
│                                   │                                           │
│                                   ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    5. DRIVER EXECUTION                               │    │
│  │                                                                       │    │
│  │  Driver Types:                                                       │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │  • humanitec/terraform - Execute Terraform modules           │  │    │
│  │  │  • humanitec/template  - Template-based (k8s manifests)      │  │    │
│  │  │  • humanitec/echo      - Pass-through existing resources     │  │    │
│  │  │  • humanitec/script    - Execute custom scripts              │  │    │
│  │  │  • humanitec/http      - HTTP API calls                      │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  │                                                                       │    │
│  │  Drivers can run:                                                    │    │
│  │  • Locally in Humanitec (managed runners)                            │    │
│  │  • In customer infrastructure (self-hosted runners)                  │    │
│  │  • In GitHub Actions (integration)                                   │    │
│  └────────────────────────────────┬─────────────────────────────────────┘    │
│                                   │                                           │
│                                   ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    6. RUNNER SELECTION & EXECUTION                   │    │
│  │                                                                       │    │
│  │  Humanitec selects runner based on:                                  │    │
│  │  • Environment configuration                                         │    │
│  │  • Resource Definition driver requirements                           │    │
│  │  • Available runner pools                                            │    │
│  │                                                                       │    │
│  │  Runner executes provisioning:                                       │    │
│  │  1. Fetch module/template from source                                │    │
│  │  2. Inject variables and secrets                                     │    │
│  │  3. Execute (terraform apply / kubectl apply / script)               │    │
│  │  4. Capture outputs (connection strings, IPs, credentials)           │    │
│  │  5. Return to Orchestrator                                           │    │
│  └────────────────────────────────┬─────────────────────────────────────┘    │
│                                   │                                           │
│                                   ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    7. OUTPUT INJECTION                               │    │
│  │                                                                       │    │
│  │  Orchestrator injects provisioned resource outputs into workload:    │    │
│  │                                                                       │    │
│  │  Original Score:                                                     │    │
│  │    SPRING_DATASOURCE_URL: ${resources.database.outputs.url}          │    │
│  │                                                                       │    │
│  │  After provisioning:                                                 │    │
│  │    SPRING_DATASOURCE_URL: jdbc:postgresql://prod-db.aws:5432/mydb   │    │
│  │                                                                       │    │
│  └────────────────────────────────┬─────────────────────────────────────┘    │
│                                   │                                           │
│                                   ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    8. WORKLOAD DEPLOYMENT                            │    │
│  │                                                                       │    │
│  │  Deploy to target runtime:                                           │    │
│  │  • Kubernetes cluster                                                │    │
│  │  • Cloud Run                                                         │    │
│  │  • ECS/Fargate                                                       │    │
│  │  • Azure Container Apps                                              │    │
│  │  • VM with Docker                                                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 🎯 Key Components Explained

### 1. Resource Definitions

Resource Definitions are **blueprints** that tell Humanitec how to provision infrastructure:

```yaml
# Example: Postgres Resource Definition for Production
id: aws-rds-postgres-prod
name: AWS RDS PostgreSQL (Production)
type: postgres
driver_type: humanitec/terraform

# What infrastructure to create
driver_inputs:
  values:
    source:
      path: terraform-aws-modules/rds/aws
      rev: v5.9.0
    variables:
      engine: postgres
      engine_version: "14.7"
      instance_class: db.r5.xlarge
      allocated_storage: 500
      storage_encrypted: true
      multi_az: true
      backup_retention_period: 30
      
    # Use credentials from another resource
    credentials_config:
      environment:
        AWS_ACCESS_KEY_ID: ${resources.aws-credentials.outputs.access_key_id}
        AWS_SECRET_ACCESS_KEY: ${resources.aws-credentials.outputs.secret_access_key}
        AWS_REGION: ${resources.aws-credentials.outputs.region}

# What to expose back to the application
driver_outputs:
  secrets:
    username: ${outputs.master_username}
    password: ${outputs.master_password}
  values:
    host: ${outputs.address}
    port: ${outputs.port}
    name: ${outputs.database_name}
```

### 2. Matching Rules

Matching Rules determine **which Resource Definition** to use for a given resource request:

```yaml
# Rule 1: Production RDS for payments app
match:
  app_id: payments
  env_id: prod
  res_type: postgres
definition_id: aws-rds-postgres-prod

# Rule 2: Standard RDS for all production
match:
  env_id: prod
  res_type: postgres
definition_id: aws-rds-postgres-standard

# Rule 3: Container Postgres for dev/test
match:
  env_id: dev
  res_type: postgres
definition_id: postgres-container

# Rule 4: Fallback (no environment specified)
match:
  res_type: postgres
definition_id: postgres-container
```

**Rule Priority:** Most specific match wins (most criteria matched).

### 3. Module System

Humanitec uses **Terraform modules** or **templates** as reusable components:

```
Platform Team's Module Library:
├── terraform/
│   ├── aws/
│   │   ├── rds-postgres/          # Standardized RDS setup
│   │   ├── elasticache-redis/     # Redis cluster
│   │   ├── eks-cluster/           # Kubernetes cluster
│   │   └── s3-bucket/             # S3 with encryption
│   ├── azure/
│   │   ├── postgresql-flexible/   # Azure Database
│   │   ├── redis-cache/
│   │   └── aks-cluster/
│   └── gcp/
│       ├── cloud-sql/
│       └── gke-cluster/
├── kubernetes/
│   ├── deployment.yaml.tpl        # K8s templates
│   └── service.yaml.tpl
└── scripts/
    ├── provision-vm.sh
    └── configure-docker.sh
```

Each module has:
- **Inputs**: What it needs (variables, credentials)
- **Outputs**: What it provides (connection strings, IPs)
- **Dependencies**: What must exist first

### 4. Runner Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    HUMANITEC RUNNER POOLS                       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Managed Runners (Humanitec-hosted):                           │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  • Pre-configured with terraform, kubectl, cloud CLIs    │ │
│  │  • Isolated per customer                                 │ │
│  │  • Automatic scaling                                     │ │
│  │  • Limited to public cloud resources                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Self-Hosted Runners (Customer infrastructure):                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  • Runs in customer VPC/network                          │ │
│  │  • Access to private resources                           │ │
│  │  • Custom tools and configurations                       │ │
│  │  • Full control over execution                           │ │
│  │                                                           │ │
│  │  Deployment Options:                                     │ │
│  │  • Docker container                                      │ │
│  │  • Kubernetes pod                                        │ │
│  │  • VM/bare metal                                         │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  GitHub Actions Integration:                                   │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  • Trigger GitHub workflow                               │ │
│  │  • Pass resource definition as input                     │ │
│  │  • Use existing GitHub runners                           │ │
│  │  • Capture outputs and return to Humanitec              │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

## 🔄 Complete Deployment Flow Example

### Scenario: Deploy Payment Service to Production

#### Step 1: Developer Pushes Score File

```yaml
# score.yaml
apiVersion: score.dev/v1b1
metadata:
  name: payment-service

containers:
  main:
    image: payments:v2.1.0
    variables:
      DB_URL: ${resources.database.outputs.url}
      REDIS_HOST: ${resources.cache.outputs.host}

resources:
  database:
    type: postgres
    
  cache:
    type: redis
```

#### Step 2: Orchestrator Analyzes Dependencies

```
Resource Graph:
  payment-service (workload)
    ├── database (postgres) - NEEDS PROVISIONING
    ├── cache (redis) - NEEDS PROVISIONING
    └── k8s-cluster (runtime) - ALREADY EXISTS
```

#### Step 3: Matching Rules Applied

```
For resource "database" (type: postgres):
  Checking rules for env=prod, app=payments, type=postgres...
  
  ✅ MATCH: Rule priority 1000
     app_id: payments
     env_id: prod
     res_type: postgres
     → Use definition: aws-rds-postgres-prod-payments
  
For resource "cache" (type: redis):
  Checking rules for env=prod, app=payments, type=redis...
  
  ✅ MATCH: Rule priority 800
     env_id: prod
     res_type: redis
     → Use definition: aws-elasticache-redis-prod
```

#### Step 4: Resource Definitions Retrieved

**Database Definition:**
```yaml
id: aws-rds-postgres-prod-payments
driver_type: humanitec/terraform
driver_inputs:
  source:
    path: terraform/aws/rds-postgres-ha
    rev: v2.3.0
  variables:
    instance_class: db.r5.2xlarge
    storage: 1000
    multi_az: true
    backup_retention: 30
  credentials: ${resources.aws-prod-creds}
```

**Cache Definition:**
```yaml
id: aws-elasticache-redis-prod
driver_type: humanitec/terraform
driver_inputs:
  source:
    path: terraform/aws/elasticache
    rev: v1.5.0
  variables:
    node_type: cache.r5.large
    num_nodes: 3
  credentials: ${resources.aws-prod-creds}
```

#### Step 5: Runner Selection

```
Humanitec checks runner configuration:

For aws-rds-postgres-prod-payments:
  Environment: prod
  Runner requirement: self-hosted (access to AWS VPC)
  
  → Select runner: prod-runner-pool-aws-us-east-1
  
For aws-elasticache-redis-prod:
  Environment: prod
  Runner requirement: self-hosted (access to AWS VPC)
  
  → Select runner: prod-runner-pool-aws-us-east-1
```

#### Step 6: Parallel Provisioning

**Runner executes in customer VPC:**

```bash
# Runner receives job from Humanitec API
# Job contains:
# - Terraform module source
# - Variables
# - Credentials (from vault)
# - Expected outputs

# Runner process:
1. Clone module: terraform/aws/rds-postgres-ha@v2.3.0
2. Create terraform.tfvars:
   instance_class = "db.r5.2xlarge"
   allocated_storage = 1000
   ...
   
3. Initialize: terraform init
4. Plan: terraform plan -out=plan.tfplan
5. Apply: terraform apply plan.tfplan
6. Capture outputs:
   {
     "url": "jdbc:postgresql://prod-payments-db.aws:5432/payments",
     "host": "prod-payments-db.aws.rds.amazonaws.com",
     "port": 5432,
     "username": "admin_user",
     "password": "<secret>",
     "database": "payments"
   }
7. Send outputs back to Humanitec
```

#### Step 7: Output Injection

Humanitec receives outputs and injects into workload:

```yaml
# Original Score:
containers:
  main:
    variables:
      DB_URL: ${resources.database.outputs.url}
      REDIS_HOST: ${resources.cache.outputs.host}

# After injection:
containers:
  main:
    variables:
      DB_URL: jdbc:postgresql://prod-payments-db.aws:5432/payments
      REDIS_HOST: prod-redis-cluster.aws.cache.amazonaws.com
    secrets:
      DB_USERNAME: admin_user
      DB_PASSWORD: <from-vault>
```

#### Step 8: Workload Deployment

```
Humanitec generates final Kubernetes manifests:

apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: payments-prod
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: main
        image: payments:v2.1.0
        env:
        - name: DB_URL
          value: jdbc:postgresql://prod-payments-db.aws:5432/payments
        - name: REDIS_HOST
          value: prod-redis-cluster.aws.cache.amazonaws.com
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: payment-service-db-creds
              key: username
```

Then deploys to target Kubernetes cluster.

## 🔐 Multi-Environment Management

### Environment-Specific Configuration

```yaml
# Organization Structure
Organization: AcmeCorp
├── Applications
│   └── payments
│       ├── Environments
│       │   ├── dev
│       │   │   ├── Runner: shared-dev-runners
│       │   │   ├── Cluster: eks-dev
│       │   │   └── Matching Rules: dev-rules
│       │   ├── stage
│       │   │   ├── Runner: shared-stage-runners
│       │   │   ├── Cluster: eks-stage
│       │   │   └── Matching Rules: stage-rules
│       │   └── prod
│       │       ├── Runner: isolated-prod-runners (in prod VPC)
│       │       ├── Cluster: eks-prod
│       │       └── Matching Rules: prod-rules
│       └── Resources
│           ├── Resource Definitions
│           └── Matching Rules
```

### Cross-Account/Subscription Deployment

```yaml
# Production Resource Definition with Cross-Account
id: aws-rds-prod-payments
driver_type: humanitec/terraform
driver_inputs:
  source:
    path: terraform/aws/rds
  
  # Assume role in production account
  credentials_config:
    environment:
      AWS_ROLE_ARN: arn:aws:iam::PROD-ACCOUNT:role/humanitec-deployer
      AWS_REGION: us-east-1
  
  # Tell Humanitec which runner can assume this role
  runner_config:
    runner_id: prod-runner-in-utilities-account
```

**Runner Configuration:**
```yaml
# Self-hosted runner in utilities account
runner:
  id: prod-runner-in-utilities-account
  location: utilities-vpc
  capabilities:
    - assume-role: arn:aws:iam::PROD-ACCOUNT:role/humanitec-deployer
    - assume-role: arn:aws:iam::STAGE-ACCOUNT:role/humanitec-deployer
    - assume-role: arn:aws:iam::DEV-ACCOUNT:role/humanitec-deployer
```

## 📊 Comparison: Humanitec vs GitHub Actions Runner Farm

| Aspect | Humanitec Orchestrator | GitHub Actions Runner Farm |
|--------|------------------------|---------------------------|
| **Resource Management** | Declarative Resource Definitions with matching rules | Manual IAM role configuration |
| **Module System** | Built-in module registry with versioning | Custom scripts/Terraform in repo |
| **Environment Routing** | Automatic via matching rules | Manual runner labels + workflow logic |
| **State Management** | Centralized in Humanitec | Terraform state in S3/Azure Storage |
| **Secrets** | Integrated vault with injection | GitHub Secrets + external vaults |
| **Dependency Resolution** | Automatic resource graph | Manual in workflow dependencies |
| **Output Sharing** | Automatic via ${resources.x.outputs} | Manual via artifacts/state |
| **Multi-Cloud** | Unified abstraction | Separate implementations |
| **Learning Curve** | Higher (platform concept) | Lower (familiar CI/CD) |
| **Flexibility** | Opinionated patterns | Full control |
| **Best For** | Large orgs, many teams | Smaller teams, custom needs |

## 🎯 Key Benefits of Humanitec Approach

### 1. Golden Paths
Platform team defines approved patterns once, developers get them automatically:
```
Developer requests "postgres" in dev → Gets containerized Postgres
Developer requests "postgres" in prod → Gets AWS RDS with HA
```

### 2. Self-Service Infrastructure
Developers don't need to know Terraform or cloud-specific details:
```yaml
# Developer writes:
resources:
  database:
    type: postgres

# Platform provides RDS with:
# - Backups configured
# - Encryption enabled
# - Multi-AZ
# - Monitoring
# - All best practices
```

### 3. Environment Parity
Same Score file works in all environments, different infrastructure underneath:
```
Score → Dev: Lightweight containers
Score → Stage: Medium cloud resources
Score → Prod: Enterprise-grade with HA
```

### 4. Dynamic Configuration
No hardcoded values, everything resolved at deployment time:
```yaml
# No more:
DB_HOST=prod-db-123.us-east-1.rds.amazonaws.com

# Instead:
DB_HOST=${resources.database.outputs.host}
# Resolved per environment automatically
```

## 🚀 Getting Started with Humanitec

1. **Define Resource Definitions** (Platform Team)
2. **Create Matching Rules** (By environment/app)
3. **Setup Runners** (Managed or self-hosted)
4. **Write Score Files** (Developers)
5. **Deploy** via Humanitec CLI or API

## 📚 Resources

- [Humanitec Documentation](https://docs.humanitec.com/)
- [Score Specification](https://docs.score.dev/)
- [Resource Drivers](https://docs.humanitec.com/platform-orchestrator/resources/drivers)
- [Matching Rules](https://docs.humanitec.com/platform-orchestrator/resources/matching-rules)

---

**Summary:** Humanitec acts as an intelligent layer that translates platform-agnostic Score files into environment-specific infrastructure using Resource Definitions, Matching Rules, and pluggable Drivers executed by managed or self-hosted runners.
