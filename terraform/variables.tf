variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-3tier-project"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Central India"
}

variable "environment" {
  description = "Environment tag (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ---------- Network ----------
variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "web_subnet_prefix" {
  description = "CIDR for the web (frontend) subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_subnet_prefix" {
  description = "CIDR for the app (backend) subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "db_subnet_prefix" {
  description = "CIDR for the database subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "bastion_subnet_prefix" {
  description = "CIDR for AzureBastionSubnet (must be /27 or larger)"
  type        = string
  default     = "10.0.10.0/27"
}

# ---------- Virtual Machines ----------
variable "admin_username" {
  description = "Admin username for Linux VMs"
  type        = string
  default     = "azureuser"
}

variable "web_vm_size" {
  description = "SKU for the Web-tier VM"
  type        = string
  default     = "Standard_B2s"
}

variable "app_vm_size" {
  description = "SKU for the App-tier VM"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_image" {
  description = "Source image reference for Linux VMs"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ---------- Azure SQL ----------
variable "sql_admin_login" {
  description = "Administrator login name for Azure SQL Server"
  type        = string
  default     = "azureadmin"
  sensitive   = true
}

variable "sql_admin_password" {
  description = "Administrator password for Azure SQL Server (min 8 chars, upper, lower, digit, special)"
  type        = string
  sensitive   = true
}

variable "sql_database_name" {
  description = "Name of the Azure SQL Database"
  type        = string
  default     = "appdb"
}

variable "sql_sku" {
  description = "Service objective / SKU for Azure SQL Database"
  type        = string
  default     = "S0"
}

# ---------- Tagging ----------
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "3tier-azure"
    ManagedBy = "Terraform"
  }
}
