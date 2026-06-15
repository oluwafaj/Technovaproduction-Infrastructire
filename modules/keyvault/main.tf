resource "azurerm_key_vault" "technova-kv" {
  resource_group_name        = var.resource_group_name
  name                       = var.keyvault_name
  location                   = var.location
  tenant_id                  = var.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = 90
  tags                       = var.tags
  enable_rbac_authorization  = true

  access_policy {
    tenant_id = var.tenant_id
    object_id = var.object_id
    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]
  }
}

resource "random_password" "vm-admin-password" {
  length           = 16
  special          = true
  override_special = "!-_="
}

resource "azurerm_key_vault_secret" "vm-admin-password" {
  name         = "vm-admin-password"
  value        = random_password.vm-admin-password.result
  key_vault_id = azurerm_key_vault.technova-kv.id
  tags         = var.tags
}