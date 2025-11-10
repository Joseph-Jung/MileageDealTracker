# V5 Phase 6: Custom Domain & SSL Configuration - Implementation Plan

**Phase**: Custom Domain and SSL Certificate Setup
**Estimated Duration**: 1-2 hours
**Prerequisites**: Phases 1-5 Complete (Infrastructure operational)
**Status**: Planning

---

## Overview

This phase implements custom domain and SSL configuration:
- Domain registration/configuration
- DNS record setup
- Azure App Service domain binding
- SSL certificate installation (Azure-managed or custom)
- HTTPS enforcement
- Domain verification
- Multi-environment domain strategy

---

## Phase 6.1: Domain Strategy

### Step 1: Plan Domain Structure
**Duration**: 15 minutes

#### Recommended Domain Structure:
```
Production:
- app.mileagedealtracker.com (primary application)
- www.mileagedealtracker.com (redirect to app)
- api.mileagedealtracker.com (API endpoint, optional)

Staging:
- staging.mileagedealtracker.com (staging environment)

Development:
- dev.mileagedealtracker.com (development environment)

Alternative if using apex domain:
- mileagedealtracker.com (primary)
- www.mileagedealtracker.com (redirect)
- staging.mileagedealtracker.com
- dev.mileagedealtracker.com
```

#### Documentation:
File: `.claude/docs/domain-configuration.md`
```markdown
# Domain Configuration

## Domain Structure

### Production
- Primary: app.mileagedealtracker.com
- Alternate: www.mileagedealtracker.com → redirects to app
- Azure App Service: mileage-deal-tracker-prod.azurewebsites.net

### Staging
- Staging: staging.mileagedealtracker.com
- Azure Slot: mileage-deal-tracker-prod-staging.azurewebsites.net

### Development
- Development: dev.mileagedealtracker.com
- Azure App Service: mileage-deal-tracker-dev.azurewebsites.net

## SSL Certificates
- Type: Azure-managed certificates (free)
- Renewal: Automatic
- Protocol: TLS 1.2+ only

## DNS Provider
- Registrar: [Your DNS provider]
- Nameservers: [DNS nameservers]
- TTL: 3600 seconds (1 hour)
```

---

## Phase 6.2: Domain Purchase and DNS Setup

### Step 1: Purchase Domain (if needed)
**Duration**: 15 minutes

#### Option 1: Purchase through Azure App Service
```bash
# Check domain availability
az appservice domain show \
  --resource-group mileage-deal-rg-prod \
  --name mileagedealtracker.com

# Purchase domain (Note: This is optional, you can use any registrar)
az appservice domain create \
  --resource-group mileage-deal-rg-prod \
  --hostname mileagedealtracker.com \
  --contact-info @domain-contact.json \
  --accept-terms
```

#### Option 2: Use External Registrar
Popular options:
- Namecheap
- Google Domains
- GoDaddy
- Cloudflare Registrar

---

### Step 2: Configure DNS Records
**Duration**: 20 minutes

#### Required DNS Records:

**For Production (app.mileagedealtracker.com):**
```
Type: CNAME
Name: app
Value: mileage-deal-tracker-prod.azurewebsites.net
TTL: 3600

Type: TXT (for domain verification)
Name: asuid.app
Value: [Custom Domain Verification ID from Azure]
TTL: 3600
```

**For Staging (staging.mileagedealtracker.com):**
```
Type: CNAME
Name: staging
Value: mileage-deal-tracker-prod-staging.azurewebsites.net
TTL: 3600

Type: TXT
Name: asuid.staging
Value: [Staging Slot Verification ID]
TTL: 3600
```

**For Development (dev.mileagedealtracker.com):**
```
Type: CNAME
Name: dev
Value: mileage-deal-tracker-dev.azurewebsites.net
TTL: 3600

Type: TXT
Name: asuid.dev
Value: [Dev App Service Verification ID]
TTL: 3600
```

**For Root Domain (optional - apex domain):**
```
Type: A
Name: @
Value: [App Service IP Address]
TTL: 3600

Type: TXT
Name: asuid
Value: [Verification ID]
TTL: 3600
```

**For WWW Redirect:**
```
Type: CNAME
Name: www
Value: app.mileagedealtracker.com
TTL: 3600
```

---

### Step 3: Get Domain Verification IDs
**Duration**: 10 minutes

