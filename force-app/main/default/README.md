# Org Metadata Dashboard — Complete Implementation

## Architecture Overview

```
MetadataEngine.cls          ← Central engine: all API calls, all data models
    ↓ called by
AgentAction classes         ← Dual-mode: @InvocableMethod (Agentforce) + @AuraEnabled (LWC)
    ↓ called by
metadataDashboard (LWC)     ← 10-tab dashboard with namespace filter bar
DeleteAction classes        ← Standalone @InvocableMethod wrappers for each delete operation
```

## Metadata Types Covered

| Type             | List+Filter | Unused Detection | Delete / Deactivate |
|------------------|-------------|-----------------|---------------------|
| Flows            | ✅ + NS filter | ✅ inactive = unused | ✅ DeleteFlowAction |
| Apex Classes     | ✅ + NS filter | ✅ symbol table analysis | ✅ DeleteApexClassAction |
| Triggers         | ✅ + NS filter | ✅ body scan | ✅ DeleteTriggerAction |
| LWC Components   | ✅ + NS filter | —              | ✅ DeleteLwcAction |
| Aura Components  | ✅ + NS filter | —              | ✅ DeleteAuraAction |
| Profiles         | ✅            | ✅ zero-user check | ✅ DeactivateProfileAction |
| Permission Sets  | ✅            | ✅ zero-assignment check | ✅ DeletePermissionSetAction |
| Custom Fields    | ✅ + NS filter | —              | ✅ DeleteCustomFieldAction |
| Custom Objects   | ✅ + NS filter | —              | ✅ DeleteCustomObjectAction |
| Validation Rules | ✅ + NS filter | ✅ inactive = unused | ✅ DeleteValidationRuleAction |

## Namespace Filter Behaviour

Tabs that support namespace filtering (Flows, Apex, Triggers, LWC, Aura, Fields, Objects, Validation Rules):
- Leave the filter blank → see ALL components
- Enter a namespace (e.g. `ITSms`, `FinanceApp`) → a blue highlighted section appears showing only matching components
- The full list always remains visible below the filtered section

## Key Use Cases Supported

| Use Case | How to trigger |
|---|---|
| Show all unused Flows | Open Flows tab — Inactive section = unused |
| Delete an Apex class | Ask Agentforce "Delete Apex class LeadScoringBatch" → DeleteApexClassAction |
| Identify profiles not assigned to any users | Open Profiles tab — Unassigned section |
| List LWC components for namespace FinanceApp | Open LWC tab, type FinanceApp, click Apply |

## Named Credential Required
All API calls use `callout:Metadata_API`. Configure this named credential in Setup before deploying.

## Deploy
```bash
sf project deploy start --source-dir . --target-org <your-org-alias>
```
