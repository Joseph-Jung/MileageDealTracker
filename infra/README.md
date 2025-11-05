# Infrastructure Documentation

This directory contains all infrastructure-as-code (IaC) and deployment configurations for the Mileage Deal Tracker application.

## Directory Structure

```
infra/
├── terraform/          # Terraform infrastructure definitions
│   ├── main.tf        # Main resource definitions
│   ├── variables.tf   # Input variables
│   ├── outputs.tf     # Output values
│   ├── terraform.tfvars.dev   # Dev environment variables
│   └── terraform.tfvars.prod  # Prod environment variables
├── scripts/           # Deployment and maintenance scripts
│   ├── deploy-db-migrations.sh  # Database migration script
│   ├── seed-production.sh       # Production data seeding
│   ├── backup-database.sh       # Database backup utility
│   └── health-check.sh          # Application health check
└── README.md          # This file
```

## Azure Resources

The Terraform configuration provisions the following Azure resources:

### Core Resources
- **Resource Group**: Container for all Azure resources
- **App Service Plan**: Compute resources for web app (Linux, Node.js 18)
- **Web App**: Next.js application hosting
- **PostgreSQL Flexible Server**: Database instance
- **Application Insights**: Monitoring and logging
- **Storage Account**: For backups and snapshots

### Environments

| Environment | Branch | Resource Group         | App Service                  |
|-------------|--------|------------------------|------------------------------|
| Development | `dev`  | `mileage-deal-rg-dev`  | `mileage-deal-tracker-dev`   |
| Production  | `main` | `mileage-deal-rg`      | `mileage-deal-tracker`       |

## Prerequisites

