#!/bin/bash
set -e

# Health Check Script for Deployed Application
# Usage: ./health-check.sh [environment]

ENVIRONMENT=${1:-prod}

echo "========================================="
echo "Application Health Check"
echo "Environment: $ENVIRONMENT"
echo "========================================="

# Set app URL based on environment
case $ENVIRONMENT in
  dev)
    APP_URL="https://mileage-deal-tracker-dev.azurewebsites.net"
    ;;
  staging)
    APP_URL="https://mileage-deal-tracker-staging.azurewebsites.net"
    ;;
  prod)
    APP_URL="https://mileage-deal-tracker.azurewebsites.net"
    ;;
  *)
    echo "Error: Environment must be dev, staging, or prod"
    exit 1
    ;;
esac

echo "Checking: $APP_URL"
echo ""

# Check if app is responding
echo "1. Testing HTTP connectivity..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL" || echo "000")

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 301 ] || [ "$HTTP_CODE" -eq 302 ]; then
    echo "   ✓ App is responding (HTTP $HTTP_CODE)"
else
    echo "   ✗ App is not responding (HTTP $HTTP_CODE)"
    exit 1
fi

# Check API health endpoint
echo ""
echo "2. Testing API health endpoint..."
HEALTH_URL="$APP_URL/api/health"
HEALTH_RESPONSE=$(curl -s "$HEALTH_URL" || echo "{\"status\":\"error\"}")

if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo "   ✓ API health check passed"
    echo "   Response: $HEALTH_RESPONSE"
else
    echo "   ✗ API health check failed"
    echo "   Response: $HEALTH_RESPONSE"
fi

# Check offers endpoint
echo ""
echo "3. Testing offers endpoint..."
OFFERS_URL="$APP_URL/api/offers"
OFFERS_RESPONSE=$(curl -s "$OFFERS_URL" || echo "[]")

if echo "$OFFERS_RESPONSE" | grep -q "\["; then
    OFFER_COUNT=$(echo "$OFFERS_RESPONSE" | grep -o "\"id\"" | wc -l | tr -d ' ')
    echo "   ✓ Offers endpoint responding"
    echo "   Offers found: $OFFER_COUNT"
else
    echo "   ✗ Offers endpoint failed"
    echo "   Response: $OFFERS_RESPONSE"
fi

# Check database connection (if DATABASE_URL is set)
if [ -n "$DATABASE_URL" ]; then
    echo ""
    echo "4. Testing database connection..."

    node -e "
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();

    prisma.\$connect()
      .then(async () => {
        const count = await prisma.offer.count();
        console.log('   ✓ Database connection successful');
        console.log('   Offers in database:', count);
        return prisma.\$disconnect();
      })
      .catch((error) => {
        console.log('   ✗ Database connection failed');
        console.log('   Error:', error.message);
        process.exit(1);
      });
    " 2>/dev/null || echo "   ⚠ Could not test database connection (Prisma client not available locally)"
fi

echo ""
echo "========================================="
echo "Health check complete!"
echo "========================================="
