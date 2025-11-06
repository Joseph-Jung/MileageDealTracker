# V3 Deployment Execution Plan - Mileage Deal Tracker

**Version**: 3.0
**Date**: 2025-11-05
**Project**: Mileage Deal Tracker
**GitHub**: [MileageDealTracker](https://github.com/Joseph-Jung/MileageDealTracker)
**Purpose**: Step-by-step execution plan for Azure deployment

---

## Executive Summary

This document provides a detailed, actionable execution plan for deploying the Mileage Deal Tracker application to Azure. It breaks down the deployment process from the requirement_v3.md into discrete, executable steps with validation checkpoints, estimated timelines, and rollback procedures.

**Status**: 📋 Ready to Execute
**Prerequisites Status**: ✅ All infrastructure code prepared
**Estimated Total Time**: 3-4 hours (first-time deployment)

---

## Table of Contents

1. [Pre-Deployment Checklist](#1-pre-deployment-checklist)
2. [Phase 1: Tool Installation and Setup](#2-phase-1-tool-installation-and-setup)
3. [Phase 2: Azure Account Configuration](#3-phase-2-azure-account-configuration)
4. [Phase 3: Terraform Infrastructure Deployment](#4-phase-3-terraform-infrastructure-deployment)
5. [Phase 4: Database Setup and Migration](#5-phase-4-database-setup-and-migration)
6. [Phase 5: Azure DevOps Pipeline Configuration](#6-phase-5-azure-devops-pipeline-configuration)
7. [Phase 6: Post-Deployment Verification](#7-phase-6-post-deployment-verification)
8. [Phase 7: Monitoring and Alerting Setup](#8-phase-7-monitoring-and-alerting-setup)
9. [Rollback Procedures](#9-rollback-procedures)
10. [Troubleshooting Decision Tree](#10-troubleshooting-decision-tree)
11. [Success Criteria](#11-success-criteria)

---

## 1. Pre-Deployment Checklist

### 1.1 Code Readiness
- [ ] All code committed to GitHub repository
- [ ] Repository URL: https://github.com/Joseph-Jung/MileageDealTracker
- [ ] Latest commit includes all Azure deployment configurations
- [ ] No local uncommitted changes

### 1.2 Infrastructure Files Present
- [ ] `.azure-pipelines/azure-pipelines.yml` exists
- [ ] `infra/terraform/main.tf` exists
- [ ] `infra/terraform/variables.tf` exists
- [ ] `infra/terraform/outputs.tf` exists
- [ ] `infra/terraform/terraform.tfvars.dev` exists
- [ ] `infra/terraform/terraform.tfvars.prod` exists
- [ ] All deployment scripts in `infra/scripts/` are executable

### 1.3 Account Requirements
- [ ] Azure account with active subscription
- [ ] Azure subscription ID available
- [ ] GitHub account with repository access
- [ ] Azure DevOps account (free tier acceptable)
- [ ] Credit card for Azure billing (even for free tier)

### 1.4 Local Environment
- [ ] macOS with Homebrew installed
- [ ] Command line access (Terminal)
- [ ] Internet connectivity
- [ ] Admin privileges for software installation

### 1.5 Documentation Access
- [ ] `infra/README.md` reviewed
- [ ] `.claude/result/azure-deployment-preparation.md` available
- [ ] This plan document accessible during deployment

**Validation Command**:
```bash
cd /Users/joseph/Playground/MileageTracking
ls -la .azure-pipelines/azure-pipelines.yml
ls -la infra/terraform/*.tf
ls -la infra/scripts/*.sh
git status
```

**Expected Result**: All files present, no errors, clean git status

---

## 2. Phase 1: Tool Installation and Setup

**Estimated Time**: 20-30 minutes
**Goal**: Install all required CLI tools and verify versions

### 2.1 Install Azure CLI

**Command**:
```bash
brew install azure-cli
```

**Validation**:
```bash
az --version
```

**Expected Output**:
```
azure-cli                         2.57.0+
```

**Troubleshooting**:
- If brew is not installed: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- If installation fails: `brew update && brew install azure-cli`

### 2.2 Install Terraform

**Command**:
```bash
brew install terraform
```

**Validation**:
```bash
terraform --version
```

**Expected Output**:
```
Terraform v1.7.x or higher
```

**Troubleshooting**:
- If version is too old: `brew upgrade terraform`
- Verify installation: `which terraform`

### 2.3 Install PostgreSQL Client Tools

**Command**:
```bash
brew install postgresql@14
echo 'export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Validation**:
```bash
psql --version
pg_dump --version
```

**Expected Output**:
```
psql (PostgreSQL) 14.x
pg_dump (PostgreSQL) 14.x
```

### 2.4 Verify Existing Tools

**Commands**:
```bash
node --version    # Should be v18.x or higher
npm --version     # Should be 9.x or higher
git --version     # Any recent version
```

**Expected Results**:
```
v18.x.x or higher
9.x.x or higher
2.x.x or higher
```

### 2.5 Phase 1 Completion Checklist
- [ ] Azure CLI installed and verified
- [ ] Terraform installed and verified
- [ ] PostgreSQL client installed and verified
- [ ] All tool versions meet minimum requirements
- [ ] Terminal environment configured (PATH updated)

**Decision Point**: Do not proceed to Phase 2 until all tools are successfully installed.

---

## 3. Phase 2: Azure Account Configuration

**Estimated Time**: 30-45 minutes
**Goal**: Configure Azure subscription and create service principal for Terraform

### 3.1 Azure Login

**Command**:
```bash
az login
```

**Process**:
1. Browser window will open
2. Sign in with Azure account credentials
3. Select subscription if multiple available
4. Return to terminal

**Validation**:
```bash
az account show
```

**Expected Output**:
```json
{
  "environmentName": "AzureCloud",
  "id": "your-subscription-id",
  "isDefault": true,
  "name": "Your Subscription Name",
  "state": "Enabled"
}
```

**Action Required**: Copy the subscription ID (the "id" field)

### 3.2 Set Active Subscription

**Command** (replace with your subscription ID):
```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
```

**Validation**:
```bash
az account show --query "id" -o tsv
```

**Expected Output**: Your subscription ID

### 3.3 Create Service Principal for Terraform

**Command**:
```bash
az ad sp create-for-rbac \
  --name "terraform-mileage-tracker-$(date +%s)" \
  --role="Contributor" \
  --scopes="/subscriptions/$AZURE_SUBSCRIPTION_ID"
```

**Expected Output**:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "terraform-mileage-tracker-xxxxx",
  "password": "your-client-secret",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

**CRITICAL**: Save this output securely! You will need these values:
- `appId` = ARM_CLIENT_ID
- `password` = ARM_CLIENT_SECRET
- `tenant` = ARM_TENANT_ID

**Action Required**: Create a secure note with these credentials

### 3.4 Configure Terraform Environment Variables

**Command** (replace with your actual values):
```bash
# Create a secure file for Azure credentials
cat > ~/azure-terraform-creds.sh << 'EOF'
export ARM_CLIENT_ID="your-app-id"
export ARM_CLIENT_SECRET="your-password"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
EOF

chmod 600 ~/azure-terraform-creds.sh
```

**Important**: Keep this file secure and never commit to git

### 3.5 Test Azure CLI Permissions

**Command**:
```bash
az group list
az provider list --query "[?registrationState=='Registered'].namespace" -o table
```

**Expected Result**: Lists should return successfully (may be empty initially)

### 3.6 Phase 2 Completion Checklist
- [ ] Successfully logged into Azure CLI
- [ ] Subscription ID identified and set
- [ ] Service principal created
- [ ] Credentials securely saved
- [ ] Environment variables configured
- [ ] Azure CLI permissions verified

**Decision Point**: Do not proceed to Phase 3 without service principal credentials

---

## 4. Phase 3: Terraform Infrastructure Deployment

**Estimated Time**: 30-45 minutes
**Goal**: Deploy Azure infrastructure using Terraform

### 4.1 Prepare Terraform Environment

**Commands**:
```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform

# Source Azure credentials
source ~/azure-terraform-creds.sh

# Verify environment variables
echo "ARM_SUBSCRIPTION_ID: $ARM_SUBSCRIPTION_ID"
echo "ARM_CLIENT_ID: $ARM_CLIENT_ID"
echo "ARM_TENANT_ID: $ARM_TENANT_ID"
echo "ARM_CLIENT_SECRET: [hidden]"
```

**Expected Result**: All variables should be set (not empty)

### 4.2 Create Terraform Variables File

**Decision Point**: Choose environment (dev or prod)
- **Recommendation**: Start with `dev` for first deployment
- **Option 1**: Development environment (lower cost, can be stopped)
- **Option 2**: Production environment (always-on, higher resources)

**For Development**:
```bash
# Get your public IP for database access
export MY_IP=$(curl -s ifconfig.me)

# Create terraform.tfvars
cat > terraform.tfvars << EOF
environment         = "dev"
resource_group_name = "mileage-deal-rg-dev"
db_admin_username   = "dbadmin"
db_admin_password   = "MileageTracker2025!"
db_storage_mb       = 32768
db_sku_name         = "B_Standard_B1ms"
app_service_sku     = "B1"
allowed_ip_address  = "$MY_IP"
location            = "East US"

tags = {
  Environment = "Development"
  Project     = "MileageDealTracker"
  Owner       = "joseph"
}
EOF
```

**For Production**:
```bash
export MY_IP=$(curl -s ifconfig.me)

cat > terraform.tfvars << EOF
environment         = "prod"
resource_group_name = "mileage-deal-rg"
db_admin_username   = "dbadmin"
db_admin_password   = "MileageTracker2025Prod!"
db_storage_mb       = 65536
db_sku_name         = "B_Standard_B2s"
app_service_sku     = "B2"
allowed_ip_address  = "$MY_IP"
location            = "East US"

tags = {
  Environment = "Production"
  Project     = "MileageDealTracker"
  Owner       = "joseph"
}
EOF
```

**Security Note**: Use a strong, unique password. Consider using a password manager.

### 4.3 Initialize Terraform

**Command**:
```bash
terraform init
```

**Expected Output**:
```
Initializing the backend...
Initializing provider plugins...
- Installing hashicorp/azurerm v3.100.x...
Terraform has been successfully initialized!
```

**Troubleshooting**:
- If backend fails: Comment out the `backend "azurerm"` block in `main.tf` for initial deployment
- If provider download fails: Check internet connectivity, try again

### 4.4 Validate Terraform Configuration

**Command**:
```bash
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

### 4.5 Plan Infrastructure Deployment

**Command**:
```bash
terraform plan -out=tfplan
```

**Expected Output**:
```
Terraform will perform the following actions:

  # azurerm_application_insights.insights will be created
  # azurerm_linux_web_app.app will be created
  # azurerm_postgresql_flexible_server.db will be created
  # azurerm_postgresql_flexible_server_database.main_db will be created
  # azurerm_resource_group.rg will be created
  # azurerm_service_plan.plan will be created
  # azurerm_storage_account.storage will be created
  # azurerm_storage_container.backups will be created
  # azurerm_storage_container.snapshots will be created
  ...

Plan: 12 to add, 0 to change, 0 to destroy.
```

**Review**:
1. Check resource names match expectations
2. Verify resource group location
3. Confirm SKU sizes (B1ms for dev, B2s for prod)
4. Review estimated costs in output

**Decision Point**: Review plan carefully. If anything looks wrong, fix terraform.tfvars and re-plan.

### 4.6 Apply Infrastructure Deployment

**Command**:
```bash
terraform apply tfplan
```

**Expected Duration**: 10-15 minutes

**Expected Output**:
```
azurerm_resource_group.rg: Creating...
azurerm_resource_group.rg: Creation complete after 2s
azurerm_service_plan.plan: Creating...
azurerm_postgresql_flexible_server.db: Creating...
...
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:
app_service_url = "https://mileage-deal-tracker-dev.azurewebsites.net"
postgresql_server_fqdn = "mileage-deal-tracker-db-dev.postgres.database.azure.com"
...
```

**Action Required**: Save the outputs

### 4.7 Save Terraform Outputs

**Commands**:
```bash
terraform output > outputs.txt
terraform output -json > outputs.json

# Display key outputs
terraform output app_service_url
terraform output postgresql_server_fqdn
terraform output database_connection_string
```

**Expected Result**: Three files created with deployment information

### 4.8 Verify Azure Resources

**Commands**:
```bash
# List resource group
az group show --name mileage-deal-rg-dev

# List all resources in group
az resource list --resource-group mileage-deal-rg-dev --output table

# Check App Service status
az webapp show --name mileage-deal-tracker-dev --resource-group mileage-deal-rg-dev --query "state"

# Check PostgreSQL status
az postgres flexible-server show --name mileage-deal-tracker-db-dev --resource-group mileage-deal-rg-dev --query "state"
```

**Expected Results**:
- Resource group exists
- 12 resources listed
- App Service state: "Running"
- PostgreSQL state: "Ready"

### 4.9 Phase 3 Completion Checklist
- [ ] Terraform initialized successfully
- [ ] Configuration validated
- [ ] Plan reviewed and approved
- [ ] Infrastructure deployed (12 resources)
- [ ] Outputs saved to files
- [ ] Azure resources verified in portal
- [ ] App Service URL accessible (may show default page)
- [ ] PostgreSQL server status: Ready

**Decision Point**: Do not proceed to Phase 4 until all Azure resources are confirmed "Ready"

---

## 5. Phase 4: Database Setup and Migration

**Estimated Time**: 15-20 minutes
**Goal**: Configure database, run migrations, and seed initial data

### 5.1 Extract Database Connection Details

**Command**:
```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform

# Extract connection details
export DB_HOST=$(terraform output -raw postgresql_server_fqdn)
export DB_NAME=$(terraform output -raw postgresql_database_name)
export DB_USER=$(grep db_admin_username terraform.tfvars | cut -d'"' -f2)
export DB_PASSWORD=$(grep db_admin_password terraform.tfvars | cut -d'"' -f2)

# Construct DATABASE_URL
export DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}?sslmode=require"

echo "DATABASE_URL configured for: $DB_HOST"
```

**Validation**:
```bash
echo $DATABASE_URL | grep -o "postgresql://[^@]*@[^:]*"
```

**Expected Output**: Should show connection string (password masked)

### 5.2 Test Database Connectivity

**Command**:
```bash
psql "$DATABASE_URL" -c "SELECT version();"
```

**Expected Output**:
```
                                                 version
---------------------------------------------------------------------------------------------------------
 PostgreSQL 14.x on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 9.4.0-1ubuntu1~20.04.1) 9.4.0, 64-bit
(1 row)
```

**Troubleshooting**:
- If connection times out: Check firewall rules in Azure Portal
- If authentication fails: Verify password in terraform.tfvars
- If SSL error: Ensure `?sslmode=require` is in connection string

### 5.3 Run Database Migrations

**Command**:
```bash
cd /Users/joseph/Playground/MileageTracking
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

Database migration completed successfully!
Verifying database connection...
✓ Database connection successful
=========================================
Migration deployment complete!
=========================================
```

**Validation**:
```bash
psql "$DATABASE_URL" -c "\dt"
```

**Expected Result**: Should list all tables (Issuer, CardProduct, Offer, etc.)

### 5.4 Seed Initial Data

**Decision Point**: Seed with sample data or start empty?
- **Recommendation**: Seed for development, empty for production

**Command**:
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
Installing dependencies...
Generating Prisma Client...
Running seed script...

Database record counts:
  Issuers: 6
  Card Products: 4
  Offers: 3
  Currency Valuations: 6

=========================================
Production seeding complete!
=========================================
```

### 5.5 Verify Seeded Data

**Commands**:
```bash
# Check record counts
psql "$DATABASE_URL" -c "SELECT 'Issuers' as table_name, COUNT(*) FROM \"Issuer\"
UNION ALL SELECT 'Products', COUNT(*) FROM \"CardProduct\"
UNION ALL SELECT 'Offers', COUNT(*) FROM \"Offer\"
UNION ALL SELECT 'Valuations', COUNT(*) FROM \"CurrencyValuation\";"

# View sample data
psql "$DATABASE_URL" -c "SELECT name, website FROM \"Issuer\" LIMIT 3;"
psql "$DATABASE_URL" -c "SELECT \"CardProduct\".name, \"Issuer\".name as issuer FROM \"CardProduct\" JOIN \"Issuer\" ON \"CardProduct\".\"issuerId\" = \"Issuer\".id LIMIT 3;"
```

**Expected Results**:
- Issuers: 6 (Citi, Amex, Chase, BofA, Capital One, US Bank)
- Products: 4
- Offers: 3
- Valuations: 6

### 5.6 Create Initial Database Backup

**Command**:
```bash
./infra/scripts/backup-database.sh dev
```

**Expected Output**:
```
=========================================
Database Backup
Environment: dev
Timestamp: 20250105_143022
=========================================
Backing up database: mileage_tracker_dev
Host: mileage-deal-tracker-db-dev.postgres.database.azure.com
Port: 5432
Backup file: /Users/joseph/Playground/MileageTracking/backups/mileage_tracker_dev_20250105_143022.sql
Running pg_dump...
Compressing backup...
=========================================
Backup complete!
File: /Users/joseph/Playground/MileageTracking/backups/mileage_tracker_dev_20250105_143022.sql.gz
Size: 2.3K
=========================================
```

### 5.7 Configure App Service Environment Variables

**Commands**:
```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform

# Set environment variables in App Service
az webapp config appsettings set \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --settings \
    DATABASE_URL="$DATABASE_URL" \
    NEXT_PUBLIC_APP_URL="$(terraform output -raw app_service_url)" \
    NODE_ENV="development"
```

**Expected Output**:
```json
[
  {
    "name": "DATABASE_URL",
    "slotSetting": false,
    "value": "postgresql://..."
  },
  {
    "name": "NEXT_PUBLIC_APP_URL",
    "slotSetting": false,
    "value": "https://mileage-deal-tracker-dev.azurewebsites.net"
  },
  {
    "name": "NODE_ENV",
    "slotSetting": false,
    "value": "development"
  }
]
```

### 5.8 Phase 4 Completion Checklist
- [ ] Database connection string configured
- [ ] Database connectivity tested successfully
- [ ] Migrations executed (all tables created)
- [ ] Sample data seeded (if desired)
- [ ] Record counts verified
- [ ] Initial backup created
- [ ] App Service environment variables configured

**Decision Point**: Verify all tables exist before proceeding to Phase 5

---

## 6. Phase 5: Azure DevOps Pipeline Configuration

**Estimated Time**: 30-45 minutes
**Goal**: Set up CI/CD pipeline for automated deployments

### 6.1 Create Azure DevOps Organization (if needed)

**Steps**:
1. Navigate to https://dev.azure.com
2. Sign in with your Azure account
3. Click "Start free" or "Create organization"
4. Organization name: `mileage-tracker` (or your preference)
5. Project location: Choose closest region

**Validation**: Organization dashboard should be accessible

### 6.2 Create Azure DevOps Project

**Steps**:
1. In Azure DevOps, click "New Project"
2. Project name: `MileageDealTracker`
3. Visibility: Private
4. Version control: Git
5. Work item process: Agile
6. Click "Create"

**Expected Result**: Project created, redirected to project dashboard

### 6.3 Connect GitHub Repository

**Steps**:
1. In Azure DevOps project, go to "Project Settings" (bottom left)
2. Navigate to "Service connections" under "Pipelines"
3. Click "New service connection"
4. Select "GitHub"
5. Choose "Grant authorization" or "Personal Access Token"
6. Authenticate with GitHub
7. Service connection name: `GitHub-MileageDealTracker`
8. Select repository: `Joseph-Jung/MileageDealTracker`
9. Grant access, click "Save"

**Validation**: Service connection appears in list with green checkmark

### 6.4 Create Azure Service Connection

**Steps**:
1. In "Service connections", click "New service connection"
2. Select "Azure Resource Manager"
3. Authentication method: "Service principal (automatic)" or "Service principal (manual)"

**Option A: Automatic (Recommended)**:
1. Select subscription: Your Azure subscription
2. Resource group: `mileage-deal-rg-dev`
3. Service connection name: `Azure-Service-Connection`
4. Grant permission to all pipelines: ✓
5. Click "Save"

**Option B: Manual (if automatic fails)**:
1. Use service principal credentials from Phase 2
2. Subscription ID: `$ARM_SUBSCRIPTION_ID`
3. Subscription name: Your subscription name
4. Service principal ID: `$ARM_CLIENT_ID`
5. Service principal key: `$ARM_CLIENT_SECRET`
6. Tenant ID: `$ARM_TENANT_ID`
7. Service connection name: `Azure-Service-Connection`
8. Click "Verify and save"

**Validation**:
```bash
# Test service connection
az pipelines service-endpoint list --org https://dev.azure.com/YOUR_ORG --project MileageDealTracker
```

### 6.5 Create Variable Group

**Steps**:
1. Go to "Pipelines" → "Library"
2. Click "+ Variable group"
3. Variable group name: `mileage-tracker-vars`
4. Add the following variables:

| Variable Name       | Value                                                     | Secret? |
|---------------------|-----------------------------------------------------------|---------|
| `DEV_DATABASE_URL`  | Your dev DATABASE_URL                                     | ✓ Yes   |
| `DEV_APP_URL`       | `https://mileage-deal-tracker-dev.azurewebsites.net`      | No      |
| `PROD_DATABASE_URL` | Your prod DATABASE_URL (if applicable)                    | ✓ Yes   |
| `PROD_APP_URL`      | `https://mileage-deal-tracker.azurewebsites.net`          | No      |

5. Click "Save"

**Important**: Mark DATABASE_URL variables as "secret" (lock icon)

### 6.6 Create Pipeline from Repository

**Steps**:
1. Go to "Pipelines" → "Pipelines"
2. Click "New pipeline"
3. Select "GitHub"
4. Select repository: `Joseph-Jung/MileageDealTracker`
5. Configure pipeline: "Existing Azure Pipelines YAML file"
6. Branch: `main`
7. Path: `/.azure-pipelines/azure-pipelines.yml`
8. Click "Continue"

**Expected Result**: Pipeline YAML displayed for review

### 6.7 Update Pipeline Variables

**In the pipeline YAML editor**:
1. Review the pipeline configuration
2. Verify trigger branches: `main`, `dev`
3. Verify pool: `ubuntu-latest`
4. Check service connection name matches: `Azure-Service-Connection`
5. Verify app names match your resources

**Note**: If names don't match, update in `.azure-pipelines/azure-pipelines.yml` in repository

### 6.8 Save and Run Pipeline

**Steps**:
1. Click "Save and run"
2. Commit message: "Add Azure Pipeline configuration"
3. Commit directly to main branch
4. Click "Save and run" again

**Expected Duration**: 10-15 minutes

**Pipeline Stages**:
1. **Build**: Install dependencies, build Next.js app (~5 min)
2. **Deploy**: Deploy to Azure Web App (~3 min)
3. **Database Migration**: Run Prisma migrations (~2 min)

**Monitoring**:
- Watch pipeline progress in Azure DevOps
- Click on stages to view detailed logs
- Check for any errors or warnings

### 6.9 Verify Pipeline Success

**Expected Output**:
```
Stage: Build
✓ Install Node.js
✓ Install pnpm
✓ Install dependencies
✓ Generate Prisma Client
✓ Build Next.js application
✓ Package application
✓ Publish build artifact

Stage: Deploy
✓ Deploy to Azure Web App (Dev)
✓ Verify deployment

Stage: Database Migration
✓ Run Prisma migrations

Pipeline completed successfully in 12m 34s
```

### 6.10 Phase 5 Completion Checklist
- [ ] Azure DevOps organization created
- [ ] Azure DevOps project created
- [ ] GitHub service connection configured
- [ ] Azure service connection configured
- [ ] Variable group created with secrets
- [ ] Pipeline created from YAML file
- [ ] Pipeline run completed successfully
- [ ] All stages passed (Build, Deploy, Migration)

**Decision Point**: Do not proceed to Phase 6 if pipeline failed. Review logs and fix issues.

---

## 7. Phase 6: Post-Deployment Verification

**Estimated Time**: 20-30 minutes
**Goal**: Comprehensive verification of deployed application

### 7.1 Check Application URL

**Command**:
```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform
export APP_URL=$(terraform output -raw app_service_url)
echo "Application URL: $APP_URL"
curl -I "$APP_URL"
```

**Expected Output**:
```
HTTP/2 200
content-type: text/html; charset=utf-8
...
```

**Manual Verification**:
1. Open browser to application URL
2. Should see Mileage Deal Tracker homepage
3. Check for proper styling and content

### 7.2 Run Automated Health Check

**Command**:
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
   Response: {"status":"ok","timestamp":"2025-11-05T...","database":{"connected":true,"offers":3,"issuers":6},"version":"1.0.0"}

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

### 7.3 Test Individual Endpoints

**Test Health Endpoint**:
```bash
curl "$APP_URL/api/health" | jq .
```

**Expected Response**:
```json
{
  "status": "ok",
  "timestamp": "2025-11-05T14:30:22.456Z",
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
```

**Expected Response**: `3` (number of seeded offers)

**Test Offers Page**:
```bash
curl "$APP_URL/offers" | grep -o "<title>.*</title>"
```

**Expected Response**: Should contain page title

### 7.4 Manual Browser Testing

**Test Plan**:

1. **Homepage** (`/`)
   - [ ] Page loads without errors
   - [ ] Hero section displays
   - [ ] Feature cards visible
   - [ ] Scoring methodology explained
   - [ ] Navigation links work

2. **Offers Page** (`/offers`)
   - [ ] All 3 offers displayed
   - [ ] Offer cards show:
     - Card product name
     - Issuer name
     - Bonus amount and CPP
     - Net value calculation
     - Valid date range
   - [ ] Cards have proper styling
   - [ ] Links to issuer websites work

3. **Issuers Page** (`/issuers`)
   - [ ] All 6 issuers displayed
   - [ ] Issuer cards show:
     - Issuer name
     - Product count
     - Website link
   - [ ] External links open in new tab

4. **API Endpoints**
   - [ ] `/api/health` returns JSON with status
   - [ ] `/api/offers` returns array of offers
   - [ ] Proper CORS headers if needed

### 7.5 Check Azure Resources

**App Service Logs**:
```bash
az webapp log tail \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev
```

**Expected**: No critical errors, proper startup logs

**PostgreSQL Metrics**:
```bash
az postgres flexible-server show \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-db-dev \
  --query "{name:name, state:state, version:version}"
```

**Expected Output**:
```json
{
  "name": "mileage-deal-tracker-db-dev",
  "state": "Ready",
  "version": "14"
}
```

**Application Insights**:
```bash
az monitor app-insights query \
  --app mileage-deal-tracker-insights-dev \
  --resource-group mileage-deal-rg-dev \
  --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode" \
  --output table
```

**Expected**: Should show 200 status codes from recent requests

### 7.6 Database Verification

**Commands**:
```bash
# Check all tables
psql "$DATABASE_URL" -c "\dt"

# Verify foreign key constraints
psql "$DATABASE_URL" -c "SELECT conname, conrelid::regclass, confrelid::regclass FROM pg_constraint WHERE contype = 'f';"

# Check indexes
psql "$DATABASE_URL" -c "SELECT schemaname, tablename, indexname FROM pg_indexes WHERE schemaname = 'public';"

# Verify data integrity
psql "$DATABASE_URL" -c "
SELECT
  (SELECT COUNT(*) FROM \"Issuer\") as issuers,
  (SELECT COUNT(*) FROM \"CardProduct\") as products,
  (SELECT COUNT(*) FROM \"Offer\") as offers,
  (SELECT COUNT(*) FROM \"CurrencyValuation\") as valuations,
  (SELECT COUNT(*) FROM \"OfferSnapshot\") as snapshots;
"
```

### 7.7 Performance Testing

**Response Time Test**:
```bash
# Test homepage
time curl -s "$APP_URL" > /dev/null

# Test API endpoint
time curl -s "$APP_URL/api/offers" > /dev/null

# Multiple requests
for i in {1..10}; do
  curl -s -w "%{time_total}\n" -o /dev/null "$APP_URL/api/health"
done | awk '{sum+=$1; count++} END {print "Average response time: " sum/count " seconds"}'
```

**Expected Results**:
- Homepage: < 2 seconds
- API endpoints: < 500ms
- Average: < 300ms

### 7.8 Create Verification Report

**Command**:
```bash
cat > /Users/joseph/Playground/MileageTracking/.claude/result/deployment-verification-report.md << 'EOF'
# Deployment Verification Report

**Date**: $(date)
**Environment**: Development
**Deployment Status**: ✅ Successful

## Application Details
- **URL**: $(terraform output -raw app_service_url)
- **Health Status**: OK
- **Database Status**: Connected

## Verification Results
- [x] Application accessible via HTTPS
- [x] Health endpoint responding correctly
- [x] Offers API returning data
- [x] All pages loading properly
- [x] Database contains expected data
- [x] No critical errors in logs

## Performance Metrics
- Homepage load time: X.X seconds
- API response time: XXX ms
- Database query time: XX ms

## Next Steps
- Set up monitoring alerts
- Configure custom domain (if needed)
- Implement CI/CD for dev branch
- Plan production deployment
EOF
```

### 7.9 Phase 6 Completion Checklist
- [ ] Application URL accessible
- [ ] Automated health check passed
- [ ] All API endpoints working
- [ ] All pages load correctly in browser
- [ ] Database verification successful
- [ ] No errors in application logs
- [ ] Performance meets expectations
- [ ] Verification report created

**Decision Point**: If any verification fails, investigate before proceeding to Phase 7

---

## 8. Phase 7: Monitoring and Alerting Setup

**Estimated Time**: 20-30 minutes
**Goal**: Configure monitoring, alerts, and logging

### 8.1 Enable Application Insights

**Verify Application Insights**:
```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform

export INSIGHTS_NAME=$(terraform output -raw application_insights_instrumentation_key)
echo "Application Insights configured"

# Check recent telemetry
az monitor app-insights query \
  --app mileage-deal-tracker-insights-dev \
  --resource-group mileage-deal-rg-dev \
  --analytics-query "requests | take 10" \
  --output table
```

### 8.2 Configure Alert Rules

**Create Alert for High Response Time**:
```bash
az monitor metrics alert create \
  --name "High Response Time - Dev" \
  --resource-group mileage-deal-rg-dev \
  --scopes "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/mileage-deal-rg-dev/providers/Microsoft.Web/sites/mileage-deal-tracker-dev" \
  --condition "avg requests/duration > 1000" \
  --description "Alert when average response time exceeds 1 second" \
  --evaluation-frequency 5m \
  --window-size 15m
```

**Create Alert for Failed Requests**:
```bash
az monitor metrics alert create \
  --name "High Error Rate - Dev" \
  --resource-group mileage-deal-rg-dev \
  --scopes "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/mileage-deal-rg-dev/providers/Microsoft.Web/sites/mileage-deal-tracker-dev" \
  --condition "count requests/failed > 10" \
  --description "Alert when more than 10 requests fail in 15 minutes" \
  --evaluation-frequency 5m \
  --window-size 15m
```

**Create Alert for Database Connection Issues**:
```bash
az monitor metrics alert create \
  --name "Database Connection Failure - Dev" \
  --resource-group mileage-deal-rg-dev \
  --scopes "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/mileage-deal-rg-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/mileage-deal-tracker-db-dev" \
  --condition "avg active_connections < 1" \
  --description "Alert when database has no active connections" \
  --evaluation-frequency 5m \
  --window-size 15m
```

### 8.3 Configure Log Analytics

**Enable detailed logging**:
```bash
az webapp log config \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --application-logging true \
  --level information \
  --web-server-logging filesystem
```

**Stream logs to verify**:
```bash
az webapp log tail \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev
```

### 8.4 Create Custom Dashboard

**Steps**:
1. Go to Azure Portal
2. Navigate to "Dashboard"
3. Click "+ New dashboard"
4. Name: "Mileage Tracker - Dev"
5. Add tiles:
   - App Service metrics (requests, response time)
   - PostgreSQL metrics (connections, CPU)
   - Application Insights overview
   - Recent errors/exceptions

### 8.5 Set Up Backup Schedule

**Configure automated PostgreSQL backups**:
```bash
az postgres flexible-server update \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-db-dev \
  --backup-retention 7
```

**Create weekly manual backup cron job** (optional):
```bash
# Add to crontab (run crontab -e)
0 2 * * 0 cd /Users/joseph/Playground/MileageTracking && ./infra/scripts/backup-database.sh dev
```

### 8.6 Document Monitoring Setup

**Create monitoring runbook**:
```bash
cat > /Users/joseph/Playground/MileageTracking/.claude/result/monitoring-runbook.md << 'EOF'
# Monitoring Runbook

## Alert Response Procedures

### High Response Time Alert
1. Check Application Insights for slow requests
2. Review database query performance
3. Check CPU/memory usage on App Service
4. Scale up if needed

### High Error Rate Alert
1. View recent errors in Application Insights
2. Check application logs
3. Review database connection status
4. Check for recent deployments

### Database Connection Failure Alert
1. Check database server status
2. Verify firewall rules
3. Check connection string configuration
4. Review connection pool settings

## Monitoring URLs
- Application Insights: [Link to Azure Portal]
- App Service Metrics: [Link to Azure Portal]
- PostgreSQL Metrics: [Link to Azure Portal]
- Log Analytics: [Link to Azure Portal]
EOF
```

### 8.7 Phase 7 Completion Checklist
- [ ] Application Insights verified
- [ ] Alert rules created (response time, errors, database)
- [ ] Logging configured
- [ ] Custom dashboard created (optional)
- [ ] Backup schedule configured
- [ ] Monitoring runbook documented

**Decision Point**: Monitoring setup complete. System is production-ready.

---

## 9. Rollback Procedures

### 9.1 Application Rollback

**Scenario**: New deployment causes issues

**Steps**:
```bash
# 1. Stop application
az webapp stop --name mileage-deal-tracker-dev --resource-group mileage-deal-rg-dev

# 2. List deployments
az webapp deployment list \
  --name mileage-deal-tracker-dev \
  --resource-group mileage-deal-rg-dev \
  --output table

# 3. Redeploy previous version
az webapp deployment redeploy \
  --name mileage-deal-tracker-dev \
  --resource-group mileage-deal-rg-dev \
  --deployment-id <previous-deployment-id>

# 4. Start application
az webapp start --name mileage-deal-tracker-dev --resource-group mileage-deal-rg-dev

# 5. Verify
./infra/scripts/health-check.sh dev
```

### 9.2 Database Rollback

**Scenario**: Migration corrupted database

**Steps**:
```bash
# 1. Stop application
az webapp stop --name mileage-deal-tracker-dev --resource-group mileage-deal-rg-dev

# 2. List backups
ls -lh /Users/joseph/Playground/MileageTracking/backups/

# 3. Restore from backup
export DATABASE_URL="..."
gunzip -c backups/mileage_tracker_dev_YYYYMMDD_HHMMSS.sql.gz | psql "$DATABASE_URL"

# 4. Verify data
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM \"Offer\";"

# 5. Start application
az webapp start --name mileage-deal-tracker-dev --resource-group mileage-deal-rg-dev
```

### 9.3 Infrastructure Rollback

**Scenario**: Terraform changes broke infrastructure

**Steps**:
```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform

# 1. Check Terraform state
terraform show

# 2. Revert to previous state (if using version control)
git log terraform.tfstate
git checkout <previous-commit> terraform.tfstate

# 3. Or destroy and recreate
terraform destroy -auto-approve
terraform apply -auto-approve

# 4. Restore database
# (follow Database Rollback steps above)
```

### 9.4 Complete Disaster Recovery

**Scenario**: Everything is broken

**Steps**:
```bash
# 1. Destroy all Azure resources
cd /Users/joseph/Playground/MileageTracking/infra/terraform
terraform destroy -auto-approve

# 2. Restore from git
cd /Users/joseph/Playground/MileageTracking
git pull origin main

# 3. Redeploy infrastructure
cd infra/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 4. Restore database from backup
# (follow Database Rollback steps)

# 5. Redeploy application
# (trigger Azure Pipeline)

# 6. Verify
./infra/scripts/health-check.sh dev
```

---

## 10. Troubleshooting Decision Tree

### Issue: Application Not Loading

```
Q: Is the App Service running?
└─ No → Run: az webapp start --name mileage-deal-tracker-dev --resource-group mileage-deal-rg-dev
└─ Yes → Q: Does health endpoint respond?
   └─ No → Q: Are environment variables set?
      └─ No → Run: az webapp config appsettings set ... (see Phase 4.7)
      └─ Yes → Check application logs: az webapp log tail ...
   └─ Yes → Q: Does UI load in browser?
      └─ No → Check browser console for errors
      └─ Yes → Issue may be client-side
```

### Issue: Database Connection Fails

```
Q: Can you connect with psql?
└─ No → Q: Are firewall rules configured?
   └─ No → Add your IP: az postgres flexible-server firewall-rule create ...
   └─ Yes → Q: Is DATABASE_URL correct?
      └─ No → Fix in App Service settings
      └─ Yes → Check PostgreSQL server status
└─ Yes → Q: Does Prisma client work?
   └─ No → Regenerate: npx prisma generate
   └─ Yes → Check connection string in app
```

### Issue: Pipeline Fails

```
Q: Which stage failed?
└─ Build → Q: Did pnpm install succeed?
   └─ No → Check network connectivity, retry
   └─ Yes → Q: Did build succeed?
      └─ No → Check for TypeScript errors locally
└─ Deploy → Q: Is service connection valid?
   └─ No → Recreate service connection
   └─ Yes → Check App Service quota/limits
└─ Migration → Q: Is DATABASE_URL set in pipeline?
   └─ No → Add to variable group
   └─ Yes → Check migration files syntax
```

### Issue: Performance Problems

```
Q: Is response time > 2 seconds?
└─ Yes → Q: Is database slow?
   └─ Yes → Check query performance, add indexes
   └─ No → Q: Is App Service CPU high?
      └─ Yes → Scale up: az appservice plan update --sku B2
      └─ No → Check for memory leaks
└─ No → Acceptable performance
```

---

## 11. Success Criteria

### Deployment Success Checklist

#### Infrastructure (Phase 3)
- [ ] All 12 Azure resources created successfully
- [ ] Resource group visible in Azure Portal
- [ ] App Service status: Running
- [ ] PostgreSQL status: Ready
- [ ] Storage account accessible
- [ ] Application Insights receiving data

#### Database (Phase 4)
- [ ] All tables created (11 tables from schema)
- [ ] Foreign key constraints in place
- [ ] Sample data seeded (6 issuers, 4 products, 3 offers)
- [ ] Initial backup created
- [ ] Connection string configured in App Service

#### Application (Phase 6)
- [ ] Application loads at Azure URL
- [ ] Homepage displays correctly
- [ ] Offers page shows 3 offers
- [ ] Issuers page shows 6 issuers
- [ ] All navigation links work
- [ ] API endpoints return correct data
- [ ] Health endpoint returns status: "ok"
- [ ] No JavaScript errors in browser console
- [ ] No critical errors in application logs

#### CI/CD (Phase 5)
- [ ] Azure DevOps pipeline configured
- [ ] Pipeline runs successfully on git push
- [ ] Build stage completes
- [ ] Deploy stage completes
- [ ] Migration stage completes
- [ ] Artifacts published
- [ ] Environment variables set

#### Monitoring (Phase 7)
- [ ] Application Insights collecting telemetry
- [ ] Alert rules created
- [ ] Logging enabled and working
- [ ] Dashboard created (optional)
- [ ] Backup schedule configured

### Performance Benchmarks

| Metric                    | Target      | Actual | Status |
|---------------------------|-------------|--------|--------|
| Homepage Load Time        | < 2s        |        |        |
| API Response Time         | < 500ms     |        |        |
| Database Query Time       | < 100ms     |        |        |
| Health Endpoint           | < 100ms     |        |        |
| Uptime (first 24h)        | > 99%       |        |        |

### Cost Verification

| Resource                  | Expected Cost | Actual Cost | Variance |
|---------------------------|---------------|-------------|----------|
| App Service (B1)          | $13/month     |             |          |
| PostgreSQL (B1ms)         | $12/month     |             |          |
| Storage Account           | $0.50/month   |             |          |
| Application Insights      | $3/month      |             |          |
| **Total**                 | **~$30/month**|             |          |

**Cost Check Command**:
```bash
az consumption usage list \
  --start-date $(date -v-1d +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[?contains(instanceId, 'mileage-deal')].{name:instanceName, cost:pretaxCost}" \
  --output table
```

---

## Final Notes

### Estimated Total Time by Phase

| Phase | Description                    | Time Estimate |
|-------|--------------------------------|---------------|
| 1     | Tool Installation              | 20-30 min     |
| 2     | Azure Account Configuration    | 30-45 min     |
| 3     | Terraform Deployment           | 30-45 min     |
| 4     | Database Setup                 | 15-20 min     |
| 5     | Azure DevOps Pipeline          | 30-45 min     |
| 6     | Post-Deployment Verification   | 20-30 min     |
| 7     | Monitoring Setup               | 20-30 min     |
| **Total** | **First-time deployment**  | **3-4 hours** |

### Subsequent Deployments

Once initial setup is complete:
- Code changes: Automatic via CI/CD pipeline (~10 min)
- Infrastructure changes: `terraform apply` (~10-15 min)
- Database migrations: Automatic in pipeline (~2 min)

### Production Deployment Considerations

When ready to deploy to production:

1. **Create new Terraform workspace**:
   ```bash
   terraform workspace new prod
   terraform workspace select prod
   ```

2. **Use production variables**:
   ```bash
   terraform plan -var-file="terraform.tfvars.prod" -out=tfplan
   terraform apply tfplan
   ```

3. **Update pipeline for prod branch**:
   - Modify `.azure-pipelines/azure-pipelines.yml`
   - Add production environment in Azure DevOps
   - Require manual approval for prod deployments

4. **Use stronger security**:
   - Azure Key Vault for secrets
   - Managed Identity for Azure resources
   - Custom domain with SSL
   - Azure Front Door for CDN/WAF

### Next Steps After Successful Deployment

1. **Custom Domain** (Optional):
   - Purchase domain
   - Configure DNS
   - Add custom domain in App Service
   - Enable SSL certificate

2. **Enhanced Monitoring**:
   - Set up custom Application Insights queries
   - Create Azure Monitor workbooks
   - Configure email/SMS alerts

3. **Security Hardening**:
   - Enable Azure Defender
   - Configure IP restrictions
   - Implement rate limiting
   - Regular security audits

4. **Phase 2 Features** (From original plan):
   - ETL pipeline for offer scraping
   - Email notification system
   - User authentication
   - Admin CMS

### Support Resources

- **Azure Documentation**: https://docs.microsoft.com/en-us/azure/
- **Terraform Azure Provider**: https://registry.terraform.io/providers/hashicorp/azurerm/
- **Next.js Deployment**: https://nextjs.org/docs/deployment
- **Prisma Deployment**: https://www.prisma.io/docs/guides/deployment
- **Project Documentation**:
  - `infra/README.md`
  - `.claude/result/azure-deployment-preparation.md`
  - `README.md`

### Feedback and Iteration

After deployment, monitor for:
- [ ] Performance issues
- [ ] Error patterns
- [ ] User feedback
- [ ] Cost overruns
- [ ] Security concerns

Iterate and improve based on real-world usage data.

---

## Appendix: Quick Command Reference

### Common Operations

**View Application Logs**:
```bash
az webapp log tail --name mileage-deal-tracker-dev --resource-group mileage-deal-rg-dev
```

**Restart Application**:
```bash
az webapp restart --name mileage-deal-tracker-dev --resource-group mileage-deal-rg-dev
```

**Scale Up**:
```bash
az appservice plan update --name mileage-deal-plan-dev --resource-group mileage-deal-rg-dev --sku B2
```

**Database Backup**:
```bash
cd /Users/joseph/Playground/MileageTracking
./infra/scripts/backup-database.sh dev
```

**Health Check**:
```bash
./infra/scripts/health-check.sh dev
```

**View Terraform State**:
```bash
cd infra/terraform
terraform show
```

**Trigger Pipeline**:
```bash
git commit --allow-empty -m "Trigger pipeline"
git push origin main
```

#### IMPORTANT RULE TO FOLLOW #### 
Perform the plans specified in this document and prepare result document under ./.claude/result folder.
Use file name with 'v3-' prepix.  

---

**Document Status**: ✅ Ready for Execution
**Last Updated**: 2025-11-05
**Version**: 3.0
**Author**: Claude Code (Anthropic)
