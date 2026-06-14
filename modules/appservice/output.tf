output "app_service_url" {
  value = azurerm_linux_web_app.app.default_hostname
}

output "app_service_id" {
  value = azurerm_linux_web_app.app.id
}

output "app_service_plan_id" {
  value = azurerm_service_plan.plan.id
}