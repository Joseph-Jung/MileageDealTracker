# V5 Phase 3: Monitoring & Observability - Implementation Plan

**Phase**: Application Insights, Logging, and Uptime Monitoring
**Estimated Duration**: 3-4 hours
**Prerequisites**: Phase 1 & 2 Complete (Infrastructure and CI/CD deployed)
**Status**: Planning

---

## Overview

This phase implements comprehensive monitoring and observability:
- Application Insights custom instrumentation
- Structured logging with correlation IDs
- Performance metrics and dashboards
- Alert rules for critical issues
- Uptime monitoring from multiple locations
- Log analytics and saved queries

---

## Phase 3.1: Application Insights Configuration

### Step 1: Install Application Insights SDK
**Duration**: 15 minutes

#### Install Dependencies:
```bash
cd apps/web

# Install Application Insights SDK
npm install applicationinsights @microsoft/applicationinsights-web

# Install OpenTelemetry (modern approach)
npm install @opentelemetry/api @opentelemetry/sdk-node
npm install @opentelemetry/auto-instrumentations-node
npm install @azure/monitor-opentelemetry-exporter
```

---

### Step 2: Configure Application Insights
**Duration**: 30 minutes

#### Create Application Insights Configuration:
File: `apps/web/src/lib/appInsights.ts`
```typescript
import * as appInsights from 'applicationinsights'

let appInsightsClient: appInsights.TelemetryClient | null = null

export function initializeAppInsights() {
  if (typeof window === 'undefined' && process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
    // Server-side initialization
    appInsights
      .setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
      .setAutoDependencyCorrelation(true)
      .setAutoCollectRequests(true)
      .setAutoCollectPerformance(true, true)
      .setAutoCollectExceptions(true)
      .setAutoCollectDependencies(true)
      .setAutoCollectConsole(true)
      .setUseDiskRetryCaching(true)
      .setSendLiveMetrics(true)
      .setDistributedTracingMode(appInsights.DistributedTracingModes.AI_AND_W3C)
      .start()

    appInsightsClient = appInsights.defaultClient

    // Set cloud role name
    appInsightsClient.context.tags[appInsightsClient.context.keys.cloudRole] = 'mileage-deal-tracker-web'
    appInsightsClient.context.tags[appInsightsClient.context.keys.cloudRoleInstance] = process.env.WEBSITE_INSTANCE_ID || 'local'

    console.log('Application Insights initialized')
  }
}

export function getAppInsightsClient() {
  return appInsightsClient
}

export function trackEvent(name: string, properties?: Record<string, any>, measurements?: Record<string, number>) {
  if (appInsightsClient) {
    appInsightsClient.trackEvent({
      name,
      properties,
      measurements,
    })
  }
}

export function trackMetric(name: string, value: number, properties?: Record<string, any>) {
  if (appInsightsClient) {
    appInsightsClient.trackMetric({
      name,
      value,
      properties,
    })
  }
}

export function trackException(exception: Error, properties?: Record<string, any>) {
  if (appInsightsClient) {
    appInsightsClient.trackException({
      exception,
      properties,
    })
  }
}

export function trackRequest(name: string, url: string, duration: number, responseCode: number, success: boolean) {
  if (appInsightsClient) {
    appInsightsClient.trackRequest({
      name,
      url,
      duration,
      resultCode: responseCode.toString(),
      success,
    })
  }
}

export function trackDependency(
  dependencyTypeName: string,
  name: string,
  data: string,
  duration: number,
  success: boolean,
  resultCode?: number
) {
  if (appInsightsClient) {
    appInsightsClient.trackDependency({
      dependencyTypeName,
      name,
      data,
      duration,
      success,
      resultCode,
    })
  }
}

// Flush telemetry before shutdown
export function flushAppInsights() {
  return new Promise<void>((resolve) => {
    if (appInsightsClient) {
      appInsightsClient.flush({
        callback: () => resolve(),
      })
    } else {
      resolve()
    }
  })
}
```

