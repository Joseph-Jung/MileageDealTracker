# V5 Phase 2: Enhanced CI/CD Pipeline - Implementation Plan

**Phase**: Enhanced CI/CD with Testing & Multi-Environment Workflows
**Estimated Duration**: 4-5 hours
**Prerequisites**: Phase 1 Complete (Production infrastructure deployed)
**Status**: Planning

---

## Overview

This phase implements a comprehensive CI/CD pipeline with:
- Automated testing (unit, integration, E2E)
- Multi-environment deployment workflows (dev, staging, production)
- Deployment approval gates for production
- Automatic rollback mechanisms
- Post-deployment verification

---

## Phase 2.1: Automated Testing Integration

### Step 1: Set Up Testing Framework
**Duration**: 45 minutes

#### Install Test Dependencies:
```bash
cd apps/web

# Install Jest and React Testing Library
npm install -D jest @jest/globals jest-environment-node
npm install -D @testing-library/react @testing-library/jest-dom
npm install -D @testing-library/user-event

# Install Playwright for E2E tests
npm install -D @playwright/test

# Install additional testing utilities
npm install -D ts-jest @types/jest
npm install -D msw # Mock Service Worker for API mocking
```

#### Create Jest Configuration:
File: `apps/web/jest.config.js`
```javascript
const nextJest = require('next/jest')

const createJestConfig = nextJest({
  // Provide the path to your Next.js app to load next.config.js and .env files in your test environment
  dir: './',
})

// Add any custom config to be passed to Jest
const customJestConfig = {
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  testEnvironment: 'jest-environment-node',
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  testMatch: [
    '**/__tests__/**/*.[jt]s?(x)',
    '**/?(*.)+(spec|test).[jt]s?(x)'
  ],
  collectCoverageFrom: [
    'src/**/*.{js,jsx,ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.{js,jsx,ts,tsx}',
    '!src/**/__tests__/**',
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },
}

module.exports = createJestConfig(customJestConfig)
```

#### Create Jest Setup File:
File: `apps/web/jest.setup.js`
```javascript
import '@testing-library/jest-dom'

// Mock environment variables
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test_db'
process.env.NODE_ENV = 'test'
```

#### Create Playwright Configuration:
File: `apps/web/playwright.config.ts`
```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
})
```

---

### Step 2: Create Unit Tests for API Routes
**Duration**: 1.5 hours

#### Health Check API Test:
File: `apps/web/src/app/api/health/__tests__/route.test.ts`
```typescript
import { GET } from '../route'
import { NextRequest } from 'next/server'

describe('/api/health', () => {
  it('should return 200 OK with healthy status', async () => {
    const request = new NextRequest('http://localhost:3000/api/health')
    const response = await GET(request)

    expect(response.status).toBe(200)

    const data = await response.json()
    expect(data).toHaveProperty('status', 'healthy')
    expect(data).toHaveProperty('timestamp')
    expect(data).toHaveProperty('database')
  })

  it('should include database connection status', async () => {
    const request = new NextRequest('http://localhost:3000/api/health')
    const response = await GET(request)
    const data = await response.json()

    expect(data.database).toHaveProperty('connected')
  })
})
```

#### Offers API Test:
File: `apps/web/src/app/api/offers/__tests__/route.test.ts`
```typescript
import { GET } from '../route'
import { NextRequest } from 'next/server'
import { prisma } from '@/lib/db'

// Mock Prisma client
jest.mock('@/lib/db', () => ({
  prisma: {
    offer: {
      findMany: jest.fn(),
      count: jest.fn(),
    },
    issuer: {
      findMany: jest.fn(),
    },
  },
}))

describe('/api/offers', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('should return paginated offers', async () => {
    const mockOffers = [
      {
        id: '1',
        title: 'Test Offer',
        miles: 60000,
        issuerId: 'issuer-1',
        issuer: { name: 'Test Bank', logoUrl: null },
      },
    ]

    ;(prisma.offer.findMany as jest.Mock).mockResolvedValue(mockOffers)
    ;(prisma.offer.count as jest.Mock).mockResolvedValue(1)

    const request = new NextRequest('http://localhost:3000/api/offers')
    const response = await GET(request)

    expect(response.status).toBe(200)

    const data = await response.json()
    expect(data).toHaveProperty('offers')
    expect(data).toHaveProperty('pagination')
    expect(data.offers).toHaveLength(1)
  })

  it('should handle pagination parameters', async () => {
    const request = new NextRequest('http://localhost:3000/api/offers?page=2&limit=10')
    await GET(request)

    expect(prisma.offer.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        skip: 10,
        take: 10,
      })
    )
  })

  it('should filter by issuer', async () => {
    const request = new NextRequest('http://localhost:3000/api/offers?issuer=chase')
    await GET(request)

    expect(prisma.offer.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          issuer: expect.objectContaining({
            name: expect.objectContaining({
              contains: 'chase',
            }),
          }),
        }),
      })
    )
  })

  it('should handle errors gracefully', async () => {
    ;(prisma.offer.findMany as jest.Mock).mockRejectedValue(new Error('DB Error'))

    const request = new NextRequest('http://localhost:3000/api/offers')
    const response = await GET(request)

    expect(response.status).toBe(500)
  })
})
```

