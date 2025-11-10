# V5 Phase 5: Performance Optimization - Implementation Plan

**Phase**: Performance Optimization and Caching Strategy
**Estimated Duration**: 4-5 hours
**Prerequisites**: Phases 1-4 Complete (Infrastructure, CI/CD, Monitoring, Security)
**Status**: Planning

---

## Overview

This phase implements comprehensive performance optimizations:
- Performance baseline and monitoring
- Database query optimization
- Multi-layer caching strategy (CDN, Application, Database)
- Next.js optimization (Image, Static Generation, Code Splitting)
- Auto-scaling configuration
- Performance budgets in CI/CD

---

## Phase 5.1: Performance Baseline

### Step 1: Establish Performance Baselines
**Duration**: 45 minutes

#### Run Lighthouse Audit:
```bash
# Install Lighthouse CLI
npm install -g lighthouse

# Run audit on production
lighthouse https://mileage-deal-tracker-prod.azurewebsites.net \
  --output html \
  --output-path ./performance-reports/baseline-$(date +%Y%m%d).html \
  --chrome-flags="--headless"

# Run audit on specific pages
lighthouse https://mileage-deal-tracker-prod.azurewebsites.net/offers \
  --output json \
  --output-path ./performance-reports/offers-baseline.json
```

#### Create Performance Metrics Tracker:
File: `apps/web/src/lib/performance/metrics.ts`
```typescript
export class PerformanceTracker {
  private static measurements = new Map<string, number>()

  static startMeasurement(label: string) {
    this.measurements.set(label, performance.now())
  }

  static endMeasurement(label: string): number {
    const start = this.measurements.get(label)
    if (!start) {
      console.warn(`No start measurement found for ${label}`)
      return 0
    }

    const duration = performance.now() - start
    this.measurements.delete(label)
    return duration
  }

  static async measureAsync<T>(label: string, fn: () => Promise<T>): Promise<T> {
    const start = performance.now()
    try {
      const result = await fn()
      const duration = performance.now() - start

      if (typeof window === 'undefined') {
        // Server-side logging
        const logger = require('@/lib/logger').default
        logger.info({
          msg: 'Performance measurement',
          label,
          duration,
        })
      }

      return result
    } catch (error) {
      throw error
    }
  }

  static measureSync<T>(label: string, fn: () => T): T {
    const start = performance.now()
    try {
      const result = fn()
      const duration = performance.now() - start

      if (typeof window === 'undefined') {
        const logger = require('@/lib/logger').default
        logger.info({
          msg: 'Performance measurement',
          label,
          duration,
        })
      }

      return result
    } catch (error) {
      throw error
    }
  }
}
```

#### Create Web Vitals Tracking:
File: `apps/web/src/components/WebVitals.tsx`
```typescript
'use client'

import { useReportWebVitals } from 'next/web-vitals'
import { trackMetric } from '@/lib/appInsights'

export function WebVitals() {
  useReportWebVitals((metric) => {
    // Send to Application Insights
    trackMetric(`web_vitals.${metric.name}`, metric.value, {
      id: metric.id,
      label: metric.label,
      rating: metric.rating,
    })

    // Log to console in development
    if (process.env.NODE_ENV === 'development') {
      console.log('Web Vital:', metric.name, metric.value, metric.rating)
    }
  })

  return null
}
```

#### Performance Targets Document:
File: `.claude/docs/performance-targets.md`
```markdown
# Performance Targets

## Page Load Times (LCP - Largest Contentful Paint)
- Homepage: < 1.5s (Good), < 2.5s (Acceptable)
- Offers Page: < 2.0s (Good), < 3.0s (Acceptable)
- Offer Detail: < 1.8s (Good), < 2.8s (Acceptable)

## API Response Times (P95)
- /api/health: < 100ms
- /api/offers: < 200ms
- /api/offers/[id]: < 150ms
- /api/issuers: < 150ms

## Core Web Vitals
- LCP (Largest Contentful Paint): < 2.5s
- FID (First Input Delay): < 100ms
- CLS (Cumulative Layout Shift): < 0.1

## Lighthouse Scores (Production)
- Performance: > 90
- Accessibility: > 95
- Best Practices: > 95
- SEO: > 90

## Database Performance
- Query time (P95): < 50ms
- Connection time: < 20ms
- Connection pool utilization: < 80%

## Network
- First Byte (TTFB): < 200ms
- Total Blocking Time (TBT): < 200ms
- Speed Index: < 3.0s

## Resource Sizes
- Main bundle: < 200KB (gzipped)
- Total page weight: < 1MB
- Image sizes: < 100KB each (optimized)
```