```bash
# Get verification ID for production
az webapp show \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --query customDomainVerificationId -o tsv

# Get verification ID for staging slot
az webapp deployment slot show \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --query customDomainVerificationId -o tsv

# Get verification ID for development
az webapp show \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --query customDomainVerificationId -o tsv

# Get App Service IP (if using A record for apex domain)
az webapp show \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --query possibleOutboundIpAddresses -o tsv
```

---

## Phase 6.3: Azure Custom Domain Configuration

### Step 1: Add Custom Domain to Production
**Duration**: 15 minutes

#### Using Azure Portal:
1. Navigate to App Service → Custom domains
2. Click "+ Add custom domain"
3. Enter: `app.mileagedealtracker.com`
4. Click "Validate"
5. Verify DNS records are detected
6. Click "Add"

#### Using Azure CLI:
```bash
# Add custom domain to production
az webapp config hostname add \
  --webapp-name mileage-deal-tracker-prod \
  --resource-group mileage-deal-rg-prod \
  --hostname app.mileagedealtracker.com

# Verify domain is added
az webapp config hostname list \
  --webapp-name mileage-deal-tracker-prod \
  --resource-group mileage-deal-rg-prod
```

---

### Step 2: Add Custom Domain to Staging Slot
**Duration**: 10 minutes

```bash
# Add custom domain to staging slot
az webapp config hostname add \
  --webapp-name mileage-deal-tracker-prod \
  --resource-group mileage-deal-rg-prod \
  --slot staging \
  --hostname staging.mileagedealtracker.com

# Verify
az webapp config hostname list \
  --webapp-name mileage-deal-tracker-prod \
  --resource-group mileage-deal-rg-prod \
  --slot staging
```

---

### Step 3: Add Custom Domain to Development
**Duration**: 10 minutes

```bash
# Add custom domain to development
az webapp config hostname add \
  --webapp-name mileage-deal-tracker-dev \
  --resource-group mileage-deal-rg-dev \
  --hostname dev.mileagedealtracker.com

# Verify
az webapp config hostname list \
  --webapp-name mileage-deal-tracker-dev \
  --resource-group mileage-deal-rg-dev
```

---

## Phase 6.4: SSL Certificate Configuration

### Step 1: Enable Azure-Managed Certificate (Free)
**Duration**: 15 minutes

#### Production SSL:
```bash
# Create Azure-managed certificate for production
az webapp config ssl create \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --hostname app.mileagedealtracker.com

# Bind SSL certificate
az webapp config ssl bind \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --certificate-thumbprint [THUMBPRINT] \
  --ssl-type SNI
```

#### Staging SSL:
```bash
# Create certificate for staging
az webapp config ssl create \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --hostname staging.mileagedealtracker.com

# Bind certificate
az webapp config ssl bind \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --certificate-thumbprint [THUMBPRINT] \
  --ssl-type SNI
```

#### Development SSL:
```bash
# Create certificate for development
az webapp config ssl create \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --hostname dev.mileagedealtracker.com

# Bind certificate
az webapp config ssl bind \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --certificate-thumbprint [THUMBPRINT] \
  --ssl-type SNI
```

---

### Step 2: Configure HTTPS Enforcement
**Duration**: 10 minutes

```bash
# Enable HTTPS only for production
az webapp update \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --https-only true

# Enable for staging slot
az webapp update \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --https-only true

# Enable for development
az webapp update \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --https-only true
```

---

### Step 3: Configure TLS Version
**Duration**: 5 minutes

```bash
# Set minimum TLS version to 1.2 (production)
az webapp config set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --min-tls-version 1.2

# Set for staging
az webapp config set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --min-tls-version 1.2

# Set for development
az webapp config set \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --min-tls-version 1.2
```

---

## Phase 6.5: Application Configuration Updates

### Step 1: Update Environment Variables
**Duration**: 15 minutes

```bash
# Update production URL
az webapp config appsettings set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --settings \
    NEXT_PUBLIC_APP_URL="https://app.mileagedealtracker.com" \
    NEXT_PUBLIC_API_URL="https://app.mileagedealtracker.com/api"

# Update staging URL (slot setting - doesn't swap)
az webapp config appsettings set \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --slot staging \
  --slot-settings NEXT_PUBLIC_APP_URL="https://staging.mileagedealtracker.com" \
  --settings NEXT_PUBLIC_API_URL="https://staging.mileagedealtracker.com/api"

# Update development URL
az webapp config appsettings set \
  --resource-group mileage-deal-rg-dev \
  --name mileage-deal-tracker-dev \
  --settings \
    NEXT_PUBLIC_APP_URL="https://dev.mileagedealtracker.com" \
    NEXT_PUBLIC_API_URL="https://dev.mileagedealtracker.com/api"
```