---

### Step 3: Initialize in Application
**Duration**: 20 minutes

#### Update Root Layout:
File: `apps/web/src/app/layout.tsx`
```typescript
import { initializeAppInsights } from '@/lib/appInsights'

// Initialize on server startup
if (typeof window === 'undefined') {
  initializeAppInsights()
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
```

#### Create Client-Side Monitoring:
File: `apps/web/src/components/ClientAppInsights.tsx`
```typescript
'use client'

import { useEffect } from 'react'
import { ApplicationInsights } from '@microsoft/applicationinsights-web'

let appInsights: ApplicationInsights | null = null

export function ClientAppInsights() {
  useEffect(() => {
    if (!appInsights && process.env.NEXT_PUBLIC_APPINSIGHTS_CONNECTION_STRING) {
      appInsights = new ApplicationInsights({
        config: {
          connectionString: process.env.NEXT_PUBLIC_APPINSIGHTS_CONNECTION_STRING,
          enableAutoRouteTracking: true,
          enableCorsCorrelation: true,
          enableRequestHeaderTracking: true,
          enableResponseHeaderTracking: true,
        },
      })

      appInsights.loadAppInsights()
      appInsights.trackPageView()
    }
  }, [])

  return null
}
```

---

### Step 4: Instrument API Routes
**Duration**: 45 minutes

#### Create API Monitoring Middleware:
File: `apps/web/src/lib/middleware/apiMonitoring.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { trackRequest, trackException, trackMetric } from '@/lib/appInsights'

export async function withApiMonitoring(
  req: NextRequest,
  handler: (req: NextRequest) => Promise<NextResponse>
) {
  const startTime = Date.now()
  const requestId = crypto.randomUUID()

  try {
    const response = await handler(req)
    const duration = Date.now() - startTime

    // Track request
    trackRequest(
      req.nextUrl.pathname,
      req.url,
      duration,
      response.status,
      response.status < 400
    )

    // Track response time metric
    trackMetric('api.response_time', duration, {
      endpoint: req.nextUrl.pathname,
      method: req.method,
      statusCode: response.status.toString(),
    })

    // Add correlation ID to response
    const headers = new Headers(response.headers)
    headers.set('X-Request-ID', requestId)

    return new NextResponse(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    })
  } catch (error) {
    const duration = Date.now() - startTime

    // Track exception
    trackException(error as Error, {
      endpoint: req.nextUrl.pathname,
      method: req.method,
      requestId,
    })

    // Track failed request
    trackRequest(req.nextUrl.pathname, req.url, duration, 500, false)

    throw error
  }
}
```

#### Update Health Check API:
File: `apps/web/src/app/api/health/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { withApiMonitoring } from '@/lib/middleware/apiMonitoring'
import { trackEvent, trackMetric } from '@/lib/appInsights'

async function handler(req: NextRequest) {
  const startTime = Date.now()

  try {
    // Check database connection
    const dbStartTime = Date.now()
    await prisma.$queryRaw`SELECT 1`
    const dbDuration = Date.now() - dbStartTime

    // Track database health metric
    trackMetric('database.health_check_duration', dbDuration, {
      status: 'healthy',
    })

    const response = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      database: {
        connected: true,
        responseTime: dbDuration,
      },
      environment: process.env.NODE_ENV,
      version: process.env.npm_package_version || 'unknown',
    }

    // Track health check event
    trackEvent('health_check', {
      status: 'healthy',
      responseTime: Date.now() - startTime,
    })

    return NextResponse.json(response, { status: 200 })
  } catch (error) {
    // Track database connection failure
    trackMetric('database.health_check_duration', Date.now() - startTime, {
      status: 'unhealthy',
    })

    trackEvent('health_check', {
      status: 'unhealthy',
      error: (error as Error).message,
    })

    return NextResponse.json(
      {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        database: {
          connected: false,
          error: (error as Error).message,
        },
      },
      { status: 503 }
    )
  }
}

export async function GET(req: NextRequest) {
  return withApiMonitoring(req, handler)
}
```

