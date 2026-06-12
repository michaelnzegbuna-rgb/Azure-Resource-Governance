# Azure Resource Tags, Policies, and Governance Learning Program

This repository contains the governance framework, automated scripts, and policy definitions designed to establish cost control, security alignment, and operational compliance within an Azure environment.

---

## Project Objectives

1.  **Tagging Schema**: Define a metadata framework balancing the needs of IT, Security, and Finance.
2.  **Resource Governance**: Implement proactive rules to deny any non-compliant deployments.
3.  **Retroactive Compliance**: Detect and update untagged legacy resources.
4.  **Audit & Reporting**: Monitor compliance via the Azure Policy Dashboard and query resource compliance with Azure Resource Graph (KQL).

---

## Directory Structure

```text
AzureGovernanceMiniProject/
├── README.md                          # Main project instructions
├── tagging-schema.md                  # Metadata tag definitions & justifications
├── policies/
│   ├── require-tag-and-value.json     # Custom Policy JSON definition
│   ├── assign-policy.ps1              # PowerShell assignment script
│   └── assign-policy.sh               # Azure CLI assignment script
├── scripts/
│   ├── apply-tags.ps1                 # PowerShell manual tag applier (requires Az module)
│   ├── apply-tags-az.ps1              # PowerShell manual tag applier (uses Azure CLI)
│   ├── apply-tags.sh                  # Azure CLI manual tag applier (Bash)
│   ├── deploy-test-resources.ps1      # PowerShell policy enforcement tester
│   ├── deploy-test-resources.sh       # Azure CLI policy enforcement tester
│   └── verify-tags.kql                # Azure Resource Graph KQL query
├── reports/
│   └── verification-report.md         # Tagged resources compliance report
└── screenshots/
    └── README.md                      # Instructions for mandatory screenshots
```

---

## Step-by-Step Execution Guide

You can run these steps using **either** **Azure CLI** or **Azure PowerShell**. Ensure you are logged into your Azure subscription before running the scripts.

### Step 1: Login & Select Subscription

*   **Azure CLI**:
    ```bash
    az login
    # If you have multiple subscriptions, select your active one:
    az account set --subscription "<subscription-name-or-id>"
    ```
*   **Azure PowerShell**:
    ```powershell
    Connect-AzAccount
    # If you have multiple subscriptions, set context:
    Set-AzContext -Subscription "<subscription-name-or-id>"
    ```

---

### Step 2: Define and Assign the Azure Policy

Deploy the custom policy to enforce tag presence and value constraints. You must target a resource scope (we recommend creating a test Resource Group).

*   **Option A: Azure CLI** (from the `policies/` directory):
    ```bash
    chmod +x assign-policy.sh
    ./assign-policy.sh -t ResourceGroup -n "rg-governance-demo" -e Deny
    ```
*   **Option B: Azure PowerShell** (from the `policies/` directory):
    ```powershell
    .\assign-policy.ps1 -ScopeType "ResourceGroup" -ScopeName "rg-governance-demo" -PolicyEffect "Deny"
    ```

*Note: Azure Policy evaluation starts immediately, but it can take 10-30 minutes to propagate fully across the scope.*

---

### Step 3: Test Enforcement (Deny and Allow)

Run the test scripts to verify the policy is working. The script attempts to deploy a storage account without tags (which should fail) and one with correct tags (which should succeed).

*   **Option A: Azure CLI** (from the `scripts/` directory):
    ```bash
    chmod +x deploy-test-resources.sh
    ./deploy-test-resources.sh -g "rg-governance-demo" -l "eastus"
    ```
*   **Option B: Azure PowerShell** (from the `scripts/` directory):
    ```powershell
    .\deploy-test-resources.ps1 -ResourceGroupName "rg-governance-demo" -Location "eastus"
    ```

> [!IMPORTANT]
> **Action Required**: Take a screenshot of the failure output showing the `RequestDisallowedByPolicy` error, rename it to `deny-error.png`, and save it under the `screenshots/` directory.

---

### Step 4: Manually Apply Tags to Existing Resources

If you have legacy resources in your Resource Group that were deployed prior to policy assignment, run this script to scan and automatically attach compliant default tags.

*   **Option A: Azure CLI / Bash** (from the `scripts/` directory):
    ```bash
    chmod +x apply-tags.sh
    ./apply-tags.sh -g "rg-governance-demo" -o "your-email@company.com"
    ```
*   **Option B: Azure PowerShell (requires Az module)** (from the `scripts/` directory):
    ```powershell
    .\apply-tags.ps1 -ResourceGroupName "rg-governance-demo" -Owner "your-email@company.com"
    ```
*   **Option C: PowerShell using Azure CLI (no Az module required)** (from the `scripts/` directory):
    ```powershell
    .\apply-tags-az.ps1 -ResourceGroupName "rg-governance-demo" -Owner "your-email@company.com"
    ```

---

### Step 5: Verify via Azure Resource Graph

1.  Navigate to **Azure Resource Graph Explorer** in the Azure Portal.
2.  Open and copy the query located in [verify-tags.kql](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/scripts/verify-tags.kql).
3.  Execute the query.
4.  Copy the output table, and update the table in [verification-report.md](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/reports/verification-report.md) with your live resources.

---

### Step 6: Capture Compliance Dashboard

1.  In the Azure Portal, search for **Policy** and click on **Compliance** in the left sidebar.
2.  Select the assignment: `Enforce Mandatory Tags and Allowed Values Assignment`.
3.  Take a screenshot showing the compliance rate and resource statuses, name it `compliance-dashboard.png`, and place it in the `screenshots/` directory.

---

## Submission Checklist

Before submitting the GitHub link, ensure your repository has:
*   [ ] Standardized [Tagging Schema Documentation](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/tagging-schema.md).
*   [ ] Exported custom policy rules: [require-tag-and-value.json](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/policies/require-tag-and-value.json).
*   [ ] Completed [Verification Report](file:///C:/Users/duduy/OneDrive/Documents/AzureGovernanceMiniProject/reports/verification-report.md) reflecting your active resources.
*   [ ] Screenshots folder containing:
    *   `screenshots/deny-error.png`
    *   `screenshots/compliance-dashboard.png`
