# Azure 3-Tier Infrastructure Project

A production-style Azure Infrastructure project:

---

# Project Architecture

## 3-Tier Architecture

### 1. Web Tier

* Azure Virtual Machine (Ubuntu)
* NGINX / Apache Web Server
* Public Access via Load Balancer

### 2. Application Tier

* Private Ubuntu VM
* Backend Application
* Accessible only from Web Tier

### 3. Database Tier

* Azure SQL Database or MySQL
* Private Access
* No Public Exposure

---

# Azure Services Used

| Service                       | Purpose              |
| ----------------------------- | -------------------- |
| Virtual Network (VNet)        | Network Isolation    |
| Subnets                       | Separate Tiers       |
| Network Security Groups (NSG) | Security Rules       |
| Virtual Machines              | Web + App Servers    |
| Azure Load Balancer           | Traffic Distribution |
| Azure Bastion                 | Secure SSH/RDP       |
| Azure Key Vault               | Secret Management    |
| Azure Monitor                 | Monitoring           |
| Log Analytics Workspace       | Logs                 |
| Azure Backup                  | Backup               |
| Managed Disks                 | Storage              |
| Azure SQL / MySQL             | Database             |
| Public IP                     | Internet Access      |
| Availability Zones            | High Availability    |

---

# Network Design

## VNet

| Component | CIDR        |
| --------- | ----------- |
| VNet      | 10.0.0.0/16 |

## Subnets

| Subnet             | CIDR         | Purpose  |
| ------------------ | ------------ | -------- |
| web-subnet         | 10.0.1.0/24  | Frontend |
| app-subnet         | 10.0.2.0/24  | Backend  |
| db-subnet          | 10.0.3.0/24  | Database |
| AzureBastionSubnet | 10.0.10.0/27 | Bastion  |

---

# Traffic Flow

```text
Internet
   ↓
Azure Load Balancer
   ↓
Web VM
   ↓
App VM
   ↓
Azure SQL / MySQL
```

---

# Folder Structure

```text
azure-3tier-project/
│
├── terraform/
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── vnet.tf
│   ├── vm.tf
│   ├── nsg.tf
│   ├── sql.tf
│   ├── outputs.tf
│   └── terraform.tfvars
│
├── scripts/
│   ├── web.sh
│   └── app.sh
│
├── ansible/
│   ├── inventory
│   └── web-config.yml
│
├── architecture/
│   └── architecture-diagram.png
│
└── README.md
```

---

# Step 1 — Create Resource Group

```bash
az group create \
--name rg-3tier-project \
--location centralindia
```

---

# Step 2 — Create Virtual Network

```bash
az network vnet create \
--resource-group rg-3tier-project \
--name vnet-3tier \
--address-prefix 10.0.0.0/16 \
--subnet-name web-subnet \
--subnet-prefix 10.0.1.0/24
```

---

# Step 3 — Create App Subnet

```bash
az network vnet subnet create \
--resource-group rg-3tier-project \
--vnet-name vnet-3tier \
--name app-subnet \
--address-prefixes 10.0.2.0/24
```

---

# Step 4 — Create DB Subnet

```bash
az network vnet subnet create \
--resource-group rg-3tier-project \
--vnet-name vnet-3tier \
--name db-subnet \
--address-prefixes 10.0.3.0/24
```

---

# Step 5 — Create NSG

```bash
az network nsg create \
--resource-group rg-3tier-project \
--name nsg-web
```

---

# Step 6 — Allow HTTP

```bash
az network nsg rule create \
--resource-group rg-3tier-project \
--nsg-name nsg-web \
--name allow-http \
--priority 100 \
--destination-port-ranges 80 \
--protocol Tcp \
--access Allow
```

---

# Step 7 — Create Public IP

```bash
az network public-ip create \
--resource-group rg-3tier-project \
--name pip-web
```

---

# Step 8 — Create Web VM

```bash
az vm create \
--resource-group rg-3tier-project \
--name vm-web \
--image Ubuntu2204 \
--admin-username azureuser \
--generate-ssh-keys \
--vnet-name vnet-3tier \
--subnet web-subnet \
--public-ip-address pip-web \
--nsg nsg-web
```

---

# Step 9 — Install NGINX

```bash
ssh azureuser@PUBLIC-IP
```

```bash
sudo apt update -y
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

---

# Step 10 — Create App VM

```bash
az vm create \
--resource-group rg-3tier-project \
--name vm-app \
--image Ubuntu2204 \
--admin-username azureuser \
--generate-ssh-keys \
--vnet-name vnet-3tier \
--subnet app-subnet \
--public-ip-address ""
```

---

# Step 11 — Create Azure SQL Server

```bash
az sql server create \
--name sqlserver3tierdemo \
--resource-group rg-3tier-project \
--location centralindia \
--admin-user azureadmin \
--admin-password 'Azure@123456'
```

---

# Step 12 — Create SQL Database

```bash
az sql db create \
--resource-group rg-3tier-project \
--server sqlserver3tierdemo \
--name appdb \
--service-objective S0
```

---

# Step 13 — Configure Monitoring

## Create Log Analytics Workspace

```bash
az monitor log-analytics workspace create \
--resource-group rg-3tier-project \
--workspace-name law-3tier
```

---

# Step 14 — Configure Backup

```bash
az backup vault create \
--resource-group rg-3tier-project \
--name backupvault3tier \
--location centralindia
```

---

# Sample Web Page

```html
<!DOCTYPE html>
<html>
<head>
<title>Azure 3-Tier Project</title>
</head>
<body>
<h1>Azure 3-Tier Infrastructure Project</h1>
<h2>Web Tier Running Successfully</h2>
</body>
</html>
```

---

# Terraform Example

## provider.tf

```hcl
provider "azurerm" {
  features {}
}
```

---

## main.tf

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-3tier-project"
  location = "Central India"
}
```

---

# Security Best Practices

## Recommended

* Use Private Subnets
* Disable Public IP for App VM
* Use Azure Bastion
* Use NSG Rules
* Use Key Vault
* Enable Disk Encryption
* Enable Backup
* Enable Azure Monitor
* Use RBAC
* Use Managed Identity

---

# CI/CD Integration

You can integrate with:

* GitHub Actions
* Microsoft Azure DevOps
* Jenkins
* Terraform Pipeline
* Ansible Automation

---

# Real-Time Enhancements

## Add:

* Azure Application Gateway
* WAF
* VM Scale Sets
* AKS
* Azure Firewall
* Private Endpoints
* Redis Cache
* CDN
* Azure Front Door
* Availability Sets
* Autoscaling

---

# Resume Points

## Add These

* Designed and deployed highly available Azure 3-tier architecture.
* Configured VNets, NSGs, Load Balancer, and secure subnet architecture.
* Deployed Linux virtual machines with NGINX web servers.
* Integrated Azure SQL Database with private networking.
* Implemented monitoring using Azure Monitor and Log Analytics.
* Automated infrastructure provisioning using Terraform and Azure CLI.
* Configured backup and security best practices for production workloads.

---

# Interview Questions Covered

This project helps answer:

* VNet & Subnet Design
* NSG Rules
* Load Balancer
* Azure SQL
* Bastion
* Terraform
* Monitoring
* Backup
* High Availability
* Security
* Azure Networking
* Disaster Recovery
