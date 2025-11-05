# Credit Card Deals Tracker — Implementation Plan v1

*Plan created: 2025-11-04*
*Based on: requirement_v1.md*

---

## Executive Summary

This document outlines a phased implementation plan for the Credit Card Deals Tracker web application. The system will aggregate credit card welcome offers (focusing on airline mileage and transferable points), track weekly changes, calculate transparent deal scores, and deliver personalized email notifications to users.

**Estimated Timeline**: 12-16 weeks for Phase 1 MVP
**Team Size**: 2-3 full-stack engineers + 1 part-time DevOps
**Key Success Metric**: ≥30 live offers across ≥6 issuers with weekly tracking operational

---

## Phase Breakdown

### Phase 0: Foundation & Setup (Week 1-2)
### Phase 1: Core Data Layer (Week 3-5)
### Phase 2: ETL Pipeline (Week 6-8)
### Phase 3: Public Frontend (Week 9-11)
### Phase 4: Email System (Week 12-13)
### Phase 5: Admin CMS (Week 14-15)
### Phase 6: Polish & Launch (Week 16)

---

## Phase 0: Foundation & Setup (Week 1-2)

### Objectives
- Establish development environment
- Set up infrastructure skeleton
- Define team workflows and coding standards

### Tasks

#### 0.1 Project Initialization
- [ ] Create monorepo structure (Turborepo or Nx recommended)
- [ ] Initialize Git repository with branching strategy (GitFlow or trunk-based)
- [ ] Set up package.json with workspace configuration
- [ ] Configure TypeScript (strict mode, path aliases)
- [ ] Set up ESLint + Prettier with shared configs
- [ ] Create .env.example templates

**Directory Structure**:
```
credit-card-tracker/
├── apps/
│   ├── web/              # Next.js frontend
│   ├── api/              # Backend API (if separate from Next.js)
│   └── worker/           # ETL worker processes
├── packages/
│   ├── database/         # Prisma schema + migrations
│   ├── ui/               # Shared UI components
│   ├── types/            # Shared TypeScript types
│   ├── validation/       # Zod schemas
│   └── config/           # Shared configs (ESLint, TS, etc.)
├── .claude/
│   ├── instruction/
│   └── plan/
├── docs/
└── scripts/
```

#### 0.2 Database Setup
- [ ] Provision PostgreSQL instance (local + staging)
- [ ] Install and configure Prisma ORM
- [ ] Set up migration workflow (dev → staging → prod)
- [ ] Configure connection pooling (PgBouncer or Prisma connection limit)
- [ ] Set up database backup strategy

#### 0.3 Infrastructure Skeleton
- [ ] Create Vercel project for frontend (or alternative hosting)
- [ ] Set up backend hosting (Fly.io/Render/Railway)
- [ ] Configure S3-compatible storage (AWS S3 or Cloudflare R2)
- [ ] Set up CDN (CloudFront or Cloudflare CDN)
- [ ] Configure environment variables in hosting platforms
- [ ] Set up staging and production environments

#### 0.4 Development Tools
- [ ] Set up local development with Docker Compose (Postgres, Redis)
- [ ] Configure hot-reload for all apps
- [ ] Set up debugging configurations (VS Code/IntelliJ)
- [ ] Install and configure testing frameworks (Jest, Vitest)
- [ ] Set up CI/CD pipeline skeleton (GitHub Actions recommended)

#### 0.5 Documentation
- [ ] Create README.md with setup instructions
- [ ] Document environment variables
- [ ] Create contributing guidelines
- [ ] Set up API documentation framework (OpenAPI/Swagger)

### Deliverables
- ✓ Fully configured development environment
- ✓ Empty apps scaffolded with build pipelines working
- ✓ Database provisioned and accessible
- ✓ CI/CD running basic linting and type checking

---

## Phase 1: Core Data Layer (Week 3-5)

### Objectives
- Implement complete database schema
- Build foundational data access layer
- Create seed data for development

### Tasks

#### 1.1 Prisma Schema Design

**File**: `packages/database/prisma/schema.prisma`

```prisma
// Core Models (to be implemented)

model Issuer {
  id          String        @id @default(cuid())
  name        String        @unique
  slug        String        @unique
  website     String
  logoUrl     String?
  createdAt   DateTime      @default(now())
  updatedAt   DateTime      @updatedAt
  products    CardProduct[]
}

model CardProduct {
  id          String   @id @default(cuid())
  issuerId    String
  name        String
  slug        String   @unique
  network     Network  // Enum: AMEX, VISA, MASTERCARD, DISCOVER
  type        CardType // Enum: PERSONAL, BUSINESS
  currency    String   // e.g., "AA miles", "UR", "MR"
  currencyCode String  // e.g., "AA", "UR", "MR" for lookups
  imageUrl    String?
  description String?  @db.Text
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  issuer      Issuer   @relation(fields: [issuerId], references: [id], onDelete: Cascade)
  offers      Offer[]

  @@index([issuerId])
  @@index([currencyCode])
}

model Offer {
  id                    String          @id @default(cuid())
  productId             String
  headline              String
  bonusPoints           Int
  minSpendAmount        Decimal         @db.Decimal(10, 2)
  minSpendWindowDays    Int
  annualFee             Decimal         @db.Decimal(10, 2)
  firstYearWaived       Boolean         @default(false)
  statementCredits      Decimal         @db.Decimal(10, 2) @default(0)
  introAprMonths        Int?
  expiresOn             DateTime?
  landingUrl            String
  affiliateUrl          String?
  sourceType            SourceType      // Enum: PUBLIC, REFERRAL, IN_BRANCH, TARGETED
  geo                   String          @default("US")
  status                OfferStatus     // Enum: ACTIVE, EXPIRED, RUMORED, DRAFT
  termsSnapshotMeta     Json?           // {hash, s3Path, capturedAt}
  lastVerifiedAt        DateTime
  publishedAt           DateTime?
  createdAt             DateTime        @default(now())
  updatedAt             DateTime        @updatedAt

  product               CardProduct     @relation(fields: [productId], references: [id], onDelete: Cascade)
  snapshots             OfferSnapshot[]

  @@index([productId])
  @@index([status])
  @@index([lastVerifiedAt])
}

model OfferSnapshot {
  id                    String    @id @default(cuid())
  offerId               String
  capturedAt            DateTime  @default(now())
  bonusPoints           Int
  minSpendAmount        Decimal   @db.Decimal(10, 2)
  minSpendWindowDays    Int
  annualFee             Decimal   @db.Decimal(10, 2)
  statementCredits      Decimal   @db.Decimal(10, 2)
  expiresOn             DateTime?
  landingUrl            String
  diffSummary           String?   @db.Text

  offer                 Offer     @relation(fields: [offerId], references: [id], onDelete: Cascade)

  @@index([offerId, capturedAt])
  @@index([capturedAt])
}

model CurrencyValuation {
  id            String   @id @default(cuid())
  currencyCode  String   @unique // "AA", "UR", "MR", etc.
  centsPerPoint Decimal  @db.Decimal(4, 2) // e.g., 1.40 for AA
  effectiveFrom DateTime @default(now())
  notes         String?  @db.Text
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  @@index([currencyCode])
}

// Email subscription models

model Subscriber {
  id                String               @id @default(cuid())
  email             String               @unique
  emailVerified     Boolean              @default(false)
  verificationToken String?              @unique
  weeklyDigest      Boolean              @default(true)
  instantAlerts     Boolean              @default(false)
  subscribedAt      DateTime             @default(now())
  unsubscribedAt    DateTime?
  unsubscribeToken  String               @unique @default(cuid())
  preferences       SubscriberPreference[]

  @@index([email])
  @@index([emailVerified])
}

model SubscriberPreference {
  id           String     @id @default(cuid())
  subscriberId String
  issuerSlug   String?    // null = all issuers
  currencyCode String?    // null = all currencies
  minBonus     Int?       // null = no minimum

  subscriber   Subscriber @relation(fields: [subscriberId], references: [id], onDelete: Cascade)

  @@unique([subscriberId, issuerSlug, currencyCode])
  @@index([subscriberId])
}

model EmailLog {
  id          String   @id @default(cuid())
  email       String
  subject     String
  type        EmailType // Enum: VERIFICATION, WEEKLY_DIGEST, INSTANT_ALERT
  status      EmailStatus // Enum: QUEUED, SENT, FAILED, BOUNCED
  sentAt      DateTime?
  failureReason String?
  createdAt   DateTime @default(now())

  @@index([email, createdAt])
  @@index([status])
}

// Admin models

model User {
  id          String   @id @default(cuid())
  email       String   @unique
  name        String?
  role        UserRole // Enum: ADMIN, EDITOR, VIEWER
  authId      String?  @unique // Clerk/Auth0 ID
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([email])
  @@index([authId])
}

model AuditLog {
  id         String   @id @default(cuid())
  userId     String?
  action     String   // e.g., "offer.created", "offer.published"
  entityType String   // e.g., "Offer", "CardProduct"
  entityId   String
  changes    Json?    // Before/after snapshot
  ipAddress  String?
  createdAt  DateTime @default(now())

  @@index([entityType, entityId])
  @@index([createdAt])
}

// Enums

enum Network {
  AMEX
  VISA
  MASTERCARD
  DISCOVER
}

enum CardType {
  PERSONAL
  BUSINESS
}

enum SourceType {
  PUBLIC
  REFERRAL
  IN_BRANCH
  TARGETED
}

enum OfferStatus {
  ACTIVE
  EXPIRED
  RUMORED
  DRAFT
}

enum EmailType {
  VERIFICATION
  WEEKLY_DIGEST
  INSTANT_ALERT
}

enum EmailStatus {
  QUEUED
  SENT
  FAILED
  BOUNCED
}

enum UserRole {
  ADMIN
  EDITOR
  VIEWER
}
```

