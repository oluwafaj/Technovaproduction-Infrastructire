# Technova Production Infrastructure

Multi-environment Azure infrastructure for the Technova platform, built entirely with Terraform and deployed through GitHub Actions. Development and Production are fully isolated — separate resource groups, separate service principals, separate state — with every change to Production gated behind a manual approval.

This repo covers networking, compute, secrets, storage, the App Service platform, monitoring, security posture, and disaster recovery. Application code lives in a separate repository ([technova-app](#)) with its own pipeline.

---

## Architecture

```
Internet
   │
   ▼
Custom Domain (fajglobalservices.co.uk, SSL)
   │
   ▼
Azure App Service (technovaprod-app, Linux, PHP 8.2)
   │
   ▼
App Service Plan (S1)
   │
   ▼
Virtual Network (technovaprod-vnet)
   ├── Subnet: web
   ├── Subnet: app
   └── Subnet: db
        │
        ├── NSG (management access only, default deny)
        │
        ├── Windows Virtual Machine (technovaprod-vm)
        │     │
        │     ├── Key Vault (RBAC-secured secrets)
        │     └── Storage Account (GRS, SMB file share)
        │
        └── Monitoring & resilience
              ├── Log Analytics Workspace
              ├── Azure Monitor Agent
              ├── Application Insights
              ├── Alert rules (CPU / availability / storage)
              ├── Action Group (email)
              ├── Recovery Services Vault (daily VM backup)
              └── Microsoft Defender for Cloud (Standard tier)
```

Development mirrors this exact structure inside its own resource group (`RG-Development`), with its own VNet, VM, Key Vault, storage account, and monitoring stack.

---

## Repository structure

```
.
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variable.tf
│   │   ├── terraform.tfvars
│   │   └── provider.tf
│   └── prod/
│       ├── main.tf
│       ├── variable.tf
│       ├── terraform.tfvars
│       └── provider.tf
├── modules/
│   ├── networking/      # VNet, subnets, NSG
│   ├── compute/          # Windows VM, NIC, public IP
│   ├── keyvault/         # Key Vault, secrets, RBAC role assignments
│   ├── storage/          # Storage account, SMB file share
│   ├── appservice/       # App Service Plan, Linux Web App
│   ├── monitoring/       # Log Analytics, alert rules, action group, DCRs
│   ├── defender/         # Microsoft Defender for Cloud pricing
│   └── backup/           # Recovery Services Vault, backup policy
└── .github/
    └── workflows/
        └── terraform.yml
```

Each module is called independently by both `environments/dev` and `environments/prod`. The modules themselves don't change between environments — only the values passed in do (names, sizing, retention).

---

## Resource inventory

| Layer | Resource | Development | Production |
|---|---|---|---|
| Resource Group | Core workload | `RG-Development` | `RG-Production` |
| Resource Group | Monitoring | `monitoring-dev` | `monitoring-prod` |
| Networking | Virtual Network | `technovadev-vnet` | `technovaprod-vnet` |
| Networking | Subnets | `web` / `app` / `db` | `web` / `app` / `db` |
| Compute | Virtual Machine | `technovadev-vm` | `technovaprod-vm` |
| App Platform | App Service Plan | `technovadev-plan` (S1) | `technovaprod-plan` (S1) |
| App Platform | App Service | `technovadev-app` | `technovaprod-app` |
| Secrets | Key Vault | `technovadev-kv` | `technovaprod-kv` |
| Storage | Storage Account | `technovadevst123` | `technovaprod` |
| Monitoring | Log Analytics | `technovadev-law` | `technovaprod-law` |
| Monitoring | Application Insights | `technovadev-appinsight` | `technovaprod-appinsight` |
| DR | Recovery Services Vault | `technovadev-rsv` | `technovaprod-rsv` |

---

## State management

Terraform state is stored remotely in Azure Storage (`azurerm` backend) with locking enabled. Each environment has a fully independent state file — there's no shared backend, so a Production apply can never touch Development's state or vice versa.

| Environment | Storage Account | Container | State File |
|---|---|---|---|
| Development | `technovadevblob` | `dev` | `terraform.tfstate` |
| Production | `technovaprodblob` | `prod` | `terraform.tfstate` |

---

## CI/CD pipeline

Defined in [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml). Runs on every push to `main` touching `environments/` or `modules/`, or manually via `workflow_dispatch`.

1. **Terraform Format Check** — `terraform fmt -check`
2. **Terraform Validate** — checks internal config consistency
3. **Terraform Dev** — plans and applies automatically
4. **Terraform Prod Plan** — computes the change set, uploads it as a build artifact, does **not** apply
5. **Manual approval** — a designated reviewer reads the Production plan in GitHub Actions and approves or rejects it
6. **Terraform Prod Apply** — applies the exact plan that was reviewed, so there's no drift between what was approved and what gets deployed

Production only runs after Development succeeds. Each job has a 10-minute timeout to avoid a stuck job holding a state lock indefinitely.

### Required secrets

Set these under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|---|---|
| `DEV_AZURE_CLIENT_ID` | Development service principal |
| `DEV_AZURE_CLIENT_SECRET` | Development service principal |
| `DEV_AZURE_SUBSCRIPTION_ID` | Development subscription |
| `DEV_AZURE_TENANT_ID` | Development Azure AD tenant |
| `PROD_AZURE_CLIENT_ID` | Production service principal |
| `PROD_AZURE_CLIENT_SECRET` | Production service principal |
| `PROD_AZURE_SUBSCRIPTION_ID` | Production subscription |
| `PROD_AZURE_TENANT_ID` | Production Azure AD tenant |

Each environment runs under its own service principal, scoped only to its own resource groups — no shared credentials between Dev and Prod.

### Required GitHub environment

Go to **Settings → Environments → production** and add yourself (or whoever should review) as a **required reviewer**. Without this, the apply step will run without pausing for approval.

---

## Running it locally

```bash
cd environments/dev   # or environments/prod
terraform init
terraform plan
terraform apply
```

You'll need the Azure CLI authenticated (`az login`) with access to the relevant subscription, or the `ARM_*` environment variables set to match the service principal credentials used in CI.

---

## Security

- **Identity** — RBAC throughout, dedicated service principals per environment, Contributor-scoped to their own resource groups only
- **Secrets** — generated programmatically (`random_password`), stored in Key Vault under Azure RBAC authorization, never hardcoded
- **Network** — each environment has its own VNet split into web/app/db subnets, NSG denies everything inbound by default except management access
- **Defender for Cloud** — Standard tier enabled at subscription level for VMs, Storage Accounts, and Key Vaults

---

## Monitoring

- **Log Analytics Workspace** per environment, fed by the Azure Monitor Agent (VM performance counters) and Application Insights (HTTP requests, failures, availability)
- **Alert rules**: CPU > 80% (15 min window), VM availability below 1 (15 min window), storage capacity threshold (6 hour window) — all routed to an Action Group by email
- Verified end to end with direct KQL queries against the workspace, not just configured and assumed

---

## Disaster recovery

| Resource | RPO | RTO |
|---|---|---|
| Virtual Machine (Prod) | 24 hours | 4 hours |
| Storage Account (Prod) | ~15 minutes | 1 hour |
| Key Vault Secrets | 90 days (soft delete) | 30 minutes |

- VM backups via Recovery Services Vault — daily at 23:00 UTC, 30-day retention (Prod) / 7-day (Dev)
- Storage uses Geo-Redundant Storage (GRS) — West Europe primary, North Europe secondary
- A full Production VM restore was tested against a real recovery point (isolated test instance, verified, then decommissioned) — came in within the 4-hour target RTO

---

## Custom domain

Production is also served at `fajglobalservices.co.uk`, bound with SNI SSL. DNS is currently managed directly at the registrar (123-reg) rather than Azure DNS — see the roadmap below.

---

## Known limitations / roadmap

- Single region (West Europe) — no automated regional failover yet
- DNS for the custom domain isn't under Infrastructure as Code
- No policy-as-code scanning (Checkov/tfsec) in the pipeline yet

Planned next: move service principal auth to OIDC federation, evaluate a secondary-region standby for Production, bring DNS into Azure DNS.

---

## Troubleshooting

**Stuck state lock** (e.g. after a cancelled pipeline run):
```bash
terraform force-unlock <LOCK_ID>
```

**Importing a resource created outside Terraform:**
```bash
terraform import <resource_address> <azure_resource_id>
```
