# Azure Tagging Schema and Governance Framework

This document outlines the standardized resource tagging schema designed for the Azure cloud environment. Implementing this framework ensures cost transparency, operational accountability, and security alignment across all business units.

---

## Tagging Schema Overview

The following tags are classified into **Mandatory** (enforced by Azure Policy) and **Optional** (highly recommended for additional context).

### 1. Mandatory Tags

These tags must be present on all resources. Azure Policy will reject deployments that lack any of these tags or contain invalid values.

| Tag Key | Expected Value Format / Allowed Values | Stakeholder | Purpose & Justification |
| :--- | :--- | :--- | :--- |
| **Environment** | `Prod`, `Stage`, `Dev`, `Test` | IT / Ops | Distinguishes workloads by environment type. Prevents non-production resources from inheriting production policies and flags environments for cost optimization during non-business hours. |
| **Owner** | Email address (e.g., `user@company.com` or distribution group) | IT / Management | Identifies the primary contact or team responsible for the resource. Used for automated alerting, security incident response, and ownership handoff. |
| **CostCenter** | `CC-` followed by a 4-digit code (e.g., `CC-1001`, `CC-2002`) | Finance | Maps resource costs back to specific business units for budgeting, financial reporting, and chargeback/showback. |
| **Application** | Alphanumeric string, no spaces (e.g., `CustomerPortal`, `InventoryAPI`) | IT / Dev | Groups resources logically under their parent workload or service. Essential for understanding architecture dependencies. |
| **DataClassification** | `Public`, `Internal`, `Confidential`, `Restricted` | Security | Categorizes the sensitivity of the data handled by the resource. Guides automated security monitoring and compliance audits. |

### 2. Optional Tags

These tags provide extra context and metadata but are not programmatically enforced by policy.

| Tag Key | Expected Value Format | Stakeholder | Purpose & Justification |
| :--- | :--- | :--- | :--- |
| **ProvisioningDate** | Date in `YYYY-MM-DD` format | IT / Ops | Documents when the resource was created. Helps identify stale resources for decommissioning. |
| **CreatedBy** | Email or automation service principal name | IT / Security | Identifies the creator (e.g., `Terraform-SPN` or `admin@company.com`) to trace deployment origin. |

---

## Tagging Conventions & Standards

1.  **Case Sensitivity**: Tag keys and values in Azure are case-sensitive. The keys must exactly match the casing defined above (e.g., `CostCenter`, not `costcenter` or `COSTCENTER`).
2.  **Allowed Characters**: Keys and values must only contain alphanumeric characters, hyphens (`-`), and underscores (`_`). Spaces are discouraged to maintain compatibility with automation scripts.
3.  **Scope**: Tags applied to a resource group are **not** automatically inherited by resources within that group. Therefore, we use Azure Policy to enforce tags directly at the resource level.

---

## Stakeholder Benefits

*   **Finance (Cost Allocation)**: By filtering reports in Microsoft Cost Management by `CostCenter`, finance teams can perform accurate chargebacks.
*   **Security (Access Control & Audits)**: Security teams can write conditional policies based on the `DataClassification` tag (e.g., enforcing tighter Network Security Group rules on `Confidential` or `Restricted` resources).
*   **Operations (Resource Management)**: Automated scripts can schedule start/stop routines on resources tagged `Environment: Dev` or `Environment: Test` to save costs when not in use.