#### 1.2 Database Migrations
- [ ] Create initial migration from schema
- [ ] Add indexes for performance-critical queries
- [ ] Create seed script for development data
  - Sample issuers (Amex, Chase, Citi, BofA, CapOne, US Bank)
  - Sample products (5-10 popular cards)
  - Sample offers with historical snapshots
  - Currency valuations (AA, United, Delta, MR, UR, TYP)

#### 1.3 Data Access Layer (packages/database)

**Core Repository Pattern**:
- [ ] Create base repository with common CRUD operations
- [ ] Implement IssuerRepository
- [ ] Implement CardProductRepository
- [ ] Implement OfferRepository
- [ ] Implement OfferSnapshotRepository
- [ ] Implement SubscriberRepository
- [ ] Implement CurrencyValuationRepository

**Key Methods**:
```typescript
// OfferRepository examples
- findActive(filters: OfferFilters): Promise<Offer[]>
- findByProductId(productId: string): Promise<Offer[]>
- findWithProduct(offerId: string): Promise<OfferWithProduct>
- createSnapshot(offerId: string, data: SnapshotData): Promise<OfferSnapshot>
- getLatestSnapshot(offerId: string): Promise<OfferSnapshot | null>
- computeWeeklyDiff(offerId: string): Promise<DiffResult>
```

#### 1.4 Shared Type Definitions (packages/types)
- [ ] Define DTOs for API requests/responses
- [ ] Create filter types (OfferFilters, ProductFilters)
- [ ] Define calculated types (ValueScore, EffectiveValue)
- [ ] Export enums matching Prisma enums

#### 1.5 Validation Schemas (packages/validation)
- [ ] Create Zod schemas for all models
- [ ] Add API request validation schemas
- [ ] Create parse/transform utilities
- [ ] Add custom validators (URL validation, email format)

### Deliverables
- ✓ Complete database schema deployed to staging
- ✓ Seed data script working
- ✓ Data access layer with comprehensive tests (>80% coverage)
- ✓ Type-safe repository APIs ready for consumption

---

## Phase 2: ETL Pipeline (Week 6-8)

### Objectives
- Build offer scraping/ingestion system
- Implement change detection logic
- Set up scheduled weekly snapshots
- Store terms evidence (HTML snapshots, screenshots)

### Tasks

#### 2.1 ETL Architecture Design

**Components**:
1. **Source Registry**: Configuration for each issuer/product source
2. **Fetcher**: HTTP client with retry logic, rate limiting
3. **Parser**: Extract offer data from HTML/JSON
4. **Differ**: Compare new data vs. current offer
5. **Snapshot Writer**: Create OfferSnapshot records
6. **Evidence Capture**: Store HTML + screenshot to S3

**Technology Choices**:
- Worker framework: BullMQ (Node.js) or Celery (Python)
- Browser automation: Playwright (for JavaScript-heavy pages)
- Queue: Redis
- Storage: AWS S3 or Cloudflare R2

#### 2.2 Source Registry (apps/worker/src/sources)

**File Structure**:
```
sources/
├── index.ts              # Registry export
├── base/
│   ├── Fetcher.ts
│   ├── Parser.ts
│   └── types.ts
├── amex/
│   ├── AmexFetcher.ts
│   ├── AmexParser.ts
│   └── sources.json      # URL + selector config
├── chase/
│   ├── ChaseFetcher.ts
│   ├── ChaseParser.ts
│   └── sources.json
└── citi/
    └── ...
```

**Source Configuration Example** (`sources/citi/sources.json`):
```json
{
  "issuer": "citi",
  "products": [
    {
      "productId": "citi-aa-platinum",
      "url": "https://www.citi.com/credit-cards/citi-aadvantage-platinum-select-credit-card",
      "type": "html",
      "selectors": {
        "bonusPoints": ".bonus-amount",
        "minSpend": ".spend-requirement",
        "annualFee": ".annual-fee"
      },
      "parser": "CitiParser"
    }
  ]
}
```

#### 2.3 Core ETL Components

**2.3.1 Fetcher (base/Fetcher.ts)**
- [ ] Implement HTTP client with exponential backoff
- [ ] Add user-agent rotation
- [ ] Implement rate limiting per domain
- [ ] Add proxy support (optional, for Phase 2)
- [ ] Log all fetch attempts with timing

**2.3.2 Parser (base/Parser.ts)**
- [ ] Create abstract Parser class
- [ ] Implement HTML parsing utilities (Cheerio/JSDOM)
- [ ] Add regex extraction helpers
- [ ] Implement JSON path utilities
- [ ] Add validation with Zod schemas
- [ ] Handle parsing errors gracefully

**2.3.3 Differ (services/Differ.ts)**
- [ ] Implement deep comparison for offer fields
- [ ] Generate human-readable diff summary
  - Example: "Bonus decreased 80,000 → 65,000 on 2025-11-03"
- [ ] Calculate percentage changes
- [ ] Flag material changes (≥20% bonus change, expiration date, fee change)

**2.3.4 Evidence Capture (services/EvidenceCapture.ts)**
- [ ] Capture full HTML source
- [ ] Generate SHA-256 hash of content
- [ ] Take screenshot with Playwright
- [ ] Upload to S3 with naming convention: `{offerId}/{timestamp}.html`
- [ ] Store metadata in `termsSnapshotMeta` JSON field

#### 2.4 Job Queue Setup

**Queue Structure**:
- `fetch-offer`: Fetch single offer URL
- `parse-offer`: Parse fetched HTML
- `snapshot-offer`: Create snapshot + diff
- `weekly-crawl`: Master job that enqueues all active offers

**Implementation**:
- [ ] Set up Redis connection
- [ ] Create BullMQ queue configurations
- [ ] Implement job processors for each queue
- [ ] Add job retry logic (3 attempts with exponential backoff)
- [ ] Set up job monitoring dashboard (Bull Board)
- [ ] Configure concurrency limits

