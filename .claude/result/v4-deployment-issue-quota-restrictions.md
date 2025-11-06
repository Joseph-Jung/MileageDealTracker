# V4 Deployment Issue: Azure Quota Restrictions

**Date**: 2025-11-06
**Status**: ⚠️ Deployment Blocked - Azure Subscription Quota Restrictions
**Phase**: Terraform Infrastructure Deployment

---

## Issue Summary

The Terraform deployment encountered **two quota restriction errors** that prevent resource creation:

### Error 1: PostgreSQL Server - Location Restricted
```
LocationIsOfferRestricted: Subscriptions are restricted from provisioning in location 'eastus'.
Try again in a different location.
```

### Error 2: App Service Plan - Quota Exceeded
```
Unauthorized: Operation cannot be completed without additional quota.
Current Limit (Basic VMs): 0
Current Usage: 0
Amount required for this deployment (Basic VMs): 0
```

---

## What Was Successfully Created ✅

Before the errors, these resources were created:

1. ✅ **Resource Group**: `mileage-deal-rg-dev`
2. ✅ **Application Insights**: `mileage-deal-tracker-insights-dev`
3. ✅ **Storage Account**: `mileagedealtrackerstdev`
4. ✅ **Storage Container**: `database-backups`
5. ✅ **Storage Container**: `offer-snapshots`

**5 out of 11 resources created** (45% complete)

---

## What Failed ❌

6. ❌ **PostgreSQL Flexible Server**: Location restricted (East US)
7. ❌ **App Service Plan**: Quota limit (0 Basic VMs allowed)
8. ❌ **Web App**: (depends on App Service Plan)
9. ❌ **PostgreSQL Database**: (depends on PostgreSQL Server)
10-11. ❌ **Firewall Rules**: (depend on PostgreSQL Server)

---

## Root Cause Analysis

### Issue 1: Free Azure Subscription Limitations

Your Azure subscription appears to be a **free tier or trial subscription** with the following restrictions:

1. **Geographic Restrictions**: PostgreSQL Flexible Server not allowed in East US region
2. **Quota Limits**: App Service Plans have 0 quota allocated
3. **Service Limitations**: Some paid services are restricted in free tier

### Issue 2: Azure Subscription Type

Based on the errors, this is likely one of:
- **Azure Free Account** ($200 credit, 12 months, limited services)
- **Pay-As-You-Go** with no quota allocated yet
- **Student/Sponsored** account with restrictions

---

## Solutions

### Solution 1: Try Different Region (Quick Fix) ⚡

PostgreSQL might be available in other regions. Let's try:

**Step 1**: Update terraform.tfvars to use West US 2:
```hcl
location = "West US 2"  # Instead of "East US"
```

**Step 2**: Clean up and retry:
```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform

# Destroy partially created resources
terraform destroy -auto-approve

# Update location
sed -i '' 's/location            = "East US"/location            = "West US 2"/' terraform.tfvars

# Retry deployment
terraform plan -out=tfplan
terraform apply tfplan
```

**Alternative Regions to Try**:
- West US 2
- Central US
- West Europe
- UK South
- Australia East

### Solution 2: Upgrade Azure Subscription (Recommended) 💳

If you need full Azure capabilities, upgrade your subscription:

**Steps**:
1. Go to Azure Portal: https://portal.azure.com
2. Navigate to "Subscriptions"
3. Select "Azure subscription 1"
4. Click "Upgrade" or "Change plan"
5. Follow prompts to upgrade to Pay-As-You-Go

**Benefits**:
- No quota restrictions
- Access to all regions
- All service types available
- Production-ready infrastructure

**Cost**: Billed based on usage (~$29/month for our dev environment)

### Solution 3: Request Quota Increase 📝

For the App Service quota issue:

**Steps**:
1. Go to Azure Portal → Subscriptions
2. Select your subscription
3. Click "Usage + quotas"
4. Search for "App Service"
5. Request increase for "Basic VMs" quota
6. Wait for approval (1-3 business days)

**Link**: https://aka.ms/postgres-request-quota-increase

### Solution 4: Use Alternative Services 🔄

If quota restrictions persist, consider alternatives:

**Instead of PostgreSQL Flexible Server**:
- Azure Database for PostgreSQL (Single Server) - Different service, might have quota
- PostgreSQL on Azure VM - More manual setup
- Azure SQL Database - Different database engine
- External database service (ElephantSQL, Supabase)

**Instead of App Service B1**:
- Try FREE tier first (F1): `app_service_sku = "F1"`
- Azure Container Instances
- Azure Functions (serverless)
- Deploy to alternative platform (Vercel, Railway)

---

## Recommended Next Steps

