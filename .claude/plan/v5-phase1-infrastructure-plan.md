# V5 Phase 1: Production Infrastructure Setup - Implementation Plan

**Phase**: Production Infrastructure
**Estimated Duration**: 3-4 hours
**Prerequisites**: V4 Complete, Azure CLI configured, Terraform installed
**Status**: Planning

---

## Overview

This plan details the implementation of production-grade Azure infrastructure including:
- Production environment with high-availability resources
- Staging deployment slots for zero-downtime deployments
- Enhanced PostgreSQL with backups and HA
- Production monitoring and security

---

## Phase 1.1: Terraform Production Configuration

### Step 1: Create Terraform Production Workspace
**Duration**: 15 minutes

#### Actions:
1. Create production workspace structure:
   ```
   infra/terraform/environments/prod/
   ├── main.tf
   ├── variables.tf
   ├── outputs.tf
   └── terraform.tfvars
   ```

2. Initialize Terraform workspace:
   ```bash
   cd infra/terraform/environments/prod
   terraform workspace new production
   terraform init
   ```

3. Configure backend state storage (optional but recommended):
   - Create Azure Storage Account for Terraform state
   - Configure remote backend in `backend.tf`

#### Files to Create:
- `infra/terraform/environments/prod/main.tf` - Main infrastructure
- `infra/terraform/environments/prod/variables.tf` - Variable definitions
- `infra/terraform/environments/prod/terraform.tfvars` - Production values
- `infra/terraform/environments/prod/outputs.tf` - Output values
- `infra/terraform/environments/prod/backend.tf` - Remote state (optional)

---

### Step 2: Configure Production App Service Plan
**Duration**: 20 minutes

#### Resource Specification:
```hcl
resource "azurerm_service_plan" "prod" {
  name                = "mileage-deal-tracker-plan-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = "West US 2"
  os_type             = "Linux"
  sku_name            = "S1"  # Standard tier required for deployment slots
}
```

#### Key Configuration:
- **SKU**: S1 Standard (1 vCPU, 1.75 GB RAM, $69.35/month)
- **Features enabled**:
  - Deployment slots (staging slot)
  - Auto-scaling (1-5 instances)
  - Custom domains
  - SSL certificates
  - Always On

#### Auto-Scaling Rules to Configure:
```hcl
resource "azurerm_monitor_autoscale_setting" "prod_app" {
  name                = "app-autoscale-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = "West US 2"
  target_resource_id  = azurerm_service_plan.prod.id

  profile {
    name = "default"

    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.prod.id
        operator           = "GreaterThan"
        threshold          = 70
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.prod.id
        operator           = "LessThan"
        threshold          = 30
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
```

---

### Step 3: Configure Production PostgreSQL Database
**Duration**: 30 minutes

#### Resource Specification:
```hcl
resource "azurerm_postgresql_flexible_server" "prod" {
  name                   = "mileage-deal-tracker-db-prod"
  resource_group_name    = azurerm_resource_group.prod.name
  location               = "West US 2"
  version                = "14"
  administrator_login    = "dbadmin"
  administrator_password = var.db_admin_password

  sku_name   = "GP_Standard_D2s_v3"  # General Purpose, 2 vCPU, 8 GB RAM
  storage_mb = 32768                  # 32 GB storage

  backup_retention_days        = 30
  geo_redundant_backup_enabled = true

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }
}
```

#### Key Features:
- **SKU**: GP_Standard_D2s_v3 ($153/month)
- **High Availability**: Zone-redundant with automatic failover
- **Backups**: 30-day retention, geo-redundant
- **Storage**: 32 GB with auto-grow enabled
- **Security**: SSL enforced, firewall rules, private endpoint (optional)

#### Backup Configuration:
```hcl
resource "azurerm_postgresql_flexible_server_configuration" "backup" {
  name      = "backup_retention_days"
  server_id = azurerm_postgresql_flexible_server.prod.id
  value     = "30"
}
```

#### Firewall Rules:
```hcl
# Allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.prod.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Production office IP (update as needed)
resource "azurerm_postgresql_flexible_server_firewall_rule" "office" {
  name             = "AllowOfficeIP"
  server_id        = azurerm_postgresql_flexible_server.prod.id
  start_ip_address = var.office_ip
  end_ip_address   = var.office_ip
}
```

---

### Step 4: Configure Production Web App
**Duration**: 20 minutes

