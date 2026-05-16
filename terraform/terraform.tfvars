# terraform.tfvars
# -----------------------------------------------------------------------
# Copy this file to terraform.tfvars and fill in sensitive values.
# Do NOT commit this file to version control.
# -----------------------------------------------------------------------

resource_group_name = "rg-3tier-project"
location            = "Central India"
environment         = "dev"

# Network
vnet_address_space    = ["10.0.0.0/16"]
web_subnet_prefix     = "10.0.1.0/24"
app_subnet_prefix     = "10.0.2.0/24"
db_subnet_prefix      = "10.0.3.0/24"
bastion_subnet_prefix = "10.0.10.0/27"

# Virtual Machines
admin_username = "azureuser"
web_vm_size    = "Standard_B2s"
app_vm_size    = "Standard_B2s"

# Azure SQL  (store real values in Key Vault or CI/CD secrets – never hard-code in VCS)
sql_admin_login    = "azureadmin"
sql_admin_password = "REPLACE_WITH_STRONG_PASSWORD"   # min 8 chars, upper, lower, digit, special
sql_database_name  = "appdb"
sql_sku            = "S0"

# Tags
tags = {
  Project   = "3tier-azure"
  ManagedBy = "Terraform"
  Env       = "dev"
}
