# Credit Card Deals Tracker — Web Requirements

*Last updated: 2025-11-04*

## 1) Project Summary

Build a web application that aggregates the **latest credit card welcome offers** (with a focus on airline mileage bonuses), tracks **weekly changes** by issuer and product, and provides **actionable insights** (trend lines and value scores) to help users decide when to apply. Include **email subscriptions** with apply links.

---

## 2) Goals & Non‑Goals

**Goals**

* Centralize current public welcome offers for major issuers and travel cards.
* Track week‑over‑week changes (bonus amount, spend requirement, fee, expiration).
* Calculate a “deal value” score using transparent assumptions.
* Provide subscription emails highlighting notable changes and top picks.
* Support affiliate/partner links and campaign tracking.

**Non‑Goals (Phase 1)**

* In‑app application processing (redirect only).
* Personalized credit advice or hard‑pull pre‑qualifications.
* Comprehensive cash‑back coverage (focus is airline mileage + transferable points; cash‑back optional).

---

## 3) Target Users & Use Cases

**Personas**

* **Optimizer** (experienced churner): scans weekly deltas, cares about issuer rules (e.g., 5/24), wants peak bonuses.
* **Planner** (occasional applicant): wants a simple “Is now good?” indicator + how hard the spend is.
* **Newbie**: subscribes to curated picks and education pages.

**Primary Use Cases**

1. Browse all current airline/points offers; filter by issuer, program, minimum spend, AF, eligibility constraints.
2. View a card’s **offer history**: “80k → 65k” with dates, landing‑page notes, and terms snapshot.
3. Get a weekly digest email of changes and top 10 offers by value score.
4. Click through to issuer/affiliate apply page with UTM and disclosure.

---

## 4) Functional Requirements

1. **Offer Catalog**

   * List all active public offers by issuer (Amex, Chase, Citi, Bank of America, Capital One, U.S. Bank, etc.).
   * Each offer has a canonical product (e.g., “Citi® / AAdvantage® Platinum Select®”) and one or more variants (public, in‑branch, targeted if allowed, referral if allowed).
2. **Weekly Tracking**

   * Snapshot offers every week (Sun 00:00 CT default) and on detected changes.
   * Compute week‑over‑week deltas for: bonus amount, min spend, window, AF, credits, expiration date, landing URL, terms key lines.
3. **Trend & History**

   * Per product page timeline chart (bonus miles/points vs. date).
   * Change log with human‑readable diffs.
4. **Deal Scoring**

   * Publish scoring formula and assumptions (cents‑per‑point table below).
   * Show **Value Score** and **Effective First‑Year Net Value**.
5. **Notifications / Subscriptions**

   * Double opt‑in email sign‑up; weekly digest, and instant alerts for large changes (e.g., ≥20% bonus).
   * Manage preferences by issuer/program.
6. **Outbound Links**

   * Support affiliate links and non‑affiliate public links.
   * UTM tagging + link health monitoring; FTC disclosures.
7. **Search & Filters**

   * Filter: issuer, program, bonus size, min spend, spend window, AF, first‑year‑waived, Biz/Personal, metal/plastic (optional), credit score estimate.
8. **Admin CMS**

   * CRUD for issuers, products, offers.
   * Approve/Publish flow; bulk import; terms snapshot upload; evidence links.
   * Flag disputes and retire stale offers.
9. **Compliance & Content**

   * Clear disclaimers; data freshness timestamp; privacy policy; cookie consent.

---

## 5) Data Model (Proposed)

```mermaid
erDiagram
  Issuer ||--o{ CardProduct : has
  CardProduct ||--o{ Offer : offers
  Offer ||--o{ OfferSnapshot : snapshots

  Issuer {
    string id PK
    string name
    string website
  }

  CardProduct {
    string id PK
    string issuer_id FK
    string name
    string network  // Amex, Visa, MC, Discover
    string type     // Personal, Business
    string currency // AA miles, UR, MR, TYP, etc.
  }

  Offer {
    string id PK
    string product_id FK
    string headline
    int    bonus_points
    decimal min_spend_amount
    int    min_spend_window_days
    decimal annual_fee
    bool   first_year_waived
    decimal statement_credits  // sum of structured credits
    decimal intro_apr_months   // optional
    date   expires_on          // null if none
    string landing_url
    string source_type         // public, refer-a-friend, in-branch
    string geo                 // US, PR, etc.
    string status              // active, expired, rumored
    json   terms_snapshot_meta // hash, s3 path, captured_at
    datetime last_verified_at
  }

  OfferSnapshot {
    string id PK
    string offer_id FK
    datetime captured_at
    int bonus_points
    decimal min_spend_amount
    int min_spend_window_days
    decimal annual_fee
    decimal statement_credits
    date expires_on
    string landing_url
    string diff_summary
  }
```

