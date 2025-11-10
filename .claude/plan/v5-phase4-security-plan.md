# V5 Phase 4: Security Hardening - Implementation Plan

**Phase**: Security Headers, Rate Limiting, and Secret Management
**Estimated Duration**: 3-4 hours
**Prerequisites**: Phases 1-3 Complete (Infrastructure, CI/CD, and Monitoring deployed)
**Status**: Planning

---

## Overview

This phase implements comprehensive security hardening:
- Security headers (CSP, HSTS, X-Frame-Options, etc.)
- Rate limiting for API endpoints
- CORS configuration
- Input validation and sanitization
- Azure Key Vault integration
- Secret rotation procedures
- Security audit checklist

---

## Phase 4.1: Security Headers

### Step 1: Configure Next.js Security Headers
**Duration**: 30 minutes

File: `apps/web/next.config.js`
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Security headers
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=31536000; includeSubDomains; preload',
          },
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'Permissions-Policy',
            value: 'camera=(), microphone=(), geolocation=(), interest-cohort=()',
          },
        ],
      },
    ]
  },

  // Additional security configurations
  poweredByHeader: false,
  compress: true,

  // Webpack configuration for security
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        net: false,
        tls: false,
      }
    }
    return config
  },
}

module.exports = nextConfig
```

---

### Step 2: Implement Content Security Policy
**Duration**: 45 minutes

#### Create CSP Configuration:
File: `apps/web/src/lib/security/csp.ts`
```typescript
export function generateCSP() {
  const isDevelopment = process.env.NODE_ENV === 'development'

  const cspDirectives = {
    'default-src': ["'self'"],
    'script-src': [
      "'self'",
      "'unsafe-eval'", // Required for Next.js development
      isDevelopment ? "'unsafe-inline'" : '',
      'https://js.monitor.azure.com', // Application Insights
    ].filter(Boolean),
    'style-src': [
      "'self'",
      "'unsafe-inline'", // Required for Tailwind and styled-components
    ],
    'img-src': [
      "'self'",
      'data:',
      'blob:',
      'https:', // Allow images from any HTTPS source (credit card logos, etc.)
    ],
    'font-src': ["'self'", 'data:'],
    'connect-src': [
      "'self'",
      'https://*.azurewebsites.net',
      'https://dc.services.visualstudio.com', // Application Insights
      isDevelopment ? 'ws://localhost:*' : '', // WebSocket for hot reload
      isDevelopment ? 'http://localhost:*' : '',
    ].filter(Boolean),
    'frame-src': ["'none'"],
    'object-src': ["'none'"],
    'base-uri': ["'self'"],
    'form-action': ["'self'"],
    'frame-ancestors': ["'none'"],
    'upgrade-insecure-requests': isDevelopment ? [] : [''],
  }

  return Object.entries(cspDirectives)
    .map(([key, values]) => {
      if (Array.isArray(values) && values.length === 0) return ''
      return `${key} ${Array.isArray(values) ? values.join(' ') : values}`
    })
    .filter(Boolean)
    .join('; ')
}

export function getSecurityHeaders() {
  return {
    'Content-Security-Policy': generateCSP(),
    'X-DNS-Prefetch-Control': 'on',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), interest-cohort=()',
  }
}
```

#### Update Next.js Config to Use Dynamic CSP:
File: `apps/web/next.config.js` (updated)
```javascript
const { getSecurityHeaders } = require('./src/lib/security/csp')

/** @type {import('next').NextConfig} */
const nextConfig = {
  async headers() {
    const securityHeaders = getSecurityHeaders()

    return [
      {
        source: '/:path*',
        headers: Object.entries(securityHeaders).map(([key, value]) => ({
          key,
          value,
        })),
      },
    ]
  },

  poweredByHeader: false,
  compress: true,
}

module.exports = nextConfig
```

---

## Phase 4.2: Rate Limiting

### Step 1: Install Rate Limiting Library
**Duration**: 15 minutes

```bash
cd apps/web

# Install rate limiting library
npm install @upstash/ratelimit @upstash/redis

# Alternative: in-memory rate limiting
npm install express-rate-limit
```

---

### Step 2: Configure Rate Limiting Middleware
**Duration**: 45 minutes

#### Create Rate Limiter:
File: `apps/web/src/lib/security/rateLimiter.ts`
```typescript
import { LRUCache } from 'lru-cache'

