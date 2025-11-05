variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region for resources"
  default     = "East US"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "app_name" {
  type        = string
  description = "Base name for the application"
  default     = "mileage-deal-tracker"
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name"
  default     = "mileage_tracker"
}

variable "db_admin_username" {
  type        = string
  description = "PostgreSQL administrator username"
  default     = "dbadmin"
}

variable "db_admin_password" {
  type        = string
  description = "PostgreSQL administrator password"
  sensitive   = true
}

variable "db_storage_mb" {
  type        = number
  description = "PostgreSQL storage in MB"
  default     = 32768
}

variable "db_sku_name" {
  type        = string
  description = "PostgreSQL SKU name"
  default     = "B_Standard_B1ms"

  validation {
    condition     = can(regex("^(B_Standard_B1ms|B_Standard_B2s|GP_Standard_D2s_v3)$", var.db_sku_name))
    error_message = "db_sku_name must be a valid PostgreSQL Flexible Server SKU."
  }
}

variable "app_service_sku" {
  type        = string
  description = "App Service plan SKU"
  default     = "B1"

  validation {
    condition     = can(regex("^(B1|B2|S1|P1v2|P1v3)$", var.app_service_sku))
    error_message = "app_service_sku must be a valid App Service SKU."
  }
}

variable "allowed_ip_address" {
  type        = string
  description = "IP address to allow access to PostgreSQL (optional)"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
