# Output values for each resource group deployment

output "resource_group_info" {
  description = "Resource group information"
  value = {
    name     = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    id       = azurerm_resource_group.main.id
    index    = var.resource_group_index
  }
}

output "app_service_plans" {
  description = "App Service Plans information"
  value = [
    for asp in azurerm_service_plan.asp : {
      name = asp.name
      id   = asp.id
      sku  = asp.sku_name
    }
  ]
}

output "web_apps" {
  description = "Web Apps information"
  value = [
    for webapp in azurerm_linux_web_app.webapp : {
      name         = webapp.name
      id          = webapp.id
      default_url = "https://${webapp.default_hostname}"
      asp_id      = webapp.service_plan_id
    }
  ]
}

output "application_insights" {
  description = "Application Insights information"
  value = var.enable_application_insights ? {
    name                = azurerm_application_insights.main[0].name
    instrumentation_key = azurerm_application_insights.main[0].instrumentation_key
    app_id             = azurerm_application_insights.main[0].app_id
  } : null
  sensitive = true
}

output "deployment_summary" {
  description = "Deployment summary for this resource group"
  value = {
    resource_group_index = var.resource_group_index
    region              = local.selected_region
    total_web_apps      = length(azurerm_linux_web_app.webapp)
    total_asp           = length(azurerm_service_plan.asp)
    web_apps_per_asp    = 10
  }
}
