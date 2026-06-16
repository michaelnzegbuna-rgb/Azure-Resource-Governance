# Azure Tagging, Policy, and Governance Mini-Project

This repository pulls together the governance setup, the automation scripts, and the policy definitions used to bring cost control, security alignment, and compliance discipline to an Azure environment.

---

## What This Project Sets Out to Do

1.  **Build a Tagging Schema**: Land on a metadata structure that works for IT, Security, and Finance all at once.
2.  **Govern Resource Creation**: Put proactive rules in place that block any deployment falling outside the schema.
3.  **Clean Up Existing Resources**: Find and retag legacy resources that were deployed before governance was in place.
4.  **Track and Report Compliance**: Keep an eye on things through the Azure Policy Dashboard, and cross-check with Azure Resource Graph (KQL) queries.

---

## How the Repository Is Organized

```text
AzureGovernanceMiniProject/
├── README.md                          # Top-level project walkthrough
├── tagging-schema.md                  # Tag definitions and the reasoning behind them
├── policies/
│   ├── require-tag-and-value.json     # Custom policy definition (JSON)
│   ├── assign-policy.ps1              # Assigns the policy via PowerShell
│   └── assign-policy.sh               # Assigns the policy via Azure CLI / Bash
├── scripts/
│   ├── apply-tags.ps1                 # Manual tag applier — PowerShell, needs the Az module
│   ├── apply-tags-az.ps1              # Manual tag applier — PowerShell, Azure CLI only
│   ├── apply-tags.sh                  # Manual tag applier — Bash / Azure CLI
│   ├── deploy-test-resources.ps1      # Tests policy enforcement — PowerShell
│   ├── deploy-test-resources.sh       # Tests policy enforcement — Azure CLI / Bash
│   └── verify-tags.kql                # Resource Graph query for tag verification
├── reports/
│   └── verification-report.md         # Compliance report for tagged resources
└── screenshots/
    └── README.md                      # Notes on which screenshots are required
```

---

## Running Through It Step by Step

Everything here can be done with **either Azure CLI or Azure PowerShell** — pick whichever you're more comfortable with. Make sure you're signed in to the right subscription before starting.

### Step 1: Sign In and Pick a Subscription

*   **Azure CLI**:
    ```bash
    az login
    # If more than one subscription is available, set the one you want active:
    az account set --subscription "<subscription-name-or-id>"
    ```
*   **Azure PowerShell**:
    ```powershell
    Connect-AzAccount
    # If more than one subscription is available, set the context:
    Set-AzContext -Subscription "<subscription-name-or-id>"
    ```

---

### Step 2: Create and Apply the Policy

This deploys the custom policy that enforces both tag presence and allowed tag values. You'll need a scope to target — a dedicated test Resource Group is recommended.

*   **Option A: Azure CLI** (run from the `policies/` folder):
    ```bash
    chmod +x assign-policy.sh
    ./assign-policy.sh -t ResourceGroup -n "rg-governance-demo" -e Deny
    ```
*   **Option B: Azure PowerShell** (run from the `policies/` folder):
    ```powershell
    .\assign-policy.ps1 -ScopeType "ResourceGroup" -ScopeName "rg-governance-demo" -PolicyEffect "Deny"
    ```

*Heads up: the policy starts evaluating right away, but full propagation across the scope can take anywhere from 10 to 30 minutes.*

---

### Step 3: Confirm the Policy Actually Blocks Things

These test scripts confirm enforcement is working — one deployment attempt has no tags (and should be rejected), and a second has the correct tags (and should go through fine).

*   **Option A: Azure CLI** (run from the `scripts/` folder):
    ```bash
    chmod +x deploy-test-resources.sh
    ./deploy-test-resources.sh -g "rg-governance-demo" -l "eastus"
    ```
*   **Option B: Azure PowerShell** (run from the `scripts/` folder):
    ```powershell
    .\deploy-test-resources.ps1 -ResourceGroupName "rg-governance-demo" -Location "eastus"
    ```

> [!IMPORTANT]
> **You'll need to do this manually**: capture a screenshot of the failed deployment showing the `RequestDisallowedByPolicy` error, save it as `deny-error.png`, and drop it into the `screenshots/` folder.

---

### Step 4: Backfill Tags on Older Resources

For any resources that were already sitting in your Resource Group before the policy was assigned, this script scans them and fills in the missing default tags automatically.

*   **Option A: Azure CLI / Bash** (run from the `scripts/` folder):
    ```bash
    chmod +x apply-tags.sh
    ./apply-tags.sh -g "rg-governance-demo" -o "your-email@company.com"
    ```
*   **Option B: Azure PowerShell, Az module required** (run from the `scripts/` folder):
    ```powershell
    .\apply-tags.ps1 -ResourceGroupName "rg-governance-demo" -Owner "your-email@company.com"
    ```
*   **Option C: Azure PowerShell via CLI, no Az module needed** (run from the `scripts/` folder):
    ```powershell
    .\apply-tags-az.ps1 -ResourceGroupName "rg-governance-demo" -Owner "your-email@company.com"
    ```

---

### Step 5: Double-Check Everything via Resource Graph

1.  Open **Azure Resource Graph Explorer** inside the Azure Portal.
2.  Grab the query from [verify-tags.kql](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/scripts/verify-tags.kql) and paste it in.
3.  Run it.
4.  Take the resulting table and drop it into [verification-report.md](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/reports/verification-report.md), updated with your own live resources.

---

### Step 6: Grab a Screenshot of the Compliance Dashboard

1.  In the Azure Portal, search for **Policy**, then click **Compliance** in the sidebar.
2.  Open the assignment named `Enforce Mandatory Tags and Allowed Values Assignment`.
3.  Screenshot the compliance rate and resource statuses, save it as `compliance-dashboard.png`, and place it in the `screenshots/` folder.

---

## Before You Submit

Double-check your repo includes:
*   [ ] A complete [Tagging Schema write-up](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/tagging-schema.md)
*   [ ] The exported policy definition: [require-tag-and-value.json](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/policies/require-tag-and-value.json)
*   [ ] A finished [Verification Report](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/reports/verification-report.md) reflecting your actual resources
*   [ ] A screenshots folder containing:
    *   `screenshots/deny-error.png`
    *   `screenshots/compliance-dashboard.png`
