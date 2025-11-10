# V5 Requirements: Production Deployment & Enhanced CI/CD Pipeline

**Project**: Mileage Deal Tracker
**Phase**: V5 - Production Environment & Advanced CI/CD
**Prerequisites**: V4 Complete (Dev environment fully operational)
**Estimated Duration**: 6-8 hours

---

## Executive Summary

This phase focuses on creating a production-ready deployment pipeline with:
- Separate production environment in Azure
- Staging slot for blue-green deployments
- Enhanced CI/CD with testing and approval gates
- Monitoring, alerts, and operational readiness
- Security hardening and performance optimization

---

## Goals & Objectives

### Primary Goals
1. Create isolated production environment in Azure
2. Implement staging/production deployment workflow
3. Add automated testing to CI/CD pipeline
4. Set up comprehensive monitoring and alerting
5. Implement security best practices
6. Optimize performance and scalability

### Success Criteria
- ✅ Production environment deployed and isolated from dev
- ✅ Blue-green deployment working with zero downtime
- ✅ Automated tests passing in CI/CD
- ✅ Monitoring dashboards and alerts configured
- ✅ Custom domain configured with SSL
- ✅ Performance benchmarks met
- ✅ Security audit passed

---

## Phase 1: Production Infrastructure Setup

### 1.1 Terraform Configuration for Production
**Duration**: 1-2 hours

#### Tasks:
- [ ] Create new Terraform workspace for production
- [ ] Update `infra/terraform/environments/prod/` configuration
- [ ] Configure production-grade resources:
  - [ ] App Service Plan: Standard S1 (minimum for production slots)
  - [ ] PostgreSQL: General Purpose tier with high availability
  - [ ] Storage Account: Geo-redundant storage (GRS)
  - [ ] Application Insights: Enhanced retention (90 days)
  - [ ] Azure Front Door or CDN for static assets
- [ ] Set up production-specific settings:
  - [ ] Auto-scaling rules
  - [ ] Backup policies
  - [ ] Disaster recovery configuration
  - [ ] Network isolation (VNet if needed)

#### Deliverables:
- `infra/terraform/environments/prod/main.tf`
- `infra/terraform/environments/prod/variables.tf`
- `infra/terraform/environments/prod/terraform.tfvars`
- Production environment deployed in separate resource group

#### Resource Naming Convention:
```
Resource Group: mileage-deal-rg-prod
App Service Plan: mileage-deal-tracker-plan-prod (S1)
Web App: mileage-deal-tracker-prod
PostgreSQL: mileage-deal-tracker-db-prod
Database: mileage_tracker_prod
Application Insights: mileage-deal-tracker-insights-prod
Storage Account: mileagedealtrackerstprod
```

---

### 1.2 Staging Slot Configuration
**Duration**: 30 minutes

#### Tasks:
- [ ] Create staging deployment slot in production App Service
- [ ] Configure slot-specific settings:
  - [ ] `DATABASE_URL` (staging database or prod read-replica)
  - [ ] `NEXT_PUBLIC_APP_URL` (staging URL)
  - [ ] `NODE_ENV=staging`
- [ ] Set up slot swap settings (which settings stick vs swap)
- [ ] Test manual slot swap

#### Deliverables:
- Staging slot: `mileage-deal-tracker-prod-staging`
- Slot configuration documented
- Swap procedure tested

---

### 1.3 Production Database Setup
**Duration**: 1 hour

#### Tasks:
- [ ] Deploy PostgreSQL production database
- [ ] Configure high availability and backups:
  - [ ] Zone-redundant deployment
  - [ ] Automated backups (daily, 7-day retention)
  - [ ] Point-in-time restore enabled
- [ ] Set up read replicas (if needed for scaling)
- [ ] Configure firewall rules (production only)
- [ ] Apply database schema (Prisma migrations)
- [ ] Load production seed data (if applicable)

#### Security:
- [ ] Enable Azure AD authentication
- [ ] Restrict access to specific IP ranges
- [ ] Enable SSL enforcement
- [ ] Set up private endpoints (optional, for enhanced security)

---

## Phase 2: Enhanced CI/CD Pipeline

### 2.1 Automated Testing Integration
**Duration**: 2-3 hours

#### Tasks:
- [ ] Set up testing framework:
  - [ ] Jest for unit tests
  - [ ] Playwright or Cypress for E2E tests
  - [ ] Add `npm test` script to package.json