#### Resource Specification:
```hcl
resource "azurerm_linux_web_app" "prod" {
  name                = "mileage-deal-tracker-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = "West US 2"
  service_plan_id     = azurerm_service_plan.prod.id

  site_config {
    always_on = true

    application_stack {
      node_version = "18-lts"
    }

    app_command_line = "npm start"
  }

  app_settings = {
    "NODE_ENV"                         = "production"
    "WEBSITE_NODE_DEFAULT_VERSION"     = "18-lts"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"   = "true"
    "WEBSITE_RUN_FROM_PACKAGE"         = "0"
    "DATABASE_URL"                     = "postgresql://..."  # From Key Vault
    "NEXT_PUBLIC_APP_URL"              = "https://mileage-deal-tracker-prod.azurewebsites.net"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.prod.connection_string
  }

  identity {
    type = "SystemAssigned"  # For Key Vault access
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 30
        retention_in_mb   = 100
      }
    }
  }
}
```

---

### Step 5: Configure Storage and Application Insights
**Duration**: 15 minutes

#### Storage Account (Geo-Redundant):
```hcl
resource "azurerm_storage_account" "prod" {
  name                     = "mileagedealtrackerstprod"
  resource_group_name      = azurerm_resource_group.prod.name
  location                 = "West US 2"
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant storage

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "database_backups" {
  name                  = "database-backups"
  storage_account_name  = azurerm_storage_account.prod.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "offer_snapshots" {
  name                  = "offer-snapshots"
  storage_account_name  = azurerm_storage_account.prod.name
  container_access_type = "private"
}
```

#### Application Insights (Enhanced):
```hcl
resource "azurerm_application_insights" "prod" {
  name                = "mileage-deal-tracker-insights-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = "West US 2"
  application_type    = "Node.JS"

  retention_in_days = 90  # Enhanced retention for production

  daily_data_cap_in_gb                  = 10
  daily_data_cap_notifications_disabled = false

  sampling_percentage = 100  # Full sampling for production
}
```

---

## Phase 1.2: Staging Slot Configuration

### Step 1: Create Staging Deployment Slot
**Duration**: 15 minutes

#### Terraform Configuration:
```hcl
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.prod.id

  site_config {
    always_on = true

    application_stack {
      node_version = "18-lts"
    }

    app_command_line = "npm start"
  }

  app_settings = {
    "NODE_ENV"                         = "staging"
    "WEBSITE_NODE_DEFAULT_VERSION"     = "18-lts"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"   = "true"
    "WEBSITE_RUN_FROM_PACKAGE"         = "0"
    "DATABASE_URL"                     = var.staging_database_url
    "NEXT_PUBLIC_APP_URL"              = "https://mileage-deal-tracker-prod-staging.azurewebsites.net"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.prod.connection_string
  }
}
```

#### Slot-Specific Settings:
Settings that DON'T swap (stay with slot):
- `DATABASE_URL` (staging uses separate DB or read-replica)
- `NEXT_PUBLIC_APP_URL` (staging URL)
- `NODE_ENV` (staging vs production)

Settings that DO swap:
- Application code
- App configuration (most settings)
- SSL bindings
- Custom domains

---

### Step 2: Configure Slot Swap Settings
**Duration**: 10 minutes

