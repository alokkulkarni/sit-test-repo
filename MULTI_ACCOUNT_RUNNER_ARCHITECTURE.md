# Multi-Organization Multi-Account Runner Farm Architecture

## 📋 Executive Summary

This document explains how to use a **centralized runner farm** in a common utilities account/subscription to deploy Docker-based applications across multiple environments (Dev, Stage, Prod) in different accounts/subscriptions within an organization.

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        ORGANIZATION: Acme Corp                            │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │              UTILITIES ACCOUNT (Shared Services)                   │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │           RUNNER FARM (Self-Hosted Runners)                  │ │ │
│  │  │                                                               │ │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │ │ │
│  │  │  │  Runner 1   │  │  Runner 2   │  │  Runner 3   │         │ │ │
│  │  │  │  Labels:    │  │  Labels:    │  │  Labels:    │         │ │ │
│  │  │  │  - dev      │  │  - stage    │  │  - prod     │         │ │ │
│  │  │  │  - docker   │  │  - docker   │  │  - docker   │         │ │ │
│  │  │  │  - linux    │  │  - linux    │  │  - linux    │         │ │ │
│  │  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │ │ │
│  │  │         │                 │                 │                 │ │ │
│  │  │         └─────────────────┼─────────────────┘                │ │ │
│  │  │                           │                                   │ │ │
│  │  └───────────────────────────┼───────────────────────────────────┘ │ │
│  │                              │                                     │ │
│  │  ┌───────────────────────────▼───────────────────────────────┐   │ │
│  │  │   Cross-Account IAM Roles (AssumeRole)                    │   │ │
│  │  │   - dev-deployer-role                                     │   │ │
│  │  │   - stage-deployer-role                                   │   │ │
│  │  │   - prod-deployer-role                                    │   │ │
│  │  └───────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │  DEV ACCOUNT     │  │  STAGE ACCOUNT   │  │  PROD ACCOUNT    │   │
│  │                  │  │                  │  │                  │   │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │   │
│  │  │ VM/Container│ │  │  │ VM/Container│ │  │  │ VM/Container│ │   │
│  │  │   + Docker  │ │  │  │   + Docker  │ │  │  │   + Docker  │ │   │
│  │  │   + Nginx   │ │  │  │   + Nginx   │ │  │  │   + Nginx   │ │   │
│  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │   │
│  │                  │  │                  │  │                  │   │
│  │  Network: Dev    │  │  Network: Stage  │  │  Network: Prod   │   │
│  │  VNET/VPC        │  │  VNET/VPC        │  │  VNET/VPC        │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘   │
│                                                                         │
└──────────────────────────────────────────────────────────────────────────┘

                                  ▲
                                  │
                          GitHub Actions Workflow
                          (Score/Docker Compose)
```

## 🎯 Key Concepts

### 1. Runner Farm (Utilities Account)

A **centralized pool of self-hosted GitHub runners** that:
- Run in a dedicated utilities/shared services account
- Are labeled by environment (`dev`, `stage`, `prod`)
- Have Docker installed for container deployment
- Can assume roles in target accounts via cross-account IAM

### 2. Target Accounts

Separate accounts for each environment:
- **Dev Account**: Development environment
- **Stage Account**: Staging/QA environment  
- **Prod Account**: Production environment

Each contains:
- VMs with Docker installed
- Nginx reverse proxy
- Application containers
- Isolated networking

### 3. Cross-Account Access

Runners assume IAM roles in target accounts to:
- Deploy Docker containers
- Execute docker-compose commands
- Update configurations
- Monitor deployments

## 🔑 Implementation Plan

### Phase 1: Setup Runner Farm (Utilities Account)

#### Step 1.1: Provision Runner Infrastructure

**For AWS:**
```bash
cd infrastructure/AWS
./scripts/setup-terraform-backend.sh

# Deploy runners with environment-specific labels
terraform apply \
  -var="github_runner_labels=['self-hosted','linux','docker','utilities','dev']" \
  -var="environment=dev"

terraform apply \
  -var="github_runner_labels=['self-hosted','linux','docker','utilities','stage']" \
  -var="environment=stage"

terraform apply \
  -var="github_runner_labels=['self-hosted','linux','docker','utilities','prod']" \
  -var="environment=prod"
```

**For Azure:**
```bash
cd infrastructure/Azure
./scripts/setup-terraform-backend.sh

