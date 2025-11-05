# Credit Card Deals Tracker

A web application that aggregates credit card welcome offers (focusing on airline mileage and transferable points), tracks weekly changes, and provides actionable insights to help users decide when to apply.

## Project Structure

This is a monorepo managed with Turborepo containing:

```
credit-card-tracker/
├── apps/
│   ├── web/              # Next.js frontend application
│   ├── api/              # Backend API (future)
│   └── worker/           # ETL worker processes (future)
├── packages/
│   ├── database/         # Prisma schema + client + repositories
│   ├── ui/               # Shared UI components (future)
│   ├── types/            # Shared TypeScript types (future)
│   ├── validation/       # Zod schemas (future)
│   └── config/           # Shared configs
└── docs/                 # Documentation
```

## Prerequisites

- Node.js >= 18.0.0
- pnpm >= 8.0.0
- PostgreSQL 14+
- Redis (for job queue)

## Getting Started

### 1. Install Dependencies

```bash
pnpm install
```

### 2. Set Up Environment Variables

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

### 3. Set Up Database

```bash
# Generate Prisma client
cd packages/database
pnpm db:generate

# Push schema to database
pnpm db:push

# Seed database with sample data
pnpm db:seed
```

### 4. Run Development Server

```bash
pnpm dev
```

## Database Schema

The application uses PostgreSQL with Prisma ORM. Key models include:

- **Issuer**: Credit card issuers (Amex, Chase, Citi, etc.)
- **CardProduct**: Individual credit card products
- **Offer**: Current welcome offers with all details
- **OfferSnapshot**: Historical snapshots for tracking changes
- **CurrencyValuation**: Cents-per-point values for different point currencies
- **Subscriber**: Email subscribers with preferences
- **User**: Admin users for CMS access

See `packages/database/prisma/schema.prisma` for full schema details.

## Development

### Available Scripts

- `pnpm dev` - Start development servers for all apps
- `pnpm build` - Build all apps for production
- `pnpm test` - Run tests
- `pnpm lint` - Lint all packages
- `pnpm format` - Format code with Prettier

### Database Commands

- `pnpm db:generate` - Generate Prisma client
- `pnpm db:push` - Push schema changes to database
- `pnpm db:migrate` - Create and apply migrations
- `pnpm db:studio` - Open Prisma Studio (database GUI)
- `pnpm db:seed` - Seed database with sample data

## Architecture

### Frontend (Next.js)
- App Router with React Server Components
- TypeScript for type safety
- Tailwind CSS for styling
- TanStack Query for data fetching
- Server-side rendering for SEO

### Backend
- Next.js API Routes
- Prisma ORM for database access
- Zod for validation
- Repository pattern for data access

### ETL Pipeline (Planned)
- BullMQ for job queue
- Playwright for web scraping
- Redis for queue storage
- S3 for terms snapshots

## Features

### Phase 1 (MVP)
- [x] Database schema and migrations
- [x] Seed data with sample offers
- [ ] Public offer listing with filters
- [ ] Card detail pages with history charts
- [ ] Comparison tool
- [ ] Email subscriptions (double opt-in)
- [ ] Weekly digest emails
- [ ] Admin CMS for content management
- [ ] ETL pipeline for data collection

### Phase 2 (Future)
- [ ] User accounts and watchlists
- [ ] Personalized recommendations
- [ ] Cash-back offers coverage
- [ ] Community features
- [ ] Browser extension
- [ ] Mobile app

## Deal Scoring

The application uses a transparent scoring system:

### Cents-per-Point Valuations
- AA (American Airlines): 1.4¢
- United: 1.2¢
- Delta: 1.1¢
- MR (Amex): 1.7¢
- UR (Chase): 1.6¢
- TYP (Citi): 1.5¢

### Effective First-Year Net Value
```
value = (bonus_points × cpp) + statement_credits - (annual_fee if !first_year_waived else 0)
```

### Deal Value Score (0-100)
Normalized against 12-month rolling distribution with bonuses for historically high offers.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

TBD

## Support

For questions or issues, please open a GitHub issue.