#### Azure Portal Configuration:
1. Navigate to App Service → Deployment slots
2. Configure sticky settings (settings that don't swap):
   - `DATABASE_URL`
   - `NEXT_PUBLIC_APP_URL`
   - `NODE_ENV`

#### CLI Command:
```bash
az webapp config appsettings set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --slot-settings DATABASE_URL NEXT_PUBLIC_APP_URL NODE_ENV
```

---

### Step 3: Test Slot Swap
**Duration**: 10 minutes

#### Manual Swap Test:
```bash
# 1. Deploy to staging slot
# 2. Verify staging slot is working
curl https://mileage-deal-tracker-prod-staging.azurewebsites.net/api/health

# 3. Perform swap
az webapp deployment slot swap \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --target-slot production

# 4. Verify production after swap
curl https://mileage-deal-tracker-prod.azurewebsites.net/api/health

# 5. Swap back if needed (rollback test)
az webapp deployment slot swap \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot production \
  --target-slot staging
```

---

## Phase 1.3: Production Database Setup

### Step 1: Deploy Database and Configure HA
**Duration**: 30 minutes

#### Database Deployment:
1. Apply Terraform configuration (from Step 3 above)
2. Verify high availability is enabled
3. Confirm backups are configured

#### Verification Commands:
```bash
# Check database status
az postgres flexible-server show \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-db-prod

# Verify HA configuration
az postgres flexible-server show \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-db-prod \
  --query highAvailability

# Check backup retention
az postgres flexible-server show \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-db-prod \
  --query backup.backupRetentionDays
```

---

### Step 2: Apply Database Schema
**Duration**: 15 minutes

#### Schema Migration:
```bash
# Set production database URL
export DATABASE_URL="postgresql://dbadmin:PASSWORD@mileage-deal-tracker-db-prod.postgres.database.azure.com:5432/mileage_tracker_prod?sslmode=require"

# Navigate to web app directory
cd apps/web

# Apply Prisma migrations
npx prisma migrate deploy

# Verify schema
npx prisma db pull
```

---

### Step 3: Load Production Data
**Duration**: 15 minutes

#### Initial Data Loading:
```bash
# Option 1: Fresh seed (for new production)
npx prisma db seed

# Option 2: Migrate from dev (if applicable)
# Export from dev database
pg_dump "$DEV_DATABASE_URL" --data-only > dev_data.sql

# Import to production (carefully!)
psql "$PROD_DATABASE_URL" < dev_data.sql
```

---

## Deployment Execution Plan

### Pre-Deployment Checklist:
- [ ] Terraform installed and configured
- [ ] Azure CLI authenticated with production subscription
- [ ] Production database password generated and stored securely
- [ ] Production environment variables documented
- [ ] Budget alerts configured for cost monitoring
- [ ] Team notified of production infrastructure deployment

### Deployment Steps:

#### Step 1: Validate Terraform Configuration
```bash
cd infra/terraform/environments/prod
terraform validate
terraform plan -out=tfplan
```

#### Step 2: Review and Apply
```bash
# Review the plan
terraform show tfplan

# Apply (creates all resources)
terraform apply tfplan
```

#### Step 3: Configure Post-Deployment Settings
```bash
# Get connection strings
terraform output database_connection_string
terraform output app_service_url

# Configure app settings
az webapp config appsettings set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --settings @prod-settings.json
```

#### Step 4: Verify Deployment
```bash
# Check all resources
az resource list --resource-group mileage-deal-rg-prod --output table

# Test database connection
psql "$PROD_DATABASE_URL" -c "SELECT version();"

# Check app service status
az webapp show \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --query state
```

---

## Cost Estimation

### Monthly Costs (Production):
```
App Service Plan S1:           $69.35
PostgreSQL GP_Standard_D2s_v3: $153.00
Storage Account (GRS):         $5.00
Application Insights:          $20.00
Auto-scaling (avg 1.5x):       ~$35.00
-------------------------------------------
Estimated Monthly Total:       $282.35

With 20% buffer:               ~$340.00/month
```

---

## Rollback Plan

### If Deployment Fails:
1. Review Terraform error messages
2. Check Azure Portal for partially created resources
3. Destroy and recreate:
   ```bash
   terraform destroy -target=specific_resource
   terraform apply
   ```

### If Production Issues Occur:
1. Use staging slot for immediate rollback
2. Database has point-in-time restore (30 days)
3. All configurations in Terraform (infrastructure as code)

---

## Validation Checklist

After deployment, verify:
- [ ] All resources created successfully
- [ ] App Service plan is S1 with auto-scaling enabled
- [ ] PostgreSQL has high availability enabled
- [ ] Database backups configured (30 days, geo-redundant)
- [ ] Staging slot created and accessible
- [ ] Application Insights collecting data
- [ ] Storage containers created
- [ ] Firewall rules allow necessary connections
- [ ] SSL enforced on all connections
- [ ] Cost alerts configured

---

## Next Steps

After Phase 1 completion:
1. Proceed to Phase 2: Enhanced CI/CD Pipeline
2. Configure GitHub Actions for staging/production deployments
3. Set up monitoring and alerts
4. Implement security hardening

#### IMPORTANT RULE TO FOLLOW #### 
Perform the plans specified in this document and prepare result document under ./.claude/result folder.
Also, deployment of this project via CI/CD is not completed yet and perform all the steps specified in this document. No operation rule books need to be prepared yet until the deployment is completed and ready to run. 
Use file name with 'v5-' prepix.  

---

**Plan Created**: 2025-11-08
**Status**: Ready for Implementation
**Estimated Time**: 3-4 hours