#### 2.5 Scheduler Setup

**Cron Jobs**:
- [ ] Weekly crawl: Every Sunday at 02:00 CT (`0 2 * * 0`)
- [ ] Health check: Daily at 08:00 CT (`0 8 * * *`)
- [ ] Stale offer cleanup: Daily at 03:00 CT (`0 3 * * *`)

**Implementation Options**:
1. **Vercel Cron** (if using Vercel)
2. **GitHub Actions** with workflow dispatch
3. **Cloud Scheduler** (GCP) or EventBridge (AWS)
4. **Node-cron** in worker process (less reliable)

#### 2.6 Initial Source Implementations

**Priority Issuers** (implement in order):
1. [ ] Citi (AAdvantage cards) - Start here, relatively simple HTML
2. [ ] American Express (MR cards) - More complex, may need Playwright
3. [ ] Chase (UR cards) - Often requires browser automation
4. [ ] Bank of America (various) - Mid-complexity
5. [ ] Capital One (transferable points) - API-friendly if available
6. [ ] U.S. Bank (various) - Lower priority

**Per Issuer**:
- [ ] Implement Fetcher subclass
- [ ] Implement Parser subclass
- [ ] Create sources.json configuration
- [ ] Write unit tests for parser
- [ ] Manually verify first 3 offers
- [ ] Document any quirks or limitations

#### 2.7 Error Handling & Monitoring

- [ ] Implement comprehensive error logging
- [ ] Send alerts on fetch failures (>3 consecutive failures)
- [ ] Track success/failure metrics
- [ ] Create dashboard for ETL health (Grafana or similar)
- [ ] Set up dead letter queue for failed jobs

### Deliverables
- ✓ ETL pipeline processing ≥6 issuers, ≥30 products
- ✓ Weekly snapshot job running successfully
- ✓ Change detection generating accurate diffs
- ✓ Evidence stored in S3 with 100% capture rate
- ✓ Monitoring dashboard showing job health

---

## Phase 3: Public Frontend (Week 9-11)

### Objectives
- Build responsive, accessible UI
- Implement all public-facing pages
- Add filtering, sorting, search
- Render historical charts

### Tasks

#### 3.1 Next.js App Setup (apps/web)

**Framework Configuration**:
- [ ] Initialize Next.js 14+ with App Router
- [ ] Configure TypeScript (strict mode)
- [ ] Set up Tailwind CSS with custom theme
- [ ] Install shadcn/ui or similar component library
- [ ] Configure TanStack Query (React Query) for data fetching
- [ ] Set up Zustand or Context for client state (filters, compare tray)

**Directory Structure**:
```
apps/web/
├── src/
│   ├── app/
│   │   ├── page.tsx              # Home / Top Deals
│   │   ├── layout.tsx
│   │   ├── issuers/
│   │   │   ├── page.tsx          # Issuer list
│   │   │   └── [slug]/
│   │   │       └── page.tsx      # Issuer hub
│   │   ├── cards/
│   │   │   └── [slug]/
│   │   │       └── page.tsx      # Card detail
│   │   ├── compare/
│   │   │   └── page.tsx          # Comparison tool
│   │   ├── learn/
│   │   │   └── page.tsx          # Educational content
│   │   ├── subscribe/
│   │   │   └── page.tsx          # Email subscription
│   │   └── api/
│   │       └── ...               # API routes
│   ├── components/
│   │   ├── ui/                   # Base components (shadcn)
│   │   ├── offer/
│   │   │   ├── OfferCard.tsx
│   │   │   ├── OfferTable.tsx
│   │   │   └── OfferFilters.tsx
│   │   ├── charts/
│   │   │   ├── BonusHistoryChart.tsx
│   │   │   └── Sparkline.tsx
│   │   └── layout/
│   │       ├── Header.tsx
│   │       └── Footer.tsx
│   ├── lib/
│   │   ├── api/                  # API client functions
│   │   ├── utils/                # Utility functions
│   │   └── scoring/              # Value score calculations
│   └── styles/
│       └── globals.css
```

#### 3.2 API Routes (Next.js API Routes)

**Endpoints to Implement**:

```typescript
// GET /api/offers
// Query params: issuer, currency, minBonus, maxSpend, etc.
export async function GET(request: Request) {
  // Fetch offers with filters
  // Calculate value scores
  // Return paginated results
}

// GET /api/offers/[id]
// Returns offer detail with product info
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  // Fetch offer with product
  // Include latest snapshot
  // Return enriched data
}

// GET /api/offers/[id]/snapshots
// Returns historical snapshots for charting
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  // Fetch all snapshots for offer
  // Order by capturedAt DESC
  // Return time series data
}

// GET /api/issuers
// Returns all issuers with product counts
export async function GET(request: Request) {
  // Fetch issuers with aggregated stats
}

// GET /api/issuers/[slug]
// Returns issuer detail with all products
export async function GET(
  request: Request,
  { params }: { params: { slug: string } }
) {
  // Fetch issuer
  // Include all products with active offers
}
```

**Implementation Tasks**:
- [ ] Set up API error handling middleware
- [ ] Implement request validation with Zod
- [ ] Add response caching (Next.js cache or Redis)
- [ ] Implement rate limiting (optional for MVP)
- [ ] Add OpenAPI/Swagger documentation

#### 3.3 Deal Scoring Library (lib/scoring)

**File**: `lib/scoring/ValueCalculator.ts`

```typescript
interface ValueCalculation {
  effectiveFirstYearValue: number;
  valueScore: number; // 0-100
  breakdown: {
    bonusValue: number;
    statementCredits: number;
    annualFee: number;
    netValue: number;
  };
  context: {
    historicalMax: number;
    historicalMin: number;
    percentile: number;
  };
}

class ValueCalculator {
  calculateValue(offer: Offer, cpp: number): ValueCalculation
  calculateValueScore(value: number, distribution: Distribution): number
  applyBonusBoost(score: number, historicalPercentile: number): number
}
```

**Implementation**:
- [ ] Load currency valuations from database
- [ ] Implement effective value formula
- [ ] Build distribution calculator (p10, p50, p90 from snapshots)
- [ ] Add historical percentile lookup
- [ ] Implement score normalization (0-100 scale)
- [ ] Add unit tests with known examples

#### 3.4 Page Implementations

**3.4.1 Home / Top Deals (app/page.tsx)**

**Features**:
- Hero section with value proposition
- Sortable offers table (Value Score, Bonus, Spend, AF, Expiry)
- Filters sidebar:
  - Issuer (multi-select)
  - Currency/Program (multi-select)
  - Bonus range (slider)
  - Min spend range (slider)
  - Annual fee range (slider)
  - First-year waived (toggle)
  - Card type (Personal/Business)
- "New/Changed this week" badge
- Pagination or infinite scroll
- Mobile-responsive table (card view on mobile)

**Tasks**:
- [ ] Create OfferTable component with sorting
- [ ] Implement OfferFilters component
- [ ] Add client-side filter state management
- [ ] Implement server-side data fetching with filters
- [ ] Add loading skeletons
- [ ] Implement responsive design

**3.4.2 Issuer Hub (app/issuers/[slug]/page.tsx)**