type RateLimitOptions = {
  interval: number // Time window in milliseconds
  uniqueTokenPerInterval: number // Max number of unique tokens
}

export class RateLimiter {
  private cache: LRUCache<string, number[]>

  constructor(private options: RateLimitOptions) {
    this.cache = new LRUCache({
      max: options.uniqueTokenPerInterval,
      ttl: options.interval,
    })
  }

  check(limit: number, token: string): { success: boolean; remaining: number; reset: number } {
    const now = Date.now()
    const tokenKey = token
    const tokenCount = this.cache.get(tokenKey) || []

    // Remove old timestamps outside the window
    const windowStart = now - this.options.interval
    const validTimestamps = tokenCount.filter((timestamp) => timestamp > windowStart)

    if (validTimestamps.length >= limit) {
      const oldestTimestamp = validTimestamps[0]
      const reset = oldestTimestamp + this.options.interval

      return {
        success: false,
        remaining: 0,
        reset,
      }
    }

    // Add new timestamp
    validTimestamps.push(now)
    this.cache.set(tokenKey, validTimestamps)

    return {
      success: true,
      remaining: limit - validTimestamps.length,
      reset: now + this.options.interval,
    }
  }
}

// Create rate limiters for different endpoints
export const apiRateLimiter = new RateLimiter({
  interval: 60 * 1000, // 1 minute
  uniqueTokenPerInterval: 500, // Max 500 unique IPs per minute
})

export const strictRateLimiter = new RateLimiter({
  interval: 60 * 1000, // 1 minute
  uniqueTokenPerInterval: 100, // Max 100 unique IPs per minute
})
```

#### Create Rate Limiting Middleware:
File: `apps/web/src/lib/middleware/rateLimit.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { apiRateLimiter, strictRateLimiter } from '@/lib/security/rateLimiter'
import logger from '@/lib/logger'

export type RateLimitConfig = {
  limit: number // Max requests per window
  strict?: boolean // Use stricter rate limiter
}

export async function withRateLimit(
  req: NextRequest,
  handler: (req: NextRequest) => Promise<NextResponse>,
  config: RateLimitConfig = { limit: 100 }
) {
  // Get client identifier (IP address)
  const identifier = getClientIdentifier(req)

  // Choose rate limiter
  const limiter = config.strict ? strictRateLimiter : apiRateLimiter

  // Check rate limit
  const { success, remaining, reset } = limiter.check(config.limit, identifier)

  if (!success) {
    logger.warn({
      msg: 'Rate limit exceeded',
      ip: identifier,
      endpoint: req.nextUrl.pathname,
      limit: config.limit,
    })

    return new NextResponse(
      JSON.stringify({
        error: 'Too many requests',
        message: 'Rate limit exceeded. Please try again later.',
        retryAfter: Math.ceil((reset - Date.now()) / 1000),
      }),
      {
        status: 429,
        headers: {
          'Content-Type': 'application/json',
          'Retry-After': Math.ceil((reset - Date.now()) / 1000).toString(),
          'X-RateLimit-Limit': config.limit.toString(),
          'X-RateLimit-Remaining': '0',
          'X-RateLimit-Reset': reset.toString(),
        },
      }
    )
  }

  // Add rate limit headers to response
  const response = await handler(req)

  const headers = new Headers(response.headers)
  headers.set('X-RateLimit-Limit', config.limit.toString())
  headers.set('X-RateLimit-Remaining', remaining.toString())
  headers.set('X-RateLimit-Reset', reset.toString())

  return new NextResponse(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  })
}

function getClientIdentifier(req: NextRequest): string {
  // Try to get real IP from various headers
  const forwardedFor = req.headers.get('x-forwarded-for')
  const realIp = req.headers.get('x-real-ip')
  const cfConnectingIp = req.headers.get('cf-connecting-ip') // Cloudflare

  if (forwardedFor) {
    return forwardedFor.split(',')[0].trim()
  }

  if (realIp) {
    return realIp
  }

  if (cfConnectingIp) {
    return cfConnectingIp
  }

  // Fallback to a default identifier
  return 'unknown'
}
```

---

### Step 3: Apply Rate Limiting to API Routes
**Duration**: 30 minutes

#### Update Offers API:
File: `apps/web/src/app/api/offers/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { withApiMonitoring } from '@/lib/middleware/apiMonitoring'
import { withRateLimit } from '@/lib/middleware/rateLimit'