#### Database Connection Test:
File: `apps/web/src/lib/__tests__/db.test.ts`
```typescript
import { prisma } from '../db'

describe('Database Connection', () => {
  afterAll(async () => {
    await prisma.$disconnect()
  })

  it('should connect to database successfully', async () => {
    await expect(prisma.$connect()).resolves.not.toThrow()
  })

  it('should execute raw query', async () => {
    const result = await prisma.$queryRaw`SELECT 1 as value`
    expect(result).toBeDefined()
  })
})
```

---

### Step 3: Create Component Tests
**Duration**: 1 hour

#### Offer Card Component Test:
File: `apps/web/src/components/__tests__/OfferCard.test.tsx`
```typescript
import { render, screen } from '@testing-library/react'
import { OfferCard } from '../OfferCard'

describe('OfferCard', () => {
  const mockOffer = {
    id: '1',
    title: 'Chase Sapphire Preferred',
    miles: 60000,
    minSpend: 4000,
    timeframe: 3,
    annualFee: 95,
    issuer: {
      name: 'Chase',
      logoUrl: '/logos/chase.png',
    },
  }

  it('should render offer details', () => {
    render(<OfferCard offer={mockOffer} />)

    expect(screen.getByText('Chase Sapphire Preferred')).toBeInTheDocument()
    expect(screen.getByText(/60,000/)).toBeInTheDocument()
    expect(screen.getByText(/\$4,000/)).toBeInTheDocument()
  })

  it('should display annual fee', () => {
    render(<OfferCard offer={mockOffer} />)

    expect(screen.getByText(/\$95/)).toBeInTheDocument()
  })

  it('should handle offers with no annual fee', () => {
    const freeOffer = { ...mockOffer, annualFee: 0 }
    render(<OfferCard offer={freeOffer} />)

    expect(screen.getByText(/no annual fee/i)).toBeInTheDocument()
  })
})
```

---

### Step 4: Create E2E Tests
**Duration**: 1 hour

#### Home Page E2E Test:
File: `apps/web/tests/e2e/home.spec.ts`
```typescript
import { test, expect } from '@playwright/test'

test.describe('Home Page', () => {
  test('should load successfully', async ({ page }) => {
    await page.goto('/')

    await expect(page).toHaveTitle(/Mileage Deal Tracker/i)
  })

  test('should display navigation', async ({ page }) => {
    await page.goto('/')

    await expect(page.getByRole('navigation')).toBeVisible()
    await expect(page.getByRole('link', { name: /offers/i })).toBeVisible()
  })
})
```

#### Offers Page E2E Test:
File: `apps/web/tests/e2e/offers.spec.ts`
```typescript
import { test, expect } from '@playwright/test'

test.describe('Offers Page', () => {
  test('should display offer list', async ({ page }) => {
    await page.goto('/offers')

    // Wait for offers to load
    await page.waitForSelector('[data-testid="offer-card"]')

    const offers = page.locator('[data-testid="offer-card"]')
    await expect(offers).toHaveCount(await offers.count())
  })

  test('should filter offers by issuer', async ({ page }) => {
    await page.goto('/offers')

    // Click issuer filter
    await page.click('[data-testid="filter-issuer-chase"]')

    // Verify filtered results
    const offers = page.locator('[data-testid="offer-card"]')
    await expect(offers.first()).toContainText('Chase')
  })

  test('should navigate to offer details', async ({ page }) => {
    await page.goto('/offers')

    await page.click('[data-testid="offer-card"]:first-child')

    await expect(page).toHaveURL(/\/offers\/[a-zA-Z0-9-]+/)
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
  })

  test('should handle pagination', async ({ page }) => {
    await page.goto('/offers')

    const nextButton = page.getByRole('button', { name: /next/i })
    await nextButton.click()

    await expect(page).toHaveURL(/page=2/)
  })
})
```

