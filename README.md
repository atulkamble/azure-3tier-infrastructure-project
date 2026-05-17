# Azure 3-Tier Infrastructure Project

> A production-style, cloud-native 3-tier web application infrastructure deployed entirely on **Microsoft Azure**, provisioned with **Terraform**, and configured with **Ansible** and cloud-init scripts.

![Architecture Diagram](architecture/architecture-diagram.svg)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Azure Services Used](#2-azure-services-used)
3. [Architecture Flow](#3-architecture-flow)
4. [High Availability & Scalability](#4-high-availability--scalability)
5. [Security Implementation](#5-security-implementation)
6. [Monitoring & Logging](#6-monitoring--logging)
7. [CI/CD Pipeline](#7-cicd-pipeline)
8. [Infrastructure as Code (IaC)](#8-infrastructure-as-code-iac)
9. [Backup & Disaster Recovery](#9-backup--disaster-recovery)
10. [Cost Optimization](#10-cost-optimization)
11. [Troubleshooting & Challenges](#11-troubleshooting--challenges)
12. [Business Impact / Outcome](#12-business-impact--outcome)
13. [Tools & Technologies](#13-tools--technologies)
14. [GitHub Repository Structure](#14-github-repository-structure)
15. [Deployment Guide](#15-deployment-guide)

---

## 1. Project Overview

This project demonstrates a **fully automated, production-ready 3-tier architecture** on Microsoft Azure — built for a developer or DevOps engineer who wants a reference implementation that balances security, observability, and cost efficiency.

**What it does:**
- Serves a modern web dashboard through an NGINX reverse proxy on the Web tier.
- Exposes a RESTful Node.js / Express API on the App tier, connected to a managed Azure SQL Database.
- Keeps the database entirely off the public internet using a Private Endpoint and Private DNS Zone.
- Manages all secrets (SQL password, SSH keys) in Azure Key Vault, accessed by VMs via System-Assigned Managed Identities — no hard-coded credentials anywhere.

**Key goals:**
| Goal | How it is met |
|---|---|
| Zero public exposure of internal tiers | No public IPs on VMs; Bastion for SSH access |
| Secrets never in source code | Key Vault + Managed Identity |
| Full audit trail | Log Analytics + Azure Monitor diagnostics |
| Reproducibility | 100% Terraform-provisioned; Ansible for day-2 config |
| Low operational cost | B2s VMs, S0 SQL SKU, 30-day log retention |

---

## 2. Azure Services Used

| Service | Purpose |
|---|---|
| **Resource Group** | Logical container for all project resources (`rg-3tier-project`) |
| **Virtual Network (VNet)** | Network isolation across `10.0.0.0/16` |
| **Subnets × 4** | Tier separation: `web-subnet`, `app-subnet`, `db-subnet`, `AzureBastionSubnet` |
| **Network Security Groups × 3** | Granular inbound/outbound rules per tier |
| **NAT Gateway** | Outbound internet for Web and App subnets (Standard LB blocks SNAT) |
| **Azure Load Balancer (Standard)** | Zone-redundant public IP distributes HTTP traffic to Web VM |
| **Azure Bastion** | Browser-based SSH/RDP with no public IP on VMs |
| **Virtual Machines × 2** | Web tier (`vm-web`, NGINX) + App tier (`vm-app`, Node.js 20) |
| **Azure SQL Database** | Managed relational DB, S0 SKU, TLS 1.2 enforced |
| **Private Endpoint** | SQL Server reachable only from within the VNet (`10.0.3.x`) |
| **Private DNS Zone** | `privatelink.database.windows.net` — DNS resolution stays inside VNet |
| **Azure Key Vault** | Stores SQL admin password and VM SSH private key |
| **Managed Identity (System-Assigned)** | Both VMs authenticate to Key Vault via RBAC — no stored credentials |
| **Log Analytics Workspace** | Central sink for all diagnostic logs and metrics |
| **Azure Monitor** | Diagnostic settings for VMs, SQL, and Key Vault |
| **Recovery Services Vault** | Daily VM backup with 7-day retention |
| **Public IP (Standard)** | Load balancer front-end and Bastion host |

---

## 3. Architecture Flow

```text
                          ┌──────────────────────────────────────────────┐
                          │              Azure Region (Central India)      │
                          │                                                │
  Internet                │   ┌─────────────────────────────────────────┐ │
  ─────────               │   │         VNet  10.0.0.0/16               │ │
  User Request            │   │                                         │ │
      │                   │   │  ┌──────────────────────────────────┐   │ │
      ▼                   │   │  │  web-subnet  10.0.1.0/24         │   │ │
  ┌───────────────┐       │   │  │  vm-web · Ubuntu 22.04 · NGINX   │   │ │
  │ Azure Load    │──────►│   │  │  (reverse proxy → port 8080)     │   │ │
  │ Balancer      │       │   │  └──────────────┬───────────────────┘   │ │
  │ (Standard,    │       │   │                 │ :8080                 │ │
  │  public IP)   │       │   │  ┌──────────────▼───────────────────┐   │ │
  └───────────────┘       │   │  │  app-subnet  10.0.2.0/24         │   │ │
                          │   │  │  vm-app · Ubuntu 22.04           │   │ │
  ┌───────────────┐       │   │  │  Node.js 20 LTS · Express API    │   │ │
  │ Azure Bastion │──────►│   │  └──────────────┬───────────────────┘   │ │
  │ (SSH access)  │       │   │                 │ :1433 (private)       │ │
  └───────────────┘       │   │  ┌──────────────▼───────────────────┐   │ │
                          │   │  │  db-subnet  10.0.3.0/24          │   │ │
                          │   │  │  Azure SQL Database              │   │ │
                          │   │  │  Private Endpoint (no public IP) │   │ │
                          │   │  └──────────────────────────────────┘   │ │
                          │   │                                         │ │
                          │   │  ┌────────────────────────────────────┐ │ │
                          │   │  │ AzureBastionSubnet 10.0.10.0/27    │ │ │
                          │   │  └────────────────────────────────────┘ │ │
                          │   └─────────────────────────────────────────┘ │
                          └──────────────────────────────────────────────┘
```

### Request lifecycle

1. **User** hits the Load Balancer public IP over HTTP (port 80).
2. **Load Balancer** forwards the request to `vm-web` (Web tier, port 80).
3. **NGINX** on `vm-web` acts as a reverse proxy — static content is served directly; API calls (`/api/*`) are proxied to `vm-app` on port 8080.
4. **Node.js / Express API** on `vm-app` processes the request. For data operations it connects to Azure SQL via the private endpoint on `10.0.3.x`.
5. **Azure SQL** returns data over the private link — traffic never leaves the VNet.
6. **Operators** access VMs exclusively through **Azure Bastion** (no SSH port exposed to the internet).

### Tier Details

| Tier | Resource | Details |
|---|---|---|
| Web | `vm-web` | Ubuntu 22.04, Standard_B2s, NGINX, port 80 |
| App | `vm-app` | Ubuntu 22.04, Standard_B2s, Node.js 20 LTS, port 8080 |
| Database | Azure SQL Server | `sqlsvr-3tier-<suffix>`, S0 SKU, private endpoint only |

### Network Design

| Subnet | CIDR | Purpose |
|---|---|---|
| `web-subnet` | `10.0.1.0/24` | Web VM (NGINX) |
| `app-subnet` | `10.0.2.0/24` | App VM (Node.js) — private |
| `db-subnet` | `10.0.3.0/24` | SQL private endpoint |
| `AzureBastionSubnet` | `10.0.10.0/27` | Azure Bastion host |

---

## 4. High Availability & Scalability

| Feature | Implementation |
|---|---|
| **Zone-redundant Load Balancer** | Standard SKU Load Balancer with a static Standard public IP; survives Availability Zone failures |
| **VM Availability Zones** | Both `vm-web` and `vm-app` are pinned to Zone 1; can be spread across zones by changing `zone` in `vm.tf` |
| **NAT Gateway** | Provides reliable, scalable outbound internet for both subnets without relying on LB SNAT |
| **Premium LRS OS disks** | 30 GB Premium_LRS disks on both VMs for consistent I/O performance |
| **Azure SQL managed service** | Automatic patching, built-in HA, and point-in-time restore handled by the platform |
| **Horizontal scale path** | Add VMs to the LB backend pool or introduce Azure VMSS with minimal Terraform changes |
| **Vertical scale** | Change `web_vm_size` / `app_vm_size` variables and re-apply — no architectural changes needed |

> **Current SKUs** (`Standard_B2s`, SQL S0) are sized for development and demonstration. For production traffic, upgrade to `Standard_D2s_v3`+ VMs and SQL S2/S3.

---

## 5. Security Implementation

Security is applied at every layer using the principle of **least privilege** and **defence in depth**.

### Network Security Groups

Three dedicated NSGs enforce strict traffic rules:

| NSG | Tier | Allowed Inbound | Blocked |
|---|---|---|---|
| `nsg-web` | Web | HTTP :80, HTTPS :443 from Internet; SSH :22 from Bastion subnet only | All other inbound (priority 4096 Deny-All) |
| `nsg-app` | App | :8080 from `web-subnet` only; SSH :22 from Bastion subnet only | Direct internet access |
| `nsg-db` | DB | :1433 from `app-subnet` only | All other inbound |

### Identity & Access

- **No public IPs on VMs** — lateral movement from the internet is impossible.
- **Azure Bastion** provides browser-based SSH over TLS; no inbound port 22 exposed externally.
- **System-Assigned Managed Identities** on both VMs — no service account passwords needed.
- **Azure Key Vault RBAC** — VMs are granted `Key Vault Secrets User` role only; no wildcard permissions.
- **SSH key pair** generated by Terraform's `tls_private_key` resource (RSA 4096); private key stored in Key Vault, never on disk locally.

### Data Protection

- **Azure SQL TLS 1.2 enforced** (`minimum_tls_version = "1.2"`).
- **Public network access disabled** on SQL Server (`public_network_access_enabled = false`).
- **Private Endpoint** — SQL traffic stays within the VNet on `10.0.3.x`.
- **Private DNS Zone** (`privatelink.database.windows.net`) — DNS resolution never leaves the VNet.
- **Auto-generated SQL password** (20 chars, mixed case, digits, specials) via `random_password`; stored in Key Vault.
- **Entra ID (Azure AD) administrator** configured on SQL Server for passwordless auth path.

### Terraform State Security

- Soft-delete and purge protection disabled for dev; recommended to enable for production Key Vaults.
- `terraform.tfvars` is excluded from version control (`.gitignore`) — no secrets in git history.

---

## 6. Monitoring & Logging

All observability data flows into a single **Log Analytics Workspace** (`law-3tier-dev`).

| Resource | Diagnostic Setting | Logs / Metrics Collected |
|---|---|---|
| Web VM (`vm-web`) | `diag-vm-web` | Performance counters, syslog, heartbeat |
| App VM (`vm-app`) | `diag-vm-app` | Performance counters, syslog, heartbeat |
| Azure SQL Database | `diag-sql` | SQLInsights, Errors, Timeouts, QueryStoreWait |
| Key Vault | `diag-kv` | AuditEvent (every read/write to secrets) |

### Key Metrics to Watch

- **VM CPU / Memory** — via `Perf` table in Log Analytics.
- **SQL DTU utilisation** — via `AzureMetrics` table; alert if DTU% > 80 for S0 SKU.
- **Failed login attempts on SQL** — via `SQLSecurityAuditEvents`.
- **Key Vault secret access** — via `AzureDiagnostics` with `ResourceType == "VAULTS"`.

### Sample KQL Query — VM CPU

```kql
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart
```

### Alerting (recommended additions)

```hcl
# Add to main.tf — example metric alert for high CPU
resource "azurerm_monitor_metric_alert" "web_cpu_alert" {
  name                = "alert-web-cpu"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.web_vm.id]
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  action { action_group_id = "<action-group-id>" }
}
```

---

## 7. CI/CD Pipeline

The project does not include a CI/CD pipeline file by default, but it is designed to integrate cleanly with **GitHub Actions** or **Azure DevOps**.

### Recommended GitHub Actions Workflow

```yaml
# .github/workflows/terraform.yml
name: Terraform CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    permissions:
      id-token: write   # required for OIDC login to Azure
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.6"

      - name: Terraform Init
        run: terraform init
        working-directory: terraform

      - name: Terraform Validate
        run: terraform validate
        working-directory: terraform

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: terraform

      - name: Terraform Apply  # only on push to main
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply tfplan
        working-directory: terraform
```

### Pipeline Stages

| Stage | Trigger | Action |
|---|---|---|
| **Validate** | Every PR | `terraform validate` + `terraform fmt -check` |
| **Plan** | Every PR | `terraform plan` — output posted as PR comment |
| **Apply** | Merge to `main` | `terraform apply` with saved plan |
| **Ansible** | Post-apply | `ansible-playbook web-config.yml` |

> Use **OIDC federated credentials** (not long-lived secrets) for Azure authentication in GitHub Actions.

---

## 8. Infrastructure as Code (IaC)

The entire infrastructure is defined in Terraform using the **AzureRM ~> 4.0** provider. No manual portal clicks are needed.

### Terraform File Breakdown

| File | Responsibility |
|---|---|
| `provider.tf` | AzureRM, `random`, and `tls` provider versions; Key Vault and VM feature flags |
| `variables.tf` | All input variables with defaults and descriptions |
| `terraform.tfvars` | Environment-specific overrides (region, SKUs, tags) |
| `main.tf` | Resource Group, Log Analytics Workspace, Recovery Services Vault, Backup Policy, Key Vault |
| `vnet.tf` | VNet, 4 subnets, NAT Gateway, Bastion host, Load Balancer |
| `vm.tf` | Web VM, App VM, NICs, SSH key generation, Key Vault secrets, LB backend association |
| `nsg.tf` | NSG rules for Web, App, and DB tiers |
| `sql.tf` | SQL Server, SQL Database, Private Endpoint, Private DNS Zone, diagnostic settings |
| `outputs.tf` | Load Balancer IP, VM private IPs, SQL FQDN, Key Vault URI |

### Deploying from Scratch

```bash
# 1. Authenticate
az login
az account set --subscription "<subscription-id>"

# 2. Initialise providers and modules
cd terraform
terraform init

# 3. Preview changes
terraform plan -out=tfplan

# 4. Apply
terraform apply tfplan

# 5. Read outputs
terraform output load_balancer_public_ip
terraform output sql_server_fqdn
```

### Teardown

```bash
terraform destroy
```

### State Management (Production Recommendation)

```hcl
# Add to provider.tf for remote state
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate<suffix>"
    container_name       = "tfstate"
    key                  = "3tier/terraform.tfstate"
  }
}
```

---

## 9. Backup & Disaster Recovery

| Component | Mechanism | Retention | RPO / RTO |
|---|---|---|---|
| Web VM (`vm-web`) | Azure Backup (Recovery Services Vault) | 7 days | RPO: 24h / RTO: ~30 min |
| App VM (`vm-app`) | Azure Backup (Recovery Services Vault) | 7 days | RPO: 24h / RTO: ~30 min |
| Azure SQL Database | Built-in automated backups (full/diff/log) | 7 days (S0 default) | RPO: 5–10 min (log backup) |

### Backup Schedule

- **Daily backup window:** 02:00 UTC (configurable via `azurerm_backup_policy_vm`).
- **Vault SKU:** Standard — supports cross-region restore when geo-redundancy is enabled.

### Disaster Recovery Steps

1. **VM failure** — Restore from the Recovery Services Vault via portal or CLI:
   ```bash
   az backup protection restore-disks \
     --resource-group rg-3tier-project \
     --vault-name backupvault-3tier-dev \
     --container-name "iaasvmcontainer;iaasvmcontainerv2;rg-3tier-project;vm-web" \
     --item-name "vm;iaasvmcontainerv2;rg-3tier-project;vm-web" \
     --restore-mode OriginalLocation \
     --rp-name <recovery-point-name>
   ```
2. **SQL failure** — Use Azure portal Point-in-Time Restore (PITR) to restore to any second within the 7-day window.
3. **Full region failure** — Re-run `terraform apply` in a secondary region after updating `location` in `terraform.tfvars`.

---

## 10. Cost Optimization

| Resource | SKU / Config | Monthly Estimate (approx.) |
|---|---|---|
| `vm-web` (Standard_B2s) | 2 vCPU, 4 GB RAM | ~$30 |
| `vm-app` (Standard_B2s) | 2 vCPU, 4 GB RAM | ~$30 |
| Azure SQL S0 | 10 DTU, 250 GB max | ~$15 |
| Azure Bastion (Basic SKU) | Hourly billing | ~$140/month (or use Developer SKU at $0) |
| Load Balancer (Standard) | Rules + data processed | ~$18 |
| NAT Gateway | Hourly + data | ~$32 |
| Log Analytics (PerGB2018) | 30-day retention | Pay-per-GB ingested |
| Recovery Services Vault | Backup storage | Pay-per-GB stored |

### Cost-saving Tips Applied

- **B2s VMs** — burstable compute ideal for dev/test workloads with variable CPU.
- **SQL S0** — smallest managed SQL SKU; upgrade to S1+ for production.
- **30-day log retention** — Log Analytics retention set to minimum to reduce storage costs.
- **No redundant public IPs on VMs** — only one public IP (LB) + one Bastion IP.
- **Tags on all resources** — `Project=3tier-azure`, `ManagedBy=Terraform`, `Env=dev` enable cost allocation reports in Azure Cost Management.

### Further Optimisations (Production)

- Use **Azure Reserved Instances** (1-year or 3-year) to save up to 60% on VM costs.
- Switch to **Azure SQL Serverless** for intermittent workloads (auto-pause when idle).
- Enable **Azure Advisor** recommendations — automatically surfaces underutilised resources.
- Use **Bastion Developer SKU** (free tier) for non-production environments.

---

## 11. Troubleshooting & Challenges

### Challenge 1 — Standard Load Balancer blocks outbound SNAT

**Problem:** After switching from Basic to Standard LB, VMs lost outbound internet access (needed for `apt-get` during bootstrap).

**Root cause:** Standard Load Balancer does not provide implicit outbound SNAT rules.

**Solution:** Added a **NAT Gateway** associated with both `web-subnet` and `app-subnet`. This provides dedicated, scalable outbound connectivity independent of the LB.

---

### Challenge 2 — Key Vault soft-delete prevents re-creation

**Problem:** Running `terraform destroy` followed by `terraform apply` failed because Key Vault enters a soft-deleted state and the name cannot be reused for 90 days.

**Solution:** Set `purge_soft_delete_on_destroy = false` in the provider block and used `recover_soft_deleted_key_vaults = true` so Terraform recovers the vault on the next apply instead of failing.

---

### Challenge 3 — Private endpoint requires subnet policy disabled

**Problem:** Terraform `apply` failed when creating the SQL private endpoint with: *"PrivateEndpointNetworkPolicies must be Disabled on the subnet."*

**Solution:** Set `private_endpoint_network_policies = "Disabled"` on `db-subnet` in `vnet.tf`.

---

### Challenge 4 — VM cannot reach SQL at startup (DNS not yet propagated)

**Problem:** App VM bootstrap script tried to connect to SQL before Private DNS Zone was linked to the VNet, causing connection timeouts.

**Solution:** Added `depends_on` in `vm.tf` to ensure the DNS zone VNet link and private endpoint DNS A record are created before the VMs start.

---

### Challenge 5 — Ansible inventory — dynamic private IPs

**Problem:** VM private IPs are assigned dynamically by Azure DHCP; the Ansible inventory file could not have them hard-coded.

**Solution:** Retrieve the IP from Terraform output and pass it to Ansible:

```bash
WEB_IP=$(terraform output -raw web_vm_private_ip)
ansible-playbook -i "${WEB_IP}," web-config.yml
```

---

## 12. Business Impact / Outcome

| Metric | Value |
|---|---|
| **Deployment time** | Full environment provisioned in ~15 minutes (`terraform apply`) |
| **Manual steps** | Zero — fully automated from `terraform init` to live dashboard |
| **Security posture** | No VM public IPs; all secrets in Key Vault; traffic encrypted in transit |
| **Operational overhead** | Managed SQL (no DBA needed); Bastion (no VPN gateway needed) |
| **Repeatability** | Identical environment in any Azure region by changing one variable |
| **Cost (dev environment)** | ~$265/month fully running; can be reduced to ~$75 by stopping VMs when not in use |

### What this project demonstrates

- **End-to-end IaC discipline** — infrastructure is code; no snowflake resources.
- **Zero-trust network design** — each tier can only talk to the tier directly below it.
- **Secrets management at scale** — Key Vault + Managed Identity pattern applicable to any Azure workload.
- **Observability from day one** — Log Analytics and diagnostic settings wired up before the first request hits.
- **Runbook-ready operations** — backup, restore, and scale-up procedures documented and testable.

---

## 13. Tools & Technologies

| Category | Tool / Technology | Version |
|---|---|---|
| **Cloud Platform** | Microsoft Azure | — |
| **IaC** | Terraform | ≥ 1.6.0 |
| **Terraform Provider** | hashicorp/azurerm | ~> 4.0 |
| **Terraform Provider** | hashicorp/random | ~> 3.6 |
| **Terraform Provider** | hashicorp/tls | ~> 4.0 |
| **Configuration Management** | Ansible | ≥ 2.14 |
| **Web Server** | NGINX | Latest (Ubuntu 22.04 apt) |
| **Runtime** | Node.js LTS | 20.x |
| **API Framework** | Express.js | ^4.19.2 |
| **DB Driver** | mssql (npm) | ^10.0.4 |
| **Operating System** | Ubuntu Server | 22.04 LTS Gen2 |
| **Database** | Azure SQL Database | SQL Server 12.0 compatible |
| **Secret Store** | Azure Key Vault | — |
| **Monitoring** | Azure Monitor + Log Analytics | PerGB2018 SKU |
| **Backup** | Azure Recovery Services | Standard SKU |
| **Access** | Azure Bastion | Standard SKU |
| **Version Control** | Git / GitHub | — |
| **Shell Scripting** | Bash | — |

---

## 14. GitHub Repository Structure

```text
azure-3tier-infrastructure-project/
│
├── terraform/                        # All infrastructure-as-code
│   ├── provider.tf                   # AzureRM + random + tls providers, feature flags
│   ├── variables.tf                  # Input variables with types, defaults, descriptions
│   ├── terraform.tfvars              # Environment-specific values (not committed to git)
│   ├── main.tf                       # Resource Group, Key Vault, Log Analytics, Backup vault
│   ├── vnet.tf                       # VNet, 4 subnets, NAT Gateway, Bastion, Load Balancer
│   ├── vm.tf                         # Web VM, App VM, NICs, SSH keys, LB backend
│   ├── nsg.tf                        # NSG rules for Web, App, and DB tiers
│   ├── sql.tf                        # Azure SQL Server, Database, Private Endpoint, DNS zone
│   └── outputs.tf                    # LB public IP, VM IPs, SQL FQDN, Key Vault URI
│
├── scripts/                          # Cloud-init bootstrap scripts
│   ├── web.sh                        # Installs NGINX, deploys web dashboard
│   └── app.sh                        # Installs Node.js 20, Express API, systemd service
│
├── ansible/                          # Day-2 configuration management
│   ├── inventory                     # Target hosts (web VM)
│   └── web-config.yml                # Configures NGINX with security hardening
│
├── web/                              # Frontend assets
│   └── index.html                    # Modern Azure infrastructure dashboard (canonical source)
│
├── architecture/                     # Diagrams
│   └── architecture-diagram.svg      # Visual architecture overview
│
├── LICENSE
└── README.md                         # This file
```

### Branch Strategy (recommended)

| Branch | Purpose |
|---|---|
| `main` | Production-ready, protected — triggers `terraform apply` via CI/CD |
| `dev` | Active development and feature work |
| `feature/*` | Short-lived feature branches |

---

## 15. Deployment Guide

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.6
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) — authenticated (`az login`)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) ≥ 2.14 (for web config playbook)
- An Azure subscription with **Contributor** and **Key Vault Administrator** roles

### Step 1 — Configure variables

Edit `terraform/terraform.tfvars`:

```hcl
location            = "Central India"
resource_group_name = "rg-3tier-project"
environment         = "dev"
sql_admin_login     = "azureadmin"
sql_database_name   = "appdb"
sql_sku             = "S0"
```

> The SQL password is **auto-generated** by Terraform and stored in Key Vault — you do not need to set it manually.

### Step 2 — Provision infrastructure

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Key outputs after apply:

```bash
terraform output load_balancer_public_ip   # open in browser for the dashboard
terraform output sql_server_fqdn           # e.g. sqlsvr-3tier-abc123.database.windows.net
terraform output app_vm_private_ip         # e.g. 10.0.2.4
terraform output web_vm_private_ip         # e.g. 10.0.1.4
terraform output key_vault_name            # for secret retrieval
```

### Step 3 — Configure the App VM (DB credentials)

Connect to `vm-app` via **Azure Bastion** and populate `/opt/app/.env`:

```bash
sudo nano /opt/app/.env
```

```ini
DB_SERVER=sqlsvr-3tier-<suffix>.database.windows.net
DB_NAME=appdb
DB_USER=azureadmin
DB_PASS=<retrieve-from-key-vault>
PORT=8080
```

```bash
sudo chmod 600 /opt/app/.env
sudo chown nobody /opt/app/.env
sudo systemctl restart app-tier
```

### Step 4 — Initialise the database schema

```bash
curl -X POST http://<app-vm-private-ip>:8080/db/setup
# Expected: { "message": "Schema ready", "rows_inserted": 5 }
```

### Step 5 — Deploy the web dashboard (Ansible)

```bash
cd ansible
ansible-playbook -i inventory web-config.yml
```

### Step 6 — Verify

```bash
LB_IP=$(cd terraform && terraform output -raw load_balancer_public_ip)
curl http://$LB_IP/          # Dashboard HTML
curl http://$LB_IP/api/health         # { "status": "ok" }
curl http://$LB_IP/api/db-status      # SQL connection info
curl http://$LB_IP/api/items          # Items from DB
```

### App Tier — API Endpoints

All endpoints served on port `8080` on `vm-app` and proxied by NGINX at `/api/*`:

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Static health check — always returns `{ status: "ok" }` |
| GET | `/db-status` | SQL connectivity check — server version, DB name, timestamp |
| GET | `/db/tables` | Lists all base tables in the connected database |
| POST | `/db/setup` | Idempotent — creates `items` table and seeds 5 rows |
| GET | `/items` | Returns items from DB; falls back to 3 static items if DB unavailable |

### Teardown

```bash
cd terraform
terraform destroy
```

---