async function handler(req: NextRequest) {
  // Existing handler code...
}

export async function GET(req: NextRequest) {
  return withRateLimit(
    req,
    (req) => withApiMonitoring(req, handler),
    { limit: 100 } // 100 requests per minute
  )
}
```

#### Update Health Check API (Relaxed):
File: `apps/web/src/app/api/health/route.ts`
```typescript
export async function GET(req: NextRequest) {
  return withRateLimit(
    req,
    (req) => withApiMonitoring(req, handler),
    { limit: 60 } // 60 requests per minute (more generous for monitoring)
  )
}
```

#### Create Auth Endpoint with Strict Rate Limiting:
File: `apps/web/src/app/api/auth/login/route.ts` (example)
```typescript
export async function POST(req: NextRequest) {
  return withRateLimit(
    req,
    (req) => withApiMonitoring(req, handler),
    { limit: 5, strict: true } // Only 5 login attempts per minute
  )
}
```

---

## Phase 4.3: CORS Configuration

### Step 1: Configure CORS
**Duration**: 20 minutes

File: `apps/web/src/lib/security/cors.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'

const allowedOrigins = [
  'https://mileage-deal-tracker-prod.azurewebsites.net',
  'https://mileage-deal-tracker-prod-staging.azurewebsites.net',
  'https://app.mileagedealtracker.com', // Custom domain
  process.env.NODE_ENV === 'development' ? 'http://localhost:3000' : '',
].filter(Boolean)

export function configureCORS(req: NextRequest, res: NextResponse): NextResponse {
  const origin = req.headers.get('origin')

  // Check if origin is allowed
  if (origin && allowedOrigins.includes(origin)) {
    res.headers.set('Access-Control-Allow-Origin', origin)
  }

  res.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
  res.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Request-ID')
  res.headers.set('Access-Control-Max-Age', '86400') // 24 hours

  return res
}

export async function handleCORSPreflightRequest(req: NextRequest): Promise<NextResponse | null> {
  if (req.method === 'OPTIONS') {
    const response = new NextResponse(null, { status: 204 })
    return configureCORS(req, response)
  }
  return null
}
```

#### Apply CORS to API Routes:
File: `apps/web/src/middleware.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { handleCORSPreflightRequest, configureCORS } from '@/lib/security/cors'

export async function middleware(req: NextRequest) {
  // Handle CORS preflight requests
  const corsResponse = await handleCORSPreflightRequest(req)
  if (corsResponse) {
    return corsResponse
  }

  // Continue with request
  const response = NextResponse.next()

  // Add CORS headers to all API responses
  if (req.nextUrl.pathname.startsWith('/api')) {
    return configureCORS(req, response)
  }

  return response
}

export const config = {
  matcher: '/api/:path*',
}
```

---

## Phase 4.4: Input Validation

### Step 1: Install Validation Library
**Duration**: 10 minutes

```bash
cd apps/web

# Install Zod for schema validation
npm install zod
```

---

### Step 2: Create Validation Schemas
**Duration**: 30 minutes

File: `apps/web/src/lib/validation/schemas.ts`
```typescript
import { z } from 'zod'

// Pagination schema
export const paginationSchema = z.object({
  page: z
    .string()
    .optional()
    .default('1')
    .transform((val) => parseInt(val, 10))
    .pipe(z.number().min(1).max(1000)),
  limit: z
    .string()
    .optional()
    .default('20')
    .transform((val) => parseInt(val, 10))
    .pipe(z.number().min(1).max(100)),
})

// Offer query schema
export const offerQuerySchema = paginationSchema.extend({
  issuer: z.string().max(100).optional(),
  minMiles: z
    .string()
    .optional()
    .transform((val) => (val ? parseInt(val, 10) : undefined))
    .pipe(z.number().min(0).max(1000000).optional()),
  maxAnnualFee: z
    .string()
    .optional()
    .transform((val) => (val ? parseInt(val, 10) : undefined))
    .pipe(z.number().min(0).max(10000).optional()),
})

// Offer ID schema
export const offerIdSchema = z.object({
  id: z.string().uuid(),
})