#### Health Check E2E Test:
File: `apps/web/tests/e2e/api/health.spec.ts`
```typescript
import { test, expect } from '@playwright/test'

test.describe('Health Check API', () => {
  test('should return healthy status', async ({ request }) => {
    const response = await request.get('/api/health')

    expect(response.ok()).toBeTruthy()
    expect(response.status()).toBe(200)

    const data = await response.json()
    expect(data.status).toBe('healthy')
    expect(data.database.connected).toBe(true)
  })
})
```

---

### Step 5: Update Package.json Scripts
**Duration**: 10 minutes

File: `apps/web/package.json` (add scripts section)
```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:headed": "playwright test --headed",
    "test:all": "npm run lint && npm run test && npm run test:e2e",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate deploy"
  }
}
```

---

## Phase 2.2: Multi-Environment Deployment Workflows

### Step 1: Create Development Deployment Workflow
**Duration**: 30 minutes

File: `.github/workflows/deploy-dev.yml`
```yaml
name: Deploy to Development

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  NODE_VERSION: '18'

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: apps/web/package-lock.json

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Run linter
        working-directory: apps/web
        run: npm run lint

      - name: Run unit tests
        working-directory: apps/web
        run: npm run test -- --coverage

      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          files: ./apps/web/coverage/coverage-final.json
          flags: unittests

  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: apps/web/package-lock.json

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Build Next.js
        working-directory: apps/web
        run: npm run build
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL_DEV }}

  deploy:
    name: Deploy to Azure Dev
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: development
      url: https://mileage-deal-tracker-dev.azurewebsites.net

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Build application
        working-directory: apps/web
        run: npm run build

      - name: Deploy to Azure Web App
        uses: azure/webapps-deploy@v2
        with:
          app-name: mileage-deal-tracker-dev
          publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE_DEV }}
          package: apps/web

  verify:
    name: Post-Deployment Verification
    runs-on: ubuntu-latest
    needs: deploy

    steps:
      - name: Wait for deployment
        run: sleep 30

      - name: Health check
        run: |
          response=$(curl -s -o /dev/null -w "%{http_code}" https://mileage-deal-tracker-dev.azurewebsites.net/api/health)
          if [ $response -ne 200 ]; then
            echo "Health check failed with status $response"
            exit 1
          fi
          echo "Health check passed"

      - name: Smoke test - Offers API
        run: |
          response=$(curl -s -o /dev/null -w "%{http_code}" https://mileage-deal-tracker-dev.azurewebsites.net/api/offers)
          if [ $response -ne 200 ]; then
            echo "Offers API test failed with status $response"
            exit 1
          fi
          echo "Offers API test passed"
```

---

### Step 2: Create Staging Deployment Workflow
**Duration**: 30 minutes

File: `.github/workflows/deploy-staging.yml`
```yaml
name: Deploy to Staging

on:
  push:
    branches:
      - staging
  workflow_dispatch:

env:
  NODE_VERSION: '18'
  AZURE_WEBAPP_NAME: mileage-deal-tracker-prod
  SLOT_NAME: staging

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: apps/web/package-lock.json

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Run linter
        working-directory: apps/web
        run: npm run lint

      - name: Run unit tests
        working-directory: apps/web
        run: npm run test -- --coverage

      - name: Install Playwright browsers
        working-directory: apps/web
        run: npx playwright install --with-deps

      - name: Run E2E tests
        working-directory: apps/web
        run: npm run test:e2e
        env:
          BASE_URL: http://localhost:3000

      - name: Upload Playwright report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: apps/web/playwright-report/
          retention-days: 30

  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: apps/web/package-lock.json

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Build Next.js
        working-directory: apps/web
        run: npm run build
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL_STAGING }}

  deploy:
    name: Deploy to Staging Slot
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: staging
      url: https://mileage-deal-tracker-prod-staging.azurewebsites.net

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Build application
        working-directory: apps/web
        run: npm run build

      - name: Deploy to Azure Staging Slot
        uses: azure/webapps-deploy@v2
        with:
          app-name: ${{ env.AZURE_WEBAPP_NAME }}
          slot-name: ${{ env.SLOT_NAME }}
          publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE_STAGING }}
          package: apps/web

  verify:
    name: Staging Verification
    runs-on: ubuntu-latest
    needs: deploy

    steps:
      - name: Wait for deployment
        run: sleep 30

      - name: Health check
        run: |
          response=$(curl -s -o /dev/null -w "%{http_code}" https://mileage-deal-tracker-prod-staging.azurewebsites.net/api/health)
          if [ $response -ne 200 ]; then
            echo "Health check failed with status $response"
            exit 1
          fi
          echo "Health check passed"

      - name: Checkout code (for E2E tests)
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Install Playwright
        working-directory: apps/web
        run: npx playwright install --with-deps

      - name: Run E2E smoke tests on staging
        working-directory: apps/web
        run: npm run test:e2e
        env:
          BASE_URL: https://mileage-deal-tracker-prod-staging.azurewebsites.net

      - name: Notify team
        if: success()
        run: |
          echo "Staging deployment successful"
          echo "URL: https://mileage-deal-tracker-prod-staging.azurewebsites.net"
```

