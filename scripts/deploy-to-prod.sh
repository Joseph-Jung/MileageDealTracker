#!/bin/bash

# Manual Production Deployment Script
# Usage: ./scripts/deploy-to-prod.sh

set -e  # Exit on error

echo "========================================="
echo "Manual Production Deployment"
echo "========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="mileage-deal-rg-prod"
APP_NAME="mileage-deal-tracker-prod"
WORK_DIR="apps/web"

echo -e "${YELLOW}Step 1: Verifying Azure CLI login${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged into Azure CLI${NC}"
    echo "Please run: az login"
    exit 1
fi
echo -e "${GREEN}✓ Azure CLI authenticated${NC}"
echo ""

echo -e "${YELLOW}Step 2: Building Next.js application${NC}"
cd "$WORK_DIR"
echo "Running: npm ci"
npm ci --quiet
echo "Running: npx prisma generate"
npx prisma generate > /dev/null
echo "Running: npm run build"
npm run build
echo -e "${GREEN}✓ Build completed successfully${NC}"
echo ""

echo -e "${YELLOW}Step 3: Creating deployment package${NC}"
rm -rf deploy deployment.zip 2>/dev/null || true
mkdir -p deploy

# Copy necessary files
cp -r .next deploy/
cp -r src deploy/
cp -r public deploy/ 2>/dev/null || true
cp -r prisma deploy/
cp -r prisma-lib deploy/
cp -r node_modules deploy/
cp package*.json deploy/
cp next.config.js deploy/
cp postcss.config.js deploy/
cp tailwind.config.js deploy/
cp tsconfig.json deploy/

# Create ZIP file
cd deploy
zip -r ../deployment.zip . -x "*.git*" > /dev/null
cd ..
echo -e "${GREEN}✓ Deployment package created: $(du -h deployment.zip | cut -f1)${NC}"
echo ""

echo -e "${YELLOW}Step 4: Deploying to production staging slot${NC}"
echo "This will deploy to the staging slot first for safety..."
az webapp deployment source config-zip \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --slot staging \
  --src deployment.zip
echo -e "${GREEN}✓ Deployed to staging slot${NC}"
echo ""

echo -e "${YELLOW}Step 5: Waiting for deployment to complete (60 seconds)${NC}"
sleep 60
echo -e "${GREEN}✓ Wait complete${NC}"
echo ""

echo -e "${YELLOW}Step 6: Testing staging slot${NC}"
STAGING_URL="https://${APP_NAME}-staging.azurewebsites.net/api/health"
echo "Testing: $STAGING_URL"
RESPONSE=$(curl -s -w "\n%{http_code}" "$STAGING_URL" || echo "000")
STATUS_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$STATUS_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Staging health check passed (200 OK)${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Staging health check failed (Status: $STATUS_CODE)${NC}"
    echo "Response: $RESPONSE"
    echo ""
    echo "Deployment stopped. Staging slot is not healthy."
    echo "Check logs: az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_NAME --slot staging"
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 7: Swapping staging to production${NC}"
echo "This will perform a blue-green deployment..."
read -p "Type 'SWAP' to swap staging to production (or Ctrl+C to cancel): " confirmation
if [ "$confirmation" != "SWAP" ]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

az webapp deployment slot swap \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --slot staging \
  --target-slot production

echo -e "${GREEN}✓ Slot swap completed${NC}"
echo ""

echo -e "${YELLOW}Step 8: Verifying production deployment${NC}"
sleep 30
PROD_URL="https://${APP_NAME}.azurewebsites.net/api/health"
echo "Testing: $PROD_URL"
RESPONSE=$(curl -s -w "\n%{http_code}" "$PROD_URL" || echo "000")
STATUS_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$STATUS_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Production health check passed (200 OK)${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Production health check failed (Status: $STATUS_CODE)${NC}"
    echo "Response: $RESPONSE"
    echo ""
    echo -e "${YELLOW}Consider rolling back:${NC}"
    echo "az webapp deployment slot swap --resource-group $RESOURCE_GROUP --name $APP_NAME --slot production --target-slot staging"
    exit 1
fi
echo ""

echo "========================================="
echo -e "${GREEN}✓ PRODUCTION DEPLOYMENT SUCCESSFUL${NC}"
echo "========================================="
echo ""
echo "Production URL: https://${APP_NAME}.azurewebsites.net"
echo "Staging URL: https://${APP_NAME}-staging.azurewebsites.net"
echo ""
echo "To rollback if issues occur:"
echo "  az webapp deployment slot swap --resource-group $RESOURCE_GROUP --name $APP_NAME --slot production --target-slot staging"
echo ""

# Cleanup
rm -rf deploy deployment.zip