#### Instrument Offers API:
File: `apps/web/src/app/api/offers/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { withApiMonitoring } from '@/lib/middleware/apiMonitoring'
import { trackEvent, trackMetric, trackDependency } from '@/lib/appInsights'

async function handler(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams
  const page = parseInt(searchParams.get('page') || '1')
  const limit = Math.min(parseInt(searchParams.get('limit') || '20'), 100)
  const issuerFilter = searchParams.get('issuer')

  const skip = (page - 1) * limit

  try {
    // Track database query
    const dbStartTime = Date.now()

    const [offers, total] = await Promise.all([
      prisma.offer.findMany({
        where: issuerFilter
          ? {
              issuer: {
                name: {
                  contains: issuerFilter,
                  mode: 'insensitive',
                },
              },
            }
          : {},
        include: {
          issuer: true,
        },
        skip,
        take: limit,
        orderBy: {
          miles: 'desc',
        },
      }),
      prisma.offer.count({
        where: issuerFilter
          ? {
              issuer: {
                name: {
                  contains: issuerFilter,
                  mode: 'insensitive',
                },
              },
            }
          : {},
      }),
    ])

    const dbDuration = Date.now() - dbStartTime

    // Track database dependency
    trackDependency('PostgreSQL', 'offers_query', 'SELECT', dbDuration, true)

    // Track query performance
    trackMetric('database.offers_query_duration', dbDuration, {
      page: page.toString(),
      limit: limit.toString(),
      hasFilter: (!!issuerFilter).toString(),
      resultCount: offers.length.toString(),
    })

    // Track business event
    trackEvent('offers_viewed', {
      page: page.toString(),
      limit: limit.toString(),
      issuerFilter: issuerFilter || 'none',
      resultCount: offers.length,
    })

    return NextResponse.json({
      offers,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    })
  } catch (error) {
    trackMetric('database.offers_query_errors', 1, {
      error: (error as Error).message,
    })

    throw error
  }
}

export async function GET(req: NextRequest) {
  return withApiMonitoring(req, handler)
}
```

---

### Step 5: Create Custom Metrics
**Duration**: 30 minutes

#### Business Metrics Tracker:
File: `apps/web/src/lib/metrics/businessMetrics.ts`
```typescript
import { trackEvent, trackMetric } from '@/lib/appInsights'

export class BusinessMetrics {
  static trackOfferView(offerId: string, issuer: string) {
    trackEvent('offer_viewed', {
      offerId,
      issuer,
    })

    trackMetric('offers.views', 1, {
      issuer,
    })
  }

  static trackOfferClick(offerId: string, issuer: string, destination: string) {
    trackEvent('offer_clicked', {
      offerId,
      issuer,
      destination,
    })

    trackMetric('offers.clicks', 1, {
      issuer,
      destination,
    })
  }

  static trackPageView(page: string, duration?: number) {
    trackEvent('page_viewed', {
      page,
      duration: duration?.toString(),
    })

    if (duration) {
      trackMetric('page.load_time', duration, {
        page,
      })
    }
  }

  static trackError(errorType: string, message: string, stack?: string) {
    trackEvent('error_occurred', {
      errorType,
      message,
      stack: stack?.substring(0, 1000), // Limit stack trace length
    })

    trackMetric('errors.count', 1, {
      errorType,
    })
  }

  static trackDatabaseQuery(queryType: string, duration: number, success: boolean) {
    trackMetric('database.query_duration', duration, {
      queryType,
      success: success.toString(),
    })
  }
}
```

