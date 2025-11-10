terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "prod" {
  name     = "mileage-deal-rg-prod"
  location = var.location

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
    Project     = "MileageDealTracker"
  }
}

# App Service Plan - S1 required for deployment slots
resource "azurerm_service_plan" "prod" {
  name                = "mileage-deal-tracker-plan-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
  os_type             = "Linux"
  sku_name            = "S1"

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Auto-scaling for App Service Plan
resource "azurerm_monitor_autoscale_setting" "prod_app" {
  name                = "app-autoscale-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
  target_resource_id  = azurerm_service_plan.prod.id

  profile {
    name = "default"

    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.prod.id
        operator           = "GreaterThan"
        threshold          = 70
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.prod.id
        operator           = "LessThan"
        threshold          = 30
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# PostgreSQL Flexible Server with High Availability
resource "azurerm_postgresql_flexible_server" "prod" {
  name                   = "mileage-deal-tracker-db-prod"
  resource_group_name    = azurerm_resource_group.prod.name
  location               = azurerm_resource_group.prod.location
  version                = "14"
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password

  sku_name   = "GP_Standard_D2s_v3"
  storage_mb = 32768

  backup_retention_days        = 35
  geo_redundant_backup_enabled = false

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "prod" {
  name      = "mileage_tracker_prod"
  server_id = azurerm_postgresql_flexible_server.prod.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Firewall Rules
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.prod.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "office" {
  count            = var.office_ip != "" ? 1 : 0
  name             = "AllowOfficeIP"
  server_id        = azurerm_postgresql_flexible_server.prod.id
  start_ip_address = var.office_ip
  end_ip_address   = var.office_ip
}

# Storage Account - Geo-Redundant
resource "azurerm_storage_account" "prod" {
  name                     = "mileagedealtrackerstprod"
  resource_group_name      = azurerm_resource_group.prod.name
  location                 = azurerm_resource_group.prod.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Storage Containers
resource "azurerm_storage_container" "database_backups" {
  name                  = "database-backups"
  storage_account_name  = azurerm_storage_account.prod.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "offer_snapshots" {
  name                  = "offer-snapshots"
  storage_account_name  = azurerm_storage_account.prod.name
  container_access_type = "private"
}

# Application Insights
resource "azurerm_application_insights" "prod" {
  name                = "mileage-deal-tracker-insights-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
  application_type    = "Node.JS"

  retention_in_days = 90

  daily_data_cap_in_gb                  = 10
  daily_data_cap_notifications_disabled = false

  sampling_percentage = 100

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Linux Web App - Production
resource "azurerm_linux_web_app" "prod" {
  name                = "mileage-deal-tracker-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
  service_plan_id     = azurerm_service_plan.prod.id

  site_config {
    always_on = true

    application_stack {
      node_version = "20-lts"
    }

    app_command_line = "npm start"
  }

  app_settings = {
    "NODE_ENV"                              = "production"
    "WEBSITE_NODE_DEFAULT_VERSION"          = "18-lts"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"        = "true"
    "WEBSITE_RUN_FROM_PACKAGE"              = "0"
    "DATABASE_URL"                          = "postgresql://${var.db_admin_username}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.prod.fqdn}:5432/${azurerm_postgresql_flexible_server_database.prod.name}?sslmode=require"
    "NEXT_PUBLIC_APP_URL"                   = "https://mileage-deal-tracker-prod.azurewebsites.net"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.prod.connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 30
        retention_in_mb   = 100
      }
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Staging Deployment Slot
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.prod.id

  site_config {
    always_on = true

    application_stack {
      node_version = "20-lts"
    }

    app_command_line = "npm start"
  }

  app_settings = {
    "NODE_ENV"                              = "staging"
    "WEBSITE_NODE_DEFAULT_VERSION"          = "18-lts"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"        = "true"
    "WEBSITE_RUN_FROM_PACKAGE"              = "0"
    "DATABASE_URL"                          = var.staging_database_url
    "NEXT_PUBLIC_APP_URL"                   = "https://mileage-deal-tracker-prod-staging.azurewebsites.net"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.prod.connection_string
  }

  tags = {
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}