---

## Phase 5.2: Database Query Optimization

### Step 1: Add Database Indexes
**Duration**: 30 minutes

#### Analyze Current Queries:
File: `apps/web/prisma/schema.prisma` (updated with indexes)
```prisma
model Issuer {
  id        String   @id @default(uuid())
  name      String   @unique
  logoUrl   String?
  website   String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  offers    Offer[]

  @@index([name]) // Index for searching by name
}

model Offer {
  id          String   @id @default(uuid())
  title       String
  miles       Int
  minSpend    Int?
  timeframe   Int?
  annualFee   Int      @default(0)
  description String?
  applyUrl    String?
  issuerId    String
  issuer      Issuer   @relation(fields: [issuerId], references: [id])
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([issuerId]) // Index for joins
  @@index([miles]) // Index for sorting by miles
  @@index([annualFee]) // Index for filtering by fee
  @@index([createdAt]) // Index for sorting by date
}
```

#### Create Migration:
```bash
cd apps/web
npx prisma migrate dev --name add_performance_indexes
```

---

### Step 2: Optimize Prisma Queries
**Duration**: 45 minutes

#### Create Optimized Query Utilities:
File: `apps/web/src/lib/db/queries.ts`
```typescript
import { prisma } from '@/lib/db'
import { PerformanceTracker } from '@/lib/performance/metrics'

export async function getOffersPaginated(params: {
  page: number
  limit: number
  issuer?: string
  minMiles?: number
  maxAnnualFee?: number
}) {
  return PerformanceTracker.measureAsync('db.getOffersPaginated', async () => {
    const { page, limit, issuer, minMiles, maxAnnualFee } = params
    const skip = (page - 1) * limit

    const where: any = {}

    if (issuer) {
      where.issuer = {
        name: {
          contains: issuer,
          mode: 'insensitive',
        },
      }
    }

    if (minMiles) {
      where.miles = { gte: minMiles }
    }

    if (maxAnnualFee !== undefined) {
      where.annualFee = { lte: maxAnnualFee }
    }

    // Use Promise.all for parallel queries
    const [offers, total] = await Promise.all([
      prisma.offer.findMany({
        where,
        select: {
          // Select only needed fields to reduce data transfer
          id: true,
          title: true,
          miles: true,
          minSpend: true,
          timeframe: true,
          annualFee: true,
          issuer: {
            select: {
              id: true,
              name: true,
              logoUrl: true,
            },
          },
        },
        skip,
        take: limit,
        orderBy: { miles: 'desc' },
      }),
      prisma.offer.count({ where }),
    ])

    return { offers, total }
  })
}

export async function getOfferById(id: string) {
  return PerformanceTracker.measureAsync('db.getOfferById', async () => {
    return prisma.offer.findUnique({
      where: { id },
      include: {
        issuer: {
          select: {
            id: true,
            name: true,
            logoUrl: true,
            website: true,
          },
        },
      },
    })
  })
}

export async function getIssuers() {
  return PerformanceTracker.measureAsync('db.getIssuers', async () => {
    return prisma.issuer.findMany({
      select: {
        id: true,
        name: true,
        logoUrl: true,
        _count: {
          select: { offers: true },
        },
      },
      orderBy: { name: 'asc' },
    })
  })
}

export async function getTopOffers(limit: number = 10) {
  return PerformanceTracker.measureAsync('db.getTopOffers', async () => {
    return prisma.offer.findMany({
      select: {
        id: true,
        title: true,
        miles: true,
        annualFee: true,
        issuer: {
          select: {
            name: true,
            logoUrl: true,
          },
        },
      },
      take: limit,
      orderBy: { miles: 'desc' },
    })
  })
}
```