---

### Step 3: Create Production Deployment Workflow
**Duration**: 45 minutes

File: `.github/workflows/deploy-prod.yml`
```yaml
name: Deploy to Production

on:
  workflow_dispatch:
    inputs:
      confirm:
        description: 'Type "DEPLOY" to confirm production deployment'
        required: true
        default: ''

env:
  NODE_VERSION: '18'
  AZURE_WEBAPP_NAME: mileage-deal-tracker-prod

jobs:
  validate:
    name: Validate Deployment Request
    runs-on: ubuntu-latest

    steps:
      - name: Validate confirmation
        run: |
          if [ "${{ github.event.inputs.confirm }}" != "DEPLOY" ]; then
            echo "Deployment not confirmed. Exiting."
            exit 1
          fi
          echo "Deployment confirmed"

  test:
    name: Run Full Test Suite
    runs-on: ubuntu-latest
    needs: validate

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: apps/web/package-lock.json

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Run linter
        working-directory: apps/web
        run: npm run lint

      - name: Run unit tests
        working-directory: apps/web
        run: npm run test -- --coverage

      - name: Check test coverage
        working-directory: apps/web
        run: |
          npm run test -- --coverage --coverageThreshold='{"global":{"branches":70,"functions":70,"lines":70,"statements":70}}'

      - name: Install Playwright
        working-directory: apps/web
        run: npx playwright install --with-deps

      - name: Run E2E tests
        working-directory: apps/web
        run: npm run test:e2e

  build:
    name: Build Production Bundle
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: apps/web/package-lock.json

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Build Next.js (production)
        working-directory: apps/web
        run: npm run build
        env:
          NODE_ENV: production
          DATABASE_URL: ${{ secrets.DATABASE_URL_PROD }}

      - name: Check bundle size
        working-directory: apps/web
        run: |
          du -sh .next
          echo "Build completed successfully"

  deploy-to-staging-slot:
    name: Deploy to Production Staging Slot
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: production-staging
      url: https://mileage-deal-tracker-prod-staging.azurewebsites.net

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Generate Prisma Client
        working-directory: apps/web
        run: npx prisma generate

      - name: Build application
        working-directory: apps/web
        run: npm run build
        env:
          NODE_ENV: production

      - name: Deploy to Staging Slot
        uses: azure/webapps-deploy@v2
        with:
          app-name: ${{ env.AZURE_WEBAPP_NAME }}
          slot-name: staging
          publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE_STAGING }}
          package: apps/web

  verify-staging-slot:
    name: Verify Staging Slot
    runs-on: ubuntu-latest
    needs: deploy-to-staging-slot

    steps:
      - name: Wait for deployment
        run: sleep 60

      - name: Health check
        run: |
          for i in {1..5}; do
            response=$(curl -s -o /dev/null -w "%{http_code}" https://mileage-deal-tracker-prod-staging.azurewebsites.net/api/health)
            if [ $response -eq 200 ]; then
              echo "Health check passed"
              exit 0
            fi
            echo "Attempt $i: Health check returned $response, retrying..."
            sleep 10
          done
          echo "Health check failed after 5 attempts"
          exit 1

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Install Playwright
        working-directory: apps/web
        run: npx playwright install --with-deps

      - name: Run smoke tests on staging slot
        working-directory: apps/web
        run: npm run test:e2e
        env:
          BASE_URL: https://mileage-deal-tracker-prod-staging.azurewebsites.net

  swap-to-production:
    name: Swap to Production
    runs-on: ubuntu-latest
    needs: verify-staging-slot
    environment:
      name: production
      url: https://mileage-deal-tracker-prod.azurewebsites.net

    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Swap staging to production
        run: |
          az webapp deployment slot swap \
            --resource-group mileage-deal-rg-prod \
            --name ${{ env.AZURE_WEBAPP_NAME }} \
            --slot staging \
            --target-slot production

      - name: Wait for swap to complete
        run: sleep 30

  verify-production:
    name: Verify Production
    runs-on: ubuntu-latest
    needs: swap-to-production

    steps:
      - name: Production health check
        id: health_check
        run: |
          for i in {1..10}; do
            response=$(curl -s -o /dev/null -w "%{http_code}" https://mileage-deal-tracker-prod.azurewebsites.net/api/health)
            if [ $response -eq 200 ]; then
              echo "Production health check passed"
              exit 0
            fi
            echo "Attempt $i: Health check returned $response, retrying..."
            sleep 10
          done
          echo "Production health check failed"
          echo "::set-output name=failed::true"
          exit 1

      - name: Rollback on failure
        if: steps.health_check.outputs.failed == 'true'
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Execute rollback
        if: steps.health_check.outputs.failed == 'true'
        run: |
          echo "Rolling back to previous version"
          az webapp deployment slot swap \
            --resource-group mileage-deal-rg-prod \
            --name ${{ env.AZURE_WEBAPP_NAME }} \
            --slot production \
            --target-slot staging

      - name: Checkout code
        if: steps.health_check.outputs.failed != 'true'
        uses: actions/checkout@v4

      - name: Setup Node.js
        if: steps.health_check.outputs.failed != 'true'
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install dependencies
        if: steps.health_check.outputs.failed != 'true'
        working-directory: apps/web
        run: npm ci

      - name: Install Playwright
        if: steps.health_check.outputs.failed != 'true'
        working-directory: apps/web
        run: npx playwright install --with-deps

      - name: Run production smoke tests
        if: steps.health_check.outputs.failed != 'true'
        working-directory: apps/web
        run: npm run test:e2e
        env:
          BASE_URL: https://mileage-deal-tracker-prod.azurewebsites.net

      - name: Monitor for 5 minutes
        if: steps.health_check.outputs.failed != 'true'
        run: |
          echo "Monitoring production for 5 minutes..."
          for i in {1..30}; do
            response=$(curl -s -o /dev/null -w "%{http_code}" https://mileage-deal-tracker-prod.azurewebsites.net/api/health)
            if [ $response -ne 200 ]; then
              echo "Production monitoring failed at check $i"
              exit 1
            fi
            sleep 10
          done
          echo "Production monitoring successful"

      - name: Notify success
        if: success()
        run: |
          echo "🚀 Production deployment successful!"
          echo "URL: https://mileage-deal-tracker-prod.azurewebsites.net"
          echo "Timestamp: $(date)"
```