### Required Tools
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.40.0
- [Node.js](https://nodejs.org/) >= 18.x
- [PostgreSQL client tools](https://www.postgresql.org/download/) (for pg_dump)

### Azure Setup
1. Log in to Azure CLI:
   ```bash
   az login
   ```

2. Set your subscription:
   ```bash
   az account set --subscription "your-subscription-id"
   ```

3. Create service principal for Terraform (if needed):
   ```bash
   az ad sp create-for-rbac --name "terraform-mileage-tracker" --role="Contributor"
   ```

## Terraform Deployment

### Initial Setup

1. **Initialize Terraform**:
   ```bash
   cd infra/terraform
   terraform init
   ```

2. **Create `terraform.tfvars`** (copy from template):
   ```bash
   cp terraform.tfvars.dev terraform.tfvars
   ```

3. **Update `terraform.tfvars`** with your values:
   ```hcl
   db_admin_password = "your-secure-password"
   allowed_ip_address = "your-ip-address"  # Optional
   ```

### Deploy Infrastructure

1. **Plan the deployment**:
   ```bash
   terraform plan -out=tfplan
   ```

2. **Review the plan** and verify resources

3. **Apply the plan**:
   ```bash
   terraform apply tfplan
   ```

4. **Save outputs**:
   ```bash
   terraform output > outputs.txt
   ```

### Environment-Specific Deployments

**Development**:
```bash
terraform workspace new dev  # First time only
terraform workspace select dev
terraform plan -var-file="terraform.tfvars.dev" -out=tfplan
terraform apply tfplan
```

**Production**:
```bash
terraform workspace new prod  # First time only
terraform workspace select prod
terraform plan -var-file="terraform.tfvars.prod" -out=tfplan
terraform apply tfplan
```

## Database Management

### Run Migrations

```bash
export DATABASE_URL="postgresql://username:password@host:5432/database?sslmode=require"
./scripts/deploy-db-migrations.sh prod
```

### Seed Production Database

```bash
export DATABASE_URL="postgresql://username:password@host:5432/database?sslmode=require"
./scripts/seed-production.sh
```

### Backup Database

```bash
export DATABASE_URL="postgresql://username:password@host:5432/database?sslmode=require"
./scripts/backup-database.sh prod
```

Backups are saved to `backups/` directory and optionally uploaded to Azure Blob Storage.

## Application Deployment

### Via Azure Pipeline

The `.azure-pipelines/azure-pipelines.yml` file defines the CI/CD pipeline:

1. **Trigger**: Automatically runs on push to `main` or `dev` branches
2. **Build**: Installs dependencies, generates Prisma client, builds Next.js app
3. **Deploy**: Deploys to appropriate environment based on branch
4. **Migrations**: Runs database migrations after production deployment

### Manual Deployment

```bash
cd apps/web
npm install
npm run build

# Deploy using Azure CLI
az webapp deployment source config-zip \
  --resource-group mileage-deal-rg \
  --name mileage-deal-tracker \
  --src ./build.zip
```

## Health Checks

Run the health check script to verify deployment:

```bash
./scripts/health-check.sh prod
```

This checks:
- HTTP connectivity
- API health endpoint (`/api/health`)
- Offers endpoint (`/api/offers`)
- Database connection (if `DATABASE_URL` is set)

## Configuration

### Environment Variables

Required environment variables for the application:

| Variable                | Description                      | Example                                      |
|-------------------------|----------------------------------|----------------------------------------------|
| `DATABASE_URL`          | PostgreSQL connection string     | `postgresql://user:pass@host:5432/db?ssl=require` |
| `NEXT_PUBLIC_APP_URL`   | Public URL of the application    | `https://mileage-deal-tracker.azurewebsites.net` |
| `NODE_ENV`              | Node environment                 | `production` or `development`                |

Set these in Azure Portal:
1. Go to App Service → Configuration → Application settings
2. Add each environment variable
3. Save and restart the app

### Secrets Management

Sensitive values should be stored in:
- **Azure Key Vault** (recommended for production)
- **Azure DevOps Library** (for pipeline variables)
- **Local `.env` file** (for local development only)

Never commit secrets to version control!

## Monitoring

### Application Insights

View logs and metrics in Azure Portal:
1. Go to Application Insights resource
2. Navigate to:
   - **Failures**: Exception tracking
   - **Performance**: Response times
   - **Live Metrics**: Real-time monitoring

### Query Logs

```bash
az monitor app-insights query \
  --app mileage-deal-tracker-insights-prod \
  --analytics-query "requests | take 10"
```

## Cost Management

### Estimated Monthly Costs (Phase 1)

| Resource                      | SKU               | Cost (USD) |
|-------------------------------|-------------------|------------|
| App Service Plan              | B1 (Basic)        | $13.14     |
| PostgreSQL Flexible Server    | B_Standard_B1ms   | $12.41     |
| Storage Account               | Standard LRS      | $0.50      |
| Application Insights          | Basic             | $2.88      |
| **Total**                     |                   | **~$43/mo**|

### Cost Optimization Tips

1. **Scale down when not in use** (dev environments)
   ```bash
   az appservice plan update --name mileage-deal-plan-dev --sku FREE
   ```

2. **Use Reserved Instances** for production (save up to 72%)

3. **Set up auto-scaling** based on metrics

4. **Enable cost alerts** in Azure Portal

## Troubleshooting

### Common Issues

**1. Terraform state lock**
```bash
# Force unlock (use carefully!)
terraform force-unlock <lock-id>
```

**2. Database connection timeout**
- Verify firewall rules in Azure Portal
- Check `allowed_ip_address` in Terraform
- Ensure `?sslmode=require` is in connection string

**3. App Service won't start**
```bash
# View logs
az webapp log tail --name mileage-deal-tracker --resource-group mileage-deal-rg

# Check environment variables
az webapp config appsettings list --name mileage-deal-tracker --resource-group mileage-deal-rg
```

**4. Prisma Client not generated**
```bash
# Rebuild with postinstall hook
npm install --production=false
```

## Rollback Procedures

### Application Rollback

1. **Via Azure Portal**:
   - Go to App Service → Deployment Center
   - Select previous deployment
   - Click "Redeploy"

2. **Via Azure CLI**:
   ```bash
   az webapp deployment list --name mileage-deal-tracker --resource-group mileage-deal-rg
   az webapp deployment redeploy --name mileage-deal-tracker --resource-group mileage-deal-rg --deployment-id <id>
   ```

### Database Rollback

```bash
# Restore from backup
psql $DATABASE_URL < backups/mileage_tracker_prod_20250105_120000.sql
```

### Infrastructure Rollback

```bash
terraform workspace select prod
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

## Security Best Practices

1. **Use Managed Identity** for Azure resources
2. **Enable SSL** for database connections
3. **Restrict database firewall** to known IPs only
4. **Rotate secrets** regularly
5. **Enable Azure Security Center**
6. **Review access logs** periodically

## Support

- **Infrastructure Issues**: Check Terraform state and Azure Portal
- **Application Issues**: Check Application Insights logs
- **Database Issues**: Check PostgreSQL logs in Azure Portal
- **Pipeline Issues**: Check Azure DevOps build logs

## References

- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/postgresql/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [Prisma Deployment](https://www.prisma.io/docs/guides/deployment)
