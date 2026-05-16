output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.rg.name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.vnet.id
}

output "web_subnet_id" {
  description = "Web subnet ID"
  value       = azurerm_subnet.web_subnet.id
}

output "app_subnet_id" {
  description = "App subnet ID"
  value       = azurerm_subnet.app_subnet.id
}

output "db_subnet_id" {
  description = "DB subnet ID"
  value       = azurerm_subnet.db_subnet.id
}

output "load_balancer_public_ip" {
  description = "Public IP of the Azure Load Balancer"
  value       = azurerm_public_ip.lb_pip.ip_address
}

output "web_vm_private_ip" {
  description = "Private IP of the Web VM"
  value       = azurerm_network_interface.web_nic.private_ip_address
}

output "app_vm_private_ip" {
  description = "Private IP of the App VM"
  value       = azurerm_network_interface.app_nic.private_ip_address
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of Azure SQL Server"
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Azure SQL Database name"
  value       = azurerm_mssql_database.app_db.name
}

output "sql_private_endpoint_ip" {
  description = "Private IP address of the SQL private endpoint"
  value       = azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.kv.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.law.id
}

output "backup_vault_name" {
  description = "Recovery Services Vault name"
  value       = azurerm_recovery_services_vault.backup_vault.name
}

output "bastion_public_ip" {
  description = "Public IP of Azure Bastion (for SSH/RDP access)"
  value       = azurerm_public_ip.bastion_pip.ip_address
}

output "ssh_private_key_secret_name" {
  description = "Key Vault secret name for the VM SSH private key"
  value       = azurerm_key_vault_secret.ssh_private_key.name
  sensitive   = true
}