#### Performance Metrics Tracker:
File: `apps/web/src/lib/metrics/performanceMetrics.ts`
```typescript
import { trackMetric } from '@/lib/appInsights'

export class PerformanceMetrics {
  static trackMemoryUsage() {
    if (typeof process !== 'undefined') {
      const usage = process.memoryUsage()

      trackMetric('performance.memory.heapUsed', usage.heapUsed / 1024 / 1024) // MB
      trackMetric('performance.memory.heapTotal', usage.heapTotal / 1024 / 1024)
      trackMetric('performance.memory.external', usage.external / 1024 / 1024)
      trackMetric('performance.memory.rss', usage.rss / 1024 / 1024)
    }
  }

  static trackCpuUsage() {
    if (typeof process !== 'undefined') {
      const usage = process.cpuUsage()

      trackMetric('performance.cpu.user', usage.user / 1000) // microseconds to milliseconds
      trackMetric('performance.cpu.system', usage.system / 1000)
    }
  }

  static trackEventLoopLag(lag: number) {
    trackMetric('performance.eventloop.lag', lag)
  }

  static startPerformanceMonitoring(intervalMs: number = 60000) {
    setInterval(() => {
      this.trackMemoryUsage()
      this.trackCpuUsage()
    }, intervalMs)
  }
}

// Start monitoring on server startup
if (typeof window === 'undefined' && process.env.NODE_ENV === 'production') {
  PerformanceMetrics.startPerformanceMonitoring()
}
```

---

## Phase 3.2: Structured Logging

### Step 1: Install Logging Library
**Duration**: 15 minutes

```bash
cd apps/web

# Install Pino (high-performance logging)
npm install pino pino-pretty
npm install -D @types/pino
```

---

### Step 2: Configure Logger
**Duration**: 30 minutes

File: `apps/web/src/lib/logger.ts`
```typescript
import pino from 'pino'

const isProduction = process.env.NODE_ENV === 'production'

const logger = pino({
  level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
  formatters: {
    level: (label) => {
      return { level: label.toUpperCase() }
    },
    bindings: (bindings) => {
      return {
        pid: bindings.pid,
        hostname: bindings.hostname,
        node_version: process.version,
      }
    },
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  ...(isProduction
    ? {
        // Production: JSON logging
        serializers: pino.stdSerializers,
      }
    : {
        // Development: Pretty printing
        transport: {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'HH:MM:ss Z',
            ignore: 'pid,hostname',
          },
        },
      }),
})

// Add correlation ID to logs
export function createLogger(context?: Record<string, any>) {
  return logger.child({
    ...context,
    correlationId: context?.correlationId || crypto.randomUUID(),
  })
}

export default logger
```

---

### Step 3: Add Request Logging
**Duration**: 20 minutes

File: `apps/web/src/lib/middleware/requestLogging.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { createLogger } from '@/lib/logger'

export async function withRequestLogging(
  req: NextRequest,
  handler: (req: NextRequest) => Promise<NextResponse>
) {
  const correlationId = crypto.randomUUID()
  const logger = createLogger({ correlationId })

  const startTime = Date.now()

  logger.info({
    msg: 'Request started',
    method: req.method,
    url: req.url,
    headers: {
      'user-agent': req.headers.get('user-agent'),
      'x-forwarded-for': req.headers.get('x-forwarded-for'),
    },
  })

  try {
    const response = await handler(req)
    const duration = Date.now() - startTime

    logger.info({
      msg: 'Request completed',
      method: req.method,
      url: req.url,
      statusCode: response.status,
      duration,
    })

    return response
  } catch (error) {
    const duration = Date.now() - startTime

    logger.error({
      msg: 'Request failed',
      method: req.method,
      url: req.url,
      duration,
      error: {
        message: (error as Error).message,
        stack: (error as Error).stack,
      },
    })

    throw error
  }
}
```

---

### Step 4: Database Query Logging
**Duration**: 20 minutes

