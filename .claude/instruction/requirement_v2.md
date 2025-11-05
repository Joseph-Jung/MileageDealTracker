I wasn’t able to directly open the GitHub link you provided — I can only “click into” URLs you explicitly share, not browse arbitrary ones.

However, based on your detailed implementation summary and your goal to deploy the **Mileage Deal Tracker** (Turborepo monorepo with Prisma/PostgreSQL backend and planned Next.js frontend), here’s a **proposed `deployment-requirements.md`** that defines an **Azure CI/CD pipeline** setup — with an optional Terraform section (only if infrastructure-as-code is desired).

---

# Mileage Deal Tracker — Deployment Requirements (Azure CI/CD)

*Version: 1.0 – Draft Proposal*
*Date: 2025-11-05*
*Repository: [MileageDealTracker](https://github.com/Joseph-Jung/MileageDealTracker)*

---

## 1. Overview

This document defines the **deployment requirements and CI/CD pipeline design** for the **Mileage Deal Tracker** monorepo.
The pipeline will automate:

* Continuous integration (build, lint, type-check, Prisma migration validation)
* Continuous deployment (to Azure Web App or Container App)
* Optional infrastructure provisioning with Terraform

---

## 2. Target Hosting Options

| Option                             | Description                              | Recommended Use                       | Complexity |
| ---------------------------------- | ---------------------------------------- | ------------------------------------- | ---------- |
| **Azure Web App (Node.js)**        | Easiest for hosting Next.js + API Routes | Recommended for MVP                   | ⭐️         |
| **Azure Container Apps**           | Deploy via Docker container              | For scalable, containerized workloads | ⭐️⭐️       |
| **Azure Kubernetes Service (AKS)** | Full cluster orchestration               | Overkill for this project             | ⭐️⭐️⭐️⭐️   |

**Recommendation:**
Use **Azure Web App for Containers** or standard **Azure App Service (Node.js runtime)** to deploy both frontend and API.
Use **Azure Database for PostgreSQL Flexible Server** for the Prisma backend.

---

## 3. Azure CI/CD Pipeline (YAML Outline)

### 3.1 Folder: `.azure-pipelines/azure-pipelines.yml`

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: ubuntu-latest

variables:
  NODE_VERSION: '18.x'
  DATABASE_URL: $(DATABASE_URL)

steps:
  - checkout: self

  - task: NodeTool@0
    inputs:
      versionSpec: $(NODE_VERSION)
    displayName: 'Install Node.js'

  - script: |
      corepack enable
      corepack prepare pnpm@8.10.0 --activate
      pnpm install --frozen-lockfile
    displayName: 'Install dependencies with pnpm'

  - script: |
      pnpm lint
      pnpm build
    displayName: 'Build project'

  - script: |
      cd packages/database
      pnpm db:generate
      pnpm db:push
      pnpm db:seed
    displayName: 'Run Prisma setup'

  - task: ArchiveFiles@2
    inputs:
      rootFolderOrFile: 'apps/web/.next'
      includeRootFolder: false
      archiveType: 'zip'
      archiveFile: '$(Build.ArtifactStagingDirectory)/web.zip'
    displayName: 'Package Next.js app'

  - publish: '$(Build.ArtifactStagingDirectory)/web.zip'
    artifact: drop
    displayName: 'Publish artifact'

  - task: AzureWebApp@1
    inputs:
      azureSubscription: 'AzureConnectionName'
      appName: 'mileage-deal-tracker'
      package: '$(Pipeline.Workspace)/drop/web.zip'
    displayName: 'Deploy to Azure Web App'
```

### 3.2 Pipeline Stages

| Stage        | Description                      | Example Output               |
| ------------ | -------------------------------- | ---------------------------- |
| **Build**    | Run `pnpm install`, `pnpm build` | Linted and compiled code     |
| **Database** | Apply Prisma migrations          | PostgreSQL tables up-to-date |
| **Package**  | Zip Next.js build                | `web.zip` artifact           |
| **Deploy**   | Publish artifact to Azure        | Production ready app         |

---

## 4. Azure Resource Requirements

| Resource               | Suggested Service             | Notes                    |
| ---------------------- | ----------------------------- | ------------------------ |
| **App Hosting**        | Azure App Service (Linux)     | Node.js 18 runtime       |
| **Database**           | Azure Database for PostgreSQL | Single flexible server   |
| **Storage (optional)** | Azure Blob Storage            | Future: snapshot archive |
| **Redis (future)**     | Azure Cache for Redis         | For ETL queue (Phase 2)  |
| **Monitoring**         | Application Insights          | Logs + error tracking    |

---

## 5. Secrets & Configuration

Add the following to **Azure Pipeline → Library → Variable Group** or **Azure App Service → Configuration**:

| Key                   | Value                        | Source         |
| --------------------- | ---------------------------- | -------------- |
| `DATABASE_URL`        | PostgreSQL connection string | Azure Database |
| `NEXT_PUBLIC_APP_URL` | App base URL                 | App Service    |
| `API_BASE_URL`        | API base URL                 | App Service    |
| `SENTRY_DSN`          | Optional                     | Sentry         |
| `POSTMARK_API_KEY`    | Optional                     | Postmark       |

---

## 6. Optional: Terraform Infrastructure as Code

Terraform is **optional** but beneficial if you plan multi-environment deployments (staging, production).

### 6.1 Folder: `infra/`

```
infra/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
```

### 6.2 Example Terraform Setup

```hcl
terraform {
  required_version = ">=1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.100.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "mileage-deal-rg"
  location = "East US"
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                = "mileage-deal-db"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  administrator_login = "postgres"
  administrator_password = var.db_password
  version             = "14"
  storage_mb          = 32768
  sku_name            = "Standard_B1ms"
}

resource "azurerm_app_service_plan" "plan" {
  name                = "mileage-deal-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true
  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_app_service" "app" {
  name                = "mileage-deal-tracker"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.plan.id

  site_config {
    linux_fx_version = "NODE|18-lts"
  }

  app_settings = {
    DATABASE_URL = "postgresql://${azurerm_postgresql_flexible_server.db.administrator_login}:${var.db_password}@${azurerm_postgresql_flexible_server.db.name}.postgres.database.azure.com:5432/mileage_tracker"
  }
}
```

### 6.3 Terraform Variables (`variables.tf`)

```hcl
variable "db_password" {
  type        = string
  description = "Password for PostgreSQL admin"
  sensitive   = true
}
```

### 6.4 CI/CD Integration

In Azure Pipeline:

```yaml
- task: TerraformInstaller@1
  inputs:
    terraformVersion: '1.6.0'

- script: |
    cd infra
    terraform init
    terraform plan -out=tfplan
    terraform apply -auto-approve tfplan
  displayName: 'Provision Infrastructure'
```

---

## 7. Deployment Environments

| Environment | Branch | App Name                 | Database            | Notes            |
| ----------- | ------ | ------------------------ | ------------------- | ---------------- |
| **Dev**     | `dev`  | mileage-deal-tracker-dev | mileage-deal-db-dev | Test environment |
| **Prod**    | `main` | mileage-deal-tracker     | mileage-deal-db     | Production app   |

---

## 8. Rollback Strategy

1. Maintain build artifacts in Azure DevOps.
2. Roll back via **“Redeploy previous artifact”** in App Service.
3. Keep schema migrations versioned with Prisma.
4. Optionally use Terraform workspaces for safe rollback of infra.

---

## 9. Cost Estimate (Low-Cost Setup)

| Component               | Service         | Monthly Cost (Approx.) |
| ----------------------- | --------------- | ---------------------- |
| Azure App Service (B1)  | Node.js Web App | $10–15                 |
| Azure PostgreSQL (B1ms) | DB instance     | $25–30                 |
| Application Insights    | Monitoring      | $5                     |
| Total                   |                 | **$40–50/month**       |

---

## 10. Summary

* ✅ CI/CD automated with Azure Pipeline YAML
* ✅ Type-safe deployment validated via Prisma
* ✅ Environment variables secured via Azure Secrets
* ⚙️ Optional: Terraform for infra reproducibility
* 🧠 Next Step: Connect frontend + API builds to same pipeline


#### IMPORTANT RULE TO FOLLOW #### 
Do not make code change or propose code but prepare plan document under ./.claude/plan folder.