# Deploy runners with environment-specific labels
terraform apply \
  -var="github_runner_labels=['self-hosted','azure','linux','docker','utilities','dev']" \
  -var="environment=dev"
```

#### Step 1.2: Configure Runner Pools

Create separate runner groups in GitHub:
1. Go to: **Organization Settings → Actions → Runner groups**
2. Create groups:
   - `dev-runners` (access: dev repositories/workflows)
   - `stage-runners` (access: stage workflows)
   - `prod-runners` (access: prod workflows, requires approval)

#### Step 1.3: Label Runners by Environment

Each runner should have labels:
```yaml
labels:
  - self-hosted
  - linux
  - docker
  - utilities
  - <environment>  # dev, stage, or prod
```

### Phase 2: Setup Cross-Account Access

#### Step 2.1: Create IAM Roles in Target Accounts

**In DEV Account:**
```bash
# Create role that utilities account can assume
aws iam create-role \
  --role-name dev-deployer-role \
  --assume-role-policy-document file://trust-policy-dev.json

# trust-policy-dev.json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::UTILITIES-ACCOUNT-ID:root"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "sts:ExternalId": "github-runner-dev"
      }
    }
  }]
}

# Attach policies for EC2/Docker operations
aws iam attach-role-policy \
  --role-name dev-deployer-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
  --role-name dev-deployer-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess
```

**Repeat for STAGE and PROD accounts** with appropriate role names and external IDs.

**For Azure (OIDC approach):**
```bash
# In DEV subscription
az ad sp create-for-rbac \
  --name "github-runner-dev-deployer" \
  --role "Contributor" \
  --scopes /subscriptions/DEV-SUBSCRIPTION-ID

# Create federated credentials for the runner
az ad app federated-credential create \
  --id APP-ID \
  --parameters federated-credential-dev.json

# federated-credential-dev.json
{
  "name": "github-runner-dev",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:ORG/REPO:environment:dev",
  "audiences": ["api://AzureADTokenExchange"]
}
```

#### Step 2.2: Grant Runners Permission to Assume Roles

**In Utilities Account:**
```bash
# Attach policy to runner's IAM role
aws iam put-role-policy \
  --role-name github-runner-role \
  --policy-name AssumeTargetAccountRoles \
  --policy-document file://assume-role-policy.json

# assume-role-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [
        "arn:aws:iam::DEV-ACCOUNT-ID:role/dev-deployer-role",
        "arn:aws:iam::STAGE-ACCOUNT-ID:role/stage-deployer-role",
        "arn:aws:iam::PROD-ACCOUNT-ID:role/prod-deployer-role"
      ]
    }
  ]
}
```

### Phase 3: Configure Target Environment Infrastructure

#### Step 3.1: Deploy Docker Hosts in Each Account

**In DEV Account:**
```bash
cd infrastructure/AWS  # or Azure
export AWS_PROFILE=dev-account

terraform init \
  -backend-config="key=dev/docker-hosts/terraform.tfstate"

terraform apply \
  -var="environment=dev" \
  -var="install_docker=true" \
  -var="install_nginx=true"
```

**In STAGE Account:**
```bash
export AWS_PROFILE=stage-account

terraform init \
  -backend-config="key=stage/docker-hosts/terraform.tfstate"

terraform apply \
  -var="environment=stage" \
  -var="install_docker=true" \
  -var="install_nginx=true"
```

**In PROD Account:**
```bash
export AWS_PROFILE=prod-account

terraform init \
  -backend-config="key=prod/docker-hosts/terraform.tfstate"

terraform apply \
  -var="environment=prod" \
  -var="install_docker=true" \
  -var="install_nginx=true"
```

#### Step 3.2: Network Configuration

Ensure network connectivity:
```yaml
Dev Account:
  VPC CIDR: 10.0.0.0/16
  Public Subnet: 10.0.1.0/24
  Private Subnet: 10.0.2.0/24
  
Stage Account:
  VPC CIDR: 10.1.0.0/16
  Public Subnet: 10.1.1.0/24
  Private Subnet: 10.1.2.0/24
  
Prod Account:
  VPC CIDR: 10.2.0.0/16
  Public Subnet: 10.2.1.0/24
  Private Subnet: 10.2.2.0/24
```

### Phase 4: Create GitHub Actions Workflows

#### Step 4.1: Environment-Aware Deployment Workflow

```yaml
# .github/workflows/deploy-multi-account.yml
name: Multi-Account Docker Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - dev
          - stage
          - prod
      action:
        description: 'Deployment action'
        required: true
        type: choice
        options:
          - deploy
          - stop
          - restart
          - teardown