---

### Step 2: Update CORS Configuration
**Duration**: 10 minutes

File: `apps/web/src/lib/security/cors.ts` (update allowed origins)
```typescript
const allowedOrigins = [
  'https://app.mileagedealtracker.com',
  'https://www.mileagedealtracker.com',
  'https://staging.mileagedealtracker.com',
  'https://dev.mileagedealtracker.com',
  'https://mileage-deal-tracker-prod.azurewebsites.net',
  'https://mileage-deal-tracker-prod-staging.azurewebsites.net',
  'https://mileage-deal-tracker-dev.azurewebsites.net',
  process.env.NODE_ENV === 'development' ? 'http://localhost:3000' : '',
].filter(Boolean)
```

---

### Step 3: Update Security Headers
**Duration**: 5 minutes

File: `apps/web/src/lib/security/csp.ts` (update CSP)
```typescript
export function generateCSP() {
  const cspDirectives = {
    'default-src': ["'self'"],
    'script-src': [
      "'self'",
      "'unsafe-eval'",
      'https://js.monitor.azure.com',
    ],
    'connect-src': [
      "'self'",
      'https://app.mileagedealtracker.com',
      'https://staging.mileagedealtracker.com',
      'https://dc.services.visualstudio.com',
    ],
    // ... other directives
  }

  // ... rest of CSP generation
}
```

---

## Phase 6.6: Verification and Testing

### Step 1: Verify DNS Propagation
**Duration**: 15 minutes

```bash
# Check DNS resolution
nslookup app.mileagedealtracker.com
nslookup staging.mileagedealtracker.com
nslookup dev.mileagedealtracker.com

# Check from multiple locations
dig app.mileagedealtracker.com
dig staging.mileagedealtracker.com

# Verify TXT records
dig TXT asuid.app.mileagedealtracker.com
```

Online tools:
- https://dnschecker.org
- https://www.whatsmydns.net

---

### Step 2: Verify SSL Certificates
**Duration**: 10 minutes

```bash
# Check SSL certificate
openssl s_client -connect app.mileagedealtracker.com:443 -servername app.mileagedealtracker.com

# Verify certificate details
curl -vI https://app.mileagedealtracker.com
```

Online tools:
- https://www.ssllabs.com/ssltest/
- https://www.sslshopper.com/ssl-checker.html

Expected SSL Labs grade: A or A+

---

### Step 3: Test Application Functionality
**Duration**: 15 minutes

#### Manual Testing:
```bash
# Test production
curl -I https://app.mileagedealtracker.com
curl https://app.mileagedealtracker.com/api/health

# Test staging
curl -I https://staging.mileagedealtracker.com
curl https://staging.mileagedealtracker.com/api/health

# Test development
curl -I https://dev.mileagedealtracker.com
curl https://dev.mileagedealtracker.com/api/health

# Verify HTTPS redirect
curl -I http://app.mileagedealtracker.com
# Should return 301 or 308 redirect to HTTPS
```

#### Browser Testing:
1. Visit https://app.mileagedealtracker.com
2. Check for lock icon in address bar
3. Verify certificate details
4. Test all major pages
5. Check browser console for mixed content warnings
6. Test www redirect (if configured)

---

### Step 4: Update GitHub Secrets and Workflows
**Duration**: 10 minutes

Update environment URLs in workflows:

File: `.github/workflows/deploy-prod.yml`
```yaml
environment:
  name: production
  url: https://app.mileagedealtracker.com
```

File: `.github/workflows/deploy-staging.yml`
```yaml
environment:
  name: staging
  url: https://staging.mileagedealtracker.com
```

File: `.github/workflows/deploy-dev.yml`
```yaml
environment:
  name: development
  url: https://dev.mileagedealtracker.com
```

---

## Phase 6.7: Optional: Custom SSL Certificate

### Step 1: Purchase SSL Certificate
**Duration**: 30 minutes (if using custom cert)

If you prefer a custom SSL certificate over Azure-managed:

```bash
# Upload custom certificate
az webapp config ssl upload \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --certificate-file /path/to/certificate.pfx \
  --certificate-password [password]

# Get certificate thumbprint
az webapp config ssl list \
  --resource-group mileage-deal-rg-prod

# Bind certificate
az webapp config ssl bind \
  --resource-group mileage-deal-rg-prod \
  --name mileage-deal-tracker-prod \
  --certificate-thumbprint [THUMBPRINT] \
  --ssl-type SNI
```

---

## Phase 6.8: WWW Redirect Configuration

### Step 1: Configure WWW to Non-WWW Redirect
**Duration**: 15 minutes

#### Option 1: Using Azure App Service Redirect Rules
File: `apps/web/web.config` (for IIS, if applicable)
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <rewrite>
      <rules>
        <rule name="Redirect www to non-www" stopProcessing="true">
          <match url="(.*)" />
          <conditions>
            <add input="{HTTP_HOST}" pattern="^www\.mileagedealtracker\.com$" />
          </conditions>
          <action type="Redirect" url="https://app.mileagedealtracker.com/{R:1}" redirectType="Permanent" />
        </rule>
      </rules>
    </rewrite>
  </system.webServer>
</configuration>
```

#### Option 2: Using Next.js Middleware
File: `apps/web/src/middleware.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'

export function middleware(req: NextRequest) {
  const hostname = req.headers.get('host')

  // Redirect www to non-www
  if (hostname === 'www.mileagedealtracker.com') {
    return NextResponse.redirect(
      `https://app.mileagedealtracker.com${req.nextUrl.pathname}${req.nextUrl.search}`,
      { status: 308 } // Permanent redirect
    )
  }

  return NextResponse.next()
}
```

---

## Validation Checklist

After implementation, verify:
- [ ] Custom domain purchased/configured
- [ ] DNS records created and propagated
- [ ] Domain verification TXT records added
- [ ] Custom domain added to all environments
- [ ] SSL certificates installed (Azure-managed or custom)
- [ ] HTTPS enforced on all environments
- [ ] TLS 1.2+ enforced
- [ ] Application environment variables updated
- [ ] CORS configuration updated with new domains
- [ ] CSP updated with new domains
- [ ] DNS propagation verified globally
- [ ] SSL certificate valid and A+ rated
- [ ] Application functional on custom domain
- [ ] HTTP to HTTPS redirect working
- [ ] WWW redirect configured (if applicable)
- [ ] GitHub workflows updated with new URLs
- [ ] No mixed content warnings
- [ ] All API endpoints accessible

---

## Time Estimates

| Task | Estimated Time |
|------|----------------|
| Domain strategy planning | 15 min |
| DNS configuration | 20 min |
| Get verification IDs | 10 min |
| Add custom domain (prod) | 15 min |
| Add custom domain (staging) | 10 min |
| Add custom domain (dev) | 10 min |
| Enable SSL certificates | 15 min |
| HTTPS enforcement | 10 min |
| TLS configuration | 5 min |
| Update environment variables | 15 min |
| Update CORS | 10 min |
| Update CSP | 5 min |
| Verify DNS propagation | 15 min |
| Verify SSL certificates | 10 min |
| Test functionality | 15 min |
| Update GitHub workflows | 10 min |
| WWW redirect setup | 15 min |
| **Total** | **~3 hours** |

---

## Rollback Procedures

### If Custom Domain Not Working:
1. Verify DNS records are correct
2. Wait for DNS propagation (up to 48 hours)
3. Check domain verification status in Azure
4. Temporarily use .azurewebsites.net URLs

### If SSL Certificate Issues:
1. Remove SSL binding
2. Delete and recreate certificate
3. Verify domain ownership
4. Check certificate expiration date

### If Application Not Accessible:
1. Verify app service is running
2. Check DNS resolution
3. Test with .azurewebsites.net URL
4. Review application logs
5. Verify firewall rules

---

## Monitoring and Maintenance

### Certificate Renewal:
- Azure-managed certificates: Auto-renewed automatically
- Custom certificates: Set calendar reminder 30 days before expiration

### DNS Monitoring:
- Set up uptime monitoring for custom domain
- Monitor DNS resolution from multiple locations
- Check SSL certificate expiration monthly

---

## Next Steps

After Phase 6 completion:
1. Proceed to Phase 7: Operational Readiness
2. Create comprehensive documentation
3. Set up backup and disaster recovery
4. Prepare team onboarding materials

---

**Plan Created**: 2025-11-08
**Status**: Ready for Implementation
**Estimated Time**: 1-2 hours