---

## Phase 2.3: Rollback Mechanism

### Step 1: Create Manual Rollback Workflow
**Duration**: 30 minutes

File: `.github/workflows/rollback-prod.yml`
```yaml
name: Rollback Production

on:
  workflow_dispatch:
    inputs:
      reason:
        description: 'Reason for rollback'
        required: true
      confirm:
        description: 'Type "ROLLBACK" to confirm'
        required: true
        default: ''

env:
  AZURE_WEBAPP_NAME: mileage-deal-tracker-prod

jobs:
  validate:
    name: Validate Rollback
    runs-on: ubuntu-latest

    steps:
      - name: Validate confirmation
        run: |
          if [ "${{ github.event.inputs.confirm }}" != "ROLLBACK" ]; then
            echo "Rollback not confirmed. Exiting."
            exit 1
          fi
          echo "Rollback confirmed"
          echo "Reason: ${{ github.event.inputs.reason }}"

  rollback:
    name: Execute Rollback
    runs-on: ubuntu-latest
    needs: validate
    environment:
      name: production

    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Swap production back to previous version
        run: |
          echo "Executing rollback..."
          az webapp deployment slot swap \
            --resource-group mileage-deal-rg-prod \
            --name ${{ env.AZURE_WEBAPP_NAME }} \
            --slot production \
            --target-slot staging

      - name: Wait for swap
        run: sleep 30

  verify:
    name: Verify Rollback
    runs-on: ubuntu-latest
    needs: rollback

    steps:
      - name: Health check after rollback
        run: |
          for i in {1..10}; do
            response=$(curl -s -o /dev/null -w "%{http_code}" https://mileage-deal-tracker-prod.azurewebsites.net/api/health)
            if [ $response -eq 200 ]; then
              echo "Rollback successful - health check passed"
              exit 0
            fi
            echo "Attempt $i: Health check returned $response, retrying..."
            sleep 10
          done
          echo "Rollback verification failed"
          exit 1

      - name: Notify team
        if: always()
        run: |
          echo "Rollback executed"
          echo "Reason: ${{ github.event.inputs.reason }}"
          echo "Status: ${{ job.status }}"
          echo "Timestamp: $(date)"
```

