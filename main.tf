# Main Terraform configuration for 2000 Web Apps deployment
# Architecture: 100 RGs, 2 ASPs per RG, 10 Web Apps per ASP
# Distributed across multiple regions with separate state files

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  # Using local state - no backend configuration needed
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Variables are defined in variables.tf

# Calculate region for this RG (distribute RGs across regions)
locals {
  region_index = (var.resource_group_index - 1) % length(var.regions)
  selected_region = var.regions[local.region_index]
  
  # Resource naming with index
  rg_name = "${var.base_name}-rg-${format("%03d", var.resource_group_index)}"
  
  # App Service Plan names
  asp_names = [
    "${var.base_name}-asp-${format("%03d", var.resource_group_index)}-01",
    "${var.base_name}-asp-${format("%03d", var.resource_group_index)}-02"
  ]
  
  # Generate all web app names for this RG
  web_app_names = [
    for asp_index in range(2) : [
      for app_index in range(10) : 
      "${var.base_name}-wa-${format("%03d", var.resource_group_index)}-${format("%02d", asp_index + 1)}-${format("%02d", app_index + 1)}"
    ]
  ]
  
  # Flatten web app names
  all_web_app_names = flatten(local.web_app_names)
}

# Random string for unique naming
resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = local.selected_region
  
  tags = merge(var.tags, {
    Region = local.selected_region
    RGIndex = var.resource_group_index
  })
}

# App Service Plans (2 per RG)
resource "azurerm_service_plan" "asp" {
  count               = 2
  name                = "${local.asp_names[count.index]}-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  
  os_type  = "Linux"
  sku_name = var.app_service_sku
  
  tags = merge(var.tags, {
    ASPIndex = count.index + 1
    RGIndex  = var.resource_group_index
  })
}

# Web Apps (10 per ASP, 20 total per RG)
resource "azurerm_linux_web_app" "webapp" {
  count               = 20
  name                = "${local.all_web_app_names[count.index]}-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.asp[floor(count.index / 10)].id
  
  site_config {
    application_stack {
      node_version = var.node_version
    }
    
    # Basic security and performance settings
    always_on         = false  # Cost optimization for B1 tier
    http2_enabled     = true
    ftps_state        = "FtpsOnly"
    
    # CORS configuration
    cors {
      allowed_origins = ["*"]
    }
  }
  
  # App settings - conditionally include Application Insights
  app_settings = var.enable_application_insights ? {
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main[0].instrumentation_key
  } : {
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }
  
  # HTTPS only
  https_only = true
  
  tags = merge(var.tags, {
    ASPIndex = floor(count.index / 10) + 1
    AppIndex = (count.index % 10) + 1
    RGIndex  = var.resource_group_index
  })
  
  # Identity for managed authentication
  identity {
    type = "SystemAssigned"
  }
}

# Application Insights for monitoring (conditional)
resource "azurerm_application_insights" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "${var.base_name}-ai-${format("%03d", var.resource_group_index)}-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
  
  tags = merge(var.tags, {
    RGIndex = var.resource_group_index
  })
}

# Log Analytics Workspace for centralized logging
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.base_name}-law-${format("%03d", var.resource_group_index)}-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  
  tags = merge(var.tags, {
    RGIndex = var.resource_group_index
  })
}