jobs:
  deploy:
    runs-on: [self-hosted, linux, docker, utilities, ${{ github.event.inputs.environment }}]
    environment: ${{ github.event.inputs.environment }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS Credentials (Cross-Account)
        if: env.CLOUD_PROVIDER == 'aws'
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets[format('{0}_DEPLOYER_ROLE_ARN', github.event.inputs.environment)] }}
          role-session-name: github-runner-${{ github.event.inputs.environment }}
          aws-region: ${{ vars.AWS_REGION }}
          role-external-id: github-runner-${{ github.event.inputs.environment }}
      
      - name: Azure Login (Cross-Subscription)
        if: env.CLOUD_PROVIDER == 'azure'
        uses: azure/login@v1
        with:
          client-id: ${{ secrets[format('{0}_CLIENT_ID', github.event.inputs.environment)] }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets[format('{0}_SUBSCRIPTION_ID', github.event.inputs.environment)] }}
      
      - name: Get Target VM IP
        id: get-vm
        run: |
          if [ "${{ env.CLOUD_PROVIDER }}" == "aws" ]; then
            VM_IP=$(aws ec2 describe-instances \
              --filters "Name=tag:Environment,Values=${{ github.event.inputs.environment }}" \
                        "Name=tag:Role,Values=docker-host" \
                        "Name=instance-state-name,Values=running" \
              --query 'Reservations[0].Instances[0].PrivateIpAddress' \
              --output text)
          else
            VM_IP=$(az vm show \
              --name docker-host-${{ github.event.inputs.environment }} \
              --resource-group testcontainers-${{ github.event.inputs.environment }}-rg \
              --query "privateIps" -o tsv)
          fi
          echo "vm_ip=$VM_IP" >> $GITHUB_OUTPUT
      
      - name: Setup SSH Connection (if needed)
        run: |
          # Setup SSH tunnel or SSM session
          # This depends on network topology
          echo "VM IP: ${{ steps.get-vm.outputs.vm_ip }}"
      
      - name: Deploy with Score/Docker Compose
        run: |
          # Set environment-specific variables
          export ENVIRONMENT=${{ github.event.inputs.environment }}
          export VM_IP=${{ steps.get-vm.outputs.vm_ip }}
          
          # Convert Score to docker-compose
          score-compose generate score-humanitec.yaml \
            --env $ENVIRONMENT \
            --output docker-compose-$ENVIRONMENT.yml
          
          # Copy compose file to target VM
          if [ "${{ env.CLOUD_PROVIDER }}" == "aws" ]; then
            aws ssm send-command \
              --instance-id ${{ steps.get-vm.outputs.instance_id }} \
              --document-name "AWS-RunShellScript" \
              --parameters "commands=['mkdir -p /opt/deployments']"
            
            # Use SSM to copy file
            aws s3 cp docker-compose-$ENVIRONMENT.yml \
              s3://deployment-artifacts-$ENVIRONMENT/
            
            aws ssm send-command \
              --instance-id ${{ steps.get-vm.outputs.instance_id }} \
              --document-name "AWS-RunShellScript" \
              --parameters "commands=[
                'aws s3 cp s3://deployment-artifacts-$ENVIRONMENT/docker-compose-$ENVIRONMENT.yml /opt/deployments/',
                'cd /opt/deployments',
                'docker compose -f docker-compose-$ENVIRONMENT.yml ${{ github.event.inputs.action }}'
              ]"
          else
            # Azure - use az vm run-command
            az vm run-command invoke \
              --name docker-host-$ENVIRONMENT \
              --resource-group testcontainers-$ENVIRONMENT-rg \
              --command-id RunShellScript \
              --scripts @deploy-script.sh \
              --parameters "action=${{ github.event.inputs.action }}"
          fi
      
      - name: Verify Deployment
        run: |
          # Health check via ALB/Application Gateway
          ENDPOINT="${{ secrets[format('{0}_APP_ENDPOINT', github.event.inputs.environment)] }}"
          
          echo "Checking health at: $ENDPOINT/health"
          for i in {1..30}; do
            if curl -sf "$ENDPOINT/health" > /dev/null; then
              echo "✅ Application is healthy"
              exit 0
            fi
            echo "⏳ Waiting for application... ($i/30)"
            sleep 10
          done
          
          echo "❌ Health check failed"
          exit 1
      
      - name: Post-Deployment Actions
        if: success()
        run: |
          # Notify teams, update monitoring, etc.
          echo "Deployment to ${{ github.event.inputs.environment }} completed successfully"