**Features**:
- Issuer header (logo, name, website link)
- All products from this issuer
- Active offers grouped by product
- Quick stats (# of cards, avg bonus value)

**Tasks**:
- [ ] Create IssuerHeader component
- [ ] Display products in grid layout
- [ ] Group offers by product
- [ ] Add breadcrumb navigation

**3.4.3 Card Detail (app/cards/[slug]/page.tsx)**

**Features**:
- Card image and details
- Current offer prominently displayed
- Value score breakdown with explanation
- Bonus history chart (12+ months)
- Change log table with diffs
- Terms snapshot access (link to PDF/screenshot)
- FAQs accordion
- Large "Apply Now" CTA with disclosure
- Affiliate link tracking (UTM parameters)

**Tasks**:
- [ ] Create CardHeader component
- [ ] Implement BonusHistoryChart with Recharts or Chart.js
- [ ] Create ChangeLog component
- [ ] Add ValueScoreBreakdown component
- [ ] Implement "Apply Now" button with UTM tagging
- [ ] Add affiliate disclosure banner
- [ ] Implement sticky CTA on scroll (mobile)

**3.4.4 Compare (app/compare/page.tsx)**

**Features**:
- Select up to 3 cards
- Side-by-side comparison table
- Highlight differences
- Value score comparison
- "Add to comparison" from other pages (sticky tray)

**Tasks**:
- [ ] Create comparison selection UI
- [ ] Implement ComparisonTable component
- [ ] Add difference highlighting logic
- [ ] Create sticky compare tray component
- [ ] Persist comparison state (localStorage or query params)

**3.4.5 Learn / Educational Pages (app/learn/page.tsx)**

**Content Areas**:
- How our scoring works
- Bank-specific rules (5/24, once-per-lifetime, 24-month, etc.)
- When to apply for cards
- Understanding mileage value
- Glossary

**Tasks**:
- [ ] Create markdown content pages
- [ ] Implement content rendering (MDX recommended)
- [ ] Add internal linking
- [ ] Create visual aids (infographics, diagrams)

**3.4.6 Subscribe (app/subscribe/page.tsx)**

**Features**:
- Email signup form
- Preference selection (issuers, currencies, thresholds)
- Example digest preview
- Privacy policy link

**Tasks**:
- [ ] Create subscription form with validation
- [ ] Implement API endpoint for signup
- [ ] Add loading states and success message
- [ ] Create preference selection UI

#### 3.5 Charting Implementation

**Library**: Recharts or Chart.js

**Chart Types**:
1. **Line Chart**: Bonus history over time
2. **Sparkline**: Mini bonus trend in list view
3. **Bar Chart**: Value comparison (optional)

**Tasks**:
- [ ] Install and configure charting library
- [ ] Create BonusHistoryChart component
- [ ] Implement responsive sizing
- [ ] Add tooltip with date and value
- [ ] Style to match brand
- [ ] Add loading states
- [ ] Optimize for performance (lazy loading)

#### 3.6 SEO & Metadata

**Tasks**:
- [ ] Implement dynamic meta tags (title, description, OG tags)
- [ ] Add JSON-LD structured data for offers
- [ ] Generate sitemap.xml dynamically
- [ ] Add robots.txt
- [ ] Implement canonical URLs
- [ ] Add lastmod timestamps from snapshots
- [ ] Set up Google Analytics or Plausible
- [ ] Implement event tracking (offer clicks, compares, subscribes)

#### 3.7 Accessibility (WCAG 2.2 AA)

**Tasks**:
- [ ] Run Lighthouse accessibility audit
- [ ] Ensure all interactive elements are keyboard accessible
- [ ] Add ARIA labels to complex components
- [ ] Verify color contrast ratios (4.5:1 minimum)
- [ ] Add focus indicators
- [ ] Test with screen reader (NVDA or JAWS)
- [ ] Add skip links
- [ ] Ensure semantic HTML structure

#### 3.8 Legal & Compliance Pages

**Pages to Create**:
- [ ] Privacy Policy (app/privacy/page.tsx)
- [ ] Terms of Service (app/terms/page.tsx)
- [ ] Affiliate Disclosure (app/disclosure/page.tsx)
- [ ] Cookie Policy (app/cookies/page.tsx)

**Tasks**:
- [ ] Draft or source legal content (consult legal counsel)
- [ ] Implement cookie consent banner (optional for MVP)
- [ ] Add last updated timestamps
- [ ] Link from footer

### Deliverables
- ✓ Fully functional public website with all pages
- ✓ Responsive design working on mobile, tablet, desktop
- ✓ Filtering and sorting working smoothly
- ✓ Charts rendering historical data accurately
- ✓ SEO basics implemented (meta tags, sitemap, structured data)
- ✓ Accessibility audit passing with no critical issues

---

## Phase 4: Email System (Week 12-13)

### Objectives
- Implement double opt-in subscription flow
- Build email templates
- Create weekly digest job
- Implement instant alerts for major changes

### Tasks

#### 4.1 Email Service Setup

**Provider Selection**:
- Recommended: Postmark (transactional) or SendGrid
- Alternative: AWS SES, Mailgun, Resend

**Configuration**:
- [ ] Create email service account
- [ ] Verify sending domain
- [ ] Configure SPF, DKIM, DMARC records
- [ ] Set up webhook for delivery tracking (bounces, opens)
- [ ] Generate API keys and add to environment

#### 4.2 Email Template System

**Template Engine**:
- Recommended: React Email or MJML
- Alternative: Handlebars with inline CSS

**Templates to Create**:

1. **Verification Email** (`VerificationEmail.tsx`)
   - Subject: "Confirm your subscription to Credit Card Tracker"
   - Content: Welcome message, verification link, what to expect

2. **Weekly Digest** (`WeeklyDigestEmail.tsx`)
   - Subject: "This Week's Top Credit Card Offers - [Date]"
   - Sections:
     - Top 5 offers by value score (personalized if preferences set)
     - Notable changes (≥10k points delta)
     - Expiring soon (next 7-14 days)
     - Footer with unsubscribe link

3. **Instant Alert** (`InstantAlertEmail.tsx`)
   - Subject: "[Issuer] [Card] - Big Bonus Change!"
   - Content: Single offer with before/after comparison, apply link

**Tasks**:
- [ ] Set up React Email or MJML environment
- [ ] Design email templates (mobile-first)
- [ ] Ensure proper HTML email rendering (table layouts, inline CSS)
- [ ] Test rendering across email clients (Litmus or Email on Acid)
- [ ] Implement plain text alternatives
- [ ] Add UTM parameters to all links
- [ ] Add unsubscribe link to footer

#### 4.3 Subscription Flow API

**Endpoints**:

```typescript
// POST /api/subscribe
// Body: { email, preferences }
// Creates subscriber, sends verification email
export async function POST(request: Request) {
  // Validate email format
  // Check if already subscribed
  // Generate verification token
  // Create Subscriber record (emailVerified: false)
  // Send verification email
  // Return success message
}

// GET /api/subscribe/verify?token=xxx
// Verifies email and activates subscription
export async function GET(request: Request) {
  // Find subscriber by token
  // Set emailVerified: true
  // Clear token
  // Redirect to success page
}

// POST /api/subscribe/preferences
// Updates subscriber preferences
export async function POST(request: Request) {
  // Validate token/email
  // Update SubscriberPreference records
  // Return success
}

// GET /api/subscribe/unsubscribe?token=xxx
// Unsubscribes user
export async function GET(request: Request) {
  // Find subscriber by unsubscribe token
  // Set unsubscribedAt timestamp
  // Optionally delete data (GDPR)
  // Render confirmation page
}
```

**Tasks**:
- [ ] Implement all endpoints with validation
- [ ] Add rate limiting to prevent abuse
- [ ] Create unsubscribe landing page
- [ ] Create subscription confirmation page
- [ ] Add error handling for invalid tokens
- [ ] Log all subscription events to EmailLog table

#### 4.4 Weekly Digest Job

**Job Logic** (apps/worker/src/jobs/WeeklyDigest.ts):

```typescript
async function generateWeeklyDigest() {
  // 1. Fetch all verified subscribers
  const subscribers = await getVerifiedSubscribers();

  for (const subscriber of subscribers) {
    // 2. Fetch personalized content based on preferences
    const topOffers = await getTopOffers(subscriber.preferences);
    const changes = await getWeeklyChanges(subscriber.preferences);
    const expiringSoon = await getExpiringSoon(subscriber.preferences);

    // 3. Render email template
    const emailHtml = await renderWeeklyDigest({
      subscriber,
      topOffers,
      changes,
      expiringSoon,
      unsubscribeUrl: `${BASE_URL}/api/subscribe/unsubscribe?token=${subscriber.unsubscribeToken}`
    });

    // 4. Queue email for sending
    await emailQueue.add('send-email', {
      to: subscriber.email,
      subject: `This Week's Top Credit Card Offers - ${formatDate(new Date())}`,
      html: emailHtml,
      type: 'WEEKLY_DIGEST'
    });
  }
}
```

**Tasks**:
- [ ] Implement digest generation logic
- [ ] Add personalization based on preferences
- [ ] Create email sending queue
- [ ] Implement batch processing (avoid rate limits)
- [ ] Add retry logic for failed sends
- [ ] Log all sends to EmailLog table
- [ ] Schedule job for Sundays at 08:00 CT

#### 4.5 Instant Alert System

**Trigger Logic**:
- When ETL pipeline detects material change (≥20% bonus delta)
- Check for subscribers with instant alerts enabled
- Filter by preferences (issuer, currency)
- Send individual alert emails

**Tasks**:
- [ ] Add instant alert trigger to ETL differ
- [ ] Implement alert email generation
- [ ] Add throttling (max 1 alert per product per day)
- [ ] Test with sample data
- [ ] Add opt-in checkbox to subscription form

#### 4.6 Email Analytics

**Metrics to Track**:
- Verification rate (verified / total signups)
- Open rate (if supported by provider)
- Click rate on apply links
- Unsubscribe rate
- Bounce rate

**Tasks**:
- [ ] Set up webhook endpoint for email events
- [ ] Store events in EmailLog table
- [ ] Create simple analytics dashboard (admin only)
- [ ] Set up alerts for high bounce rate

### Deliverables
- ✓ Double opt-in subscription working end-to-end
- ✓ Weekly digest sending to all verified subscribers
- ✓ Instant alerts triggering on material changes
- ✓ All emails rendering correctly across clients
- ✓ Unsubscribe flow working
- ✓ Email analytics dashboard showing key metrics

---

## Phase 5: Admin CMS (Week 14-15)

### Objectives
- Build admin dashboard for content management
- Implement CRUD for issuers, products, offers
- Add review/approval workflow
- Enable bulk import functionality

### Tasks

#### 5.1 Authentication Setup

**Provider**: Clerk or Auth0 recommended

**Configuration**:
- [ ] Create authentication provider account
- [ ] Configure application in provider dashboard
- [ ] Add authentication to Next.js app
- [ ] Implement role-based access control (ADMIN, EDITOR, VIEWER)
- [ ] Protect all /admin routes with middleware
- [ ] Create User records in database on first login

#### 5.2 Admin Layout & Navigation

**File**: `apps/web/src/app/admin/layout.tsx`

**Features**:
- Sidebar navigation
- User profile dropdown
- Breadcrumbs
- Role indicator

**Navigation Items**:
- Dashboard (overview stats)
- Offers (CRUD + approval queue)
- Products (CRUD)
- Issuers (CRUD)
- Subscribers (view only)
- Email Logs (view only)
- ETL Jobs (monitoring)
- Settings (currency valuations, etc.)

**Tasks**:
- [ ] Create admin layout component
- [ ] Implement navigation menu
- [ ] Add role-based menu item visibility
- [ ] Style with Tailwind

#### 5.3 Dashboard (app/admin/page.tsx)

**Widgets**:
- Total active offers
- Total subscribers (verified)
- Offers pending review
- Recent changes (last 7 days)
- ETL job status
- Email delivery stats (last 24h)

**Tasks**:
- [ ] Create dashboard stats queries
- [ ] Implement widget components
- [ ] Add auto-refresh (every 30s)

#### 5.4 Offer Management (app/admin/offers/...)

**List View** (app/admin/offers/page.tsx):
- Table with filters (status, issuer, product)
- Search by headline or product name
- Inline status badges
- Quick actions (edit, publish, archive)
- Bulk actions (publish selected, delete selected)

**Create/Edit View** (app/admin/offers/[id]/edit/page.tsx):
- Form with all offer fields
- Product selector (autocomplete)
- Terms snapshot upload
- Preview value calculation
- Save as draft or publish
- Version history viewer (if time permits)

**Approval Queue** (app/admin/offers/pending/page.tsx):
- List of offers detected by ETL (status: DRAFT)
- Side-by-side diff view (old vs. new)
- Approve/Reject buttons
- Bulk approve

**Tasks**:
- [ ] Implement offer CRUD API endpoints
- [ ] Create OfferForm component with validation
- [ ] Implement file upload for terms snapshots (S3)
- [ ] Create approval queue UI
- [ ] Add diff visualization component
- [ ] Implement bulk actions
- [ ] Add audit logging for all changes

#### 5.5 Product Management (app/admin/products/...)

**List View**:
- Table with issuer filter
- Show offer count per product
- Edit/Delete actions

**Create/Edit View**:
- Form with product fields
- Issuer selector
- Image upload (card image)
- Currency code selector with validation

**Tasks**:
- [ ] Implement product CRUD API endpoints
- [ ] Create ProductForm component
- [ ] Add image upload to S3
- [ ] Validate currency codes against CurrencyValuation table

#### 5.6 Issuer Management (app/admin/issuers/...)

**List View**:
- Simple table with issuer name, slug, product count
- Edit/Delete actions

**Create/Edit View**:
- Form with issuer fields
- Logo upload

**Tasks**:
- [ ] Implement issuer CRUD API endpoints
- [ ] Create IssuerForm component
- [ ] Add logo upload to S3
- [ ] Generate slug automatically from name

#### 5.7 Subscriber Management (app/admin/subscribers/page.tsx)

**Features**:
- Read-only list view
- Search by email
- Show subscription status, verified status
- View preferences per subscriber
- Export to CSV

**Tasks**:
- [ ] Create subscriber list component
- [ ] Implement search
- [ ] Add CSV export functionality
- [ ] Do NOT allow editing (privacy concerns)

#### 5.8 Email Logs (app/admin/email-logs/page.tsx)

**Features**:
- Searchable list of all sent emails
- Filter by type, status, date range
- View email content (if stored)
- Retry failed emails

**Tasks**:
- [ ] Create email log list component
- [ ] Implement filters
- [ ] Add retry functionality for failed emails

#### 5.9 ETL Job Monitoring (app/admin/jobs/page.tsx)

**Features**:
- Real-time job status (via Bull Board or custom UI)
- View failed jobs with error details
- Retry failed jobs
- Manually trigger jobs

**Tasks**:
- [ ] Integrate Bull Board or build custom UI
- [ ] Add job retry controls
- [ ] Implement manual job trigger
- [ ] Show job history

#### 5.10 Settings (app/admin/settings/page.tsx)

**Features**:
- Manage currency valuations (CPP table)
- Update global settings (e.g., alert thresholds)
- View system info

**Tasks**:
- [ ] Create CurrencyValuation CRUD UI
- [ ] Implement settings form
- [ ] Add save functionality with validation

#### 5.11 Bulk Import (app/admin/import/page.tsx)

**Features**:
- CSV upload for bulk offer creation
- Validation with error reporting
- Preview before import
- Execute import with progress indicator

**CSV Format**:
```csv
product_id,bonus_points,min_spend_amount,min_spend_window_days,annual_fee,first_year_waived,landing_url,source_type
citi-aa-platinum,80000,6000,90,99,true,https://...,public
```

**Tasks**:
- [ ] Implement CSV parser with validation
- [ ] Create preview UI showing validation results
- [ ] Implement bulk insert logic
- [ ] Add error handling and rollback on failure
- [ ] Create sample CSV template for download

#### 5.12 Audit Logging

**Automatic Logging**:
- All create/update/delete operations on offers, products, issuers
- User who performed action
- Timestamp
- Before/after values (JSON diff)

**Tasks**:
- [ ] Create middleware to capture all mutations
- [ ] Store in AuditLog table
- [ ] Create audit log viewer (app/admin/audit/page.tsx)

### Deliverables
- ✓ Fully functional admin CMS with authentication
- ✓ CRUD operations for all core entities
- ✓ Approval workflow for ETL-detected changes
- ✓ Bulk import working with validation
- ✓ Monitoring dashboards for jobs and emails
- ✓ Audit logging capturing all admin actions

---

## Phase 6: Polish & Launch (Week 16)

### Objectives
- Fix bugs and polish UI
- Performance optimization
- Security hardening
- Final testing
- Deploy to production

### Tasks

#### 6.1 Testing

**Unit Tests**:
- [ ] Achieve >80% coverage for critical paths
- [ ] Test all repository methods
- [ ] Test value calculation logic
- [ ] Test parsers with mock data

**Integration Tests**:
- [ ] Test API endpoints with real database
- [ ] Test ETL pipeline end-to-end
- [ ] Test email sending flow

**E2E Tests**:
- [ ] Install Playwright or Cypress
- [ ] Write tests for critical user flows:
  - Browse offers and apply filters
  - View card detail and history
  - Compare cards
  - Subscribe to emails (up to verification email sent)
  - Admin login and create offer

**Manual QA**:
- [ ] Test on Chrome, Firefox, Safari, Edge
- [ ] Test on mobile devices (iOS, Android)
- [ ] Test accessibility with screen reader
- [ ] Verify all links work (no 404s)
- [ ] Test email templates in multiple clients

#### 6.2 Performance Optimization

**Frontend**:
- [ ] Run Lighthouse audit, aim for >90 scores
- [ ] Optimize images (next/image, WebP format)
- [ ] Implement lazy loading for charts and images
- [ ] Code splitting (dynamic imports for heavy components)
- [ ] Minify CSS and JS (should be automatic with Next.js)
- [ ] Enable Brotli compression

**Backend**:
- [ ] Add database indexes for slow queries
- [ ] Implement caching strategy:
  - Cache offer list (5 minutes)
  - Cache offer detail (15 minutes)
  - Cache snapshots (1 hour)
- [ ] Optimize N+1 queries (use Prisma include/select carefully)
- [ ] Add CDN for static assets

**Database**:
- [ ] Run EXPLAIN ANALYZE on critical queries
- [ ] Add missing indexes
- [ ] Consider materialized views for aggregations (if needed)

**Tasks**:
- [ ] Complete all optimization tasks
- [ ] Measure before/after metrics
- [ ] Document any remaining bottlenecks

#### 6.3 Security Hardening

**Tasks**:
- [ ] Run security audit (npm audit, Snyk)
- [ ] Fix all critical and high vulnerabilities
- [ ] Implement Content Security Policy (CSP) headers
- [ ] Add rate limiting to all public API endpoints
- [ ] Validate all user inputs with Zod schemas
- [ ] Sanitize HTML in user-generated content (if any)
- [ ] Enable HTTPS only (HSTS header)
- [ ] Review and rotate all API keys and secrets
- [ ] Implement API key authentication for admin endpoints
- [ ] Add CAPTCHA to subscription form (optional, to prevent spam)

#### 6.4 SEO Final Touches

**Tasks**:
- [ ] Submit sitemap to Google Search Console
- [ ] Verify structured data with Google Rich Results Test
- [ ] Set up Google Analytics (if not done already)
- [ ] Create and submit robots.txt
- [ ] Ensure all pages have unique meta titles and descriptions
- [ ] Add Open Graph images for social sharing

#### 6.5 Legal & Compliance Final Review

**Tasks**:
- [ ] Review all disclaimers with legal counsel (if available)
- [ ] Ensure affiliate disclosure is prominent
- [ ] Verify GDPR/CCPA compliance (data export, deletion)
- [ ] Add "Last Updated" timestamps to all legal pages
- [ ] Test unsubscribe and data deletion flows

#### 6.6 Documentation

**Internal Documentation**:
- [ ] Update README with deployment instructions
- [ ] Document environment variables
- [ ] Create runbook for common operations:
  - How to add a new issuer
  - How to manually trigger ETL
  - How to fix failed email jobs
  - How to handle scraping failures
- [ ] Document API endpoints (OpenAPI/Swagger)

**User-Facing Documentation**:
- [ ] Write FAQ page
- [ ] Create "How It Works" page
- [ ] Document scoring methodology publicly

#### 6.7 Monitoring & Alerts

**Tasks**:
- [ ] Set up application monitoring (Sentry, Datadog, or similar)
- [ ] Configure error alerts (Slack, email, PagerDuty)
- [ ] Set up uptime monitoring (UptimeRobot, Pingdom)
- [ ] Create alerting rules:
  - ETL job failures (>3 consecutive)
  - Email bounce rate >5%
  - API error rate >1%
  - Database connection failures
- [ ] Set up log aggregation (if not using platform logs)

#### 6.8 Deployment

**Pre-Production Checklist**:
- [ ] All tests passing
- [ ] Performance benchmarks met
- [ ] Security audit complete
- [ ] Staging environment tested thoroughly
- [ ] Backup strategy in place
- [ ] Rollback plan documented

**Production Deployment**:
- [ ] Deploy database migrations
- [ ] Deploy backend/worker services
- [ ] Deploy frontend to production
- [ ] Verify all services healthy
- [ ] Run smoke tests on production
- [ ] Monitor for first 24 hours

**Post-Launch**:
- [ ] Announce launch (if applicable)
- [ ] Monitor error rates and performance
- [ ] Gather user feedback
- [ ] Create backlog for Phase 2 features

### Deliverables
- ✓ Production-ready application deployed
- ✓ All critical bugs fixed
- ✓ Performance targets met (Lighthouse >90)
- ✓ Security hardening complete
- ✓ Monitoring and alerts configured
- ✓ Documentation complete

---

## Non-Functional Requirements

### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Page Load Time (LCP) | <2.5s | Lighthouse, Core Web Vitals |
| Time to Interactive (TTI) | <3.5s | Lighthouse |
| API Response Time (p95) | <500ms | Server logs, APM |
| Database Query Time (p95) | <100ms | Prisma logs, DB monitoring |
| ETL Job Success Rate | >95% | Job queue metrics |
| Email Delivery Rate | >98% | Email provider webhooks |

### Scalability

**Current Capacity Targets** (Phase 1):
- Support 100K+ page views per month
- Handle 10K+ email subscribers
- Track 50+ card products across 8+ issuers
- Store 52+ weeks of historical snapshots per offer

**Future Scalability** (Phase 2+):
- Horizontal scaling for web frontend (stateless)
- Database read replicas for reporting
- ETL worker scaling (multi-instance)
- CDN for static assets and cached API responses

### Reliability

**Uptime Target**: 99.5% (allows ~3.6 hours downtime per month)

**Strategies**:
- Database automated backups (daily, retained 30 days)
- Application health checks
- Graceful degradation (show cached data if fresh data unavailable)
- Circuit breakers for external dependencies
- Retry logic with exponential backoff

### Security

**Requirements**:
- All data in transit encrypted (HTTPS/TLS 1.2+)
- Database connections encrypted
- Secrets stored in environment variables or secret manager
- Regular dependency updates (automated via Dependabot)
- SQL injection prevention (Prisma parameterized queries)
- XSS prevention (React default escaping)
- CSRF protection (Next.js built-in)

**Compliance**:
- GDPR: Data export, deletion, consent management
- CCPA: Data deletion, opt-out
- CAN-SPAM: Unsubscribe, sender identification

---

## Risk Management

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Issuer changes page structure, breaking scraper | High | Medium | Implement monitoring, fallback to manual entry, design flexible parsers |
| Third-party API rate limiting | Medium | Medium | Implement exponential backoff, respect rate limits, cache aggressively |
| Database performance degradation | Low | High | Add indexes, optimize queries, consider read replicas |
| Email deliverability issues | Medium | Medium | Use reputable provider, configure SPF/DKIM/DMARC, monitor bounce rates |
| Security vulnerability in dependencies | Medium | High | Automated scanning (Dependabot), regular updates, security reviews |

### Business Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Low user adoption | Medium | High | Focus on SEO, content marketing, provide unique value (historical data) |
| Affiliate program termination | Low | Medium | Diversify affiliate partnerships, track multiple programs |
| Legal challenges from issuers | Low | High | Clear disclaimers, respect ToS, consult legal counsel |
| Data accuracy concerns | Medium | High | Show last verified timestamp, allow user reports, manual verification |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Scraper implementation takes longer than expected | High | Medium | Start with easiest issuers, allocate buffer time, consider third-party data sources |
| Scope creep | Medium | Medium | Strict phase boundaries, defer Phase 2 features |
| Key team member unavailable | Low | High | Document everything, pair programming for critical components |

---

## Success Metrics (Phase 1)

### Launch Criteria (Go/No-Go)

Must have:
- ✓ 30+ active offers across 6+ issuers
- ✓ Weekly snapshot job running successfully
- ✓ Email subscription working end-to-end
- ✓ Admin CMS functional for CRUD operations
- ✓ All legal pages published
- ✓ Security audit passing
- ✓ Performance targets met (Lighthouse >85)

### Post-Launch Metrics (First 30 Days)

**Engagement**:
- 1,000+ unique visitors
- 10+ email subscribers per day
- >50% email verification rate
- >15% email open rate
- >5% click-through rate on apply links

**System Health**:
- >99% uptime
- >95% ETL job success rate
- >98% email delivery rate
- <1% error rate on API endpoints

**Data Quality**:
- >90% offers verified within 7 days
- <5% user-reported data inaccuracies

---

## Phase 2 Roadmap (Future)

### Priority Features

1. **User Accounts & Watchlists**
   - Allow users to create accounts
   - Save favorite cards
   - Set custom alerts with thresholds
   - Track personal 5/24 status (Chase rules)

2. **Enhanced Personalization**
   - Income-based spend feasibility scoring
   - Credit score guidance
   - Personalized recommendations

3. **Cash-Back Offers**
   - Expand beyond travel cards
   - Normalize cash-back offers with same value framework

4. **Community Features**
   - User-submitted deals (with moderation)
   - Comments/discussion per card
   - Upvote best offers

5. **Browser Extension**
   - Detect card landing pages
   - Show current vs. historical bonus inline
   - Alert if better offer exists

6. **Mobile App**
   - Native iOS/Android app
   - Push notifications for instant alerts

7. **API for Third Parties**
   - Public API with rate limiting
   - API key registration
   - Documentation portal

### Technical Improvements

- Implement Redis caching layer
- Add full-text search (Algolia or ElasticSearch)
- Migrate to microservices (if scale demands)
- Add A/B testing framework
- Implement feature flags

---

## Team & Roles

### Recommended Team Composition

**Phase 1 (MVP)**:
- 1x Full-Stack Engineer (Lead) — Architecture, database, API, frontend
- 1x Full-Stack Engineer — ETL pipeline, scrapers, admin CMS
- 0.5x DevOps Engineer — Infrastructure, CI/CD, monitoring
- 0.25x Designer — UI/UX design, branding (can be contractor)

**Phase 2+**:
- Add 1x Frontend Engineer (focus on performance, UX polish)
- Add 1x Data Engineer (focus on ETL reliability, data quality)
- Add 0.5x QA Engineer (testing, automation)

### Responsibilities

| Role | Key Responsibilities |
|------|---------------------|
| Full-Stack Lead | Architecture decisions, code reviews, database design, API design |
| Full-Stack Engineer | ETL implementation, parser development, admin CMS |
| DevOps Engineer | Infrastructure setup, CI/CD, monitoring, security |
| Designer | UI design, component library, branding, accessibility |

---

## Technology Stack Summary

### Frontend
- **Framework**: Next.js 14+ (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Component Library**: shadcn/ui or Radix UI
- **State Management**: Zustand or React Context
- **Data Fetching**: TanStack Query (React Query)
- **Charts**: Recharts or Chart.js
- **Forms**: React Hook Form + Zod validation

### Backend
- **API**: Next.js API Routes (or NestJS if separate)
- **ORM**: Prisma
- **Database**: PostgreSQL 14+
- **Validation**: Zod
- **Authentication**: Clerk or Auth0

### ETL & Jobs
- **Language**: TypeScript (Node.js) or Python
- **Queue**: BullMQ (Node.js) with Redis
- **Browser Automation**: Playwright
- **Scraping**: Cheerio (HTML parsing)
- **Scheduler**: Vercel Cron or GitHub Actions

### Infrastructure
- **Hosting (Frontend)**: Vercel or Netlify
- **Hosting (Backend/Worker)**: Fly.io, Render, or Railway
- **Database**: Supabase, Neon, or AWS RDS
- **Storage**: AWS S3 or Cloudflare R2
- **CDN**: CloudFront or Cloudflare
- **Email**: Postmark or SendGrid
- **Monitoring**: Sentry (errors), Datadog or Grafana (metrics)
- **Logging**: Platform logs (Vercel, Fly.io) or Papertrail

### Development Tools
- **Monorepo**: Turborepo or Nx
- **Version Control**: Git + GitHub
- **CI/CD**: GitHub Actions
- **Testing**: Jest (unit), Playwright (E2E)
- **Linting**: ESLint + Prettier
- **Documentation**: Markdown + Docusaurus (optional)

---

## Cost Estimation (Monthly, Phase 1)

| Service | Tier/Usage | Cost (USD) |
|---------|------------|------------|
| Vercel (Frontend) | Pro | $20 |
| Fly.io (Backend + Worker) | 2x shared-cpu-1x | $10-20 |
| Database (Neon/Supabase) | Pro | $25 |
| Redis (Upstash) | Pay-as-you-go | $5-10 |
| S3 Storage | ~10GB + bandwidth | $5 |
| Postmark (Email) | 10K emails/mo | $15 |
| Auth (Clerk) | Free tier | $0 |
| Domain + SSL | Annual amortized | $2 |
| Monitoring (Sentry) | Free tier | $0 |
| **Total** | | **~$82-97/mo** |

**Note**: Costs will increase with scale. Budget for Phase 2: $200-500/mo.

---

## Appendix

### A. Sample Data Seed Script Outline

```typescript
// seed.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // 1. Seed Currency Valuations
  await prisma.currencyValuation.createMany({
    data: [
      { currencyCode: 'AA', centsPerPoint: 1.4, notes: 'American Airlines AAdvantage' },
      { currencyCode: 'UA', centsPerPoint: 1.2, notes: 'United MileagePlus' },
      { currencyCode: 'DL', centsPerPoint: 1.1, notes: 'Delta SkyMiles' },
      { currencyCode: 'MR', centsPerPoint: 1.7, notes: 'Amex Membership Rewards' },
      { currencyCode: 'UR', centsPerPoint: 1.6, notes: 'Chase Ultimate Rewards' },
      { currencyCode: 'TYP', centsPerPoint: 1.5, notes: 'Citi ThankYou Points' },
    ]
  });

  // 2. Seed Issuers
  const citi = await prisma.issuer.create({
    data: {
      name: 'Citi',
      slug: 'citi',
      website: 'https://www.citi.com/credit-cards'
    }
  });

  const amex = await prisma.issuer.create({
    data: {
      name: 'American Express',
      slug: 'american-express',
      website: 'https://www.americanexpress.com'
    }
  });

  // 3. Seed Products
  const citiAA = await prisma.cardProduct.create({
    data: {
      issuerId: citi.id,
      name: 'Citi® / AAdvantage® Platinum Select®',
      slug: 'citi-aadvantage-platinum-select',
      network: 'MASTERCARD',
      type: 'PERSONAL',
      currency: 'AA miles',
      currencyCode: 'AA'
    }
  });

  // 4. Seed Offers
  const offer = await prisma.offer.create({
    data: {
      productId: citiAA.id,
      headline: 'Earn 80,000 AAdvantage miles',
      bonusPoints: 80000,
      minSpendAmount: 6000,
      minSpendWindowDays: 90,
      annualFee: 99,
      firstYearWaived: true,
      statementCredits: 0,
      landingUrl: 'https://example.com/apply',
      sourceType: 'PUBLIC',
      status: 'ACTIVE',
      lastVerifiedAt: new Date(),
      publishedAt: new Date()
    }
  });

  // 5. Seed Historical Snapshots (simulate past changes)
  await prisma.offerSnapshot.createMany({
    data: [
      {
        offerId: offer.id,
        capturedAt: new Date('2025-10-01'),
        bonusPoints: 75000,
        minSpendAmount: 6000,
        minSpendWindowDays: 90,
        annualFee: 99,
        statementCredits: 0,
        landingUrl: 'https://example.com/apply'
      },
      {
        offerId: offer.id,
        capturedAt: new Date('2025-10-27'),
        bonusPoints: 80000,
        minSpendAmount: 6000,
        minSpendWindowDays: 90,
        annualFee: 99,
        statementCredits: 0,
        landingUrl: 'https://example.com/apply',
        diffSummary: 'Bonus increased 75,000 → 80,000'
      }
    ]
  });

  console.log('Seed data created successfully!');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
