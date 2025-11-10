variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West US 2"
}

variable "db_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "dbadmin"
}

variable "db_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "office_ip" {
  description = "Office IP address for database firewall (optional)"
  type        = string
  default     = ""
}

variable "staging_database_url" {
  description = "Database URL for staging slot (can be same as prod or separate staging database)"
  type        = string
  sensitive   = true
}