File: `apps/web/src/lib/db.ts`
```typescript
import { PrismaClient } from '@prisma/client'
import logger from './logger'

const prismaClientSingleton = () => {
  const client = new PrismaClient({
    log: [
      {
        emit: 'event',
        level: 'query',
      },
      {
        emit: 'event',
        level: 'error',
      },
      {
        emit: 'event',
        level: 'warn',
      },
    ],
  })

  // Log queries in development
  if (process.env.NODE_ENV !== 'production') {
    client.$on('query', (e) => {
      logger.debug({
        msg: 'Database query',
        query: e.query,
        params: e.params,
        duration: e.duration,
      })
    })
  }

  // Always log slow queries
  client.$on('query', (e) => {
    if (e.duration > 1000) {
      // Queries taking more than 1 second
      logger.warn({
        msg: 'Slow database query',
        query: e.query,
        params: e.params,
        duration: e.duration,
      })
    }
  })

  // Log errors
  client.$on('error', (e) => {
    logger.error({
      msg: 'Database error',
      error: e.message,
      target: e.target,
    })
  })

  // Log warnings
  client.$on('warn', (e) => {
    logger.warn({
      msg: 'Database warning',
      message: e.message,
    })
  })

  return client
}

declare global {
  var prisma: undefined | ReturnType<typeof prismaClientSingleton>
}

export const prisma = globalThis.prisma ?? prismaClientSingleton()

if (process.env.NODE_ENV !== 'production') globalThis.prisma = prisma
```

---

## Phase 3.3: Application Insights Dashboards

### Step 1: Create Performance Dashboard
**Duration**: 30 minutes

#### Navigate to Azure Portal:
1. Go to Application Insights resource
2. Click "Dashboards" → "New Dashboard"
3. Name: "Mileage Tracker - Performance"

#### Add Tiles:

**Tile 1: Response Time**
```kusto
requests
| where timestamp > ago(1h)
| summarize
    P50 = percentile(duration, 50),
    P95 = percentile(duration, 95),
    P99 = percentile(duration, 99)
    by bin(timestamp, 5m)
| render timechart
```

**Tile 2: Request Rate**
```kusto
requests
| where timestamp > ago(24h)
| summarize count() by bin(timestamp, 1h)
| render timechart
```

**Tile 3: Failed Requests**
```kusto
requests
| where timestamp > ago(24h)
| where success == false
| summarize count() by resultCode, bin(timestamp, 1h)
| render timechart
```

**Tile 4: Database Query Performance**
```kusto
customMetrics
| where name == "database.offers_query_duration"
| where timestamp > ago(1h)
| summarize avg(value), max(value), min(value) by bin(timestamp, 5m)
| render timechart
```

**Tile 5: Top 10 Slowest Requests**
```kusto
requests
| where timestamp > ago(24h)
| top 10 by duration desc
| project timestamp, name, duration, resultCode, success
```

---

### Step 2: Create Application Health Dashboard
**Duration**: 30 minutes

**Tile 1: Availability**
```kusto
availabilityResults
| where timestamp > ago(24h)
| summarize
    total = count(),
    successful = countif(success == true),
    availability = (todouble(countif(success == true)) / count()) * 100
    by bin(timestamp, 1h)
| render timechart
```

**Tile 2: Exception Count**
```kusto
exceptions
| where timestamp > ago(24h)
| summarize count() by type, bin(timestamp, 1h)
| render timechart
```

**Tile 3: Database Health**
```kusto
customMetrics
| where name == "database.health_check_duration"
| where timestamp > ago(1h)
| summarize avg(value) by bin(timestamp, 5m), tostring(customDimensions.status)
| render timechart
```

**Tile 4: Memory Usage**
```kusto
customMetrics
| where name == "performance.memory.heapUsed"
| where timestamp > ago(1h)
| summarize avg(value), max(value) by bin(timestamp, 5m)
| render timechart
```

---

### Step 3: Create Business Metrics Dashboard
**Duration**: 20 minutes

**Tile 1: Offer Views**
```kusto
customEvents
| where name == "offer_viewed"
| where timestamp > ago(24h)
| summarize count() by tostring(customDimensions.issuer), bin(timestamp, 1h)
| render columnchart
```

