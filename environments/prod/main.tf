locals {
  common_tags = {
    Environment = "Production"
    Department  = "IT"
    Owner       = "Admin"
  }
}

module "keyvault" {
  source = "../../modules/keyvault" # points to the module folder

  keyvault_name       = var.keyvault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.object_id
  sku_name            = var.sku_name
  tags                = local.common_tags
}

module "networking" {
  source              = "../../modules/networking"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = "technovaprod-vnet"
  nsg_name            = "technovaprod-nsg"

  subnets = {
    "web" = { address_prefixes = ["10.0.1.0/24"] }
    "app" = { address_prefixes = ["10.0.2.0/24"] }
    "db"  = { address_prefixes = ["10.0.3.0/24"] }
  }
  tags = local.common_tags
}


module "compute" {
  source              = "../../modules/compute"
  resource_group_name = var.resource_group_name
  location            = var.location
  vm_name             = "technovaprod-vm"
  admin_username      = "adminuserprod"
  admin_password      = module.keyvault.admin_password
  subnet_id           = module.networking.subnet_ids["web"]
  tags                = local.common_tags
}

module "appservice" {
  source                = "../../modules/appservice"
  resource_group_name   = var.resource_group_name
  location              = var.location
  app_service_plan_name = "technovaprod-plan"
  app_service_name      = "technovaprod-app"
  sku_name              = "S1"
  runtime_stack         = "NODE|18-lts"
  tags                  = local.common_tags
}

module "storage" {
  source                           = "../../modules/storage"
  resource_group_name              = var.resource_group_name
  location                         = var.location
  storage_account_name             = var.storage_account_name
  storage_account_tier             = var.storage_account_tier
  storage_account_replication_type = var.storage_account_replication_type
  file_share_name                  = "prodshare"
  file_share_quota                 = "5"
  tags                             = local.common_tags
}

module "monitoring" {
  source                           = "../../modules/monitoring"
  resource_group_name              = "monitoring-prod"
  location                         = var.location
  log_analytics_workspace_name     = "technovaprod-law"
  action_group_name                = "technovaprod-alerts"
  alert_email_address              = "femiajao@ymail.com"
  vm_id                            = module.compute.vm_id
  storage_account_id               = module.storage.storage_account_id
  cpu_threshold                    = 80
  storage_capacity_threshold_bytes = 4294967296
  tags                             = local.common_tags
}

module "defender" {
  source = "../../modules/defender"
}