---

### Step 3: Connection Pooling Optimization
**Duration**: 20 minutes

File: `apps/web/src/lib/db.ts` (update connection settings)
```typescript
import { PrismaClient } from '@prisma/client'

const getDatabaseUrl = () => {
  const url = process.env.DATABASE_URL
  if (!url) {
    throw new Error('DATABASE_URL is not defined')
  }

  // Add connection pooling parameters
  const urlObj = new URL(url)

  // Optimize connection pool
  urlObj.searchParams.set('connection_limit', '10') // Max connections
  urlObj.searchParams.set('pool_timeout', '10') // Connection timeout (seconds)
  urlObj.searchParams.set('connect_timeout', '10') // Initial connection timeout

  // Enable prepared statements caching
  urlObj.searchParams.set('statement_cache_size', '100')

  return urlObj.toString()
}

const prismaClientSingleton = () => {
  return new PrismaClient({
    datasources: {
      db: {
        url: getDatabaseUrl(),
      },
    },
    log: process.env.NODE_ENV === 'development'
      ? ['query', 'error', 'warn']
      : ['error'],
  })
}

declare global {
  var prisma: undefined | ReturnType<typeof prismaClientSingleton>
}

export const prisma = globalThis.prisma ?? prismaClientSingleton()

if (process.env.NODE_ENV !== 'production') globalThis.prisma = prisma

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect()
})
```

---

## Phase 5.3: Application-Level Caching

### Step 1: Install Caching Libraries
**Duration**: 15 minutes

```bash
cd apps/web

# Install in-memory cache
npm install lru-cache

# Optional: Redis client for distributed caching
npm install ioredis
npm install -D @types/ioredis
```

---

### Step 2: Create Cache Layer
**Duration**: 45 minutes

File: `apps/web/src/lib/cache/index.ts`
```typescript
import { LRUCache } from 'lru-cache'

export type CacheOptions = {
  ttl?: number // Time to live in milliseconds
  max?: number // Maximum number of items
}

export class AppCache {
  private cache: LRUCache<string, any>

  constructor(options: CacheOptions = {}) {
    this.cache = new LRUCache({
      max: options.max || 500, // Maximum items
      ttl: options.ttl || 5 * 60 * 1000, // Default 5 minutes
      updateAgeOnGet: true,
      updateAgeOnHas: false,
    })
  }

  get<T>(key: string): T | undefined {
    return this.cache.get(key)
  }

  set<T>(key: string, value: T, ttl?: number): void {
    this.cache.set(key, value, { ttl })
  }

  has(key: string): boolean {
    return this.cache.has(key)
  }

  delete(key: string): boolean {
    return this.cache.delete(key)
  }

  clear(): void {
    this.cache.clear()
  }

  size(): number {
    return this.cache.size
  }
}

// Create cache instances
export const offersCache = new AppCache({
  ttl: 5 * 60 * 1000, // 5 minutes
  max: 100,
})

export const issuersCache = new AppCache({
  ttl: 30 * 60 * 1000, // 30 minutes
  max: 50,
})

export const staticDataCache = new AppCache({
  ttl: 60 * 60 * 1000, // 1 hour
  max: 50,
})

// Helper function to cache async results
export async function cacheAsync<T>(
  cache: AppCache,
  key: string,
  fetcher: () => Promise<T>,
  ttl?: number
): Promise<T> {
  // Check cache first
  const cached = cache.get<T>(key)
  if (cached !== undefined) {
    return cached
  }

  // Fetch and cache
  const result = await fetcher()
  cache.set(key, result, ttl)
  return result
}
```

---

### Step 3: Apply Caching to API Routes
**Duration**: 30 minutes