- [ ] Create test files:
  - [ ] Unit tests for API routes (`apps/web/src/app/api/**/*.test.ts`)
  - [ ] Component tests for React components
  - [ ] Integration tests for database operations
  - [ ] E2E tests for critical user flows
- [ ] Add test step to GitHub Actions workflow
- [ ] Configure test coverage reporting
- [ ] Set minimum coverage threshold (e.g., 70%)

#### Test Coverage Areas:
```
Priority 1 (Critical):
- /api/health endpoint
- /api/offers endpoint (GET)
- Database connection
- Offer listing page

Priority 2 (Important):
- Issuer listing
- Offer detail views
- Error handling
- Input validation

Priority 3 (Nice to have):
- UI component rendering
- Responsive design
- Accessibility
```

#### Deliverables:
- `.github/workflows/test.yml` - Separate test workflow
- Updated `.github/workflows/azure-deploy.yml` with test gate
- Test files in `apps/web/src/**/*.test.ts`
- Test coverage report in CI/CD

---

### 2.2 Multi-Environment Deployment Workflow
**Duration**: 2 hours

#### Tasks:
- [ ] Create environment-specific workflows:
  - [ ] `.github/workflows/deploy-dev.yml` (auto-deploy on push to `main`)
  - [ ] `.github/workflows/deploy-staging.yml` (auto-deploy on push to `staging` branch)
  - [ ] `.github/workflows/deploy-prod.yml` (manual trigger with approval)
- [ ] Set up GitHub Environments:
  - [ ] `development` - Auto-deploy
  - [ ] `staging` - Auto-deploy to staging slot
  - [ ] `production` - Requires approval from designated reviewers
- [ ] Configure environment-specific secrets:
  - [ ] `AZURE_WEBAPP_PUBLISH_PROFILE_DEV`
  - [ ] `AZURE_WEBAPP_PUBLISH_PROFILE_STAGING`
  - [ ] `AZURE_WEBAPP_PUBLISH_PROFILE_PROD`
  - [ ] `DATABASE_URL_DEV`
  - [ ] `DATABASE_URL_STAGING`
  - [ ] `DATABASE_URL_PROD`
- [ ] Add deployment approval gates for production

#### Deployment Flow:
```
┌──────────────────────────────────────────────────────────────┐
│ Developer pushes to branch                                   │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ├─ main branch ──────────────┐
                 │                            │
                 ├─ staging branch ───────────┤
                 │                            │
                 └─ Manual prod trigger ──────┤
                                              │
                                              ▼
┌──────────────────────────────────────────────────────────────┐
│ Run Tests                                                    │
│  - Unit tests                                                │
│  - Integration tests                                         │
│  - E2E tests                                                 │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ Build Application                                            │
│  - Install dependencies                                      │
│  - Generate Prisma client                                    │
│  - Build Next.js                                             │
│  - Run linter                                                │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ Deploy to Target Environment                                 │
│  - Development: Auto-deploy                                  │
│  - Staging: Auto-deploy to staging slot                      │
│  - Production: Wait for approval → Deploy → Slot swap        │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ Post-Deployment Verification                                 │
│  - Health check                                              │
│  - Smoke tests                                               │
│  - Notify team (Slack/Teams)                                 │
└──────────────────────────────────────────────────────────────┘
```

#### Deliverables:
- Three separate deployment workflows
- GitHub Environment configurations
- Approval gate for production
- Environment-specific secrets configured

---

### 2.3 Rollback Mechanism
**Duration**: 1 hour

#### Tasks:
- [ ] Implement automatic rollback on failed health checks
- [ ] Create manual rollback workflow (`.github/workflows/rollback-prod.yml`)
- [ ] Document rollback procedures
- [ ] Test rollback with intentional failure

#### Rollback Triggers:
- Health check fails after deployment
- Error rate exceeds threshold (from Application Insights)
- Manual trigger by authorized users

#### Deliverables:
- Automatic rollback logic in deployment workflow
- Manual rollback workflow
- Rollback runbook documentation

---

## Phase 3: Monitoring & Observability

### 3.1 Application Insights Configuration
**Duration**: 1-2 hours

#### Tasks:
- [ ] Configure comprehensive telemetry:
  - [ ] Custom metrics for business KPIs
  - [ ] Request tracking
  - [ ] Dependency tracking (database, external APIs)
  - [ ] Exception tracking
  - [ ] Custom events (user actions)