**Minimal Offer JSON** (API response example)

```json
{
  "issuer": "Citi",
  "product": "AAdvantage Platinum Select",
  "currency": "AA miles",
  "offer": {
    "bonus_points": 80000,
    "min_spend_amount": 6000,
    "min_spend_window_days": 90,
    "annual_fee": 99,
    "first_year_waived": true,
    "expires_on": null,
    "landing_url": "https://example.com/apply",
    "status": "active"
  },
  "last_verified_at": "2025-11-03T10:00:00-06:00"
}
```

---

## 6) Trend Logic & Examples

**Weekly diff rules**

* A change event is recorded when any of: `bonus_points`, `min_spend_amount`, `min_spend_window_days`, `annual_fee`, `statement_credits`, `expires_on`, `landing_url` changes.
* Generate human text:

  * *“Bonus decreased **80,000 → 65,000** on 2025‑11‑03; min spend unchanged at $6,000/3mo.”*

**Example change table**

| Date       |  Bonus | Spend/Window |  AF | Notes     |
| ---------- | -----: | -----------: | --: | --------- |
| 2025‑10‑27 | 80,000 |   $6,000/90d | $99 | FY waived |
| 2025‑11‑03 | 65,000 |   $6,000/90d | $99 | FY waived |

---

## 7) Deal Scoring (Transparent)

**Cents‑per‑Point (CPP) Baseline (conservative)**

* AA: **1.4**¢
* United: **1.2**¢
* Delta: **1.1**¢
* MR (Amex): **1.7**¢
* UR (Chase): **1.6**¢
* TYP (Citi): **1.5**¢

**Effective First‑Year Net Value**

```
value = (bonus_points * cpp) + statement_credits - (annual_fee if !first_year_waived else 0)
```

**Deal Value Score (0–100)**

* Normalize `value` against 12‑month rolling distribution (p10→10, median→50, p90→90).
* Boost +5 for historically high bonus (≥ 90th percentile for that product).
* Penalty −5 if min spend / monthly income ratio > 0.5 (if user‑provided income, Phase 2).

Each card page shows **score**, components, and historical max/min for context.

---

## 8) Sources & Ingestion

**Sources**

* Official issuer public landing pages.
* Allowed partner/affiliate networks (if applicable).
* Bank press releases/blogs.

**Ingestion Strategy**

* Prefer structured connectors/feeds. Fallback to HTML scraping with selectors.
* Store **terms snapshot** (HTML hash + PDF/image capture) for auditing.
* Change detection: diff latest fetch vs. prior OfferSnapshot; enqueue review if material change.

**Cadence**

* Scheduled weekly crawl (Sun 02:00 CT) + on‑demand re‑check for monitored URLs.
* Alerts on fetch failure or HTTP/content diffs.

---

## 9) UI/UX Requirements

**Pages**

1. **Home / Top Deals**: sortable table with Value Score, Bonus, Spend, Window, AF, Expiry.
2. **Issuer Hubs** (Amex, Chase, Citi, BofA, CapOne, U.S. Bank...).
3. **Card Detail**: trend chart, change log, terms snapshot, FAQs, apply button.
4. **Compare**: side‑by‑side up to 3 cards.
5. **Learn**: bank rules (e.g., 5/24, family language, once‑per‑lifetime, 24‑month, etc.).
6. **Subscribe**: preferences + examples of prior digests.

**Components**

* Badge for **New/Changed this week**.
* Graph: bonus vs. date (sparklines in list; full chart on detail).
* Disclosure ribbon for affiliate relationships.
* Mobile first; sticky compare tray.

**Accessibility**

* WCAG 2.2 AA: focus states, aria labels, 4.5:1 contrast, semantic tables.

---

## 10) Email & Subscription

* **Double opt‑in** (confirm link).
* Weekly digest: top movers (>= ±10k points), expiring soon, top 5 by Value Score.
* Instant alert opt‑in for a watched issuer/product.
* Link tracking with UTM; template supports dynamic blocks per preference.
* One‑click unsubscribe; DKIM/SPF/DMARC configured.

---

## 11) Architecture (Suggested)

