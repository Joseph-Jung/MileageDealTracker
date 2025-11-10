# V5 Deployment - Next Steps

**Date**: 2025-11-08
**Current Status**: Phase 1 - 75% Complete

---

## Immediate Priority: Complete Phase 1

Before proceeding to Phase 2 (CI/CD Pipeline), we need to complete the remaining Phase 1 infrastructure tasks:

### 1. Configure Production Web App Settings (15 minutes)

The production web app `mileage-deal-tracker-prod` was created but needs configuration:

```bash
# Set the production database connection string
az webapp config appsettings set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --settings \
    NODE_ENV="production" \
    WEBSITE_NODE_DEFAULT_VERSION="20-lts" \
    SCM_DO_BUILD_DURING_DEPLOYMENT="true" \
    WEBSITE_RUN_FROM_PACKAGE="0" \
    DATABASE_URL="postgresql://dbadmin:2IaMMlQPsmAPLd73ypRF7K9kWpkQ6wiY@mileage-deal-tracker-db-prod.postgres.database.azure.com:5432/mileage_tracker_prod?sslmode=require" \
    NEXT_PUBLIC_APP_URL="https://mileage-deal-tracker-prod.azurewebsites.net"

# Get Application Insights connection string
APPINSIGHTS_CONN=$(az monitor app-insights component show \
  --resource-group mileage-deal-rg-prod \
  --app mileage-deal-tracker-insights-prod \
  --query connectionString -o tsv)

# Set Application Insights connection
az webapp config appsettings set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$APPINSIGHTS_CONN"

# Configure always-on and other settings
az webapp config set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --always-on true \
  --linux-fx-version "NODE|20-lts"
```

### 2. Create Staging Deployment Slot (20 minutes)

```bash
# Create staging slot
az webapp deployment slot create \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --configuration-source mileage-deal-tracker-prod

# Configure staging-specific settings
az webapp config appsettings set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --settings \
    NODE_ENV="staging" \
    NEXT_PUBLIC_APP_URL="https://mileage-deal-tracker-prod-staging.azurewebsites.net" \
  --slot-settings \
    NODE_ENV \
    NEXT_PUBLIC_APP_URL \
    DATABASE_URL

# Verify slot was created
az webapp deployment slot list \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --output table
```

### 3. Apply Database Schema (10 minutes)

```bash
# Navigate to web app directory
cd apps/web

# Set production database URL
export DATABASE_URL="postgresql://dbadmin:2IaMMlQPsmAPLd73ypRF7K9kWpkQ6wiY@mileage-deal-tracker-db-prod.postgres.database.azure.com:5432/mileage_tracker_prod?sslmode=require"

# Run Prisma migrations
npx prisma migrate deploy

# Verify schema
npx prisma db pull

# Seed database with initial data
npx prisma db seed

# Verify data was loaded
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM \"Offer\";"
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM \"Issuer\";"
```

### 4. Update GitHub Actions for Production (15 minutes)

Update the existing `.github/workflows/azure-deploy.yml` to use Node 20:

```yaml
env:
  NODE_VERSION: '20.x'  # Change from 18.x to 20.x
```

### 5. Deploy Application Code to Production (20 minutes)

Option A: Manual deployment via Azure CLI:
```bash
cd apps/web

# Create deployment package
mkdir -p deploy
cp -r src deploy/
cp -r public deploy/ 2>/dev/null || true
cp -r prisma deploy/
cp -r prisma-lib deploy/
cp package*.json deploy/
cp next.config.js deploy/
cp postcss.config.js deploy/
cp tailwind.config.js deploy/

# Create zip
cd deploy && zip -r ../prod-deployment.zip .

# Deploy to production
az webapp deployment source config-zip \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --src ../prod-deployment.zip
```

Option B: Trigger GitHub Actions:
```bash
# Push to main branch to trigger deployment
git add .
git commit -m "Configure production deployment"
git push origin main
```

### 6. Verify Production Deployment (10 minutes)

```bash
# Wait for deployment to complete
sleep 120

# Check health endpoint
curl -s https://mileage-deal-tracker-prod.azurewebsites.net/api/health | jq

# Check offers endpoint
curl -s https://mileage-deal-tracker-prod.azurewebsites.net/api/offers | jq

# Check web interface
open https://mileage-deal-tracker-prod.azurewebsites.net
```

---

## Phase 1 Completion Checklist

- [ ] Production web app settings configured
- [ ] Application Insights connected
- [ ] Staging deployment slot created
- [ ] Database schema migrated
- [ ] Initial data seeded
- [ ] Application code deployed to production
- [ ] Health check returning 200 OK
- [ ] Web interface accessible and styled
- [ ] All API endpoints functional

**Estimated Time**: 1.5 hours

---

## Then Proceed to Phase 2: Enhanced CI/CD Pipeline

Once Phase 1 is complete, Phase 2 will involve:

### Phase 2.1: Automated Testing (3 hours)
- Set up Jest for unit tests
- Set up Playwright for E2E tests
- Create test suites for API routes
- Create component tests
- Create E2E tests for critical user journeys

### Phase 2.2: Multi-Environment Workflows (2 hours)
- Create development deployment workflow
- Create staging deployment workflow
- Create production deployment workflow with approvals
- Configure GitHub environments

### Phase 2.3: Rollback Mechanism (1 hour)
- Create manual rollback workflow
- Test slot swap functionality
- Document rollback procedures

**Phase 2 Total Estimated Time**: 5-6 hours

---

## Current Infrastructure Summary

### ✅ Deployed
- Resource Group: `mileage-deal-rg-prod`
- App Service Plan: `mileage-deal-tracker-plan-prod` (S1)
- PostgreSQL Database: `mileage-deal-tracker-db-prod` (GP_Standard_D2s_v3)
- Storage Account: `mileagedealtrackerstprod` (GRS)
- Application Insights: `mileage-deal-tracker-insights-prod`
- Production Web App: `mileage-deal-tracker-prod` (Node 20-lts)
- Auto-scaling: Configured (1-5 instances)

### ⚠️ Pending Configuration
- Web App application settings
- Staging deployment slot
- Database schema and data
- Application code deployment

### 📊 Monthly Cost: ~$340

---

## Recommended Approach

**Session 1 (Current)**:
- ✅ Complete - Phase 1 infrastructure deployment

**Session 2 (Next)**:
- Complete remaining Phase 1 tasks (1.5 hours)
- Test and verify production deployment
- Update documentation

**Session 3 (Future)**:
- Implement Phase 2: Enhanced CI/CD Pipeline
- Set up automated testing
- Create multi-environment workflows
- Test rollback mechanisms

---

## Important Notes

1. **Node Version**: Updated from 18-lts to 20-lts (Azure's current LTS support)
2. **HA Limitation**: West US 2 does not support PostgreSQL HA - using enhanced backups instead
3. **Terraform State**: Some resources created via Azure CLI due to state conflicts
4. **Security**: Database password stored in gitignored terraform.tfvars file

---

## Quick Commands Reference

### Check All Resources
```bash
az resource list --resource-group mileage-deal-rg-prod --output table
```

### Get Database Connection String
```bash
echo "postgresql://dbadmin:2IaMMlQPsmAPLd73ypRF7K9kWpkQ6wiY@mileage-deal-tracker-db-prod.postgres.database.azure.com:5432/mileage_tracker_prod?sslmode=require"
```

### Check Web App Status
```bash
az webapp show \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --query state -o tsv
```

### View Web App Logs
```bash
az webapp log tail \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod
```

---

**Document Created**: 2025-11-08
**Status**: Ready for Phase 1 completion
**Next Action**: Configure web app settings and create staging slot