- [ ] Set up dashboards:
  - [ ] Application health dashboard
  - [ ] Performance metrics
  - [ ] User analytics
  - [ ] Error trends
- [ ] Create alerts:
  - [ ] 5xx errors > 5 in 5 minutes
  - [ ] Response time > 2 seconds (P95)
  - [ ] Failed requests > 10%
  - [ ] Database connection failures
  - [ ] Low availability (< 99%)

#### Custom Metrics to Track:
```javascript
// Business metrics
- Offers viewed
- Click-through rate on offers
- API response times by endpoint
- Database query performance
- Cache hit rates (if implemented)

// Technical metrics
- Node.js memory usage
- CPU utilization
- Request queue depth
- External API latency
```

#### Deliverables:
- Application Insights custom instrumentation
- 3-5 operational dashboards
- 5-10 alert rules configured
- On-call rotation configured (if applicable)

---

### 3.2 Logging Strategy
**Duration**: 1 hour

#### Tasks:
- [ ] Implement structured logging:
  - [ ] Use logging library (Winston, Pino, or Bunyan)
  - [ ] JSON formatted logs
  - [ ] Correlation IDs for request tracing
  - [ ] Log levels (error, warn, info, debug)
- [ ] Configure log retention:
  - [ ] Development: 7 days
  - [ ] Staging: 30 days
  - [ ] Production: 90 days
- [ ] Set up log queries and saved searches
- [ ] Create log-based alerts

#### Log Categories:
```
- Application logs (app)
- HTTP access logs (http)
- Database query logs (db)
- Security events (security)
- Performance traces (perf)
```

#### Deliverables:
- Structured logging implemented
- Log retention policies configured
- Key log queries documented
- Log-based alerts set up

---

### 3.3 Uptime Monitoring
**Duration**: 30 minutes

#### Tasks:
- [ ] Configure Application Insights availability tests:
  - [ ] Health endpoint monitoring (5 locations)
  - [ ] Critical page load tests
  - [ ] API endpoint tests
- [ ] Set up external monitoring (optional):
  - [ ] UptimeRobot or Pingdom
  - [ ] StatusPage.io for public status
- [ ] Configure availability alerts

#### Deliverables:
- Multi-location availability tests
- Public status page (optional)
- Availability alerts configured

---

## Phase 4: Security Hardening

### 4.1 Security Best Practices
**Duration**: 2 hours

#### Tasks:
- [ ] Implement security headers:
  ```javascript
  // next.config.js
  headers: [
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000',
    'Content-Security-Policy': '...',
    'Referrer-Policy': 'strict-origin-when-cross-origin'
  ]
  ```
- [ ] Enable rate limiting:
  - [ ] API routes: 100 requests/minute per IP
  - [ ] Authentication endpoints: 5 requests/minute
  - [ ] Use Azure App Service rate limiting or middleware
- [ ] Implement CORS policies
- [ ] Add request validation and sanitization
- [ ] Enable Azure AD authentication for admin routes (optional)
- [ ] Set up Azure Key Vault for secrets (optional)

#### Security Checklist:
- [ ] No secrets in code or environment files
- [ ] HTTPS enforced (redirect HTTP to HTTPS)
- [ ] Database connections use SSL
- [ ] Sensitive endpoints protected
- [ ] Input validation on all forms/APIs
- [ ] SQL injection protection (Prisma parameterization)
- [ ] XSS protection (React escaping + CSP)
- [ ] CSRF tokens (if using forms)

#### Deliverables:
- Security headers configured
- Rate limiting implemented
- Security audit checklist completed
- Vulnerability scan passed

---

### 4.2 Secret Management
**Duration**: 1 hour

#### Tasks:
- [ ] Audit all secrets and credentials
- [ ] Rotate production secrets:
  - [ ] Database passwords
  - [ ] API keys
  - [ ] Publish profiles
- [ ] Implement secret rotation schedule (quarterly)
- [ ] Document secret management procedures
- [ ] Consider Azure Key Vault integration:
  - [ ] Store secrets in Key Vault
  - [ ] Reference from App Service
  - [ ] Enable managed identity

#### Deliverables:
- All secrets rotated
- Secret rotation schedule documented
- Azure Key Vault configured (optional)

---