#### Update Offers API with Caching:
File: `apps/web/src/app/api/offers/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { getOffersPaginated } from '@/lib/db/queries'
import { cacheAsync, offersCache } from '@/lib/cache'
import { withApiMonitoring } from '@/lib/middleware/apiMonitoring'
import { withRateLimit } from '@/lib/middleware/rateLimit'
import { trackMetric } from '@/lib/appInsights'

async function handler(req: NextRequest, validatedQuery: any) {
  const { page, limit, issuer, minMiles, maxAnnualFee } = validatedQuery

  // Create cache key
  const cacheKey = `offers:${page}:${limit}:${issuer || 'all'}:${minMiles || 'any'}:${maxAnnualFee || 'any'}`

  // Try to get from cache
  const result = await cacheAsync(
    offersCache,
    cacheKey,
    async () => {
      // Track cache miss
      trackMetric('cache.offers.miss', 1)

      const { offers, total } = await getOffersPaginated({
        page,
        limit,
        issuer,
        minMiles,
        maxAnnualFee,
      })

      return {
        offers,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      }
    },
    5 * 60 * 1000 // 5 minutes TTL
  )

  // Track cache hit
  if (offersCache.has(cacheKey)) {
    trackMetric('cache.offers.hit', 1)
  }

  const response = NextResponse.json(result)

  // Add cache headers
  response.headers.set('Cache-Control', 'public, max-age=60, s-maxage=300')
  response.headers.set('CDN-Cache-Control', 'max-age=300')

  return response
}

export async function GET(req: NextRequest) {
  return withRateLimit(
    req,
    (req) => withApiMonitoring(req, () => handler(req, validatedQuery)),
    { limit: 100 }
  )
}
```

#### Cache Invalidation Utilities:
File: `apps/web/src/lib/cache/invalidation.ts`
```typescript
import { offersCache, issuersCache, staticDataCache } from './index'
import logger from '@/lib/logger'

export function invalidateOffersCache() {
  logger.info('Invalidating offers cache')
  offersCache.clear()
}

export function invalidateIssuersCache() {
  logger.info('Invalidating issuers cache')
  issuersCache.clear()
}

export function invalidateAllCaches() {
  logger.info('Invalidating all caches')
  offersCache.clear()
  issuersCache.clear()
  staticDataCache.clear()
}

// Invalidate specific offer
export function invalidateOffer(offerId: string) {
  logger.info({ msg: 'Invalidating offer cache', offerId })
  // Clear all offer list caches (since they might contain this offer)
  invalidateOffersCache()
}
```

---

## Phase 5.4: Next.js Optimization

### Step 1: Image Optimization
**Duration**: 30 minutes

File: `apps/web/next.config.js` (add image optimization)
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    minimumCacheTTL: 60 * 60 * 24 * 30, // 30 days
    domains: [
      'mileage-deal-tracker-prod.azurewebsites.net',
      'mileagedealtrackerstprod.blob.core.windows.net', // Azure Storage
    ],
  },

  // Enable SWC minification
  swcMinify: true,

  // Compression
  compress: true,

  // Production optimizations
  productionBrowserSourceMaps: false,

  // Experimental features
  experimental: {
    optimizeCss: true,
    optimizePackageImports: ['@/components', '@/lib'],
  },
}

module.exports = nextConfig
```

#### Optimize Image Component Usage:
File: `apps/web/src/components/OptimizedImage.tsx`
```typescript
import Image from 'next/image'

type OptimizedImageProps = {
  src: string
  alt: string
  width?: number
  height?: number
  priority?: boolean
  className?: string
}

export function OptimizedImage({
  src,
  alt,
  width = 400,
  height = 300,
  priority = false,
  className,
}: OptimizedImageProps) {
  return (
    <Image
      src={src}
      alt={alt}
      width={width}
      height={height}
      priority={priority}
      className={className}
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAIAAoDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAhEAACAQMDBQAAAAAAAAAAAAABAgMABAUGIWEREiMxUf/EABUBAQEAAAAAAAAAAAAAAAAAAAMF/8QAGhEAAgIDAAAAAAAAAAAAAAAAAAECEgMRkf/aAAwDAQACEQMRAD8AltJagyeH0AthI5xdrLcNM91BF5pX2HaH9bcfaSXWGaRmknyJckliyjqTzSlT54b6bk+h0R//2Q=="
      loading={priority ? 'eager' : 'lazy'}
    />
  )
}
```

---

### Step 2: Static Generation and ISR
**Duration**: 45 minutes

#### Configure Static Pages:
File: `apps/web/src/app/offers/page.tsx`
```typescript
import { getOffersPaginated } from '@/lib/db/queries'

