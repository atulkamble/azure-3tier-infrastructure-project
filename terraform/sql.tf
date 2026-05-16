# -----------------------------------------------------------------------
# Azure SQL Server
# -----------------------------------------------------------------------
resource "random_string" "sql_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Auto-generate a strong password that meets Azure SQL complexity requirements
resource "random_password" "sql_password" {
  length           = 20
  special          = true
  override_special = "!#%&*()-_=+"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_mssql_server" "sql_server" {
  name                          = "sqlsvr-3tier-${random_string.sql_suffix.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = random_password.sql_password.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = data.azurerm_client_config.current.object_id
  }
}

# -----------------------------------------------------------------------
# Azure SQL Database
# -----------------------------------------------------------------------
resource "azurerm_mssql_database" "app_db" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.sql_server.id
  sku_name       = var.sql_sku
  max_size_gb    = 2
  zone_redundant = false
  tags           = var.tags
}

# -----------------------------------------------------------------------
# Private Endpoint – SQL Server (no public internet exposure)
# -----------------------------------------------------------------------
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "pe-sql-3tier"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.db_subnet.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

# -----------------------------------------------------------------------
# Private DNS Zone for SQL
# -----------------------------------------------------------------------
resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "sql-dns-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "sql_dns_record" {
  name                = azurerm_mssql_server.sql_server.name
  zone_name           = azurerm_private_dns_zone.sql_dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address]
}

# -----------------------------------------------------------------------
# Diagnostic Settings – SQL Server
# -----------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "sql_diag" {
  name                       = "diag-sql"
  target_resource_id         = azurerm_mssql_database.app_db.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "Errors"
  }

  enabled_metric {
    category = "Basic"
  }
}