## Phase 5: Performance Optimization

### 5.1 Performance Baseline & Optimization
**Duration**: 2-3 hours

#### Tasks:
- [ ] Establish performance baselines:
  - [ ] Run Lighthouse audit (target: 90+ score)
  - [ ] Measure API response times (target: < 200ms P95)
  - [ ] Measure database query times
  - [ ] Measure page load times (target: < 2s)
- [ ] Implement optimizations:
  - [ ] Next.js Image optimization
  - [ ] Static page generation where possible
  - [ ] API response caching (Redis or in-memory)
  - [ ] Database query optimization:
    - [ ] Add indexes on frequently queried fields
    - [ ] Optimize Prisma queries (select only needed fields)
    - [ ] Connection pooling
  - [ ] Enable compression (gzip/brotli)
  - [ ] Implement CDN for static assets
- [ ] Set up performance budgets in CI/CD
- [ ] Configure auto-scaling rules:
  - [ ] Scale out when CPU > 70%
  - [ ] Scale in when CPU < 30%
  - [ ] Min instances: 1, Max instances: 5

#### Performance Targets:
```
Page Load Times:
- Homepage: < 1.5s (LCP)
- Offers page: < 2s
- API responses: < 200ms P95

Lighthouse Scores (Production):
- Performance: > 90
- Accessibility: > 95
- Best Practices: > 95
- SEO: > 90

Database:
- Query time: < 50ms P95
- Connection pool: 10-20 connections
```

#### Deliverables:
- Performance baseline report
- Optimizations implemented
- Performance monitoring dashboard
- Auto-scaling configured

---

### 5.2 Caching Strategy
**Duration**: 2 hours

#### Tasks:
- [ ] Implement caching layers:
  - [ ] Static asset caching (CDN)
  - [ ] API response caching (Redis or in-memory)
  - [ ] Database query caching (Redis)
  - [ ] Next.js page caching
- [ ] Configure cache headers:
  ```javascript
  Static assets: Cache-Control: public, max-age=31536000, immutable
  API responses: Cache-Control: public, max-age=60, s-maxage=120
  Dynamic pages: Cache-Control: private, no-cache
  ```
- [ ] Set up cache invalidation strategy
- [ ] Deploy Azure Redis Cache (optional, for production)

#### Cache Strategy:
```
Layer 1: CDN (Azure Front Door)
- Static assets (JS, CSS, images)
- TTL: 1 year

Layer 2: Application Cache (Redis or in-memory)
- API responses (offers, issuers)
- TTL: 5-60 minutes

Layer 3: Database Cache (Prisma query result cache)
- Frequently accessed data
- TTL: 1-5 minutes
```

#### Deliverables:
- Caching implemented at multiple layers
- Cache hit rate monitoring
- Cache invalidation strategy documented

---

## Phase 6: Custom Domain & SSL

### 6.1 Domain Configuration
**Duration**: 1 hour

#### Tasks:
- [ ] Purchase/configure custom domain (if not done)
- [ ] Add custom domain to Azure App Service:
  - [ ] Production: `app.mileagedealtracker.com` or custom domain
  - [ ] Staging: `staging.mileagedealtracker.com`
- [ ] Configure DNS records:
  - [ ] A record or CNAME to Azure App Service
  - [ ] TXT record for domain verification
- [ ] Enable SSL certificate:
  - [ ] Use Azure managed certificate (free)
  - [ ] Or upload custom SSL certificate
- [ ] Configure HTTPS redirect
- [ ] Update `NEXT_PUBLIC_APP_URL` to custom domain

#### Deliverables:
- Custom domain configured
- SSL certificate installed
- HTTPS enforced
- DNS records updated

---

## Phase 7: Operational Readiness

### 7.1 Documentation
**Duration**: 2-3 hours

#### Tasks:
- [ ] Create operational runbooks:
  - [ ] Deployment procedures
  - [ ] Rollback procedures
  - [ ] Incident response guide
  - [ ] Troubleshooting guide
  - [ ] Database backup/restore procedures
  - [ ] Secret rotation procedures
- [ ] Update README.md:
  - [ ] Architecture overview
  - [ ] Setup instructions
  - [ ] Development workflow
  - [ ] Deployment guide
  - [ ] Contributing guidelines
- [ ] Create architecture diagrams:
  - [ ] Infrastructure diagram
  - [ ] Deployment flow diagram
  - [ ] Data flow diagram
