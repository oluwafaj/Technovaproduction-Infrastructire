# Microsoft Defender for Cloud - Free tier (CSPM)

resource "azurerm_security_center_subscription_pricing" "vm" {
  tier          = "Free"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Free"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "keyvault" {
  tier          = "Free"
  resource_type = "KeyVaults"
}