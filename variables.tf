# Variables definition file

variable "resource_group_index" {
  description = "Index of the resource group (1-100)"
  type        = number
  validation {
    condition     = var.resource_group_index >= 1 && var.resource_group_index <= 100
    error_message = "Resource group index must be between 1 and 100."
  }
}

variable "base_name" {
  description = "Base name for all resources"
  type        = string
  default     = "webapp-deployment"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.base_name)) && length(var.base_name) <= 20
    error_message = "Base name must contain only lowercase letters, numbers, and hyphens, and be 20 characters or less."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, staging, prod."
  }
}

variable "regions" {
  description = "List of Azure regions for deployment"
  type        = list(string)
  default = [
    "Central India",  # Primary region for deployment
    "East US 2",      # Secondary region with good quota
    #"East US",        # 100 vCPU quota
    #"West US 2",      # 100 vCPU quota 
    #"Central US",     # 100 vCPU quota
    #"North Europe",   # 100 vCPU quota
    #"West Europe",    # 100 vCPU quota
    #"Southeast Asia", # 100 vCPU quota
    #"Japan East",     # Unknown quota
    #"Australia East"  # Unknown quota
  ]
  
  validation {
    condition     = length(var.regions) > 0
    error_message = "At least one region must be specified."
  }
}

variable "app_service_sku" {
  description = "SKU for App Service Plans"
  type        = string
  default     = "B1"
  
  validation {
    condition     = contains(["F1", "D1", "B1", "B2", "B3", "S1", "S2", "S3", "P1V2", "P2V2", "P3V2"], var.app_service_sku)
    error_message = "App Service SKU must be a valid Azure App Service plan SKU."
  }
}

variable "node_version" {
  description = "Node.js version for web apps"
  type        = string
  default     = "18-lts"
  
  validation {
    condition     = contains(["14-lts", "16-lts", "18-lts", "20-lts"], var.node_version)
    error_message = "Node version must be a supported LTS version."
  }
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Project     = "WebApp-Mass-Deployment"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

variable "enable_application_insights" {
  description = "Enable Application Insights for monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention in days for Log Analytics workspace"
  type        = number
  default     = 30
  
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 30 and 730."
  }
}
