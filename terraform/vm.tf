# -----------------------------------------------------------------------
# SSH Key – generated locally, public key stored in Key Vault
# -----------------------------------------------------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key as a Key Vault secret (retrieve once for initial setup)
resource "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "vm-ssh-private-key"
  value        = tls_private_key.ssh_key.private_key_pem
  key_vault_id = azurerm_key_vault.kv.id
}

# -----------------------------------------------------------------------
# Web VM – NIC (Public IP removed; access via Bastion + LB)
# -----------------------------------------------------------------------
resource "azurerm_network_interface" "web_nic" {
  name                = "nic-vm-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "web-ip-config"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "web_nic_nsg" {
  network_interface_id      = azurerm_network_interface.web_nic.id
  network_security_group_id = azurerm_network_security_group.nsg_web.id
}

# -----------------------------------------------------------------------
# Web VM
# -----------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "web_vm" {
  name                            = "vm-web"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.web_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  zone                            = "1"
  tags                            = var.tags

  network_interface_ids = [azurerm_network_interface.web_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  # Bootstrap: install and start NGINX
  custom_data = base64encode(file("${path.module}/../scripts/web.sh"))

  identity {
    type = "SystemAssigned"
  }
}

# -----------------------------------------------------------------------
# App VM – NIC (no public IP; private only)
# -----------------------------------------------------------------------
resource "azurerm_network_interface" "app_nic" {
  name                = "nic-vm-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "app-ip-config"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "app_nic_nsg" {
  network_interface_id      = azurerm_network_interface.app_nic.id
  network_security_group_id = azurerm_network_security_group.nsg_app.id
}

# -----------------------------------------------------------------------
# App VM
# -----------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "app_vm" {
  name                            = "vm-app"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.app_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  zone                            = "1"
  tags                            = var.tags

  network_interface_ids = [azurerm_network_interface.app_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  # Bootstrap: install Node.js runtime
  custom_data = base64encode(file("${path.module}/../scripts/app.sh"))

  identity {
    type = "SystemAssigned"
  }
}

# -----------------------------------------------------------------------
# Diagnostic Settings – Web VM
# -----------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "web_vm_diag" {
  name                       = "diag-vm-web"
  target_resource_id         = azurerm_linux_virtual_machine.web_vm.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
}

# -----------------------------------------------------------------------
# Diagnostic Settings – App VM
# -----------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "app_vm_diag" {
  name                       = "diag-vm-app"
  target_resource_id         = azurerm_linux_virtual_machine.app_vm.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
}