```

### B. Sample ETL Source Configuration

```json
{
  "issuer": "citi",
  "issuerSlug": "citi",
  "products": [
    {
      "productId": "citi-aa-platinum",
      "productName": "Citi AAdvantage Platinum Select",
      "url": "https://www.citi.com/credit-cards/citi-aadvantage-platinum-select-world-elite-mastercard",
      "fetchMethod": "html",
      "requiresJavaScript": false,
      "selectors": {
        "bonusPoints": {
          "selector": ".bonus-miles-amount",
          "regex": "([0-9,]+)",
          "type": "number"
        },
        "minSpendAmount": {
          "selector": ".spend-requirement",
          "regex": "\\$([0-9,]+)",
          "type": "currency"
        },
        "minSpendWindowDays": {
          "selector": ".spend-window",
          "regex": "([0-9]+) months",
          "type": "days",
          "transform": "monthsToDays"
        },
        "annualFee": {
          "selector": ".annual-fee",
          "regex": "\\$([0-9,]+)",
          "type": "currency"
        }
      },
      "parser": "CitiHtmlParser",
      "notes": "Relatively stable selectors; verify quarterly"
    }
  ]
}
```

### C. Sample Email Template (React Email)

```tsx
// WeeklyDigestEmail.tsx
import {
  Body,
  Container,
  Head,
  Heading,
  Html,
  Link,
  Preview,
  Section,
  Text,
} from '@react-email/components';