* **Frontend**: Next.js (App Router), TypeScript, Tailwind, TanStack Query.
* **Backend API**: Node.js (NestJS / Express) or Next.js API routes; Zod schemas.
* **DB**: Postgres (Prisma ORM). Time‑series snapshots table.
* **ETL**: Node or Python workers (Playwright for capture), Redis queue (BullMQ / RQ).
* **Storage**: S3 (terms snapshots, screenshots). CloudFront CDN.
* **Email**: Postmark/SendGrid; List management + templates.
* **Auth (Admin)**: Clerk/Auth0; role‑based access for CMS.
* **Infra**: Vercel (FE), Fly.io/Render/AWS (BE/ETL). Cron via Cloud Scheduler / GitHub Actions / Vercel Cron.

**APIs**

* `GET /api/offers?issuer=Citi&currency=AA` — list current offers
* `GET /api/offers/{id}` — card detail + history
* `GET /api/offers/{id}/snapshots` — time series
* `POST /api/subscribe` — email opt‑in
* `POST /api/admin/offers` — create/update (protected)

**Open Data Export (optional)**

* Weekly CSV/JSON dump for transparency.

---

## 12) SEO, Analytics & Tracking

* Server‑side rendered list/detail pages; JSON‑LD for product/offer.
* Canonicals, sitemap, lastmod by snapshot.
* Event tracking: `offer_clicked`, `subscribe_started`, `subscribe_confirmed`, `alert_opt_in`, `compare_used`.

---

## 13) Legal, Risk & Compliance

* **Disclosures**: affiliate relationships; “information not provided by any bank.”
* **Accuracy**: show last verified time and source link.
* **Privacy**: GDPR/CCPA compliant; clear data retention; unsubscribe.
* Respect issuer terms; do not scrape authenticated/targeted content where prohibited.

---

## 14) Admin Workflow

* Queue of suspected changes with diffs → reviewer confirms → publish.
* Versioned edits; revert.
* Bulk import via CSV; validation with Zod/JSON Schema.

---

## 15) Acceptance Criteria (Phase 1)

* Users can view a table of ≥ 30 live offers across ≥ 6 issuers.
* Each offer shows last verified timestamp and source link.
* Weekly snapshot job runs and generates at least one diff when a change occurs.
* Card detail page renders a 12‑month bonus history chart.
* Email subscription works end‑to‑end (double opt‑in) and sends a weekly digest.
* Affiliate links include UTM and disclosure banner is visible on pages with such links.

---

## 16) Backlog / Phase 2 Ideas

* User watchlists and personalized alerts (issuer/product/thresholds).
* Cash‑back offers with normalized “net first‑year value.”
* Browser extension for on‑page detection.
* Community submit‑a‑deal with moderation.
* Soft eligibility guidance (e.g., Chase 5/24 tracker if user provides inputs).

---

## 17) Sample Tables (UI copy)

**List Page Columns**

| Issuer | Card                       |  Bonus | Spend / Window |  AF | FY Waived | Value (est.) | Status | Last Verified       |
| ------ | -------------------------- | -----: | -------------: | --: | :-------: | -----------: | :----: | :------------------ |
| Citi   | AAdvantage Platinum Select | 80,000 |   $6,000 / 90d | $99 |    Yes    |       $1,021 | Active | 2025‑11‑03 10:00 CT |

**Change Log Snippet**

* 2025‑11‑03: **Bonus decreased** 80,000 → 65,000; spend unchanged; AF unchanged.

---

## 18) Content Guidelines

* Avoid bank trademarks misuse; use registered marks with ® where needed in static copy.
* Keep educational tone; explain scoring assumptions and limitations.
* Always include date/time zone (America/Chicago) on freshness indicators.

---

## 19) Monitoring & QA

* Uptime and job alerts; notify on zero offers fetched or drastic drop.
* Visual regression tests for key pages.
* Link checker for landing URLs; 404/302 changes alert.

---

## 20) Implementation Checklist

* [ ] DB schema & migrations
* [ ] ETL scaffolding + source registry
* [ ] Offer diffing + snapshots
* [ ] Admin CMS (create/approve/publish)
* [ ] Public API + caching
* [ ] Frontend list/detail/compare
* [ ] Email service + templates + double opt‑in
* [ ] Analytics + SEO
* [ ] Legal pages & disclosures
* [ ] Production cron + monitoring

#### IMPORTANT RULE TO FOLLOW #### 
Do not make code change or propose code but prepare plan document under ./.claude/plan folder.