**Tile 2: Click-Through Rate**
```kusto
let views = customEvents
| where name == "offer_viewed"
| where timestamp > ago(24h)
| summarize views = count();
let clicks = customEvents
| where name == "offer_clicked"
| where timestamp > ago(24h)
| summarize clicks = count();
views
| extend clicks = toscalar(clicks)
| extend ctr = (todouble(clicks) / views) * 100
| project CTR = ctr
```

**Tile 3: Page Views by Page**
```kusto
customEvents
| where name == "page_viewed"
| where timestamp > ago(24h)
| summarize count() by tostring(customDimensions.page)
| render piechart
```

---

## Phase 3.4: Alert Rules

### Step 1: Configure Critical Alerts
**Duration**: 45 minutes

#### Alert 1: High Error Rate
```bash
az monitor metrics alert create \
  --name "High-Error-Rate" \
  --resource-group mileage-deal-rg-prod \
  --scopes /subscriptions/{sub-id}/resourceGroups/mileage-deal-rg-prod/providers/microsoft.insights/components/mileage-deal-tracker-insights-prod \
  --condition "count requests/failed > 5" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --description "Alert when error rate exceeds 5 failed requests in 5 minutes"
```

#### Alert 2: Slow Response Time
Azure Portal Configuration:
1. Navigate to Application Insights → Alerts → New Alert Rule
2. Condition: `requests | where duration > 2000`
3. Threshold: P95 > 2 seconds
4. Window: 5 minutes
5. Action: Email to team

#### Alert 3: Database Connection Failures
```kusto
customMetrics
| where name == "database.health_check_duration"
| where customDimensions.status == "unhealthy"
| count
```
Threshold: > 0 in 5 minutes

#### Alert 4: Low Availability
```kusto
availabilityResults
| where timestamp > ago(5m)
| summarize availability = (todouble(countif(success == true)) / count()) * 100
| where availability < 99
```

#### Alert 5: Memory Usage High
```kusto
customMetrics
| where name == "performance.memory.heapUsed"
| where value > 500  // 500 MB
```

---

### Step 2: Configure Warning Alerts
**Duration**: 20 minutes

#### Alert 6: Moderate Error Rate
- Threshold: > 2 failed requests in 5 minutes
- Severity: Warning

#### Alert 7: Slow Database Queries
```kusto
customMetrics
| where name == "database.offers_query_duration"
| where value > 500  // 500ms
```

#### Alert 8: High CPU Usage
```kusto
customMetrics
| where name == "performance.cpu.system"
| where value > 70  // 70% CPU
```

---

## Phase 3.5: Uptime Monitoring

### Step 1: Configure Availability Tests
**Duration**: 30 minutes

#### Create URL Ping Test:
Azure Portal:
1. Application Insights → Availability
2. Add Standard test
3. Configure:
   - Test name: Health Endpoint Check
   - URL: https://mileage-deal-tracker-prod.azurewebsites.net/api/health
   - Frequency: 5 minutes
   - Test locations: 5 locations (US West, US East, Europe North, Asia Southeast, Australia East)
   - Success criteria: HTTP 200, Response time < 2 seconds
   - Alert threshold: 2 locations failed

#### Create Multi-Step Test (Optional):
File: `monitoring/availability-test.webtest`
```xml
<WebTest Name="Critical User Journey" Enabled="True">
  <Items>
    <Request Method="GET" Url="https://mileage-deal-tracker-prod.azurewebsites.net/" />
    <Request Method="GET" Url="https://mileage-deal-tracker-prod.azurewebsites.net/offers" />
    <Request Method="GET" Url="https://mileage-deal-tracker-prod.azurewebsites.net/api/health" />
  </Items>
</WebTest>
```

---

### Step 2: External Monitoring (Optional)
**Duration**: 15 minutes

#### UptimeRobot Configuration:
1. Create account at uptimerobot.com
2. Add monitors:
   - Health endpoint: https://mileage-deal-tracker-prod.azurewebsites.net/api/health
   - Home page: https://mileage-deal-tracker-prod.azurewebsites.net
   - Offers page: https://mileage-deal-tracker-prod.azurewebsites.net/offers
