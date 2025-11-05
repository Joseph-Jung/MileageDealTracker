# Mileage Deal Tracker — Azure Deployment Plan

*Version: 1.0*
*Date: 2025-11-05*
*Repository: [MileageDealTracker](https://github.com/Joseph-Jung/MileageDealTracker)*

---

## Executive Summary

This document provides a detailed deployment plan for the **Mileage Deal Tracker** application on **Microsoft Azure**. The plan includes CI/CD pipeline configuration, infrastructure setup, cost estimates, and step-by-step implementation guides.

**Key Objectives:**
- Automate build and deployment with Azure Pipelines
- Host Next.js application on Azure App Service
- Use Azure Database for PostgreSQL for data persistence
- Implement infrastructure as code (optional Terraform)
- Maintain low operational costs (<$50/month)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Azure Resources Required](#2-azure-resources-required)
3. [CI/CD Pipeline Design](#3-cicd-pipeline-design)
4. [Infrastructure Setup](#4-infrastructure-setup)
5. [Environment Configuration](#5-environment-configuration)
6. [Deployment Workflow](#6-deployment-workflow)
7. [Monitoring & Observability](#7-monitoring--observability)
8. [Security Considerations](#8-security-considerations)
9. [Cost Analysis](#9-cost-analysis)
10. [Rollback Strategy](#10-rollback-strategy)
11. [Implementation Checklist](#11-implementation-checklist)
12. [Appendix](#12-appendix)

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Azure Cloud                          │
│                                                              │
│  ┌────────────────────┐        ┌──────────────────────┐    │
│  │  Azure App Service │◄───────┤   Application        │    │
│  │  (Node.js 18)      │        │   Gateway            │    │
│  │                    │        │   (Optional)         │    │
│  │  - Next.js App     │        └──────────────────────┘    │
│  │  - API Routes      │                                     │
│  └─────────┬──────────┘                                     │
│            │                                                 │
│            ▼                                                 │
│  ┌─────────────────────┐       ┌──────────────────────┐    │
│  │  Azure Database for │       │  Azure Blob Storage  │    │
│  │  PostgreSQL         │       │  (Future: snapshots) │    │
│  │  (Flexible Server)  │       └──────────────────────┘    │
│  └─────────────────────┘                                    │
│                                                              │
│  ┌────────────────────┐        ┌──────────────────────┐    │
│  │  Application       │        │  Azure Cache for     │    │
│  │  Insights          │        │  Redis (Phase 2)     │    │
│  │  (Monitoring)      │        └──────────────────────┘    │
│  └────────────────────┘                                     │
└─────────────────────────────────────────────────────────────┘
        ▲
        │
        │ HTTPS
        │
┌───────┴────────┐
│     Users      │
│   (Browser)    │
└────────────────┘
```

### 1.2 Technology Stack

| Layer        | Technology                        | Version  |
|------------- |-----------------------------------|----------|
| **Frontend** | Next.js (App Router)              | 14.x     |
| **Language** | TypeScript                        | 5.3+     |
| **Database** | PostgreSQL                        | 14       |
| **ORM**      | Prisma                           | 5.7+     |
| **Runtime**  | Node.js                           | 18 LTS   |
| **Styling**  | Tailwind CSS                      | 3.4+     |
| **Hosting**  | Azure App Service (Linux)         | -        |

---

## 2. Azure Resources Required

### 2.1 Core Resources

| Resource | Azure Service | SKU/Tier | Purpose |
|----------|--------------|----------|---------|
| **Web App** | Azure App Service | B1 (Basic) | Host Next.js application |
| **Database** | Azure Database for PostgreSQL | B1ms (Burstable) | Data persistence |
| **Monitoring** | Application Insights | Standard | Logs & performance tracking |
| **Storage** | Azure Blob Storage | Standard LRS | Future: Terms snapshots (Phase 2) |
| **Cache** | Azure Cache for Redis | Basic C0 | Future: ETL queue (Phase 2) |

### 2.2 Resource Naming Convention

```
Environment: prod | dev | staging
Region: eastus | westus2

Format: {app-name}-{resource-type}-{environment}

Examples:
- mileage-deal-app-prod
- mileage-deal-db-prod
- mileage-deal-rg-prod
```

### 2.3 Resource Group Structure

```
Resource Group: mileage-deal-rg-prod
├── App Service Plan: mileage-deal-plan-prod
├── App Service: mileage-deal-app-prod
├── PostgreSQL Server: mileage-deal-db-prod
├── Application Insights: mileage-deal-insights-prod
└── Storage Account: mileagedealstore (future)
```

---

## 3. CI/CD Pipeline Design

### 3.1 Pipeline Overview

```
┌─────────────┐      ┌──────────┐      ┌───────────┐      ┌─────────┐
│   Commit    │─────▶│  Build   │─────▶│   Test    │─────▶│ Deploy  │
│  to main    │      │  & Lint  │      │  & Check  │      │ to Azure│
└─────────────┘      └──────────┘      └───────────┘      └─────────┘
```

### 3.2 Pipeline Stages

#### Stage 1: Setup & Dependencies
- Install Node.js 18
- Enable pnpm via corepack
- Install dependencies with frozen lockfile
- Cache node_modules for faster builds

#### Stage 2: Build & Lint
- Run ESLint for code quality
- Type check with TypeScript
- Build Next.js application
- Generate Prisma client

#### Stage 3: Database Setup
- Validate Prisma schema
- Run database migrations
- Optionally run seed script (dev only)

#### Stage 4: Package
- Archive Next.js build output
- Create deployment artifact
- Include necessary runtime files

#### Stage 5: Deploy
- Deploy to Azure App Service
- Restart application
- Verify health check endpoint

### 3.3 Azure Pipeline YAML

**Location:** `.azure-pipelines/azure-pipelines.yml`

```yaml
trigger:
  branches:
    include:
      - main
      - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  NODE_VERSION: '18.x'
  PNPM_VERSION: '8.10.0'

stages:
  - stage: Build
    displayName: 'Build Application'
    jobs:
      - job: BuildJob
        displayName: 'Build and Test'
        steps:
          - checkout: self
            fetchDepth: 1

          - task: NodeTool@0
            inputs:
              versionSpec: $(NODE_VERSION)
            displayName: 'Install Node.js'

          - script: |
              corepack enable
              corepack prepare pnpm@$(PNPM_VERSION) --activate
            displayName: 'Setup pnpm'

          - task: Cache@2
            inputs:
              key: 'pnpm | "$(Agent.OS)" | apps/web/package-lock.json'
              path: 'apps/web/node_modules'
              restoreKeys: |
                pnpm | "$(Agent.OS)"
            displayName: 'Cache node_modules'

          - script: |
              cd apps/web
              pnpm install --frozen-lockfile
            displayName: 'Install dependencies'

          - script: |
              cd apps/web
              pnpm lint
            displayName: 'Run lint'

          - script: |
              cd apps/web
              npx prisma generate
            displayName: 'Generate Prisma Client'

          - script: |
              cd apps/web
              pnpm build
            displayName: 'Build Next.js'

          - task: ArchiveFiles@2
            inputs:
              rootFolderOrFile: 'apps/web'
              includeRootFolder: false
              archiveType: 'zip'
              archiveFile: '$(Build.ArtifactStagingDirectory)/mileage-deal-tracker.zip'
            displayName: 'Archive application'

          - publish: '$(Build.ArtifactStagingDirectory)/mileage-deal-tracker.zip'
            artifact: 'drop'
            displayName: 'Publish artifact'

  - stage: Deploy
    displayName: 'Deploy to Azure'
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployWeb
        displayName: 'Deploy to App Service'
        environment: 'production'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: 'Azure-Service-Connection'
                    appType: 'webAppLinux'
                    appName: 'mileage-deal-app-prod'
                    package: '$(Pipeline.Workspace)/drop/mileage-deal-tracker.zip'
                    runtimeStack: 'NODE|18-lts'
                    startUpCommand: 'cd apps/web && npm start'
                  displayName: 'Deploy to Azure App Service'
```

### 3.4 Branch Strategy

| Branch | Purpose | Deploys To | Auto-Deploy |
|--------|---------|------------|-------------|
| `main` | Production | Production App Service | Yes |
| `develop` | Development | Dev App Service | Yes |
| `feature/*` | Feature development | - | No |
| `hotfix/*` | Emergency fixes | Production (manual) | No |

---

## 4. Infrastructure Setup

### 4.1 Manual Setup (Azure Portal)

#### Step 1: Create Resource Group

```bash
az group create \
  --name mileage-deal-rg-prod \
  --location eastus
```

#### Step 2: Create PostgreSQL Flexible Server

```bash
az postgres flexible-server create \
  --name mileage-deal-db-prod \
  --resource-group mileage-deal-rg-prod \
  --location eastus \
  --admin-user pgadmin \
  --admin-password '<SECURE_PASSWORD>' \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 14 \
  --storage-size 32 \
  --public-access 0.0.0.0-255.255.255.255

# Create database
az postgres flexible-server db create \
  --resource-group mileage-deal-rg-prod \
  --server-name mileage-deal-db-prod \
  --database-name mileage_tracker
```

#### Step 3: Create App Service Plan

```bash
az appservice plan create \
  --name mileage-deal-plan-prod \
  --resource-group mileage-deal-rg-prod \
  --location eastus \
  --is-linux \
  --sku B1
```

#### Step 4: Create Web App

```bash
az webapp create \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod \
  --plan mileage-deal-plan-prod \
  --runtime "NODE|18-lts"

# Configure startup command
az webapp config set \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod \
  --startup-file "cd apps/web && npm start"
```

#### Step 5: Configure Application Settings

```bash
az webapp config appsettings set \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod \
  --settings \
    DATABASE_URL="postgresql://pgadmin:<PASSWORD>@mileage-deal-db-prod.postgres.database.azure.com:5432/mileage_tracker?sslmode=require" \
    NEXT_PUBLIC_APP_URL="https://mileage-deal-app-prod.azurewebsites.net" \
    NODE_ENV="production"
```

#### Step 6: Create Application Insights

```bash
az monitor app-insights component create \
  --app mileage-deal-insights-prod \
  --location eastus \
  --resource-group mileage-deal-rg-prod \
  --application-type web

# Link to Web App
INSIGHTS_KEY=$(az monitor app-insights component show \
  --app mileage-deal-insights-prod \
  --resource-group mileage-deal-rg-prod \
  --query instrumentationKey -o tsv)

az webapp config appsettings set \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod \
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=$INSIGHTS_KEY"
```

### 4.2 Terraform Setup (Optional - Recommended)

**Location:** `infra/terraform/`

**File Structure:**
```
infra/terraform/
├── main.tf                 # Main configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── providers.tf            # Provider configuration
├── modules/
│   ├── app-service/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── database/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── prod.tfvars
    └── dev.tfvars
```

**Main Configuration (main.tf):**

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatemileagedeal"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Application = "MileageDealTracker"
    ManagedBy   = "Terraform"
  }
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-plan-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku

  tags = azurerm_resource_group.main.tags
}

# Web App
resource "azurerm_linux_web_app" "main" {
  name                = "${var.app_name}-app-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on = var.environment == "prod" ? true : false

    application_stack {
      node_version = "18-lts"
    }

    app_command_line = "cd apps/web && npm start"
  }

  app_settings = {
    "DATABASE_URL"             = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}:${var.db_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.main.name}?sslmode=require"
    "NEXT_PUBLIC_APP_URL"      = "https://${var.app_name}-app-${var.environment}.azurewebsites.net"
    "NODE_ENV"                 = "production"
    "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
  }

  https_only = true

  tags = azurerm_resource_group.main.tags
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.app_name}-db-${var.environment}"
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  version                = "14"
  administrator_login    = var.db_admin_user
  administrator_password = var.db_password
  sku_name               = var.db_sku
  storage_mb             = var.db_storage_mb

  tags = azurerm_resource_group.main.tags
}

# Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "mileage_tracker"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Firewall rule for Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.app_name}-insights-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"

  tags = azurerm_resource_group.main.tags
}
```

**Variables (variables.tf):**

```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "mileage-deal-rg-prod"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "app_name" {
  description = "Application name prefix"
  type        = string
  default     = "mileage-deal"
}

variable "app_service_sku" {
  description = "App Service Plan SKU"
  type        = string
  default     = "B1"
}

variable "db_admin_user" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "pgadmin"
}

variable "db_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "db_sku" {
  description = "PostgreSQL SKU"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "db_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}
```

**Outputs (outputs.tf):**

```hcl
output "web_app_url" {
  description = "URL of the deployed web application"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "web_app_name" {
  description = "Name of the web app"
  value       = azurerm_linux_web_app.main.name
}

output "database_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
  description = "Name of the database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}
```

**Terraform Commands:**

```bash
# Initialize
cd infra/terraform
terraform init

# Plan
terraform plan -var-file=environments/prod.tfvars -out=tfplan

# Apply
terraform apply tfplan

# Destroy (if needed)
terraform destroy -var-file=environments/prod.tfvars
```

---

## 5. Environment Configuration

### 5.1 Required Environment Variables

| Variable | Description | Example | Source |
|----------|-------------|---------|--------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:pass@host:5432/db?sslmode=require` | Azure Database |
| `NEXT_PUBLIC_APP_URL` | Public application URL | `https://mileage-deal-app-prod.azurewebsites.net` | App Service |
| `NODE_ENV` | Node environment | `production` | Manual |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Application Insights key | `InstrumentationKey=xxx` | App Insights |

### 5.2 Azure Key Vault Integration (Optional)

Store sensitive values in Azure Key Vault:

```bash
# Create Key Vault
az keyvault create \
  --name mileage-deal-kv-prod \
  --resource-group mileage-deal-rg-prod \
  --location eastus

# Store secrets
az keyvault secret set \
  --vault-name mileage-deal-kv-prod \
  --name DATABASE-PASSWORD \
  --value '<SECURE_PASSWORD>'

# Grant App Service access
az webapp identity assign \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod

PRINCIPAL_ID=$(az webapp identity show \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod \
  --query principalId -o tsv)

az keyvault set-policy \
  --name mileage-deal-kv-prod \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

Reference in App Settings:
```
DATABASE_PASSWORD=@Microsoft.KeyVault(VaultName=mileage-deal-kv-prod;SecretName=DATABASE-PASSWORD)
```

---

## 6. Deployment Workflow

### 6.1 Initial Deployment

```bash
# 1. Setup Azure resources (manual or Terraform)
cd infra/terraform
terraform apply -var-file=environments/prod.tfvars

# 2. Configure Azure Pipeline
# - Add service connection in Azure DevOps
# - Configure pipeline variables

# 3. Push to main branch
git push origin main

# 4. Monitor pipeline execution in Azure DevOps

# 5. Run database migrations
az webapp ssh --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod

# Inside SSH session:
cd apps/web
npx prisma migrate deploy
npx tsx prisma-lib/seed.ts
```

### 6.2 Continuous Deployment

After initial setup, deployments are automatic:

```bash
# Make changes
git add .
git commit -m "Your changes"

# Push to trigger pipeline
git push origin main

# Pipeline automatically:
# 1. Builds application
# 2. Runs tests
# 3. Deploys to Azure
# 4. Restarts application
```

### 6.3 Database Migration Strategy

**Development:**
```bash
# Create migration
npx prisma migrate dev --name add_new_field

# Push changes
git add prisma/migrations
git commit -m "Add new field migration"
```

**Production:**
```bash
# Migrations run automatically in CI/CD pipeline
npx prisma migrate deploy
```

---

## 7. Monitoring & Observability

### 7.1 Application Insights Metrics

**Automatic Tracking:**
- HTTP requests and responses
- Dependency calls (database queries)
- Exceptions and errors
- Custom events and metrics

**Custom Metrics:**

```typescript
// apps/web/src/lib/telemetry.ts
import { TelemetryClient } from 'applicationinsights';

const client = new TelemetryClient();

export function trackOfferView(offerId: string) {
  client.trackEvent({
    name: 'OfferViewed',
    properties: { offerId }
  });
}

export function trackAPIError(error: Error) {
  client.trackException({ exception: error });
}
```

### 7.2 Alerts Configuration

**Critical Alerts:**
- Response time > 3 seconds
- Error rate > 5%
- Database connection failures
- Application downtime

**Setup via Azure CLI:**

```bash
az monitor metrics alert create \
  --name high-response-time \
  --resource-group mileage-deal-rg-prod \
  --scopes $(az webapp show \
    --name mileage-deal-app-prod \
    --resource-group mileage-deal-rg-prod \
    --query id -o tsv) \
  --condition "avg requests/duration > 3000" \
  --description "Alert when response time exceeds 3s"
```

### 7.3 Logging Strategy

**Log Levels:**
- ERROR: Application errors
- WARN: Degraded performance
- INFO: Important events (offer updates)
- DEBUG: Detailed debugging info (dev only)

**Log Aggregation:**
```typescript
// Use Application Insights for centralized logging
import { setup } from 'applicationinsights';

setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
  .setAutoCollectConsole(true)
  .start();
```

---

## 8. Security Considerations

### 8.1 Network Security

- **SSL/TLS:** Enforce HTTPS only
- **Firewall:** Restrict database access to Azure services
- **VNet Integration:** (Phase 2) Isolate App Service in private network

### 8.2 Authentication & Authorization

- **Admin Access:** Use Azure AD integration (Phase 2)
- **API Keys:** Store in Azure Key Vault
- **Database Credentials:** Rotate regularly, store in Key Vault

### 8.3 Data Protection

- **Encryption at Rest:** Enabled by default on Azure services
- **Encryption in Transit:** PostgreSQL SSL mode required
- **Backup Strategy:** Automated daily backups (7-day retention)

### 8.4 Compliance

- **GDPR:** Data deletion capabilities in subscriber management
- **PCI DSS:** N/A (no payment processing)
- **SOC 2:** Azure compliant infrastructure

---

## 9. Cost Analysis

### 9.1 Monthly Cost Breakdown (Production)

| Service | SKU | Monthly Cost | Notes |
|---------|-----|--------------|-------|
| **App Service Plan** | B1 (1 vCPU, 1.75GB RAM) | $13.14 | Linux, always-on |
| **PostgreSQL** | B1ms (1 vCPU, 2GB RAM, 32GB storage) | $27.30 | Flexible server |
| **Application Insights** | Standard | $2.88 | First 5GB free |
| **Storage Account** | Standard LRS | $0.50 | Phase 2 |
| **Redis Cache** | Basic C0 | $16.06 | Phase 2 |
| **Bandwidth** | Outbound data transfer | ~$2.00 | First 100GB at $0.087/GB |
| **Total (Phase 1)** | | **~$43/month** | |
| **Total (Phase 2)** | | **~$62/month** | With Redis + Storage |

### 9.2 Cost Optimization Tips

1. **Use Burstable Database Tier:** B1ms auto-scales for traffic spikes
2. **Enable Auto-Pause:** For dev environments, pause when not in use
3. **Reserved Instances:** Save 30-50% with 1-3 year commitments
4. **Right-Size Resources:** Monitor and adjust based on actual usage
5. **Cleanup Dev Resources:** Delete dev environments outside work hours

### 9.3 Scaling Cost Projections

| Traffic Level | Users/Day | Estimated Cost |
|---------------|-----------|----------------|
| **MVP** | <1,000 | $43/month |
| **Growth** | 1,000-10,000 | $100-150/month |
| **Scale** | 10,000-100,000 | $300-500/month |

---

## 10. Rollback Strategy

### 10.1 Application Rollback

**Option 1: Redeploy Previous Artifact**
```bash
# List previous deployments
az webapp deployment list \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod

# Restore specific deployment
az webapp deployment slot swap \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod \
  --slot staging \
  --target-slot production
```

**Option 2: Git Revert**
```bash
# Revert last commit
git revert HEAD
git push origin main

# Pipeline will automatically deploy reverted version
```

### 10.2 Database Rollback

**Prisma Migration Rollback:**
```bash
# View migration history
npx prisma migrate status

# Rollback last migration
npx prisma migrate resolve --rolled-back <migration_name>

# Apply compensating migration
npx prisma migrate dev --name revert_changes
npx prisma migrate deploy
```

**Point-in-Time Restore:**
```bash
# Restore database to specific timestamp
az postgres flexible-server restore \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-db-prod-restored \
  --source-server mileage-deal-db-prod \
  --restore-time "2025-11-05T12:00:00Z"
```

### 10.3 Rollback Checklist

- [ ] Identify issue and decide on rollback
- [ ] Notify team via communication channel
- [ ] Execute rollback procedure
- [ ] Verify application functionality
- [ ] Check database integrity
- [ ] Monitor metrics post-rollback
- [ ] Document incident for post-mortem

---

## 11. Implementation Checklist

### Phase 1: Infrastructure Setup

- [ ] Create Azure subscription (if not exists)
- [ ] Set up billing alerts
- [ ] Create service principal for Terraform
- [ ] Initialize Terraform state storage
- [ ] Create resource group
- [ ] Provision PostgreSQL database
- [ ] Create App Service plan
- [ ] Create Web App
- [ ] Configure Application Insights
- [ ] Set up Key Vault for secrets

### Phase 2: CI/CD Configuration

- [ ] Create Azure DevOps project
- [ ] Set up service connection to Azure
- [ ] Create pipeline from YAML file
- [ ] Configure pipeline variables
- [ ] Set up variable groups for secrets
- [ ] Create dev and prod environments
- [ ] Configure approval gates (optional)
- [ ] Test pipeline with sample commit

### Phase 3: Application Configuration

- [ ] Update package.json scripts for Azure
- [ ] Configure database connection string
- [ ] Set up Application Insights SDK
- [ ] Add health check endpoint
- [ ] Configure logging
- [ ] Set up error handling
- [ ] Add production optimizations

### Phase 4: Database Migration

- [ ] Run Prisma migrations on production database
- [ ] Verify schema integrity
- [ ] Run seed script (if applicable)
- [ ] Test database connectivity from app
- [ ] Set up automated backups
- [ ] Configure backup retention policy

### Phase 5: Deployment & Testing

- [ ] Deploy application to Azure
- [ ] Verify application starts successfully
- [ ] Test all API endpoints
- [ ] Test database operations
- [ ] Verify monitoring data in Application Insights
- [ ] Load test with realistic traffic
- [ ] Security scan (OWASP, etc.)

### Phase 6: Go-Live

- [ ] Configure custom domain (if applicable)
- [ ] Set up SSL certificate
- [ ] Configure DNS records
- [ ] Enable HTTPS redirect
- [ ] Final smoke test in production
- [ ] Monitor for 24 hours
- [ ] Document any issues
- [ ] Celebrate launch! 🎉

---

## 12. Appendix

### A. Azure CLI Quick Reference

```bash
# Login
az login

# Set subscription
az account set --subscription "Subscription Name"

# List resources
az resource list --resource-group mileage-deal-rg-prod

# Restart web app
az webapp restart \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod

# View logs
az webapp log tail \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod

# SSH into web app
az webapp ssh \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod
```

### B. Troubleshooting Guide

**Issue: Application fails to start**
```bash
# Check logs
az webapp log tail --name mileage-deal-app-prod --resource-group mileage-deal-rg-prod

# Common causes:
# - Missing environment variables
# - Database connection failure
# - Node.js version mismatch
```

**Issue: Database connection timeout**
```bash
# Check firewall rules
az postgres flexible-server firewall-rule list \
  --server-name mileage-deal-db-prod \
  --resource-group mileage-deal-rg-prod

# Add App Service IPs to firewall
az webapp show \
  --name mileage-deal-app-prod \
  --resource-group mileage-deal-rg-prod \
  --query possibleOutboundIpAddresses
```

**Issue: 500 errors in production**
```bash
# Check Application Insights
az monitor app-insights query \
  --app mileage-deal-insights-prod \
  --analytics-query "exceptions | where timestamp > ago(1h)"
```

### C. Performance Optimization Checklist

- [ ] Enable response compression
- [ ] Configure CDN for static assets (Phase 2)
- [ ] Optimize database queries with indexes
- [ ] Implement caching strategy
- [ ] Use connection pooling for database
- [ ] Minify and bundle JavaScript
- [ ] Optimize images (WebP, lazy loading)
- [ ] Enable HTTP/2
- [ ] Configure browser caching headers

### D. Security Hardening Checklist

- [ ] Enable Azure Security Center
- [ ] Configure SSL/TLS 1.2 minimum
- [ ] Disable FTP access
- [ ] Enable managed identity for Key Vault
- [ ] Configure CORS policies
- [ ] Enable DDoS protection (if high traffic)
- [ ] Set up Web Application Firewall (optional)
- [ ] Regular security patching
- [ ] Implement rate limiting
- [ ] Add security headers (CSP, HSTS, etc.)

### E. Disaster Recovery Plan

**RTO (Recovery Time Objective):** 4 hours
**RPO (Recovery Point Objective):** 1 hour (automated backups)

**Backup Strategy:**
- Database: Automated daily backups (7-day retention)
- Application: Git repository (GitHub)
- Configuration: Terraform state

**Recovery Procedure:**
1. Provision new infrastructure with Terraform
2. Restore database from latest backup
3. Deploy application from Git
4. Update DNS records (if needed)
5. Verify functionality
6. Restore service

---

## Conclusion

This deployment plan provides a comprehensive guide for deploying the **Mileage Deal Tracker** to Microsoft Azure with:

✅ **Automated CI/CD** with Azure Pipelines
✅ **Infrastructure as Code** with Terraform
✅ **Production-ready** monitoring and logging
✅ **Cost-effective** hosting (<$50/month)
✅ **Secure** configuration with Key Vault
✅ **Scalable** architecture for future growth

**Next Steps:**
1. Review and approve this plan with stakeholders
2. Set up Azure subscription and billing
3. Execute Phase 1: Infrastructure Setup
4. Follow implementation checklist
5. Deploy MVP to production

#### IMPORTANT RULE TO FOLLOW #### 
Perform the plans specified in this document and prepare result document under ./.claude/result folder.

---

*Document Version: 1.0*
*Last Updated: 2025-11-05*
*Author: Claude (AI Assistant)*
*Status: Ready for Implementation*
