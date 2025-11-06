terraform {
  required_version = ">=1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.100.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "mileagetfstate"
    container_name       = "tfstate"
    key                  = "mileage-tracker.tfstate"
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
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "MileageDealTracker"
    ManagedBy   = "Terraform"
  }
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "db" {
  name                = "${var.app_name}-db-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password

  version        = "14"
  storage_mb     = var.db_storage_mb
  sku_name       = var.db_sku_name

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = {
    Environment = var.environment
    Project     = "MileageDealTracker"
  }
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "main_db" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# PostgreSQL Firewall Rule - Allow Azure Services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# PostgreSQL Firewall Rule - Allow specific IP (optional)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_office_ip" {
  count            = var.allowed_ip_address != "" ? 1 : 0
  name             = "AllowOfficeIP"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = var.allowed_ip_address
  end_ip_address   = var.allowed_ip_address
}

# App Service Plan
resource "azurerm_service_plan" "plan" {
  name                = "${var.app_name}-plan-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type  = "Linux"
  sku_name = var.app_service_sku

  tags = {
    Environment = var.environment
    Project     = "MileageDealTracker"
  }
}

# Linux Web App
resource "azurerm_linux_web_app" "app" {
  name                = "${var.app_name}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  https_only = true

  site_config {
    always_on = var.environment == "prod" ? true : false

    application_stack {
      node_version = "18-lts"
    }

    app_command_line = "node server.js"

    health_check_path = "/api/health"
  }

  app_settings = {
    "DATABASE_URL"          = "postgresql://${var.db_admin_username}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.db.fqdn}:5432/${var.db_name}?sslmode=require"
    "NEXT_PUBLIC_APP_URL"   = "https://${var.app_name}-${var.environment}.azurewebsites.net"
    "NODE_ENV"              = var.environment == "prod" ? "production" : "development"
    "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = "MileageDealTracker"
  }
}

# Application Insights
resource "azurerm_application_insights" "insights" {
  name                = "${var.app_name}-insights-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "Node.JS"

  tags = {
    Environment = var.environment
    Project     = "MileageDealTracker"
  }
}

# Storage Account (for future use - screenshots, backups)
resource "azurerm_storage_account" "storage" {
  name                     = "${replace(var.app_name, "-", "")}st${var.environment}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    Environment = var.environment
    Project     = "MileageDealTracker"
  }
}

# Storage Container for backups
resource "azurerm_storage_container" "backups" {
  name                  = "database-backups"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# Storage Container for offer snapshots
resource "azurerm_storage_container" "snapshots" {
  name                  = "offer-snapshots"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}
