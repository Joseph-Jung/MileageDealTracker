output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.rg.location
}

output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.app.name
}

output "app_service_url" {
  description = "URL of the deployed application"
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "app_service_plan_id" {
  description = "ID of the App Service Plan"
  value       = azurerm_service_plan.plan.id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.db.name
}

output "postgresql_server_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.db.fqdn
}

output "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.main_db.name
}

output "database_connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${var.db_admin_username}:***@${azurerm_postgresql_flexible_server.db.fqdn}:5432/${var.db_name}?sslmode=require"
  sensitive   = false
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.insights.connection_string
  sensitive   = true
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.storage.name
}

output "storage_account_primary_connection_string" {
  description = "Primary connection string for the storage account"
  value       = azurerm_storage_account.storage.primary_connection_string
  sensitive   = true
}

output "backup_container_name" {
  description = "Name of the backup storage container"
  value       = azurerm_storage_container.backups.name
}

output "snapshot_container_name" {
  description = "Name of the snapshot storage container"
  value       = azurerm_storage_container.snapshots.name
}