interface WeeklyDigestEmailProps {
  subscriberEmail: string;
  topOffers: Offer[];
  changes: Change[];
  unsubscribeUrl: string;
}

export const WeeklyDigestEmail = ({
  subscriberEmail,
  topOffers,
  changes,
  unsubscribeUrl,
}: WeeklyDigestEmailProps) => (
  <Html>
    <Head />
    <Preview>This week's top credit card offers</Preview>
    <Body style={main}>
      <Container style={container}>
        <Heading style={h1}>This Week's Top Credit Card Offers</Heading>

        <Section style={section}>
          <Heading as="h2" style={h2}>Top 5 Offers by Value</Heading>
          {topOffers.map((offer, i) => (
            <div key={offer.id} style={offerCard}>
              <Text style={offerTitle}>
                #{i + 1}: {offer.product.issuer.name} {offer.product.name}
              </Text>
              <Text style={offerDetail}>
                <strong>{offer.bonusPoints.toLocaleString()} {offer.product.currency}</strong>
                {' '}after ${offer.minSpendAmount.toLocaleString()} spend in {offer.minSpendWindowDays} days
              </Text>
              <Text style={offerValue}>
                Estimated Value: ${calculateValue(offer).toFixed(0)}
              </Text>
              <Link href={offer.landingUrl} style={button}>
                Apply Now
              </Link>
            </div>
          ))}
        </Section>

        <Section style={section}>
          <Heading as="h2" style={h2}>Notable Changes This Week</Heading>
          {changes.map((change) => (
            <Text key={change.id} style={changeText}>
              • <strong>{change.product}</strong>: {change.diffSummary}
            </Text>
          ))}
        </Section>

        <Section style={footer}>
          <Text style={footerText}>
            You're receiving this because you subscribed to Credit Card Tracker weekly digest.
          </Text>
          <Link href={unsubscribeUrl} style={unsubscribeLink}>
            Unsubscribe
          </Link>
        </Section>
      </Container>
    </Body>
  </Html>
);