```

#### Step 4.2: Configure GitHub Secrets

For each environment, add secrets:

**DEV Environment:**
```
DEV_DEPLOYER_ROLE_ARN = arn:aws:iam::DEV-ACCOUNT-ID:role/dev-deployer-role
DEV_SUBSCRIPTION_ID = azure-dev-subscription-id
DEV_CLIENT_ID = azure-dev-app-client-id
DEV_APP_ENDPOINT = https://dev.example.com
```

**STAGE Environment:**
```
STAGE_DEPLOYER_ROLE_ARN = arn:aws:iam::STAGE-ACCOUNT-ID:role/stage-deployer-role
STAGE_SUBSCRIPTION_ID = azure-stage-subscription-id
STAGE_CLIENT_ID = azure-stage-app-client-id
STAGE_APP_ENDPOINT = https://stage.example.com
```

**PROD Environment:**
```
PROD_DEPLOYER_ROLE_ARN = arn:aws:iam::PROD-ACCOUNT-ID:role/prod-deployer-role
PROD_SUBSCRIPTION_ID = azure-prod-subscription-id
PROD_CLIENT_ID = azure-prod-app-client-id
PROD_APP_ENDPOINT = https://prod.example.com
```

### Phase 5: Score File Configuration per Environment

#### Step 5.1: Base Score File (score-humanitec.yaml)

Keep environment-agnostic configuration in the base file.

#### Step 5.2: Environment Overrides

**score-dev.yaml:**
```yaml
workloads:
  beneficiaries:
    resources:
      score-workload:
        params:
          containers:
            main:
              resources:
                limits:
                  memory: 512Mi  # Lower for dev
                  cpu: "0.5"
              variables:
                LOG_LEVEL_ROOT: DEBUG  # More verbose logging
                HIBERNATE_DDL_AUTO: create-drop  # Reset DB
```

**score-stage.yaml:**
```yaml
workloads:
  beneficiaries:
    resources:
      score-workload:
        params:
          containers:
            main:
              resources:
                limits:
                  memory: 1Gi
                  cpu: "1.0"
              variables:
                LOG_LEVEL_ROOT: INFO
                HIBERNATE_DDL_AUTO: update
```

**score-prod.yaml:**
```yaml
workloads:
  beneficiaries:
    resources:
      score-workload:
        params:
          containers:
            main:
              resources:
                limits:
                  memory: 2Gi
                  cpu: "2.0"
              variables:
                LOG_LEVEL_ROOT: WARN  # Minimal logging
                HIBERNATE_DDL_AUTO: validate  # No schema changes
              replicas: 3  # High availability
```

#### Step 5.3: Merge Strategy in Workflow

```bash
# In deployment workflow
score-compose generate score-humanitec.yaml \
  --override score-$ENVIRONMENT.yaml \
  --output docker-compose-$ENVIRONMENT.yml
```

## 🔒 Security Considerations

### 1. Principle of Least Privilege

```
Runner Farm (Utilities Account)
  ↓ Can only AssumeRole with ExternalId
  ↓
Target Account Deployer Role
  ↓ Has permissions ONLY for:
  ↓ - EC2 instance access (SSM)
  ↓ - Docker operations
  ↓ - Application Gateway/ALB updates
  ↓ - CloudWatch/Monitor logging
  ✗ NO permissions for:
    - IAM changes
    - Network changes
    - Account-level operations
```

### 2. Environment Isolation

- **Network**: Separate VPCs/VNets per environment
- **IAM/RBAC**: Separate roles per environment
- **State**: Separate Terraform state files
- **Secrets**: Environment-specific secrets in GitHub

### 3. Audit Trail

Enable logging:
```yaml
AWS:
  - CloudTrail: Cross-account AssumeRole events
  - CloudWatch Logs: Docker deployment logs
  - VPC Flow Logs: Network traffic

Azure:
  - Activity Log: Role assumption events
  - Container Insights: Docker metrics
  - NSG Flow Logs: Network traffic
```

### 4. Approval Gates

Configure GitHub Environments:
```yaml
environments:
  prod:
    protection_rules:
      - reviewers:
          - prod-approvers-team
      - wait_timer: 300  # 5 minute delay
      - deployment_branch_policy:
          protected_branches: true