- [ ] Document environment variables and configurations

#### Deliverables:
- `.claude/docs/runbook-deployment.md`
- `.claude/docs/runbook-operations.md`
- `.claude/docs/runbook-troubleshooting.md`
- Updated `README.md`
- Architecture diagrams (draw.io or similar)

---

### 7.2 Backup & Disaster Recovery
**Duration**: 1-2 hours

#### Tasks:
- [ ] Configure automated database backups:
  - [ ] Daily backups at 2 AM UTC
  - [ ] 30-day retention for production
  - [ ] 7-day retention for development
- [ ] Test backup restoration process
- [ ] Configure geo-redundant storage for critical data
- [ ] Create disaster recovery plan:
  - [ ] RTO (Recovery Time Objective): < 4 hours
  - [ ] RPO (Recovery Point Objective): < 1 hour
  - [ ] Failover procedures
  - [ ] Data recovery procedures
- [ ] Document backup procedures
- [ ] Schedule quarterly DR drills

#### Deliverables:
- Automated backups configured
- Successful backup restoration test
- Disaster recovery plan documented
- DR drill scheduled

---

### 7.3 Team Onboarding & Handoff
**Duration**: 2 hours

#### Tasks:
- [ ] Create developer onboarding guide:
  - [ ] Local setup instructions
  - [ ] Codebase overview
  - [ ] Development workflow
  - [ ] Testing procedures
  - [ ] Deployment process
- [ ] Set up team access:
  - [ ] GitHub repository access
  - [ ] Azure Portal access (RBAC)
  - [ ] Application Insights access
  - [ ] On-call rotation (if applicable)
- [ ] Conduct knowledge transfer session
- [ ] Create video walkthrough (optional)

#### Deliverables:
- `.claude/docs/developer-guide.md`
- Team access configured
- Onboarding checklist
- Knowledge transfer complete

---

## Phase 8: Final Verification & Launch

### 8.1 Production Readiness Checklist
**Duration**: 1-2 hours

#### Pre-Launch Checklist:
- [ ] Infrastructure:
  - [ ] Production environment deployed
  - [ ] Staging slot configured
  - [ ] Database backups working
  - [ ] High availability enabled
  - [ ] Auto-scaling configured
- [ ] Application:
  - [ ] All tests passing (100% critical paths)
  - [ ] Performance benchmarks met
  - [ ] Security scan passed
  - [ ] Accessibility audit passed
  - [ ] SSL certificate installed
  - [ ] Custom domain configured
- [ ] Monitoring:
  - [ ] Application Insights configured
  - [ ] Alerts set up and tested
  - [ ] Dashboards created
  - [ ] On-call rotation ready
  - [ ] Uptime monitoring active
- [ ] Operations:
  - [ ] Documentation complete
  - [ ] Runbooks created
  - [ ] Team trained
  - [ ] DR plan tested
  - [ ] Backup restoration tested
- [ ] Security:
  - [ ] Secrets rotated
  - [ ] Security headers enabled
  - [ ] Rate limiting active
  - [ ] HTTPS enforced
  - [ ] Firewall rules configured

#### Deliverables:
- Completed production readiness checklist
- Sign-off from stakeholders
- Launch plan documented

---

### 8.2 Production Deployment
**Duration**: 1 hour

#### Launch Sequence:
1. [ ] Final staging deployment and verification
2. [ ] Database migration to production (if schema changes)
3. [ ] Deploy to production staging slot
4. [ ] Run smoke tests on staging slot
5. [ ] Swap staging slot to production
6. [ ] Monitor for 30 minutes:
   - [ ] Health checks passing
   - [ ] No error spikes
   - [ ] Performance within targets
7. [ ] Announce launch to team
8. [ ] Monitor for 24 hours

#### Rollback Plan (if issues):
- [ ] Swap back to previous slot
- [ ] Investigate issues
- [ ] Fix and redeploy

#### Deliverables:
- Production deployment successful
- Monitoring confirms stability
- Team notified of launch

---

## Success Metrics

### Technical Metrics:
- **Uptime**: > 99.9% (SLA)
- **Response Time**: < 200ms P95 for API, < 2s for pages
- **Error Rate**: < 0.1% of requests
- **Deployment Frequency**: Multiple times per week
- **Mean Time to Recovery (MTTR)**: < 1 hour
- **Test Coverage**: > 70% for critical paths