// Sanitize string input
export const sanitizedStringSchema = z
  .string()
  .trim()
  .transform((val) => {
    // Remove potentially dangerous characters
    return val.replace(/[<>\"']/g, '')
  })

// Email schema
export const emailSchema = z.string().email().max(255).toLowerCase()

// URL schema
export const urlSchema = z.string().url().max(2048)
```

---

### Step 3: Create Validation Middleware
**Duration**: 20 minutes

File: `apps/web/src/lib/middleware/validation.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { z, ZodError } from 'zod'
import logger from '@/lib/logger'

export async function withValidation<T extends z.ZodType>(
  req: NextRequest,
  schema: T,
  handler: (req: NextRequest, validatedData: z.infer<T>) => Promise<NextResponse>
): Promise<NextResponse> {
  try {
    // Parse and validate query parameters
    const searchParams = Object.fromEntries(req.nextUrl.searchParams.entries())
    const validatedData = schema.parse(searchParams)

    return await handler(req, validatedData)
  } catch (error) {
    if (error instanceof ZodError) {
      logger.warn({
        msg: 'Validation error',
        endpoint: req.nextUrl.pathname,
        errors: error.errors,
      })

      return NextResponse.json(
        {
          error: 'Validation error',
          message: 'Invalid request parameters',
          details: error.errors.map((e) => ({
            field: e.path.join('.'),
            message: e.message,
          })),
        },
        { status: 400 }
      )
    }

    throw error
  }
}
```

---

### Step 4: Apply Validation to API Routes
**Duration**: 20 minutes

#### Update Offers API with Validation:
File: `apps/web/src/app/api/offers/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/db'
import { withApiMonitoring } from '@/lib/middleware/apiMonitoring'
import { withRateLimit } from '@/lib/middleware/rateLimit'
import { withValidation } from '@/lib/middleware/validation'
import { offerQuerySchema } from '@/lib/validation/schemas'

async function handler(req: NextRequest, validatedQuery: any) {
  const { page, limit, issuer, minMiles, maxAnnualFee } = validatedQuery

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

  const [offers, total] = await Promise.all([
    prisma.offer.findMany({
      where,
      include: { issuer: true },
      skip,
      take: limit,
      orderBy: { miles: 'desc' },
    }),
    prisma.offer.count({ where }),
  ])

  return NextResponse.json({
    offers,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  })
}

export async function GET(req: NextRequest) {
  return withRateLimit(
    req,
    (req) => withValidation(req, offerQuerySchema, (req, data) => withApiMonitoring(req, () => handler(req, data))),
    { limit: 100 }
  )
}
```

---

## Phase 4.5: Azure Key Vault Integration

### Step 1: Create Azure Key Vault
**Duration**: 20 minutes

```bash
# Create Key Vault
az keyvault create \
  --name mileage-deal-tracker-kv \
  --resource-group mileage-deal-rg-prod \
  --location westus2 \
  --enable-rbac-authorization true

# Get Key Vault URI
az keyvault show \
  --name mileage-deal-tracker-kv \
  --resource-group mileage-deal-rg-prod \
  --query properties.vaultUri -o tsv
```

---

### Step 2: Configure App Service Managed Identity
**Duration**: 15 minutes

```bash
# Enable system-assigned managed identity on App Service
az webapp identity assign \
  --name mileage-deal-tracker-prod \
  --resource-group mileage-deal-rg-prod

# Get the principal ID
PRINCIPAL_ID=$(az webapp identity show \
  --name mileage-deal-tracker-prod \
  --resource-group mileage-deal-rg-prod \
  --query principalId -o tsv)

# Grant Key Vault access
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/{subscription-id}/resourceGroups/mileage-deal-rg-prod/providers/Microsoft.KeyVault/vaults/mileage-deal-tracker-kv
```

---

### Step 3: Store Secrets in Key Vault
**Duration**: 20 minutes

```bash
# Store database password
az keyvault secret set \
  --vault-name mileage-deal-tracker-kv \
  --name database-password \
  --value "your-secure-password"

# Store database URL
az keyvault secret set \
  --vault-name mileage-deal-tracker-kv \
  --name database-url \
  --value "postgresql://dbadmin:password@server.postgres.database.azure.com:5432/db"

# Store Application Insights connection string
az keyvault secret set \
  --vault-name mileage-deal-tracker-kv \
  --name appinsights-connection-string \
  --value "InstrumentationKey=..."

# Store any API keys (example)
az keyvault secret set \
  --vault-name mileage-deal-tracker-kv \
  --name external-api-key \
  --value "your-api-key"
```

---

### Step 4: Reference Secrets in App Service
**Duration**: 15 minutes

```bash
# Update App Service settings to reference Key Vault
az webapp config appsettings set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --settings \
    DATABASE_URL="@Microsoft.KeyVault(SecretUri=https://mileage-deal-tracker-kv.vault.azure.net/secrets/database-url/)" \
    APPLICATIONINSIGHTS_CONNECTION_STRING="@Microsoft.KeyVault(SecretUri=https://mileage-deal-tracker-kv.vault.azure.net/secrets/appinsights-connection-string/)"
```

---

### Step 5: Access Secrets in Code (Optional)
**Duration**: 20 minutes

```bash
# Install Azure SDK
cd apps/web
npm install @azure/keyvault-secrets @azure/identity
```

File: `apps/web/src/lib/secrets/keyVault.ts`
```typescript
import { SecretClient } from '@azure/keyvault-secrets'
import { DefaultAzureCredential } from '@azure/identity'

let secretClient: SecretClient | null = null

export function getSecretClient(): SecretClient {
  if (!secretClient && process.env.KEY_VAULT_URI) {
    const credential = new DefaultAzureCredential()
    secretClient = new SecretClient(process.env.KEY_VAULT_URI, credential)
  }

  if (!secretClient) {
    throw new Error('Key Vault client not initialized')
  }

  return secretClient
}

export async function getSecret(secretName: string): Promise<string> {
  const client = getSecretClient()
  const secret = await client.getSecret(secretName)
  return secret.value || ''
}

// Cache secrets in memory (refresh periodically)
const secretCache = new Map<string, { value: string; expiresAt: number }>()
const CACHE_TTL = 5 * 60 * 1000 // 5 minutes

export async function getCachedSecret(secretName: string): Promise<string> {
  const now = Date.now()
  const cached = secretCache.get(secretName)

  if (cached && cached.expiresAt > now) {
    return cached.value
  }

  const value = await getSecret(secretName)
  secretCache.set(secretName, {
    value,
    expiresAt: now + CACHE_TTL,
  })

  return value
}
```

---

## Phase 4.6: Secret Rotation

### Step 1: Create Secret Rotation Plan
**Duration**: 30 minutes

File: `.claude/docs/secret-rotation-plan.md`
```markdown
# Secret Rotation Plan

## Rotation Schedule
- Production database passwords: Quarterly
- API keys: Every 6 months
- Service principal credentials: Annually
- TLS/SSL certificates: Auto-renewed (Let's Encrypt)

## Rotation Procedure

### Database Password Rotation
1. Generate new secure password
2. Update password in Azure PostgreSQL
3. Update secret in Key Vault
4. Restart App Service (picks up new secret)
5. Verify connectivity
6. Update backup scripts if needed

### API Key Rotation
1. Generate new API key from provider
2. Update secret in Key Vault
3. Test with new key
4. Restart App Service
5. Revoke old API key after verification

### Publish Profile Rotation
1. Download new publish profile from Azure
2. Update GitHub secret
3. Test deployment
4. Delete old publish profile

## Emergency Rotation
If a secret is compromised:
1. Immediately rotate the secret
2. Review access logs
3. Investigate security incident
4. Update incident response documentation
```

---

## Phase 4.7: Security Audit

### Step 1: Security Checklist
**Duration**: 30 minutes

File: `.claude/docs/security-checklist.md`
```markdown
# Security Audit Checklist

## Application Security
- [ ] Security headers configured (CSP, HSTS, X-Frame-Options, etc.)
- [ ] HTTPS enforced (HTTP redirects to HTTPS)
- [ ] Rate limiting enabled on all API endpoints
- [ ] Input validation on all user inputs
- [ ] Output encoding to prevent XSS
- [ ] CORS properly configured
- [ ] No secrets in code or repository
- [ ] Dependencies up to date (no known vulnerabilities)

## Authentication & Authorization
- [ ] Strong password policy (if applicable)
- [ ] Session management secure
- [ ] API authentication implemented
- [ ] Role-based access control (if applicable)

## Database Security
- [ ] SSL/TLS enforced for database connections
- [ ] Firewall rules restrict access
- [ ] Prepared statements prevent SQL injection
- [ ] Minimal privilege principle applied
- [ ] Regular backups configured

## Infrastructure Security
- [ ] Azure Key Vault for secret management
- [ ] Managed identities for Azure resources
- [ ] Network security groups configured
- [ ] DDoS protection enabled
- [ ] Regular security updates applied

## Monitoring & Logging
- [ ] Security events logged
- [ ] Failed authentication attempts monitored
- [ ] Anomalous activity alerts configured
- [ ] Log retention policy implemented
- [ ] Access logs reviewed regularly

## Compliance
- [ ] GDPR compliance (if applicable)
- [ ] PCI DSS compliance (for payment data)
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Cookie consent implemented

## Incident Response
- [ ] Incident response plan documented
- [ ] Security contacts defined
- [ ] Breach notification procedures
- [ ] Backup and restore tested
```

---

### Step 2: Run Security Scan
**Duration**: 20 minutes

```bash
# Install security audit tools
npm install -D npm-audit-resolver
npm install -D snyk

# Run npm audit
npm audit

# Generate audit report
npm audit --json > security-audit.json

# Check for vulnerabilities with Snyk (requires account)
npx snyk test
npx snyk monitor
```

---

### Step 3: Configure Automated Security Scanning
**Duration**: 20 minutes

File: `.github/workflows/security-scan.yml`
```yaml
name: Security Scan

on:
  schedule:
    - cron: '0 0 * * 0' # Weekly on Sunday
  workflow_dispatch:

jobs:
  security-scan:
    name: Security Vulnerability Scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Install dependencies
        working-directory: apps/web
        run: npm ci

      - name: Run npm audit
        working-directory: apps/web
        run: npm audit --audit-level=moderate

      - name: Run Snyk scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      - name: Upload security report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: security-report
          path: snyk-report.json
```

---

## Validation Checklist

After implementation, verify:
- [ ] Security headers present in all responses
- [ ] CSP configured without breaking functionality
- [ ] Rate limiting working on all API endpoints
- [ ] CORS configured correctly
- [ ] Input validation preventing malicious input
- [ ] Azure Key Vault created and secrets stored
- [ ] App Service using managed identity
- [ ] Secrets referenced from Key Vault
- [ ] Secret rotation plan documented
- [ ] Security audit checklist completed
- [ ] No high/critical vulnerabilities in dependencies
- [ ] Automated security scanning configured

---

## Time Estimates

| Task | Estimated Time |
|------|----------------|
| Security headers setup | 30 min |
| CSP implementation | 45 min |
| Rate limiter installation | 15 min |
| Rate limit middleware | 45 min |
| Apply rate limits | 30 min |
| CORS configuration | 20 min |
| Validation library setup | 10 min |
| Validation schemas | 30 min |
| Validation middleware | 20 min |
| Apply validation | 20 min |
| Create Key Vault | 20 min |
| Configure managed identity | 15 min |
| Store secrets | 20 min |
| Reference secrets | 15 min |
| Secret client code | 20 min |
| Secret rotation plan | 30 min |
| Security checklist | 30 min |
| Security scan | 20 min |
| Automated scanning | 20 min |
| **Total** | **~6.5 hours** |

---

## Rollback Procedures

### If Security Headers Break Functionality:
1. Identify problematic header
2. Adjust CSP directives
3. Test thoroughly
4. Re-deploy

### If Rate Limiting Blocks Legitimate Traffic:
1. Increase rate limits temporarily
2. Review logs to identify patterns
3. Adjust limits appropriately
4. Consider IP whitelisting for known services

### If Key Vault Integration Fails:
1. Temporarily use App Service settings
2. Verify managed identity permissions
3. Check Key Vault access policies
4. Re-configure integration

---

## Next Steps

After Phase 4 completion:
1. Proceed to Phase 5: Performance Optimization
2. Implement caching strategies
3. Optimize database queries
4. Configure CDN

---

**Plan Created**: 2025-11-08
**Status**: Ready for Implementation
**Estimated Time**: 3-4 hours
