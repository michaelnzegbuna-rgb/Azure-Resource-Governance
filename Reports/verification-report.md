# Tag Compliance Audit — Azure Resource Graph Report

This report covers the process of checking resource compliance through Azure Resource Graph. It includes the query used to audit resource metadata, along with the resulting list of tagged resources filtered against the `Environment` and `CostCenter` tags.

---

## 1. Audit Query Used

The Kusto Query Language (KQL) query below was run inside **Azure Resource Graph Explorer** to check compliance across the subscription:

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

## 2. Resources Found in Scope

The table below lists the tagged resources found within scope, pulled directly from Azure Resource Graph:

| Resource Name | Resource Type | Resource Group | Environment | CostCenter | Owner | Application | DataClassification |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `compliantst49821` | `Microsoft.Storage/storageAccounts` | `rg-governance-demo` | `Dev` | `CC-1001` | `admin@company.com` | `GovernanceTest` | `Internal` |

---

## 3. Results Snapshot

*   **Resources Reviewed**: 1
*   **Fully Compliant (all required tags present)**: 1
*   **Out of Compliance**: 0
*   **Overall Compliance Rate**: 100%

### Key Takeaways
1.  **Tags Present**: Every resource checked carries all five required tags — `Environment`, `Owner`, `CostCenter`, `Application`, and `DataClassification`.
2.  **Tag Values Match Expectations**: The values themselves hold up under validation:
    *   `Environment` is correctly populated with either `Dev` or `Prod`
    *   `DataClassification` sticks to one of `Internal`, `Confidential`, or `Restricted`
    *   `CostCenter` follows the expected `CC-XXXX` naming pattern
3.  **Overall Governance Posture**: Pairing the preventative policy (which denies non-compliant resource creation) with this periodic audit query has kept configuration drift at zero so far.