export const revalidate = 300 // Revalidate every 5 minutes (ISR)

export default async function OffersPage({
  searchParams,
}: {
  searchParams: { page?: string; issuer?: string }
}) {
  const page = parseInt(searchParams.page || '1')
  const issuer = searchParams.issuer

  const { offers, total } = await getOffersPaginated({
    page,
    limit: 20,
    issuer,
  })

  return (
    <div>
      {/* Render offers */}
    </div>
  )
}
```

#### Generate Static Params for Common Pages:
File: `apps/web/src/app/offers/[id]/page.tsx`
```typescript
import { getOfferById, getTopOffers } from '@/lib/db/queries'

export const revalidate = 600 // Revalidate every 10 minutes

// Generate static pages for top offers
export async function generateStaticParams() {
  const topOffers = await getTopOffers(20)

  return topOffers.map((offer) => ({
    id: offer.id,
  }))
}

export default async function OfferDetailPage({
  params,
}: {
  params: { id: string }
}) {
  const offer = await getOfferById(params.id)

  if (!offer) {
    notFound()
  }

  return (
    <div>
      {/* Render offer details */}
    </div>
  )
}
```

---

### Step 3: Code Splitting and Lazy Loading
**Duration**: 30 minutes

File: `apps/web/src/app/layout.tsx`
```typescript
import dynamic from 'next/dynamic'

// Lazy load non-critical components
const Analytics = dynamic(() => import('@/components/Analytics'), {
  ssr: false,
})

const CookieConsent = dynamic(() => import('@/components/CookieConsent'), {
  ssr: false,
})

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        {children}
        <Analytics />
        <CookieConsent />
      </body>
    </html>
  )
}
```

---

## Phase 5.5: CDN Configuration

### Step 1: Configure Azure CDN
**Duration**: 30 minutes

```bash
# Create CDN profile
az cdn profile create \
  --name mileage-deal-tracker-cdn \
  --resource-group mileage-deal-rg-prod \
  --sku Standard_Microsoft

# Create CDN endpoint
az cdn endpoint create \
  --name mileage-deal-tracker \
  --profile-name mileage-deal-tracker-cdn \
  --resource-group mileage-deal-rg-prod \
  --origin mileage-deal-tracker-prod.azurewebsites.net \
  --origin-host-header mileage-deal-tracker-prod.azurewebsites.net \
  --enable-compression true \
  --content-types-to-compress \
    "text/html" \
    "text/css" \
    "application/javascript" \
    "application/json" \
    "image/svg+xml"

# Configure caching rules
az cdn endpoint rule add \
  --name mileage-deal-tracker \
  --profile-name mileage-deal-tracker-cdn \
  --resource-group mileage-deal-rg-prod \
  --order 1 \
  --rule-name CacheStaticAssets \
  --match-variable UrlFileExtension \
  --operator Equal \
  --match-values "jpg" "jpeg" "png" "gif" "svg" "css" "js" "woff" "woff2" \
  --action-name CacheExpiration \
  --cache-behavior Override \
  --cache-duration "30.00:00:00"
```

---

### Step 2: Configure Cache Headers
**Duration**: 20 minutes

File: `apps/web/src/middleware.ts` (add cache headers)
```typescript
import { NextRequest, NextResponse } from 'next/server'

export function middleware(req: NextRequest) {
  const response = NextResponse.next()

  // Static assets caching
  if (
    req.nextUrl.pathname.startsWith('/_next/static') ||
    req.nextUrl.pathname.match(/\.(jpg|jpeg|png|gif|svg|css|js|woff|woff2)$/)
  ) {
    response.headers.set('Cache-Control', 'public, max-age=31536000, immutable')
  }

  // API caching
  if (req.nextUrl.pathname.startsWith('/api')) {
    response.headers.set('Cache-Control', 'public, max-age=60, s-maxage=300')
  }

  // Page caching
  if (!req.nextUrl.pathname.startsWith('/api') && !req.nextUrl.pathname.startsWith('/_next')) {
    response.headers.set('Cache-Control', 'public, max-age=0, s-maxage=300, must-revalidate')
  }

  return response
}
```

---

## Phase 5.6: Performance Monitoring

### Step 1: Add Performance Budget to CI/CD
**Duration**: 30 minutes

File: `.github/workflows/performance-check.yml`
```yaml
name: Performance Check

