# Azure Deployments — Terraform IaC

This repository deploys Azure infrastructure using [Terraform](https://www.terraform.io/) and [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/), automated via a GitHub Actions CI/CD pipeline.

## What Gets Deployed

| Resource | Module | Version |
|----------|--------|---------|
| Resource Group | `Azure/avm-res-resources-resourcegroup/azurerm` | 0.2.2 |
| Virtual Network + Subnet | `Azure/avm-res-network-virtualnetwork/azurerm` | 0.17.1 |

## Repository Structure

```
├── main.tf                  # Resource definitions (RG, VNet, Subnet)
├── providers.tf             # Terraform backend & Azure provider config
├── variables.tf             # Variable declarations
├── terraform.tfvars         # Variable values
└── .github/workflows/
    └── tf-deploy.yml        # GitHub Actions CI/CD pipeline
```

## Prerequisites

- An Azure Service Principal with **federated credentials** (OIDC) configured for GitHub Actions
- The following **GitHub repository secrets** set:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
- A **Storage Account** for Terraform state with:
  - Azure AD auth enabled (key-based access can be disabled)
  - The Service Principal assigned the **Storage Blob Data Contributor** role

---

## Bug Fixes & Corrections Applied

The following issues were identified and corrected to make the deployment workflow functional.

---

### 1. Authentication Method Mismatch (providers.tf)

**Error:**
```
Error: Error building ARM Config: Authenticating using the Azure CLI is only supported as a User (not a Service Principal).
```

**Root Cause:**
The Azure provider was configured to use **Managed Service Identity (MSI)**, which only works on Azure VMs. However, the GitHub Actions workflow authenticates via **OIDC** using a Service Principal with federated credentials — a completely different auth mechanism.

**Fix:**
```diff
 provider "azurerm" {
   features {}
-  use_msi      = true
-  msi_endpoint = "http://169.254.169.254/metadata/identity/oauth2/token"
+  use_oidc = true
+  use_cli  = false
 }
```

Additionally, the GitHub Actions workflow needed `ARM_*` environment variables so Terraform can pick up the OIDC token:
```yaml
env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_USE_OIDC: true
```

---

### 2. Storage Account Key-Based Auth Blocked (providers.tf)

**Error:**
```
Status=403 Code="KeyBasedAuthenticationNotPermitted"
Message="Key based authentication is not permitted on this storage account."
```

**Root Cause:**
The Terraform backend was trying to authenticate to the state storage account using **storage account keys**, but the storage account has key-based access disabled (a security best practice).

**Fix:**
Added `use_oidc` and `use_azuread_auth` to the backend block so it authenticates via Azure AD:
```diff
 backend "azurerm" {
   resource_group_name  = "terraform-state"
   storage_account_name = "tfstate04022026olowosam"
   container_name       = "tsstate"
   key                  = "azure-deployments.tfstate"
+  use_oidc             = true
+  use_azuread_auth     = true
 }
```

---

### 3. Provider Version Constraint Conflict (providers.tf)

**Error:**
```
Could not retrieve the list of available versions for provider hashicorp/azurerm:
no available releases match the given constraints >= 3.71.0, ~> 3.100, ~> 4.0, < 5.0.0
```

**Root Cause:**
The provider was pinned to `~> 3.100` (meaning `>= 3.100, < 4.0`), but the AVM modules (v0.17.1 and v0.2.2) require `~> 4.0` (meaning `>= 4.0, < 5.0`). These two constraints are **mutually exclusive** — no version of `azurerm` can satisfy both.

**Fix:**
```diff
 azurerm = {
   source  = "hashicorp/azurerm"
-  version = "~> 3.100"
+  version = "~> 4.0"
 }
```

---

### 4. Removed `resource_group_name`, Added `parent_id` (main.tf)

**Error:**
```
The argument "parent_id" is required, but no definition was found.
An argument named "resource_group_name" is not expected here.
```

**Root Cause:**
The `avm-res-network-virtualnetwork` module v0.17.1 introduced a **breaking change** as part of the AVM v1 specification. The `resource_group_name` input was removed and replaced with `parent_id`, which takes the full Azure Resource ID of the parent resource group.

**Fix:**
```diff
 module "avm-res-network-virtualnetwork" {
   ...
-  resource_group_name = module.avm-res-resources-resourcegroup
+  parent_id           = module.avm-res-resources-resourcegroup.resource_id
   ...
 }
```

---

### 5. Variable Name Typo (main.tf)

**Error:**
```
An input variable with the name "subnet_address_prefixes" has not been declared.
Did you mean "subnet_address_prefix"?
```

**Root Cause:**
The variable was declared as `subnet_address_prefix` (singular) in `variables.tf`, but referenced as `subnet_address_prefixes` (plural) in `main.tf`.

**Fix:**
```diff
 subnets = {
   subnet1 = {
     name             = var.subnet_name
-    address_prefixes = var.subnet_address_prefixes
+    address_prefixes = var.subnet_address_prefix
   }
 }
```

---

### 6. Terraform Wrapper Corrupting Plan Files (tf-deploy.yml)

**Symptom:**
Workflow completed successfully (green checkmark) but **nothing was deployed** to Azure.

**Root Cause:**
The `hashicorp/setup-terraform@v3` action enables a **wrapper script** by default that injects extra output into all `terraform` commands. This corrupts the binary plan file created by `terraform plan -out=tfplan`, causing `terraform apply tfplan` to either fail silently or not apply any changes.

**Fix:**
```diff
 - name: Set up Terraform
   uses: hashicorp/setup-terraform@v3
   with:
     terraform_version: 1.9.0
+    terraform_wrapper: false
```

---

## Running the Workflow

The pipeline triggers automatically on pushes to `main`, or can be triggered manually via the **"Run workflow"** button in GitHub Actions.

The pipeline executes these steps:
1. **Checkout** — clones the repository
2. **Azure Login** — authenticates via OIDC
3. **Terraform Init** — initializes backend and downloads modules
4. **Terraform Validate** — checks syntax
5. **Terraform Plan** — generates an execution plan
6. **Terraform Apply** — applies changes (only on `main` branch)