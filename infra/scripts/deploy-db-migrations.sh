#!/bin/bash
set -e

# Database Migration Deployment Script
# Usage: ./deploy-db-migrations.sh [environment]

ENVIRONMENT=${1:-prod}

echo "========================================="
echo "Database Migration Deployment"
echo "Environment: $ENVIRONMENT"
echo "========================================="

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be dev, staging, or prod"
    exit 1
fi

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo "Error: DATABASE_URL environment variable is not set"
    echo "Please set DATABASE_URL before running this script"
    exit 1
fi

# Navigate to web app directory
cd "$(dirname "$0")/../../apps/web"

echo "Installing dependencies..."
npm install --production=false

echo "Generating Prisma Client..."
npx prisma generate

echo "Running database migrations..."
npx prisma migrate deploy

echo "Database migration completed successfully!"

# Optional: Run health check
echo "Verifying database connection..."
node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.\$connect()
  .then(() => {
    console.log('✓ Database connection successful');
    return prisma.\$disconnect();
  })
  .catch((error) => {
    console.error('✗ Database connection failed:', error.message);
    process.exit(1);
  });
"

echo "========================================="
echo "Migration deployment complete!"
echo "========================================="