```

## 📊 Deployment Flow Example

### Scenario: Deploy to STAGE

```
1. Developer triggers workflow:
   gh workflow run deploy-multi-account.yml \
     -f environment=stage \
     -f action=deploy

2. GitHub Actions:
   - Selects runner with labels: [utilities, stage, docker]
   - Runner farm picks up job

3. Runner assumes STAGE account role:
   - Calls AWS STS AssumeRole
   - Gets temporary credentials for STAGE-ACCOUNT
   - Duration: 1 hour

4. Runner discovers STAGE infrastructure:
   - Queries EC2/Azure for docker-host tagged 'stage'
   - Gets private IP: 10.1.2.50

5. Runner prepares deployment:
   - Merges score-humanitec.yaml + score-stage.yaml
   - Generates docker-compose-stage.yml
   - Validates configuration

6. Runner executes deployment:
   AWS:
     - Uploads compose file to S3
     - Uses SSM send-command to docker host
     - Runs: docker compose -f docker-compose-stage.yml up -d
   
   Azure:
     - Uses az vm run-command
     - Uploads compose via blob storage
     - Executes docker compose

7. Verification:
   - Waits for health checks (30 retries)
   - Tests: https://stage.example.com/health
   - Verifies: All services return 200 OK

8. Cleanup:
   - Runner credentials expire after 1 hour
   - Deployment artifacts retained for 30 days
```

## 🎯 Benefits of This Architecture

### ✅ Centralized Management
- Single runner farm for all environments
- Easier to maintain and update runners
- Cost-effective (shared infrastructure)

### ✅ Enhanced Security
- No long-lived credentials in target accounts
- Cross-account roles with external IDs
- Environment isolation via IAM/RBAC
- Audit trail for all deployments

### ✅ Scalability
- Add new environments by:
  1. Creating new target account
  2. Deploying infrastructure
  3. Adding IAM role
  4. Creating GitHub environment
- No changes to runner farm needed

### ✅ Flexibility
- Deploy to any environment from any branch
- Use Score for portable definitions
- Environment-specific overrides
- Support for multiple cloud providers

### ✅ Developer Experience
- Simple workflow dispatch interface
- Consistent deployment process
- Clear environment boundaries
- Self-service deployments (with approvals)

## 🚀 Getting Started Checklist

### Prerequisites
- [ ] Organization with multiple accounts/subscriptions
- [ ] GitHub repository with Actions enabled
- [ ] Terraform installed locally
- [ ] Cloud CLI tools (AWS CLI / Azure CLI)
- [ ] Admin access to all accounts

### Utilities Account Setup
- [ ] Provision runner farm infrastructure
- [ ] Install Docker on runners
- [ ] Register runners with GitHub
- [ ] Configure runner labels
- [ ] Create runner groups

### Target Accounts Setup
- [ ] Create IAM roles for deployment
- [ ] Configure trust relationships
- [ ] Deploy Docker host infrastructure
- [ ] Install Docker and Nginx
- [ ] Test network connectivity

### GitHub Configuration
- [ ] Create environments (dev, stage, prod)
- [ ] Add environment secrets
- [ ] Configure protection rules
- [ ] Add deployment workflow
- [ ] Test workflow execution

### Score Configuration
- [ ] Create base score-humanitec.yaml
- [ ] Create environment overrides
- [ ] Test score-compose generation
- [ ] Validate docker-compose output

### Testing
- [ ] Deploy to dev (no approval)
- [ ] Verify application health
- [ ] Deploy to stage (with approval if configured)
- [ ] Deploy to prod (with mandatory approval)
- [ ] Test teardown/rollback

## 📚 Additional Resources

- [AWS IAM Cross-Account Access](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html)
- [Azure RBAC Cross-Subscription](https://learn.microsoft.com/azure/role-based-access-control/overview)
- [GitHub Actions Environments](https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Score Specification](https://docs.score.dev/)
- [Docker Compose](https://docs.docker.com/compose/)

## 🤝 Support

For implementation assistance:
1. Review this architecture document
2. Consult cloud provider documentation
3. Test in dev environment first
4. Open GitHub issues for questions
5. Schedule architecture review sessions

---

**Last Updated**: November 26, 2025  
**Version**: 1.0  
**Maintainer**: Infrastructure Team
