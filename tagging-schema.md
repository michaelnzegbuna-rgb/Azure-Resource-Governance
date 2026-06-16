# Azure Resource Tagging Standards

This document lays out the standardized tagging approach adopted for resources across the Azure environment. Putting this framework into practice gives the organization clearer cost visibility, accountability over who owns what, and consistent alignment with security expectations across every business unit.

---

## How the Tags Are Organized

Tags fall into two buckets: **Mandatory** (enforced through Azure Policy) and **Optional** (encouraged, but not policed).

### 1. Mandatory Tags

Every resource needs all of these present. Azure Policy will block any deployment that's missing one of them or uses a value outside the allowed list.

| Tag Key | Expected Value Format / Allowed Values | Stakeholder | Why It Exists |
| :--- | :--- | :--- | :--- |
| **Environment** | `Prod`, `Stage`, `Dev`, `Test` | IT / Ops | Separates workloads by environment so non-production resources don't accidentally pick up production-grade policies, and makes it easy to flag non-prod environments for cost savings outside business hours. |
| **Owner** | Email address (e.g., `user@company.com` or a distribution group) | IT / Management | Points to the person or team accountable for the resource — used when sending automated alerts, responding to security incidents, or handing off ownership. |
| **CostCenter** | `CC-` followed by a 4-digit code (e.g., `CC-1001`, `CC-2002`) | Finance | Ties resource spend back to the right business unit for budgeting, reporting, and internal chargeback/showback. |
| **Application** | Alphanumeric, no spaces (e.g., `CustomerPortal`, `InventoryAPI`) | IT / Dev | Groups resources under the workload or service they belong to — important for tracing architecture dependencies. |
| **DataClassification** | `Public`, `Internal`, `Confidential`, `Restricted` | Security | Flags how sensitive the data on that resource is, feeding into automated security monitoring and compliance checks. |

### 2. Optional Tags

These add useful context but aren't checked or enforced by any policy.

| Tag Key | Expected Value Format | Stakeholder | Why It Exists |
| :--- | :--- | :--- | :--- |
| **ProvisioningDate** | Date in `YYYY-MM-DD` format | IT / Ops | Records when a resource was first created — useful for spotting stale resources worth decommissioning. |
| **CreatedBy** | Email address or automation service principal name | IT / Security | Notes who or what created the resource (e.g., `Terraform-SPN` or `admin@company.com`), helpful for tracing deployment history. |

---

## Conventions Worth Knowing

1.  **Case matters**: Azure treats tag keys and values as case-sensitive. Keys must match the exact casing shown above — `CostCenter`, not `costcenter` or `COSTCENTER`.
2.  **Character limits**: Stick to alphanumeric characters, hyphens (`-`), and underscores (`_`) in both keys and values. Avoid spaces, since they tend to cause friction with automation scripts.
3.  **No inheritance**: Tags set at the resource group level don't automatically carry down to the resources inside it. That's exactly why Azure Policy is used to enforce tagging directly at the resource level, rather than relying on inheritance.

---

## Why Each Team Benefits

*   **Finance — Cost Allocation**: Filtering Microsoft Cost Management reports by `CostCenter` lets finance run accurate chargebacks per business unit.
*   **Security — Access Control & Audits**: The `DataClassification` tag lets security teams write conditional rules — for example, applying stricter Network Security Group settings to anything tagged `Confidential` or `Restricted`.
*   **Operations — Resource Management**: Automation can target resources tagged `Environment: Dev` or `Environment: Test` to start/stop them on a schedule, cutting costs when they're not actively needed.
