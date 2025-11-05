# Running the Credit Card Tracker Application

## What's Been Built

The application foundation is complete with:
- ✅ Monorepo structure
- ✅ Complete database schema (12 models)
- ✅ Repository layer for data access
- ✅ Next.js frontend with pages
- ✅ API routes for data fetching
- ✅ Seed data script with sample offers

## Prerequisites to Run

The application requires **PostgreSQL** database. The schema uses features not available in SQLite:
- Enums
- Decimal types
- JSON fields
- Text fields

## Setup Instructions

### Option 1: Install PostgreSQL Locally

1. **Install PostgreSQL**:
   ```bash
   # macOS with Homebrew
   brew install postgresql@14
   brew services start postgresql@14

   # Or download from https://postgresapp.com/
   ```

2. **Create Database**:
   ```bash
   createdb credit_card_tracker
   ```

3. **Update .env file**:
   ```bash
   # Edit .env
   DATABASE_URL="postgresql://your_username@localhost:5432/credit_card_tracker"
   ```

4. **Setup Database Schema**:
   ```bash
   cd apps/web
   npx prisma generate
   npx prisma db push
   npx tsx prisma-lib/seed.ts
   ```

5. **Run the Application**:
   ```bash
   npm run dev
   ```

6. **Open Browser**:
   Navigate to [http://localhost:3000](http://localhost:3000)

### Option 2: Use Free Cloud Database (Easiest)

**Neon (Recommended - Free tier includes PostgreSQL)**

1. **Sign up at [neon.tech](https://neon.tech)**
2. **Create a new project**
3. **Copy the connection string**
4. **Update .env**:
   ```
   DATABASE_URL="postgresql://user:password@ep-xxx-xxx.us-east-2.aws.neon.tech/dbname?sslmode=require"
   ```

5. **Setup and run**:
   ```bash
   cd apps/web
   npx prisma generate
   npx prisma db push
   npx tsx prisma-lib/seed.ts
   npm run dev
   ```

**Alternative: Supabase**

1. **Sign up at [supabase.com](https://supabase.com)**
2. **Create new project**
3. **Get connection string** from Settings → Database
4. **Follow same steps as Neon above**

## What You'll See

Once running, you'll have access to:

### Home Page (`/`)
- Project overview
- Feature highlights
- Scoring methodology explanation
- Quick links to offers and issuers

### Offers Page (`/offers`)
- List of all active credit card offers
- Sorted by estimated value
- Shows:
  - Bonus points
  - Minimum spend requirements
  - Annual fee (with first-year waived indicator)
  - Calculated value in dollars
  - Apply buttons linking to card pages

### Issuers Page (`/issuers`)
- List of credit card issuers
- Shows number of products per issuer
- Links to issuer websites

### API Endpoints

The application includes these API endpoints:

- `GET /api/offers` - Returns all active offers with calculated values
  - Query params: `issuer`, `currency`, `minBonus`
  - Response includes bonus value calculations

## Sample Data Included

The seed script creates:

**6 Issuers:**
- Citi
- American Express
- Chase
- Bank of America
- Capital One
- U.S. Bank

**4 Card Products:**
- Citi® / AAdvantage® Platinum Select®
- American Express® Gold Card
- Chase Sapphire Preferred®
- Capital One Venture Rewards

**3 Active Offers with Historical Data:**
1. **Citi AA**: 80,000 AA miles ($1,120 value)
2. **Amex Gold**: 90,000 MR points ($1,325 value)
3. **Chase Sapphire Preferred**: 75,000 UR points ($1,105 value)

**Currency Valuations:**
- AA: 1.4¢
- United: 1.2¢
- Delta: 1.1¢
- MR: 1.7¢
- UR: 1.6¢
- TYP: 1.5¢

## Troubleshooting

### "Cannot find module '@prisma/client'"
```bash
cd apps/web
npx prisma generate
```

### "Database connection error"
- Verify DATABASE_URL in .env is correct
- Check PostgreSQL is running
- Test connection: `psql $DATABASE_URL`

### "Table does not exist"
```bash
cd apps/web
npx prisma db push
npx tsx prisma-lib/seed.ts
```

### Port 3000 already in use
```bash
# Kill the process
lsof -ti:3000 | xargs kill -9

# Or use different port
PORT=3001 npm run dev
```

## Next Development Steps

The foundation is complete. Next priorities:

1. **Add Charts** - Implement historical bonus trend charts
2. **Comparison Tool** - Side-by-side card comparison
3. **Email Subscriptions** - Double opt-in and digest emails
4. **Admin CMS** - Content management interface
5. **ETL Pipeline** - Automated data collection from issuers

## Project Structure

```
MileageTracking/
├── apps/
│   └── web/                    # Next.js application
│       ├── prisma/             # Database schema
│       ├── prisma-lib/         # Repositories and seed
│       └── src/
│           └── app/
│               ├── page.tsx              # Home page
│               ├── offers/page.tsx       # Offers list
│               ├── issuers/page.tsx      # Issuers list
│               └── api/offers/route.ts   # API endpoint
├── packages/
│   └── database/               # Original database package
├── .env                        # Your configuration
└── README.md                   # Project documentation
```

## Getting Help

- Review README.md for project overview
- Check .claude/result/implementation-result-v1.md for detailed implementation notes
- Verify all environment variables in .env
- Ensure Node.js 18+ is installed

## Quick Start (TL;DR)

```bash
# 1. Get a free PostgreSQL database from neon.tech or supabase.com
# 2. Add connection string to .env
echo 'DATABASE_URL="postgresql://..."' > .env

# 3. Setup database
cd apps/web
npx prisma generate
npx prisma db push
npx tsx prisma-lib/seed.ts

# 4. Run
npm run dev

# 5. Open http://localhost:3000
```

That's it! The application should now be running with sample credit card offers.
