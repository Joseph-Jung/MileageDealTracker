#!/bin/bash
set -e

# Production Database Seeding Script
# Usage: ./seed-production.sh

echo "========================================="
echo "Production Database Seeding"
echo "========================================="

# Confirm production seeding
read -p "Are you sure you want to seed the PRODUCTION database? (yes/no): " -r
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Seeding cancelled."
    exit 0
fi

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo "Error: DATABASE_URL environment variable is not set"
    echo "Please set DATABASE_URL before running this script"
    exit 1
fi

# Verify it's pointing to production
if [[ ! "$DATABASE_URL" =~ prod|azure ]]; then
    read -p "DATABASE_URL does not contain 'prod' or 'azure'. Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        echo "Seeding cancelled."
        exit 0
    fi
fi

# Navigate to web app directory
cd "$(dirname "$0")/../../apps/web"

echo "Installing dependencies..."
npm install --production=false

echo "Generating Prisma Client..."
npx prisma generate

echo "Running seed script..."
npx prisma db seed

echo "========================================="
echo "Production seeding complete!"
echo "========================================="

# Show count of records
echo "Verifying seeded data..."
node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function verify() {
  try {
    const issuers = await prisma.issuer.count();
    const products = await prisma.cardProduct.count();
    const offers = await prisma.offer.count();
    const valuations = await prisma.currencyValuation.count();

    console.log('');
    console.log('Database record counts:');
    console.log('  Issuers:', issuers);
    console.log('  Card Products:', products);
    console.log('  Offers:', offers);
    console.log('  Currency Valuations:', valuations);
    console.log('');

    await prisma.\$disconnect();
  } catch (error) {
    console.error('Error verifying data:', error.message);
    process.exit(1);
  }
}

verify();
"