// Styles (inline for email compatibility)
const main = {
  backgroundColor: '#f6f9fc',
  fontFamily: '-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Ubuntu,sans-serif',
};

const container = {
  backgroundColor: '#ffffff',
  margin: '0 auto',
  padding: '20px 0 48px',
  marginBottom: '64px',
};

const h1 = {
  color: '#333',
  fontSize: '24px',
  fontWeight: 'bold',
  margin: '40px 0',
  padding: '0 20px',
};

// ... more styles

export default WeeklyDigestEmail;
```

### D. API Documentation Sample (OpenAPI)

```yaml
openapi: 3.0.0
info:
  title: Credit Card Tracker API
  version: 1.0.0
  description: Public API for credit card offer data

paths:
  /api/offers:
    get:
      summary: List active credit card offers
      parameters:
        - name: issuer
          in: query
          schema:
            type: string
          description: Filter by issuer slug
        - name: currency
          in: query
          schema:
            type: string
          description: Filter by currency code (e.g., "AA", "UR")
        - name: minBonus
          in: query
          schema:
            type: integer
          description: Minimum bonus points
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Offer'
                  pagination:
                    $ref: '#/components/schemas/Pagination'

  /api/offers/{id}:
    get:
      summary: Get offer details
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/OfferDetail'

components:
  schemas:
    Offer:
      type: object
      properties:
        id:
          type: string
        headline:
          type: string
        bonusPoints:
          type: integer
        minSpendAmount:
          type: number
        # ... more fields
```

---

## Conclusion

This implementation plan provides a comprehensive roadmap for building the Credit Card Deals Tracker web application from foundation to launch. By following this phased approach, the team can deliver a high-quality MVP in 16 weeks while maintaining flexibility for future enhancements.

**Key Success Factors**:
1. Start with solid data foundation (Phase 1)
2. Prioritize ETL reliability (Phase 2)
3. Focus on user experience (Phase 3)
4. Ensure email deliverability (Phase 4)
5. Empower admin team (Phase 5)
6. Don't skip polish phase (Phase 6)

**Next Steps**:
1. Review and approve this plan with stakeholders
2. Assemble team and assign responsibilities
3. Set up development environment (Phase 0, Week 1)
4. Begin Phase 1 implementation

For questions or clarifications, refer to the source requirements document (`requirement_v1.md`) or consult with the technical lead.

#### IMPORTANT RULE TO FOLLOW #### 
Perform the plans specified in this document and prepare result document under ./.claude/result folder.
---
*Document version: 1.0*
*Last updated: 2025-11-04*
*Prepared by: Claude (AI Assistant)*

