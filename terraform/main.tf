# -----------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -----------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-3tier-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# -----------------------------------------------------------------------
# Recovery Services Vault (Backup)
# -----------------------------------------------------------------------
resource "azurerm_recovery_services_vault" "backup_vault" {
  name                = "backupvault-3tier-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tags                = var.tags
}

# -----------------------------------------------------------------------
# Backup Policy – Enhanced VM backup
# -----------------------------------------------------------------------
resource "azurerm_backup_policy_vm" "vm_backup_policy" {
  name                = "bp-daily-vm"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.backup_vault.name

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  retention_daily {
    count = 7
  }
}

# -----------------------------------------------------------------------
# Backup Protection – Web VM
# -----------------------------------------------------------------------
resource "azurerm_backup_protected_vm" "web_vm_backup" {
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.backup_vault.name
  source_vm_id        = azurerm_linux_virtual_machine.web_vm.id
  backup_policy_id    = azurerm_backup_policy_vm.vm_backup_policy.id
}

# -----------------------------------------------------------------------
# Backup Protection – App VM
# -----------------------------------------------------------------------
resource "azurerm_backup_protected_vm" "app_vm_backup" {
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.backup_vault.name
  source_vm_id        = azurerm_linux_virtual_machine.app_vm.id
  backup_policy_id    = azurerm_backup_policy_vm.vm_backup_policy.id
}

# -----------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------
data "azurerm_client_config" "current" {}

resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-3tier-${random_string.kv_suffix.result}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  rbac_authorization_enabled = true
  tags                       = var.tags
}

# -----------------------------------------------------------------------
# Key Vault Secret – SQL password
# -----------------------------------------------------------------------
resource "azurerm_key_vault_secret" "sql_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault.kv]
}
