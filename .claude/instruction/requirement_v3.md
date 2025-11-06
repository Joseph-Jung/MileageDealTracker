
## 7. Deployment Instructions

### 7.1 Prerequisites

Install required tools:

```bash
# Azure CLI
brew install azure-cli

# Terraform
brew install terraform

# PostgreSQL client (for backups)
brew install postgresql@14
```

### 7.2 Azure Setup (First Time Only)

```bash
# 1. Login to Azure
az login

# 2. Set your subscription
az account set --subscription "your-subscription-id"

# 3. Create service principal for Terraform
az ad sp create-for-rbac --name "terraform-mileage-tracker" --role="Contributor"

# 4. Save the output credentials (you'll need them for Terraform)
```

### 7.3 Terraform Deployment

```bash
# 1. Navigate to Terraform directory
cd infra/terraform

# 2. Initialize Terraform
terraform init

# 3. Create terraform.tfvars with your values
cat > terraform.tfvars << EOF
environment         = "prod"
resource_group_name = "mileage-deal-rg"
db_admin_password   = "YourSecurePassword123!"
allowed_ip_address  = "$(curl -s ifconfig.me)"
EOF

# 4. Plan deployment
terraform plan -out=tfplan

# 5. Review the plan, then apply
terraform apply tfplan

# 6. Save outputs
terraform output > outputs.txt
terraform output -json > outputs.json
```

### 7.4 Database Setup

```bash
# 1. Get DATABASE_URL from Terraform outputs
export DATABASE_URL=$(terraform output -raw database_connection_string | sed "s/\*\*\*/$DB_PASSWORD/")

# 2. Run migrations
cd ../..
./infra/scripts/deploy-db-migrations.sh prod

# 3. Seed database (optional)
./infra/scripts/seed-production.sh
```

### 7.5 Azure DevOps Pipeline Setup

1. **Create Azure DevOps Project**:
   - Go to https://dev.azure.com
   - Create new project: "MileageDealTracker"

2. **Create Service Connection**:
   - Project Settings → Service connections
   - New service connection → Azure Resource Manager
   - Name: `Azure-Service-Connection`

3. **Create Pipeline**:
   - Pipelines → New pipeline
   - Select: GitHub (connect to your repo)
   - Existing Azure Pipelines YAML file
   - Path: `/.azure-pipelines/azure-pipelines.yml`

4. **Configure Variables**:
   - Pipelines → Library → Variable groups
   - Create group: `mileage-tracker-vars`
   - Add variables:
     - `DEV_DATABASE_URL` (secret)
     - `DEV_APP_URL`
     - `PROD_DATABASE_URL` (secret)
     - `PROD_APP_URL`

5. **Run Pipeline**:
   - Save and run
   - Monitor deployment

### 7.6 Post-Deployment

```bash
# 1. Verify deployment
./infra/scripts/health-check.sh prod

# 2. Create initial backup
./infra/scripts/backup-database.sh prod

# 3. Monitor Application Insights
az monitor app-insights query \
  --app mileage-deal-tracker-insights-prod \
  --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode"
```

#### IMPORTANT RULE TO FOLLOW #### 
Do not make code change or propose code but prepare plan document under ./.claude/plan folder. 
Use file name with 'v3-' prepix.  