### Operational Metrics:
- **Deployment Success Rate**: > 95%
- **Rollback Rate**: < 5%
- **Incident Response Time**: < 15 minutes
- **Availability**: 99.9%+ uptime
- **Security Incidents**: 0

---

## Timeline & Milestones

### Week 1:
- **Days 1-2**: Phase 1 - Production Infrastructure
- **Days 3-4**: Phase 2 - Enhanced CI/CD Pipeline
- **Day 5**: Phase 3 - Monitoring & Observability

### Week 2:
- **Days 1-2**: Phase 4 - Security Hardening
- **Days 2-3**: Phase 5 - Performance Optimization
- **Day 4**: Phase 6 - Custom Domain & SSL
- **Day 5**: Phase 7 - Operational Readiness

### Week 3:
- **Day 1**: Phase 8 - Final Verification
- **Day 2**: Production Launch
- **Days 3-5**: Post-launch monitoring and optimization

---

## Budget Estimate

### Azure Resources (Monthly):
```
Development:
- App Service Plan B1: $13.14
- PostgreSQL B_Standard_B1ms: $12.41
- Application Insights: $2.88
- Storage: $0.50
Subtotal: $28.93/month

Production:
- App Service Plan S1: $69.35
- PostgreSQL GP_Standard_D2s_v3: $153.00
- Application Insights (enhanced): $20.00
- Storage (GRS): $5.00
- Azure Front Door/CDN: $25.00
- Azure Redis Cache (optional): $16.35
Subtotal: $272.35/month (without Redis)
         $288.70/month (with Redis)

Total (Dev + Prod): ~$301-$318/month
```

### Optional Add-ons:
- Custom domain: $10-15/year
- StatusPage.io: $29/month
- External monitoring: $10-20/month

---

## Risk Mitigation

### Identified Risks:
1. **Database Migration Issues**
   - Mitigation: Test on staging first, backup before migration
2. **Performance Degradation**
   - Mitigation: Load testing, gradual rollout, auto-scaling
3. **Security Vulnerabilities**
   - Mitigation: Security scans, penetration testing, bug bounty
4. **Deployment Failures**
   - Mitigation: Robust rollback, blue-green deployment, automated testing
5. **Cost Overruns**
   - Mitigation: Budget alerts, resource right-sizing, auto-shutdown dev env

---

## Post-Launch Activities

### Week 1 After Launch:
- [ ] Monitor all metrics closely
- [ ] Address any performance issues
- [ ] Collect user feedback
- [ ] Fix critical bugs immediately

### Month 1 After Launch:
- [ ] Review Application Insights data
- [ ] Optimize based on real usage patterns
- [ ] Fine-tune auto-scaling rules
- [ ] Update documentation based on learnings

### Ongoing:
- [ ] Weekly deployment to production
- [ ] Monthly security reviews
- [ ] Quarterly DR drills
- [ ] Quarterly secret rotation
- [ ] Continuous performance optimization

---

## Appendix

### A. Technology Stack
```
Frontend: Next.js 14, React 18, Tailwind CSS
Backend: Next.js API Routes, Node.js 18
Database: PostgreSQL (Azure Flexible Server)
ORM: Prisma
Hosting: Azure App Service (Linux)
CDN: Azure Front Door or Azure CDN
Caching: Azure Redis Cache (optional)
Monitoring: Application Insights
CI/CD: GitHub Actions
Version Control: GitHub
```

### B. Reference Links
- Azure App Service: https://azure.microsoft.com/en-us/services/app-service/
- Application Insights: https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview
- GitHub Actions: https://docs.github.com/en/actions
- Next.js Deployment: https://nextjs.org/docs/deployment
- Prisma Best Practices: https://www.prisma.io/docs/guides/performance-and-optimization

### C. Contact & Support
- Project Repository: https://github.com/Joseph-Jung/MileageDealTracker
- Azure Support: Azure Portal → Support
- GitHub Issues: Repository → Issues tab


#### IMPORTANT RULE TO FOLLOW #### 
Do not make code change or propose code but prepare plan document under ./.claude/plan folder. 
Use file name with 'v5-' prepix.  

---

**Document Version**: 1.0
**Created**: 2025-11-08
**Last Updated**: 2025-11-08
**Status**: Draft - Ready for Implementation
