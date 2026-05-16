# -----------------------------------------------------------------------
# Virtual Network
# -----------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-3tier"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# -----------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------
resource "azurerm_subnet" "web_subnet" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.web_subnet_prefix]
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.app_subnet_prefix]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.db_subnet_prefix]

  # Required for private endpoints to function correctly
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "bastion_subnet" {
  # Name must be exactly "AzureBastionSubnet"
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

# -----------------------------------------------------------------------
# Public IP for Bastion
# -----------------------------------------------------------------------
resource "azurerm_public_ip" "bastion_pip" {
  name                = "pip-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# -----------------------------------------------------------------------
# Azure Bastion Host
# -----------------------------------------------------------------------
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-3tier"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}

# -----------------------------------------------------------------------
# Public IP for Load Balancer
# -----------------------------------------------------------------------
resource "azurerm_public_ip" "lb_pip" {
  name                = "pip-lb-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# -----------------------------------------------------------------------
# Azure Load Balancer (Web Tier)
# -----------------------------------------------------------------------
resource "azurerm_lb" "web_lb" {
  name                = "lb-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "web_backend_pool" {
  name            = "web-backend-pool"
  loadbalancer_id = azurerm_lb.web_lb.id
}

resource "azurerm_lb_probe" "http_probe" {
  name            = "http-health-probe"
  loadbalancer_id = azurerm_lb.web_lb.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

resource "azurerm_lb_rule" "http_rule" {
  name                           = "http-lb-rule"
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
  disable_outbound_snat          = true
}

# -----------------------------------------------------------------------
# Associate Web NIC with LB Backend Pool
# -----------------------------------------------------------------------
resource "azurerm_network_interface_backend_address_pool_association" "web_nic_lb" {
  network_interface_id    = azurerm_network_interface.web_nic.id
  ip_configuration_name   = "web-ip-config"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool.id
}
