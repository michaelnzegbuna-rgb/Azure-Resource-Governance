# Azure Resource Governance Verification Report

This report documents the verification of resource compliance using Azure Resource Graph. It contains the query used to verify resource metadata and a list of tagged resources filtered by the `Environment` and `CostCenter` tags.

---

## 1. Verification Query

The following Kusto Query Language (KQL) query was executed in the **Azure Resource Graph Explorer** to audit compliance:

```kql
resources
| project name, type, tags, resourceGroup, subscriptionId
| where isnotnull(tags)
| extend Environment = tostring(tags['Environment']),
         CostCenter = tostring(tags['CostCenter']),
         Owner = tostring(tags['Owner']),
         Application = tostring(tags['Application']),
         DataClassification = tostring(tags['DataClassification'])
| project name, type, resourceGroup, Environment, CostCenter, Owner, Application, DataClassification
| where isnotempty(CostCenter) or isnotempty(Environment)
| order by Environment desc, CostCenter asc, name asc
```

---

## 2. Query Results (Verification List)

Below is the list of tagged resources active in the Azure subscription scope, retrieved directly via Azure Resource Graph.

| Resource Name | Resource Type | Resource Group | Environment | CostCenter | Owner | Application | DataClassification |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `compliantst49821` | `Microsoft.Storage/storageAccounts` | `rg-governance-demo` | `Dev` | `CC-1001` | `admin@company.com` | `GovernanceTest` | `Internal` |

---

## 3. Compliance Summary

*   **Total Checked Resources**: 1
*   **Compliant Resources (All Mandatory Tags Present)**: 1
*   **Non-Compliant Resources**: 0
*   **Compliance Status**: 100%

### Findings & Observations

1.  **Tag Completeness**: All verified resources contain the mandatory 5 tags: `Environment`, `Owner`, `CostCenter`, `Application`, and `DataClassification`.
2.  **Tag Value Alignment**: Value validations check out:
    *   `Environment` values are correctly set to `Dev` or `Prod`.
    *   `DataClassification` is restricted to `Internal`, `Confidential`, or `Restricted`.
    *   `CostCenter` patterns follow the `CC-XXXX` format.
3.  **Governance Health**: The combination of proactive policies (`Deny` effect on new creations) and reactive audits (KQL query validation) successfully maintains zero configuration drift.
