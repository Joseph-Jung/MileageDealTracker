# V4 Azure Deployment Execution Plan

**Version**: 4.0
**Date**: 2025-11-06
**Purpose**: Practical execution guide for deploying Mileage Deal Tracker to Azure
**Based on**: requirement_v4.md
**Status**: Ready to Execute

---

## Executive Summary

This plan provides step-by-step instructions for executing the Azure deployment of the Mileage Deal Tracker application. Unlike the v3 plan which focused on prerequisites, this v4 plan assumes all validation is complete and focuses on actual execution.

**Prerequisites Verified** (from v3):
- ✅ All tools installed (Azure CLI, Terraform, Node.js, PostgreSQL)
- ✅ Azure account authenticated (Subscription: 2c1424c4-7dd7-4e83-a0ce-98cceda941bc)
- ✅ Infrastructure code validated
- ✅ GitHub repository up to date

**Deployment Strategy**: Start with Development environment, validate thoroughly, then proceed to Production

**Estimated Time**:
- Development deployment: 4-6 hours
- Validation period: 7 days
- Production deployment: 2-3 hours

---

## Table of Contents

1. [Quick Start Guide](#1-quick-start-guide)
2. [Phase 1: Service Principal and Terraform Setup](#2-phase-1-service-principal-and-terraform-setup)
3. [Phase 2: Infrastructure Deployment](#3-phase-2-infrastructure-deployment)
4. [Phase 3: Database Setup](#4-phase-3-database-setup)
5. [Phase 4: Application Deployment](#5-phase-4-application-deployment)
6. [Phase 5: Verification and Testing](#6-phase-5-verification-and-testing)
7. [Phase 6: Monitoring Configuration](#7-phase-6-monitoring-configuration)
8. [Phase 7: Backup and Operations](#8-phase-7-backup-and-operations)
9. [Production Deployment](#9-production-deployment)
10. [Troubleshooting Guide](#10-troubleshooting-guide)

---

## 1. Quick Start Guide

### 1.1 Before You Begin

**Time Required**: 5 minutes

**Prepare the Following**:
1. **Strong Database Password**:
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, special characters
   - Store in password manager
   - Example format: `MileageTracker2025!Dev#`

2. **Your Public IP Address**:
   ```bash
   curl -s ifconfig.me
   ```
   Save this - you'll need it for database access

3. **Clear Time Block**: Reserve 4-6 uninterrupted hours for initial deployment

4. **Open Tabs**:
   - Azure Portal: https://portal.azure.com
   - GitHub Repo: https://github.com/Joseph-Jung/MileageDealTracker
   - This plan document

### 1.2 Environment Decision

**Choose Your Deployment Target**:

| Factor | Development | Production |
|--------|-------------|------------|
| **Cost** | ~$29/month | ~$43/month |
| **Can Stop?** | Yes | No (always-on) |
| **Resources** | B1 (basic) | B2 (standard) |
| **Use Case** | Testing, validation | Live users |
| **Recommendation** | ✅ Start here | Deploy after 7-day validation |

**Decision**: Proceed with **Development** environment first

### 1.3 One-Command Quick Start

If you want to execute all commands in sequence (not recommended for first deployment):

```bash
# WARNING: Run this only if you're experienced with Azure and Terraform
# For first-time deployment, follow the detailed steps below instead

cd /Users/joseph/Playground/MileageTracking
export DEPLOYMENT_ENV="dev"
export DB_PASSWORD="YourStrongPassword123!"
export MY_IP=$(curl -s ifconfig.me)

# This will execute all phases - use with caution
./infra/scripts/full-deployment.sh $DEPLOYMENT_ENV
```

**Recommendation**: Follow the detailed phase-by-phase approach below for better control and understanding.

---

## 2. Phase 1: Service Principal and Terraform Setup

**Time Required**: 15-20 minutes
**Goal**: Create Azure service principal and configure Terraform authentication

### 2.1 Create Service Principal

**Step 1**: Create the service principal

```bash
# This creates a service principal with Contributor role
az ad sp create-for-rbac \
  --name "terraform-mileage-tracker-$(date +%s)" \
  --role="Contributor" \
  --scopes="/subscriptions/2c1424c4-7dd7-4e83-a0ce-98cceda941bc"
```

**Expected Output**:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "terraform-mileage-tracker-1730889234",
  "password": "your-secret-password-here",
  "tenant": "c824a931-f293-4def-8305-3d91ef6ce43e"
}
```

**Step 2**: Save these credentials securely

⚠️ **CRITICAL**: Copy this output immediately! The password is shown only once.

Save to password manager with these fields:
- Service Principal Name: (displayName value)
- App ID (Client ID): (appId value)
- Password (Client Secret): (password value)
- Tenant ID: (tenant value)
- Subscription ID: 2c1424c4-7dd7-4e83-a0ce-98cceda941bc

### 2.2 Configure Environment Variables

**Step 3**: Create credential file

```bash
cat > ~/azure-terraform-creds.sh << 'EOF'
# Azure Service Principal Credentials for Terraform
# Created: $(date)
# KEEP THIS FILE SECURE - chmod 600

export ARM_CLIENT_ID="paste-appId-here"
export ARM_CLIENT_SECRET="paste-password-here"
export ARM_TENANT_ID="c824a931-f293-4def-8305-3d91ef6ce43e"
export ARM_SUBSCRIPTION_ID="2c1424c4-7dd7-4e83-a0ce-98cceda941bc"

echo "✓ Azure credentials loaded"
EOF

# Secure the file
chmod 600 ~/azure-terraform-creds.sh
```

**Step 4**: Edit the file and replace placeholders

```bash
nano ~/azure-terraform-creds.sh
# Or use your preferred editor:
# code ~/azure-terraform-creds.sh
# vim ~/azure-terraform-creds.sh
```

Replace:
- `paste-appId-here` with your actual appId
- `paste-password-here` with your actual password

**Step 5**: Load the credentials

```bash
source ~/azure-terraform-creds.sh
```

**Step 6**: Verify credentials

```bash
# Check all variables are set
echo "Client ID: ${ARM_CLIENT_ID:0:8}..."
echo "Tenant ID: ${ARM_TENANT_ID:0:8}..."
echo "Subscription ID: ${ARM_SUBSCRIPTION_ID:0:8}..."
echo "Secret: [${#ARM_CLIENT_SECRET} characters]"

# All should show values, not empty
```

### 2.3 Test Service Principal

**Step 7**: Login using service principal

```bash
az login --service-principal \
  -u $ARM_CLIENT_ID \
  -p $ARM_CLIENT_SECRET \
  --tenant $ARM_TENANT_ID
```

**Expected Output**: Login successful message

**Step 8**: Verify access

```bash
az account show
az group list --output table
```

**Checkpoint**:
- [ ] Service principal created
- [ ] Credentials saved securely
- [ ] Environment variables set
- [ ] Service principal login successful
- [ ] Azure access verified

---

## 3. Phase 2: Infrastructure Deployment

**Time Required**: 30-45 minutes
**Goal**: Deploy all Azure resources using Terraform

### 3.1 Prepare Terraform Configuration

**Step 1**: Navigate to Terraform directory

```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform
```

**Step 2**: Load Azure credentials (if not already loaded)

```bash
source ~/azure-terraform-creds.sh
```

**Step 3**: Get your public IP

```bash
export MY_IP=$(curl -s ifconfig.me)
echo "Your IP: $MY_IP"
```

**Step 4**: Create terraform.tfvars for development

```bash
cat > terraform.tfvars << EOF
# Mileage Deal Tracker - Development Environment
# Created: $(date)

environment         = "dev"
resource_group_name = "mileage-deal-rg-dev"
app_name            = "mileage-deal-tracker"
location            = "East US"

# Database Configuration
db_name             = "mileage_tracker_dev"
db_admin_username   = "dbadmin"
db_admin_password   = "REPLACE_WITH_YOUR_PASSWORD"
db_storage_mb       = 32768
db_sku_name         = "B_Standard_B1ms"

# App Service Configuration
app_service_sku     = "B1"

# Security
allowed_ip_address  = "$MY_IP"

# Tags
tags = {
  Environment = "Development"
  Project     = "MileageDealTracker"
  Owner       = "joseph"
  ManagedBy   = "Terraform"
}
EOF

echo "✓ terraform.tfvars created"
```

**Step 5**: Set your database password

```bash
# Edit terraform.tfvars and replace REPLACE_WITH_YOUR_PASSWORD
nano terraform.tfvars

# Look for this line:
# db_admin_password   = "REPLACE_WITH_YOUR_PASSWORD"
# Change it to your actual password, e.g.:
# db_admin_password   = "MileageTracker2025!Dev#"
```

**Important**: Your password must meet Azure PostgreSQL requirements:
- At least 8 characters
- Contains uppercase, lowercase, and numbers
- May contain special characters: ! # $ % etc.

### 3.2 Initialize Terraform

**Step 6**: Initialize Terraform (first time only)

```bash
terraform init
```

**Expected Output**:
```
Initializing the backend...
Initializing provider plugins...
- Installing hashicorp/azurerm v3.100.0...
Terraform has been successfully initialized!
```

**If you see errors about backend**, edit `main.tf`:
```bash
# Temporarily comment out the backend block for initial deployment
nano main.tf

# Find these lines around line 13-18:
#   backend "azurerm" {
#     resource_group_name  = "tfstate-rg"
#     storage_account_name = "mileagetfstate"
#     container_name       = "tfstate"
#     key                  = "mileage-tracker.tfstate"
#   }

# Add # at the beginning of each line to comment them out
```

### 3.3 Validate Configuration

**Step 7**: Validate Terraform syntax

```bash
terraform validate
```

**Expected Output**: `Success! The configuration is valid.`

**Step 8**: Format Terraform files

```bash
terraform fmt
```

### 3.4 Plan Infrastructure

**Step 9**: Create deployment plan

```bash
terraform plan -out=tfplan-dev-$(date +%Y%m%d).tfplan
```

**Expected Output**:
```
Terraform will perform the following actions:

  # azurerm_application_insights.insights will be created
  # azurerm_linux_web_app.app will be created
  # azurerm_postgresql_flexible_server.db will be created
  # azurerm_postgresql_flexible_server_database.main_db will be created
  # azurerm_postgresql_flexible_server_firewall_rule.allow_office_ip will be created
  # azurerm_postgresql_flexible_server_firewall_rule.azure_services will be created
  # azurerm_resource_group.rg will be created
  # azurerm_service_plan.plan will be created
  # azurerm_storage_account.storage will be created
  # azurerm_storage_container.backups will be created
  # azurerm_storage_container.snapshots will be created

Plan: 11 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + app_service_name                       = "mileage-deal-tracker-dev"
  + app_service_url                        = (known after apply)
  + application_insights_connection_string = (sensitive value)
  + application_insights_instrumentation_key = (sensitive value)
  + backup_container_name                  = "database-backups"
  + database_connection_string             = (sensitive value)
  + postgresql_database_name               = "mileage_tracker_dev"
  + postgresql_server_fqdn                 = (known after apply)
  + postgresql_server_name                 = "mileage-deal-tracker-db-dev"
  + resource_group_location                = "eastus"
  + resource_group_name                    = "mileage-deal-rg-dev"
  + snapshot_container_name                = "offer-snapshots"
  + storage_account_name                   = (known after apply)
  + storage_account_primary_connection_string = (sensitive value)
```

**Step 10**: Review the plan carefully

Check for:
- ✅ 11 resources to be created (none to change or destroy)
- ✅ Resource names match expectations
- ✅ Location is "East US"
- ✅ SKU sizes are correct (B1, B1ms)
- ✅ No unexpected resources

**If something looks wrong**: Edit `terraform.tfvars` and run `terraform plan` again

### 3.5 Apply Infrastructure

**Step 11**: Deploy infrastructure

```bash
# This will take 10-15 minutes
terraform apply tfplan-dev-$(date +%Y%m%d).tfplan
```

**Expected Duration**: 10-15 minutes

**Progress Updates You'll See**:
```
azurerm_resource_group.rg: Creating...
azurerm_resource_group.rg: Creation complete after 2s

azurerm_service_plan.plan: Creating...
azurerm_postgresql_flexible_server.db: Creating...
azurerm_storage_account.storage: Creating...

... (continues for each resource) ...

Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:
app_service_url = "https://mileage-deal-tracker-dev.azurewebsites.net"
postgresql_server_fqdn = "mileage-deal-tracker-db-dev.postgres.database.azure.com"
...
```

**Step 12**: Save outputs

```bash
terraform output > outputs-dev-$(date +%Y%m%d).txt
terraform output -json > outputs-dev-$(date +%Y%m%d).json

# Display key information
echo "=== Deployment Complete ==="
terraform output app_service_url
terraform output postgresql_server_fqdn
terraform output resource_group_name
```

**Step 13**: Extract important values

```bash
# Save these as environment variables for next phases
export APP_URL=$(terraform output -raw app_service_url)
export DB_HOST=$(terraform output -raw postgresql_server_fqdn)
export DB_NAME=$(terraform output -raw postgresql_database_name)
export RG_NAME=$(terraform output -raw resource_group_name)

echo "App URL: $APP_URL"
echo "Database: $DB_HOST"
```

### 3.6 Verify Resources in Azure Portal

**Step 14**: Open Azure Portal

Navigate to: https://portal.azure.com

**Step 15**: Verify resource group

1. Search for "Resource groups"
2. Find "mileage-deal-rg-dev"
3. Click to open

**Should see 11 resources**:
- mileage-deal-tracker-db-dev (PostgreSQL flexible server)
- mileage-deal-tracker-dev (App Service)
- mileage-deal-plan-dev (App Service plan)
- mileage-deal-tracker-insights-dev (Application Insights)
- mileagedealtrackerstdev (Storage account)

**Step 16**: Check resource status

Click on each resource and verify:
- PostgreSQL: Status should be "Available"
- App Service: Status should be "Running" (may show default page)
- App Service Plan: Status should be "Running"
- Application Insights: Should be created
- Storage Account: Should be accessible

### 3.7 Phase Checkpoint

**Verify before proceeding**:
- [ ] Terraform apply completed successfully (11 resources added)
- [ ] All outputs saved to files
- [ ] Environment variables set (APP_URL, DB_HOST, etc.)
- [ ] Resource group visible in Azure Portal
- [ ] PostgreSQL status: Available
- [ ] App Service status: Running
- [ ] No errors in Terraform output

**If any checks fail**: See [Troubleshooting Guide](#10-troubleshooting-guide)

---

## 4. Phase 3: Database Setup

**Time Required**: 20-30 minutes
**Goal**: Configure database, run migrations, seed data

### 4.1 Configure Database Connection

**Step 1**: Build DATABASE_URL

```bash
cd /Users/joseph/Playground/MileageTracking

# Get values from Terraform
export DB_USER=$(grep db_admin_username infra/terraform/terraform.tfvars | cut -d'"' -f2)
export DB_PASS=$(grep db_admin_password infra/terraform/terraform.tfvars | cut -d'"' -f2)

# Construct connection string
export DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:5432/${DB_NAME}?sslmode=require"

echo "DATABASE_URL configured"
echo "Host: $DB_HOST"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
```

**Step 2**: Test database connectivity

```bash
psql "$DATABASE_URL" -c "SELECT version();"
```

**Expected Output**:
```
                                                 version
---------------------------------------------------------------------------------------------------------
 PostgreSQL 14.x on x86_64-pc-linux-gnu, compiled by gcc...
(1 row)
```

**If connection fails**, check:
1. Is your IP in the firewall rules?
   ```bash
   az postgres flexible-server firewall-rule list \
     --resource-group $RG_NAME \
     --name mileage-deal-tracker-db-dev
   ```

2. Add your current IP if needed:
   ```bash
   export MY_IP=$(curl -s ifconfig.me)
   az postgres flexible-server firewall-rule create \
     --resource-group $RG_NAME \
     --name mileage-deal-tracker-db-dev \
     --rule-name "MyCurrentIP" \
     --start-ip-address $MY_IP \
     --end-ip-address $MY_IP
   ```

### 4.2 Run Database Migrations

**Step 3**: Execute migration script

```bash
./infra/scripts/deploy-db-migrations.sh dev
```

**Expected Output**:
```
=========================================
Database Migration Deployment
Environment: dev
=========================================
Installing dependencies...
Generating Prisma Client...
Running database migrations...

Prisma schema loaded from prisma/schema.prisma
Datasource "db": PostgreSQL database "mileage_tracker_dev"

The following migration(s) have been applied:

migrations/
  └─ 20231105_init/
       └─ migration.sql

Database migration completed successfully!

Verifying database connection...
✓ Database connection successful

=========================================
Migration deployment complete!
=========================================
```

**Step 4**: Verify tables created

```bash
psql "$DATABASE_URL" -c "\dt"
```

**Expected Output**: Should list 11 tables
```
              List of relations
 Schema |         Name          | Type  | Owner
--------+-----------------------+-------+--------
 public | AuditLog              | table | dbadmin
 public | CardProduct           | table | dbadmin
 public | CurrencyValuation     | table | dbadmin
 public | EmailLog              | table | dbadmin
 public | Issuer                | table | dbadmin
 public | Offer                 | table | dbadmin
 public | OfferSnapshot         | table | dbadmin
 public | Subscriber            | table | dbadmin
 public | SubscriberPreference  | table | dbadmin
 public | User                  | table | dbadmin
 public | _prisma_migrations    | table | dbadmin
```

**Step 5**: Check table structure (sample)

```bash
psql "$DATABASE_URL" -c "\d \"Offer\""
```

Should show columns: id, cardProductId, sourceType, bonusAmount, etc.

### 4.3 Seed Sample Data

**Step 6**: Run seed script

```bash
./infra/scripts/seed-production.sh
```

**Interactive Prompts**:
```
Are you sure you want to seed the PRODUCTION database? (yes/no): yes
DATABASE_URL does not contain 'prod' or 'azure'. Continue anyway? (yes/no): yes
```

**Expected Output**:
```
=========================================
Production Database Seeding
=========================================
Running seed script...

Seeding currency valuations...
Created 6 currency valuations

Seeding issuers...
Created 6 issuers

Seeding card products...
Created 4 card products

Seeding offers...
Created 3 offers with 6 snapshots

Database record counts:
  Issuers: 6
  Card Products: 4
  Offers: 3
  Currency Valuations: 6

=========================================
Production seeding complete!
=========================================
```

**Step 7**: Verify seeded data

```bash
# Check record counts
psql "$DATABASE_URL" -c "
SELECT 'Issuers' as table, COUNT(*) FROM \"Issuer\"
UNION ALL SELECT 'Products', COUNT(*) FROM \"CardProduct\"
UNION ALL SELECT 'Offers', COUNT(*) FROM \"Offer\"
UNION ALL SELECT 'Valuations', COUNT(*) FROM \"CurrencyValuation\"
UNION ALL SELECT 'Snapshots', COUNT(*) FROM \"OfferSnapshot\";
"
```

**Expected**:
- Issuers: 6
- Products: 4
- Offers: 3
- Valuations: 6
- Snapshots: 6

**Step 8**: View sample data

```bash
# View issuers
psql "$DATABASE_URL" -c "SELECT id, name, website FROM \"Issuer\" ORDER BY name;"

# View offers with product names
psql "$DATABASE_URL" -c "
SELECT o.id, cp.name as product, o.\"bonusAmount\", o.\"minSpend\"
FROM \"Offer\" o
JOIN \"CardProduct\" cp ON o.\"cardProductId\" = cp.id
WHERE o.status = 'ACTIVE'
ORDER BY o.\"bonusAmount\" DESC;
"
```

### 4.4 Configure App Service Database Connection

**Step 9**: Set DATABASE_URL in App Service

```bash
az webapp config appsettings set \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev \
  --settings DATABASE_URL="$DATABASE_URL"
```

**Step 10**: Set other environment variables

```bash
az webapp config appsettings set \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev \
  --settings \
    NEXT_PUBLIC_APP_URL="$APP_URL" \
    NODE_ENV="development" \
    WEBSITE_NODE_DEFAULT_VERSION="18-lts"
```

**Step 11**: Verify settings

```bash
az webapp config appsettings list \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev \
  --query "[?name=='DATABASE_URL' || name=='NODE_ENV' || name=='NEXT_PUBLIC_APP_URL'].{Name:name, Value:value}" \
  --output table
```

### 4.5 Create Initial Backup

**Step 12**: Create first database backup

```bash
./infra/scripts/backup-database.sh dev
```

**Expected Output**:
```
=========================================
Database Backup
Environment: dev
Timestamp: 20251106_123456
=========================================
Running pg_dump...
Compressing backup...

=========================================
Backup complete!
File: /Users/joseph/Playground/MileageTracking/backups/mileage_tracker_dev_20251106_123456.sql.gz
Size: 2.4K
=========================================
```

### 4.6 Phase Checkpoint

**Verify before proceeding**:
- [ ] Database connection successful
- [ ] All 11 tables created
- [ ] Sample data seeded (6 issuers, 4 products, 3 offers)
- [ ] App Service environment variables configured
- [ ] Initial backup created
- [ ] Can query database successfully

---

## 5. Phase 4: Application Deployment

**Time Required**: 30-45 minutes
**Goal**: Build and deploy Next.js application to Azure

### 5.1 Build Application Locally

**Step 1**: Navigate to application directory

```bash
cd /Users/joseph/Playground/MileageTracking/apps/web
```

**Step 2**: Install dependencies

```bash
npm install
```

**Step 3**: Generate Prisma Client

```bash
npx prisma generate
```

**Step 4**: Build Next.js application

```bash
npm run build
```

**Expected Output**:
```
> credit-card-tracker-web@1.0.0 build
> prisma generate && next build

✔ Generated Prisma Client

   Creating an optimized production build ...
 ✓ Compiled successfully
 ✓ Linting and checking validity of types
 ✓ Collecting page data
 ✓ Generating static pages (4/4)
 ✓ Collecting build traces
 ✓ Finalizing page optimization

Route (app)                              Size     First Load JS
┌ ○ /                                   137 B          87.7 kB
├ ○ /api/health                         0 B                0 B
├ ○ /api/offers                         0 B                0 B
├ ○ /issuers                            137 B          87.7 kB
└ ○ /offers                             137 B          87.7 kB

○  (Static)  prerendered as static content

Build completed successfully!
```

**If build fails**, check for:
- TypeScript errors
- Missing dependencies
- Prisma client generation issues

### 5.2 Package Application

**Step 5**: Create deployment package

```bash
cd /Users/joseph/Playground/MileageTracking

# Create a temporary directory for packaging
mkdir -p .deploy-temp
cp -r apps/web/.next .deploy-temp/
cp -r apps/web/public .deploy-temp/ 2>/dev/null || true
cp apps/web/package.json .deploy-temp/
cp apps/web/package-lock.json .deploy-temp/
cp -r apps/web/prisma .deploy-temp/
cp -r apps/web/prisma-lib .deploy-temp/
cp -r apps/web/src .deploy-temp/

# Create deployment configuration
cat > .deploy-temp/web.config << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="iisnode" path="server.js" verb="*" modules="iisnode"/>
    </handlers>
    <rewrite>
      <rules>
        <rule name="DynamicContent">
          <conditions>
            <add input="{REQUEST_FILENAME}" matchType="IsFile" negate="True"/>
          </conditions>
          <action type="Rewrite" url="server.js"/>
        </rule>
      </rules>
    </rewrite>
  </system.webServer>
</configuration>
EOF

# Create startup script
cat > .deploy-temp/startup.sh << 'EOF'
#!/bin/bash
cd /home/site/wwwroot
npm install --production
npx prisma generate
npm start
EOF

chmod +x .deploy-temp/startup.sh

# Create the zip file
cd .deploy-temp
zip -r ../mileage-tracker-app.zip . -x "*.git*" "node_modules/*"
cd ..

echo "✓ Deployment package created: mileage-tracker-app.zip"
ls -lh mileage-tracker-app.zip
```

### 5.3 Deploy to Azure App Service

**Step 6**: Deploy via Azure CLI

```bash
az webapp deployment source config-zip \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev \
  --src mileage-tracker-app.zip
```

**Expected Output**:
```
Getting scm site credentials for zip deployment
Starting zip deployment. This operation can take a while to complete ...
Deployment endpoint responded with status code 202
```

**This will take 3-5 minutes** as Azure unpacks and prepares the application.

**Step 7**: Configure startup command

```bash
az webapp config set \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev \
  --startup-file "npm start"
```

### 5.4 Monitor Application Startup

**Step 8**: Stream logs

```bash
az webapp log tail \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev
```

**Look for these log messages**:
```
Starting container...
Pulling image: mcr.microsoft.com/appsvc/node:18-lts
Starting warmup...
Container started successfully
npm start
> credit-card-tracker-web@1.0.0 start
> next start

ready - started server on 0.0.0.0:8080
```

**Press Ctrl+C** to exit log streaming once you see "ready - started server"

**Step 9**: Wait for application warmup (2-3 minutes)

```bash
echo "Waiting for application to start..."
sleep 180  # Wait 3 minutes
```

**Step 10**: Check application status

```bash
az webapp show \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev \
  --query "{name:name, state:state, url:defaultHostName}" \
  --output table
```

**Expected**:
```
Name                        State     Url
--------------------------  --------  ---------------------------------------------
mileage-deal-tracker-dev    Running   mileage-deal-tracker-dev.azurewebsites.net
```

### 5.5 Initial Application Test

**Step 11**: Test with curl

```bash
# Test homepage
curl -I "$APP_URL"

# Test health endpoint
curl "$APP_URL/api/health" | jq .
```

**Expected Health Response**:
```json
{
  "status": "ok",
  "timestamp": "2025-11-06T...",
  "database": {
    "connected": true,
    "offers": 3,
    "issuers": 6
  },
  "version": "1.0.0"
}
```

**Step 12**: Test in browser

Open: https://mileage-deal-tracker-dev.azurewebsites.net

**Should see**: Mileage Deal Tracker homepage

### 5.6 Phase Checkpoint

**Verify before proceeding**:
- [ ] Application built successfully
- [ ] Deployment package created and uploaded
- [ ] Application started (logs show "ready - started server")
- [ ] Application state: Running
- [ ] Homepage accessible in browser
- [ ] Health endpoint returns status: "ok"
- [ ] Database connection working (health check shows offer/issuer counts)

---

## 6. Phase 5: Verification and Testing

**Time Required**: 1-2 hours
**Goal**: Comprehensive testing of all application features

### 6.1 Automated Health Check

**Step 1**: Run health check script

```bash
cd /Users/joseph/Playground/MileageTracking
./infra/scripts/health-check.sh dev
```

**Expected Output**:
```
=========================================
Application Health Check
Environment: dev
=========================================
Checking: https://mileage-deal-tracker-dev.azurewebsites.net

1. Testing HTTP connectivity...
   ✓ App is responding (HTTP 200)

2. Testing API health endpoint...
   ✓ API health check passed
   Response: {"status":"ok",...}

3. Testing offers endpoint...
   ✓ Offers endpoint responding
   Offers found: 3

4. Testing database connection...
   ✓ Database connection successful
   Offers in database: 3

=========================================
Health check complete!
=========================================
```

**All checks must pass** ✓

### 6.2 Manual Functional Testing

**Test each page and feature**:

#### Homepage Test (`/`)

**Open**: https://mileage-deal-tracker-dev.azurewebsites.net

**Verify**:
- [ ] Page loads without errors
- [ ] Hero section displays "Credit Card Deals Tracker" or similar
- [ ] Feature cards are visible (3-4 cards)
- [ ] Scoring methodology section visible
- [ ] Navigation links work
- [ ] No console errors (open browser DevTools)

**Screenshot**: Take screenshot and save as `test-homepage.png`

#### Offers Page Test (`/offers`)

**Open**: https://mileage-deal-tracker-dev.azurewebsites.net/offers

**Verify**:
- [ ] All 3 offers displayed as cards
- [ ] Each card shows:
  - [ ] Card product name
  - [ ] Issuer name
  - [ ] Bonus amount with CPP
  - [ ] Minimum spend requirement
  - [ ] Net value calculation
  - [ ] Valid through date
  - [ ] Apply link
- [ ] Offers are sorted by net value (highest first)
- [ ] Links to issuer websites work (open in new tab)
- [ ] Responsive design works (resize browser window)
- [ ] No console errors

**Test Data Integrity**:
```bash
# Expected offers (from seed data):
# 1. Chase Sapphire Preferred: 60,000 UR points
# 2. Citi Premier: 60,000 TYP points
# 3. Amex Platinum: 150,000 MR points

curl "$APP_URL/api/offers" | jq '.[].cardProduct.name'
```

**Screenshot**: Save as `test-offers.png`

#### Issuers Page Test (`/issuers`)

**Open**: https://mileage-deal-tracker-dev.azurewebsites.net/issuers

**Verify**:
- [ ] All 6 issuers displayed
- [ ] Each card shows:
  - [ ] Issuer name
  - [ ] Number of card products
  - [ ] Website link
- [ ] Website links functional (open in new tab)
- [ ] Cards properly styled
- [ ] Responsive layout
- [ ] No console errors

**Test Data**:
```bash
# Expected issuers: Citi, Amex, Chase, BofA, Capital One, US Bank
curl "$APP_URL/api/offers" | jq -r '.[].cardProduct.issuer.name' | sort -u
```

**Screenshot**: Save as `test-issuers.png`

#### API Endpoints Test

**Test Health Endpoint**:
```bash
curl "$APP_URL/api/health" | jq .
```

**Verify Response**:
```json
{
  "status": "ok",
  "timestamp": "2025-11-06T...",
  "database": {
    "connected": true,
    "offers": 3,
    "issuers": 6
  },
  "version": "1.0.0"
}
```

**Test Offers API**:
```bash
curl "$APP_URL/api/offers" | jq '. | length'
# Should return: 3

curl "$APP_URL/api/offers" | jq '.[0] | keys'
# Should show all offer fields
```

### 6.3 Performance Testing

**Step 2**: Measure response times

```bash
# Test homepage
for i in {1..5}; do
  time curl -s "$APP_URL" > /dev/null
done

# Test API endpoint
for i in {1..10}; do
  curl -s -w "Time: %{time_total}s\n" -o /dev/null "$APP_URL/api/health"
done

# Calculate average
for i in {1..20}; do
  curl -s -w "%{time_total}\n" -o /dev/null "$APP_URL/api/offers"
done | awk '{sum+=$1; count++} END {print "Average: " sum/count " seconds"}'
```

**Performance Baselines**:
- Homepage: < 2 seconds ✓
- Health endpoint: < 200ms ✓
- Offers API: < 500ms ✓

**Step 3**: Load test (optional)

```bash
# Install Apache Bench
brew install apache-bench

# Run load test
ab -n 100 -c 10 "$APP_URL/api/health"
```

**Review**:
- Requests per second
- Mean response time
- Failed requests (should be 0)

### 6.4 Database Integration Test

**Step 4**: Test database queries

```bash
# Test relationships
psql "$DATABASE_URL" -c "
SELECT
  i.name as issuer,
  cp.name as product,
  o.\"bonusAmount\",
  o.\"minSpend\",
  o.status
FROM \"Offer\" o
JOIN \"CardProduct\" cp ON o.\"cardProductId\" = cp.id
JOIN \"Issuer\" i ON cp.\"issuerId\" = i.id
WHERE o.status = 'ACTIVE';
"
```

**Verify**:
- All relationships working
- Data displays correctly
- CPP calculations accurate

### 6.5 Error Handling Test

**Step 5**: Test error scenarios

```bash
# Test invalid endpoint
curl "$APP_URL/api/nonexistent"
# Should return 404

# Test malformed request
curl -X POST "$APP_URL/api/health"
# Should handle gracefully
```

**Verify**:
- Proper error messages
- No sensitive information leaked
- Logs show errors (not crashes)

### 6.6 Create Test Report

**Step 6**: Document test results

```bash
cat > test-results-dev-$(date +%Y%m%d).md << 'EOF'
# Test Results - Development Environment

**Date**: $(date)
**Environment**: Development
**URL**: $APP_URL

## Automated Tests
- [x] Health check: PASSED
- [x] HTTP connectivity: PASSED
- [x] API endpoints: PASSED
- [x] Database connection: PASSED

## Manual Tests
- [x] Homepage: PASSED
- [x] Offers page: PASSED (3 offers displayed)
- [x] Issuers page: PASSED (6 issuers displayed)
- [x] Navigation: PASSED
- [x] Responsive design: PASSED

## Performance Tests
- Homepage load time: X.X seconds
- API response time: XXX ms
- Database query time: XX ms

## Issues Found
(List any issues here)

## Screenshots
- test-homepage.png
- test-offers.png
- test-issuers.png

## Verdict
✅ All tests PASSED - Ready for production deployment
EOF
```

### 6.7 Phase Checkpoint

**Verify before proceeding**:
- [ ] Automated health check passed
- [ ] All pages tested and working
- [ ] API endpoints returning correct data
- [ ] Performance meets requirements
- [ ] Database integration working
- [ ] No critical errors found
- [ ] Test report created
- [ ] Screenshots captured

---

## 7. Phase 6: Monitoring Configuration

**Time Required**: 45-60 minutes
**Goal**: Configure Application Insights, alerts, and logging

### 7.1 Verify Application Insights

**Step 1**: Check Application Insights is receiving data

```bash
# Get instrumentation key
az monitor app-insights component show \
  --app mileage-deal-tracker-insights-dev \
  --resource-group $RG_NAME \
  --query "instrumentationKey" \
  --output tsv
```

**Step 2**: Query recent requests

```bash
az monitor app-insights query \
  --app mileage-deal-tracker-insights-dev \
  --resource-group $RG_NAME \
  --analytics-query "requests | take 10" \
  --offset 1h
```

**Should see**: Recent HTTP requests to your application

### 7.2 Configure Alert Rules

**Step 3**: Create high response time alert

```bash
# Get resource ID
APP_RESOURCE_ID=$(az webapp show \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev \
  --query id --output tsv)

# Create alert
az monitor metrics alert create \
  --name "High Response Time - Dev" \
  --resource-group $RG_NAME \
  --scopes "$APP_RESOURCE_ID" \
  --condition "avg responseTime > 1000" \
  --description "Alert when average response time exceeds 1 second" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 2
```

**Step 4**: Create high error rate alert

```bash
az monitor metrics alert create \
  --name "High Error Rate - Dev" \
  --resource-group $RG_NAME \
  --scopes "$APP_RESOURCE_ID" \
  --condition "count requests/failed > 10" \
  --description "Alert when more than 10 requests fail in 15 minutes" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 1
```

**Step 5**: Create database connection alert

```bash
# Get PostgreSQL resource ID
DB_RESOURCE_ID=$(az postgres flexible-server show \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-db-dev \
  --query id --output tsv)

az monitor metrics alert create \
  --name "Database Connection Issues - Dev" \
  --resource-group $RG_NAME \
  --scopes "$DB_RESOURCE_ID" \
  --condition "avg active_connections < 1" \
  --description "Alert when database has no active connections" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 0
```

**Step 6**: List all alerts

```bash
az monitor metrics alert list \
  --resource-group $RG_NAME \
  --output table
```

### 7.3 Configure Logging

**Step 7**: Enable application logging

```bash
az webapp log config \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev \
  --application-logging filesystem \
  --level information \
  --web-server-logging filesystem
```

**Step 8**: Test logging

```bash
# Trigger some requests
curl "$APP_URL"
curl "$APP_URL/api/health"
curl "$APP_URL/api/offers"

# View logs
az webapp log tail \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-dev
```

**Press Ctrl+C** to exit

### 7.4 Create Azure Dashboard (Optional)

**Step 9**: Open Azure Portal

Navigate to: https://portal.azure.com

**Step 10**: Create custom dashboard

1. Click "Dashboard"
2. Click "+ New dashboard"
3. Name: "Mileage Tracker - Dev"
4. Add tiles:
   - App Service metrics (CPU, Memory, Requests)
   - PostgreSQL metrics (Connections, CPU)
   - Application Insights overview
   - Alert status

**Step 11**: Pin important metrics

From each resource:
- Go to Metrics
- Select metric (e.g., Response Time)
- Click "Pin to dashboard"

### 7.5 Phase Checkpoint

**Verify**:
- [ ] Application Insights receiving telemetry
- [ ] 3 alert rules created
- [ ] Logging enabled and working
- [ ] Can view logs via CLI
- [ ] Dashboard created (optional)

---

## 8. Phase 7: Backup and Operations

**Time Required**: 30-45 minutes
**Goal**: Establish backup procedures and operational practices

### 8.1 Backup Configuration

**Step 1**: Verify automated PostgreSQL backups

```bash
az postgres flexible-server show \
  --resource-group $RG_NAME \
  --name mileage-deal-tracker-db-dev \
  --query "{name:name, backupRetentionDays:backup.backupRetentionDays, geoRedundantBackup:backup.geoRedundantBackup}"
```

**Expected**:
- backupRetentionDays: 7
- geoRedundantBackup: Disabled

**Step 2**: Create manual backup

```bash
cd /Users/joseph/Playground/MileageTracking
./infra/scripts/backup-database.sh dev
```

**Step 3**: Upload backup to Azure (optional)

```bash
# Get storage account name
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)

# Upload backup
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name database-backups \
  --name "backup-$(date +%Y%m%d).sql.gz" \
  --file backups/mileage_tracker_dev_*.sql.gz \
  --auth-mode login
```

### 8.2 Test Backup Restore

**Step 4**: Test restore procedure (non-destructive)

```bash
# Create test database for restore testing
psql "$DATABASE_URL" -c "CREATE DATABASE mileage_tracker_restore_test;"

# Build restore connection string
export RESTORE_DB_URL="${DATABASE_URL%/*}/mileage_tracker_restore_test?sslmode=require"

# Restore backup to test database
gunzip -c backups/mileage_tracker_dev_*.sql.gz | psql "$RESTORE_DB_URL"

# Verify restore
psql "$RESTORE_DB_URL" -c "SELECT COUNT(*) FROM \"Offer\";"

# Should show: 3

# Clean up test database
psql "$DATABASE_URL" -c "DROP DATABASE mileage_tracker_restore_test;"
```

### 8.3 Establish Backup Schedule

**Step 5**: Create backup reminder

```bash
# Add to crontab for weekly manual backups (optional)
# Run: crontab -e
# Add: 0 2 * * 0 cd /Users/joseph/Playground/MileageTracking && ./infra/scripts/backup-database.sh dev

# Or create a reminder in your calendar:
echo "Set calendar reminder: Weekly backup every Sunday 2 AM"
```

### 8.4 Document Operational Procedures

**Step 6**: Create operations quick reference

```bash
cat > ops-quickref-dev.md << 'EOF'
# Operations Quick Reference - Development

## Daily Operations

### Check Application Status
```bash
az webapp show --resource-group mileage-deal-rg-dev --name mileage-deal-tracker-dev --query state
```

### View Recent Logs
```bash
az webapp log tail --resource-group mileage-deal-rg-dev --name mileage-deal-tracker-dev
```

### Check Database Connection
```bash
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM \"Offer\";"
```

## Weekly Operations

### Create Manual Backup
```bash
./infra/scripts/backup-database.sh dev
```

### Review Costs
```bash
az consumption usage list --start-date $(date -v-7d +%Y-%m-%d) --end-date $(date +%Y-%m-%d)
```

### Check Application Insights
Visit: https://portal.azure.com → Application Insights

## Common Operations

### Restart Application
```bash
az webapp restart --resource-group mileage-deal-rg-dev --name mileage-deal-tracker-dev
```

### Update Environment Variable
```bash
az webapp config appsettings set \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --settings KEY="VALUE"
```

### Run Health Check
```bash
./infra/scripts/health-check.sh dev
```

## Emergency Procedures

### Rollback Application
See: v4-operations-runbook.md Section 3.1

### Restore Database
See: v4-operations-runbook.md Section 3.2

### Contact Information
- Azure Support: [Azure Portal]
- Database Issues: Check firewall rules first
- Application Issues: Check Application Insights
EOF
```

### 8.5 Phase Checkpoint

**Verify**:
- [ ] Automated backups configured (7-day retention)
- [ ] Manual backup created and tested
- [ ] Restore procedure tested successfully
- [ ] Backup schedule established
- [ ] Operations quick reference created

---

## 9. Production Deployment

**Note**: This section should only be executed after:
- ✅ Development environment stable for 7+ days
- ✅ All tests passing consistently
- ✅ No critical issues identified
- ✅ Cost analysis completed
- ✅ Production readiness assessment approved

### 9.1 Production Deployment Plan

**See separate document**: `v4-production-deployment.md`

**Key Differences from Development**:
- Resource Group: `mileage-deal-rg` (no -dev suffix)
- App Service SKU: B2 (instead of B1)
- Database SKU: B_Standard_B2s (instead of B1ms)
- Storage: 64GB (instead of 32GB)
- Environment: `production`
- NODE_ENV: `production`
- Always-on: Enabled
- Cost: ~$43/month (vs ~$29/month)

**Deployment Timeline**:
1. Week 1: Development deployed and tested
2. Week 2: Monitoring and operations established
3. Week 3: Production deployment executed
4. Week 4: Production stabilization

---

## 10. Troubleshooting Guide

### Issue: Terraform Apply Fails

**Error**: `Error: A resource with the ID already exists`

**Solution**:
```bash
# Import existing resource
terraform import azurerm_resource_group.rg /subscriptions/SUB_ID/resourceGroups/RESOURCE_GROUP_NAME

# Or destroy and recreate
terraform destroy
terraform apply
```

### Issue: Database Connection Timeout

**Error**: `connection timed out`

**Solutions**:
1. Check firewall rules:
   ```bash
   az postgres flexible-server firewall-rule list \
     --resource-group $RG_NAME \
     --name mileage-deal-tracker-db-dev
   ```

2. Add your IP:
   ```bash
   az postgres flexible-server firewall-rule create \
     --resource-group $RG_NAME \
     --name mileage-deal-tracker-db-dev \
     --rule-name "MyIP" \
     --start-ip-address $(curl -s ifconfig.me) \
     --end-ip-address $(curl -s ifconfig.me)
   ```

3. Check DATABASE_URL format:
   ```bash
   echo $DATABASE_URL
   # Should include: ?sslmode=require
   ```

### Issue: Application Won't Start

**Error**: App Service shows "Service Unavailable"

**Solutions**:
1. Check logs:
   ```bash
   az webapp log tail --resource-group $RG_NAME --name mileage-deal-tracker-dev
   ```

2. Verify environment variables:
   ```bash
   az webapp config appsettings list --resource-group $RG_NAME --name mileage-deal-tracker-dev
   ```

3. Check startup command:
   ```bash
   az webapp config show --resource-group $RG_NAME --name mileage-deal-tracker-dev --query "appCommandLine"
   ```

4. Restart app:
   ```bash
   az webapp restart --resource-group $RG_NAME --name mileage-deal-tracker-dev
   ```

### Issue: Prisma Client Not Generated

**Error**: `Cannot find module '@prisma/client'`

**Solution**:
```bash
cd apps/web
npm install
npx prisma generate
npm run build
```

### Issue: Migration Fails

**Error**: `Migration failed to apply`

**Solution**:
```bash
# Reset migrations (CAUTION: data loss)
npx prisma migrate reset

# Or check migration status
npx prisma migrate status

# Apply pending migrations
npx prisma migrate deploy
```

### Issue: High Costs

**Unexpected Azure charges**

**Solutions**:
1. Check cost breakdown:
   ```bash
   az consumption usage list --start-date $(date -v-30d +%Y-%m-%d)
   ```

2. Stop dev environment when not in use:
   ```bash
   az webapp stop --resource-group $RG_NAME --name mileage-deal-tracker-dev
   ```

3. Review Application Insights data volume:
   - Go to Azure Portal → Application Insights
   - Check daily data volume
   - Adjust sampling if needed

### Issue: Service Principal Permission Denied

**Error**: `AuthorizationFailed`

**Solution**:
```bash
# Verify role assignment
az role assignment list --assignee $ARM_CLIENT_ID --output table

# If missing, recreate with proper role
az ad sp create-for-rbac \
  --name "terraform-mileage-tracker-new" \
  --role="Contributor" \
  --scopes="/subscriptions/$ARM_SUBSCRIPTION_ID"
```

---

## Appendix A: Command Reference

### Essential Commands

**Check Application Status**:
```bash
az webapp show --resource-group $RG_NAME --name mileage-deal-tracker-dev --query "{name:name, state:state}"
```

**View Logs**:
```bash
az webapp log tail --resource-group $RG_NAME --name mileage-deal-tracker-dev
```

**Restart Application**:
```bash
az webapp restart --resource-group $RG_NAME --name mileage-deal-tracker-dev
```

**Run Health Check**:
```bash
./infra/scripts/health-check.sh dev
```

**Create Backup**:
```bash
./infra/scripts/backup-database.sh dev
```

**Deploy Updates**:
```bash
cd apps/web
npm run build
cd ../..
# Create new zip and deploy
az webapp deployment source config-zip --resource-group $RG_NAME --name mileage-deal-tracker-dev --src mileage-tracker-app.zip
```

---

## Appendix B: Resource Naming Convention

| Resource Type | Name Pattern | Example |
|--------------|--------------|---------|
| Resource Group | `mileage-deal-rg-{env}` | `mileage-deal-rg-dev` |
| App Service | `mileage-deal-tracker-{env}` | `mileage-deal-tracker-dev` |
| App Service Plan | `mileage-deal-plan-{env}` | `mileage-deal-plan-dev` |
| PostgreSQL Server | `mileage-deal-tracker-db-{env}` | `mileage-deal-tracker-db-dev` |
| PostgreSQL Database | `mileage_tracker_{env}` | `mileage_tracker_dev` |
| Application Insights | `mileage-deal-tracker-insights-{env}` | `mileage-deal-tracker-insights-dev` |
| Storage Account | `mileagedealtrackerstenv}` | `mileagedealtrackerstdev` |

---

## Appendix C: Cost Breakdown

### Development Environment

| Resource | SKU | Monthly Cost |
|----------|-----|--------------|
| App Service Plan | B1 | $13.14 |
| PostgreSQL | B_Standard_B1ms | $12.41 |
| Storage | Standard LRS | $0.50 |
| Application Insights | Basic | $2.88 |
| **Total** | | **$28.93** |

### Cost Optimization Tips

1. **Stop during non-use**:
   ```bash
   az webapp stop --name mileage-deal-tracker-dev --resource-group $RG_NAME
   ```

2. **Monitor with budget alerts**:
   ```bash
   az consumption budget create --budget-name dev-budget --amount 50 --time-grain Monthly
   ```

3. **Use sampling in Application Insights** (90% sampling = 90% cost reduction)


#### IMPORTANT RULE TO FOLLOW #### 
Perform the plans specified in this document and prepare result document under ./.claude/result folder.
Also, deployment of this project via CI/CD is not completed yet and perform all the steps specified in this document. No operation rule books need to be prepared yet until the deployment is completed and ready to run. 
Use file name with 'v4-' prepix.  

---

**Document Version**: 4.0
**Status**: ✅ Ready for Execution
**Last Updated**: 2025-11-06
**Next Step**: Execute Phase 1 - Create Service Principal