### Immediate Action Plan

**Option A: Try Different Region (Fastest)**
```bash
# 1. Clean up
cd /Users/joseph/Playground/MileageTracking/infra/terraform
terraform destroy -auto-approve

# 2. Update to West US 2
cat > terraform.tfvars << 'EOF'
environment         = "dev"
resource_group_name = "mileage-deal-rg-dev"
app_name            = "mileage-deal-tracker"
location            = "West US 2"  # Changed from East US

db_name             = "mileage_tracker_dev"
db_admin_username   = "dbadmin"
db_admin_password   = "MileageTracker2025!Dev#"
db_storage_mb       = 32768
db_sku_name         = "B_Standard_B1ms"

app_service_sku     = "F1"  # Try free tier first

allowed_ip_address  = "76.187.84.114"

tags = {
  Environment = "Development"
  Project     = "MileageDealTracker"
  Owner       = "joseph"
  ManagedBy   = "Terraform"
}
EOF

# 3. Retry
terraform plan -out=tfplan
terraform apply tfplan
```

**Option B: Upgrade Subscription (Best Long-Term)**
1. Upgrade Azure subscription to Pay-As-You-Go
2. Wait for upgrade to process (~5-10 minutes)
3. Retry Terraform deployment with original settings

**Option C: Deploy Elsewhere**
1. Use Vercel for frontend + API routes
2. Use Supabase/PlanetScale for PostgreSQL database
3. Lower cost, faster deployment, but less Azure-native

---

## Current State Summary

### Azure Resources Status

| Resource | Status | Resource ID |
|----------|--------|-------------|
| Resource Group | ✅ Created | mileage-deal-rg-dev |
| Application Insights | ✅ Created | mileage-deal-tracker-insights-dev |
| Storage Account | ✅ Created | mileagedealtrackerstdev |
| Storage Container (backups) | ✅ Created | database-backups |
| Storage Container (snapshots) | ✅ Created | offer-snapshots |
| PostgreSQL Server | ❌ Failed | Location restricted |
| App Service Plan | ❌ Failed | Quota exceeded |
| Web App | ❌ Not attempted | Dependency failed |
| PostgreSQL Database | ❌ Not attempted | Dependency failed |
| Firewall Rules (2) | ❌ Not attempted | Dependency failed |

### Terraform State

- State file: `infra/terraform/terraform.tfstate`
- 5 resources tracked
- Partially applied plan
- Safe to destroy and retry

### Cost Impact

**Resources Created So Far**:
- Storage Account: ~$0.50/month
- Application Insights: ~$2.88/month
- Resource Group: Free

**Current Monthly Cost**: ~$3.38/month (minimal)

---

## Cleanup Commands

If you want to start fresh:

```bash
cd /Users/joseph/Playground/MileageTracking/infra/terraform

# Option 1: Destroy everything
terraform destroy -auto-approve

# Option 2: Manually delete resource group (destroys all resources in it)
az group delete --name mileage-deal-rg-dev --yes --no-wait

# Option 3: Keep resources for now (they're cheap)
# Do nothing - only costs ~$3/month
```

---

## Error Messages (Full)

### PostgreSQL Error
```
Error: creating Flexible Server
Status: "LocationIsOfferRestricted"
Message: "Subscriptions are restricted from provisioning in location 'eastus'.
Try again in a different location. For exceptions to this rule, see how to
request a quota increase in https://aka.ms/postgres-request-quota-increase."
```

### App Service Error
```
Error: creating App Service Plan
Status: 401 (401 Unauthorized)
Message: "Operation cannot be completed without additional quota.
Current Limit (Basic VMs): 0
Current Usage: 0
Amount required for this deployment (Basic VMs): 0
(Minimum) New Limit that you should request to enable this deployment: 0."
```

---

## Lessons Learned

1. **Azure Free Tier Has Significant Restrictions**: Not suitable for this type of deployment
2. **Geographic Limitations**: PostgreSQL Flexible Server has regional restrictions
3. **Quota System**: Even with 0 usage, 0 quota means no resources can be created
4. **Partial Deployments**: Terraform handled partial failure gracefully, created what it could
5. **Subscription Upgrade Needed**: For production-like environment, paid subscription required

---

## Next Decision Point

**Question**: How would you like to proceed?

**A**: Try different Azure region (West US 2) with F1 (free) App Service?
**B**: Upgrade Azure subscription to Pay-As-You-Go?
**C**: Use alternative platform (Vercel + Supabase)?
**D**: Request quota increase and wait?
**E**: Keep exploring Azure free tier limitations?

---

**Document Created**: 2025-11-06
**Author**: Claude Code
**Status**: Awaiting user decision