---

### Step 2: Configure GitHub Environments
**Duration**: 20 minutes

#### GitHub Settings to Configure:

1. **Navigate to**: Repository → Settings → Environments

2. **Create Environments**:
   - `development`
   - `staging`
   - `production-staging`
   - `production`

3. **Configure Production Environment**:
   - Enable required reviewers (add team members)
   - Set wait timer: 0 minutes (manual approval)
   - Add deployment branch pattern: `main`, `release/*`

4. **Environment Secrets**:
   ```
   development:
   - AZURE_WEBAPP_PUBLISH_PROFILE_DEV
   - DATABASE_URL_DEV

   staging:
   - AZURE_WEBAPP_PUBLISH_PROFILE_STAGING
   - DATABASE_URL_STAGING

   production:
   - AZURE_WEBAPP_PUBLISH_PROFILE_PROD
   - DATABASE_URL_PROD
   - AZURE_CREDENTIALS (for slot swap)
   ```

#### Get Publish Profiles:
```bash
# Development
az webapp deployment list-publishing-profiles \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --xml > dev-publish-profile.xml

# Staging slot
az webapp deployment list-publishing-profiles \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --xml > staging-publish-profile.xml

# Production
az webapp deployment list-publishing-profiles \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --xml > prod-publish-profile.xml
```

#### Create Azure Service Principal:
```bash
az ad sp create-for-rbac \
  --name "mileage-deal-tracker-cicd" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/mileage-deal-rg-prod \
  --sdk-auth
```

---

## Validation Checklist

After implementation, verify:
- [ ] All test frameworks installed and configured
- [ ] Unit tests passing with >70% coverage
- [ ] E2E tests running successfully
- [ ] GitHub Actions workflows created
- [ ] All workflows validate and run without errors
- [ ] GitHub environments configured with proper secrets
- [ ] Production deployment requires manual approval
- [ ] Rollback workflow tested successfully
- [ ] Health checks working in all environments
- [ ] Smoke tests passing after deployment

---

## Time Estimates

| Task | Estimated Time |
|------|----------------|
| Testing framework setup | 45 min |
| Unit tests creation | 1.5 hours |
| Component tests | 1 hour |
| E2E tests | 1 hour |
| Dev workflow | 30 min |
| Staging workflow | 30 min |
| Prod workflow | 45 min |
| Rollback workflow | 30 min |
| GitHub config | 20 min |
| **Total** | **~5 hours** |

---

## Rollback Procedures

### If Testing Phase Fails:
1. Fix failing tests
2. Commit and push fixes
3. Workflow automatically retries

### If Build Phase Fails:
1. Review build logs
2. Fix build errors
3. Push fixes to trigger new build

### If Deployment Fails:
1. Check Azure deployment logs
2. Verify secrets are correctly configured
3. Run rollback workflow if needed

### If Production Issues After Swap:
1. Run manual rollback workflow immediately
2. Investigate issues in staging slot
3. Fix and redeploy

---

## Next Steps

After Phase 2 completion:
1. Proceed to Phase 3: Monitoring & Observability
2. Set up Application Insights dashboards
3. Configure alerts and notifications
4. Implement structured logging

---

**Plan Created**: 2025-11-08
**Status**: Ready for Implementation
**Estimated Time**: 4-5 hours