on:
  pull_request:
    branches: [main, staging]
  workflow_dispatch:

jobs:
  lighthouse:
    name: Lighthouse Performance Audit
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Wait for deployment
        if: github.event_name == 'pull_request'
        run: sleep 60

      - name: Run Lighthouse
        uses: treosh/lighthouse-ci-action@v9
        with:
          urls: |
            https://mileage-deal-tracker-dev.azurewebsites.net
            https://mileage-deal-tracker-dev.azurewebsites.net/offers
          uploadArtifacts: true
          temporaryPublicStorage: true

      - name: Check performance budget
        uses: treosh/lighthouse-ci-action@v9
        with:
          urls: https://mileage-deal-tracker-dev.azurewebsites.net
          budgetPath: ./.lighthouserc.json
          uploadArtifacts: true
```

File: `apps/web/.lighthouserc.json`
```json
{
  "ci": {
    "collect": {
      "numberOfRuns": 3
    },
    "assert": {
      "preset": "lighthouse:recommended",
      "assertions": {
        "categories:performance": ["error", {"minScore": 0.9}],
        "categories:accessibility": ["error", {"minScore": 0.95}],
        "categories:best-practices": ["error", {"minScore": 0.95}],
        "categories:seo": ["error", {"minScore": 0.9}],
        "first-contentful-paint": ["error", {"maxNumericValue": 2000}],
        "largest-contentful-paint": ["error", {"maxNumericValue": 2500}],
        "cumulative-layout-shift": ["error", {"maxNumericValue": 0.1}],
        "total-blocking-time": ["error", {"maxNumericValue": 200}]
      }
    },
    "upload": {
      "target": "temporary-public-storage"
    }
  }
}
```

---

## Validation Checklist

After implementation, verify:
- [ ] Performance baseline established with Lighthouse
- [ ] Database indexes created and applied
- [ ] Prisma queries optimized (select only needed fields)
- [ ] Connection pooling configured
- [ ] Application-level caching implemented
- [ ] Cache hit/miss metrics tracked
- [ ] Next.js image optimization configured
- [ ] Static generation enabled for appropriate pages
- [ ] Code splitting implemented
- [ ] Azure CDN configured
- [ ] Cache headers properly set
- [ ] Performance budget enforced in CI/CD
- [ ] Web Vitals tracked in Application Insights
- [ ] Performance targets documented

---

## Time Estimates

| Task | Estimated Time |
|------|----------------|
| Performance baseline | 45 min |
| Database indexes | 30 min |
| Query optimization | 45 min |
| Connection pooling | 20 min |
| Cache library setup | 15 min |
| Cache layer implementation | 45 min |
| Apply caching to APIs | 30 min |
| Image optimization | 30 min |
| Static generation | 45 min |
| Code splitting | 30 min |
| Azure CDN setup | 30 min |
| Cache headers | 20 min |
| Performance CI/CD | 30 min |
| **Total** | **~6.5 hours** |

---

## Rollback Procedures

### If Caching Causes Stale Data:
1. Clear all caches
2. Reduce TTL values
3. Implement cache invalidation on updates
4. Monitor cache hit rates

### If Database Indexes Slow Down Writes:
1. Remove non-essential indexes
2. Monitor database performance
3. Adjust indexes based on actual usage patterns

### If CDN Causes Issues:
1. Temporarily disable CDN
2. Clear CDN cache
3. Verify origin server is responding correctly
4. Re-enable CDN

---

## Next Steps

After Phase 5 completion:
1. Proceed to Phase 6: Custom Domain & SSL
2. Configure custom domain
3. Set up SSL certificates
4. Update DNS records

---

**Plan Created**: 2025-11-08
**Status**: Ready for Implementation
**Estimated Time**: 4-5 hours