3. Interval: 5 minutes
4. Alert contacts: Email, SMS

---

## Phase 3.6: Log Analytics

### Step 1: Create Saved Queries
**Duration**: 30 minutes

#### Query 1: Error Analysis
```kusto
exceptions
| where timestamp > ago(24h)
| summarize count() by type, outerMessage
| order by count_ desc
```

#### Query 2: Slow Endpoints
```kusto
requests
| where timestamp > ago(24h)
| where duration > 1000
| summarize
    count = count(),
    avgDuration = avg(duration),
    p95Duration = percentile(duration, 95)
    by name
| order by avgDuration desc
```

#### Query 3: Database Query Performance
```kusto
customMetrics
| where name startswith "database."
| where timestamp > ago(1h)
| summarize
    count = count(),
    avg = avg(value),
    max = max(value)
    by name
| order by avg desc
```

#### Query 4: User Journey Analysis
```kusto
customEvents
| where name in ("page_viewed", "offer_viewed", "offer_clicked")
| where timestamp > ago(24h)
| project timestamp, name, session_Id, customDimensions
| order by timestamp asc
```

#### Query 5: Failed Requests by Status Code
```kusto
requests
| where timestamp > ago(24h)
| where success == false
| summarize count() by resultCode, name
| order by count_ desc
```

---

### Step 2: Configure Log Retention
**Duration**: 10 minutes

```bash
# Development: 7 days
az monitor app-insights component update \
  --resource-group mileage-deal-rg-dev \
  --app mileage-deal-tracker-insights-dev \
  --retention-time 7

# Production: 90 days
az monitor app-insights component update \
  --resource-group mileage-deal-rg-prod \
  --app mileage-deal-tracker-insights-prod \
  --retention-time 90
```

---

## Validation Checklist

After implementation, verify:
- [ ] Application Insights SDK installed and configured
- [ ] Custom metrics tracking business events
- [ ] Structured logging implemented with Pino
- [ ] Request logging with correlation IDs
- [ ] Database query logging and slow query detection
- [ ] Performance dashboard created with key metrics
- [ ] Health dashboard showing availability and errors
- [ ] Business metrics dashboard tracking user behavior
- [ ] 5+ critical alerts configured
- [ ] 3+ warning alerts configured
- [ ] Availability tests running from 5 locations
- [ ] Saved queries created for common analysis
- [ ] Log retention configured appropriately
- [ ] Monitoring data visible in Azure Portal

---

## Time Estimates

| Task | Estimated Time |
|------|----------------|
| App Insights SDK setup | 15 min |
| Configure App Insights | 30 min |
| Initialize in app | 20 min |
| Instrument API routes | 45 min |
| Custom metrics | 30 min |
| Logging library setup | 15 min |
| Configure logger | 30 min |
| Request logging | 20 min |
| Database logging | 20 min |
| Performance dashboard | 30 min |
| Health dashboard | 30 min |
| Business dashboard | 20 min |
| Critical alerts | 45 min |
| Warning alerts | 20 min |
| Availability tests | 30 min |
| Saved queries | 30 min |
| **Total** | **~6 hours** |

---

## Rollback Procedures

### If Application Insights Causes Issues:
1. Remove instrumentation code temporarily
2. Set environment variable to disable tracking
3. Investigate and fix issues
4. Re-enable gradually

### If Logging Causes Performance Issues:
1. Increase log level (reduce verbosity)
2. Disable request logging for high-traffic endpoints
3. Review logging configuration

### If Alerts Are Too Noisy:
1. Adjust thresholds
2. Increase evaluation window
3. Review and refine alert conditions

---

## Next Steps

After Phase 3 completion:
1. Proceed to Phase 4: Security Hardening
2. Implement security headers
3. Configure rate limiting
4. Set up secret management

---

**Plan Created**: 2025-11-08
**Status**: Ready for Implementation
**Estimated Time**: 3-4 hours
