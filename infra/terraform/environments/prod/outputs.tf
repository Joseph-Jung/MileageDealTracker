output "resource_group_name" {
  description = "The name of the production resource group"
  value       = azurerm_resource_group.prod.name
}

output "app_service_name" {
  description = "The name of the production App Service"
  value       = azurerm_linux_web_app.prod.name
}

output "app_service_url" {
  description = "The URL of the production application"
  value       = "https://${azurerm_linux_web_app.prod.default_hostname}"
}

output "staging_slot_url" {
  description = "The URL of the staging deployment slot"
  value       = "https://${azurerm_linux_web_app.prod.name}-staging.azurewebsites.net"
}

output "database_fqdn" {
  description = "The FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.prod.fqdn
}

output "database_name" {
  description = "The name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.prod.name
}

output "database_connection_string" {
  description = "The PostgreSQL connection string"
  value       = "postgresql://${var.db_admin_username}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.prod.fqdn}:5432/${azurerm_postgresql_flexible_server_database.prod.name}?sslmode=require"
  sensitive   = true
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.prod.name
}

output "storage_account_primary_key" {
  description = "The primary access key for the storage account"
  value       = azurerm_storage_account.prod.primary_access_key
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  description = "The instrumentation key for Application Insights"
  value       = azurerm_application_insights.prod.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "The connection string for Application Insights"
  value       = azurerm_application_insights.prod.connection_string
  sensitive   = true
}

output "app_service_plan_name" {
  description = "The name of the App Service Plan"
  value       = azurerm_service_plan.prod.name
}

output "app_service_plan_sku" {
  description = "The SKU of the App Service Plan"
  value       = azurerm_service_plan.prod.sku_name
}
