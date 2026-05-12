@SuppressWarnings('PMD.ExcessiveClassLength,PMD.NcssMethodCount,PMD.AvoidDeeplyNestedIfStmts,PMD.CognitiveComplexity,PMD.NcssTypeCount,PMD.EmptyStatementBlock,PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces,PMD.ApexCRUDViolation,PMD.EmptyCatchBlock,PMD.OperationWithLimitsInLoop,PMD.ApexSOQLInjection,PMD.ExcessivePublicCount,PMD.LocalVariableNamingConventions')
public without sharing class MetadataEngine {

    // ===============================
    // GLOBAL CONSTANTS
    // ===============================

    /** Salesforce REST API version used for all callouts. Update here only when upgrading. */
    private static final String  API_VERSION    = 'v60.0';

    /** Named Credential configured in Setup → Named Credentials. Must match exactly. */
    private static final String  NAMED_CRED     = 'Metadata_API';

    /** Base URL for all REST API callouts — combines Named Credential + API version. */
    private static final String  BASE_URL       = 'callout:' + NAMED_CRED + '/services/data/' + API_VERSION + '/';

    /** Salesforce login URL for JWT OAuth flows. Use https://test.salesforce.com for sandboxes. */
    private static final String  LOGIN_URL      = 'https://login.salesforce.com';

    /** Timeout (ms) for long-running callouts: SOAP deletes, object/field queries. */
    private static final Integer TIMEOUT_LONG   = 120000;

    /** Timeout (ms) for short callouts: JWT token requests, package lookups. */
    private static final Integer TIMEOUT_SHORT  = 30000;
    private static final Integer CPU_RESERVE_MS = 3000;  // ms to keep in reserve before skipping CPU-heavy checks

    /** JWT token expiry window in minutes. */
    private static final Integer JWT_EXPIRY_MIN = 5;

    // ===============================
    // WRAPPERS — FLOWS
    // ===============================
    public class FlowInfo {
        @AuraEnabled public String  apiName;
        @AuraEnabled public String  label;
        @AuraEnabled public String  processType;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String  namespacePrefix;
        @AuraEnabled public String  durableId;         // FlowDefinition DurableId — used for Id-based MCD lookup
        // Enhanced fields
        @AuraEnabled public Boolean isManagedPackage;  // Namespace present → never delete
        @AuraEnabled public Boolean isCalledByFlow;    // Referenced by another Flow (subflow)
        @AuraEnabled public Boolean isScheduled;       // ScheduledFlow = has its own trigger
        @AuraEnabled public String  safetyStatus;      // IN_USE / SCHEDULED / MANAGED / INACTIVE / SAFE_TO_REVIEW
    }

    public class FlowSummary {
        public Integer        total;
        public Integer        active;
        public Integer        inactive;
        public List<String>   activeFlows;
        public List<String>   inactiveFlows;
        public Integer        filteredTotal;
        public List<String>   filteredActiveFlows;
        public List<String>   filteredInactiveFlows;
        public String         namespaceFilter;
        public List<FlowInfo> allFlowObjects;
    }

    // ===============================
    // WRAPPERS — APEX CLASSES
    // ===============================
    public class ApexClassInfo {
        public String  id;
        public String  name;
        public String  status;
        public Integer linesOfCode;
        public String  lastModifiedDate;
        public String  namespacePrefix;
        // Enhanced fields
        public Boolean isTestClass;       // Has @IsTest annotation
        public Boolean isManagedPackage;  // Namespace present → never delete
        public Boolean isInvocable;       // Has @InvocableMethod → called by Flow/Process
        public Boolean isAuraEnabled;     // Has @AuraEnabled → called by LWC/Aura
        public String  safetyStatus;      // IN_USE / TEST_CLASS / MANAGED / SAFE_TO_REVIEW
    }

    public class ApexSummary {
        public Integer             total;
        public Integer             unused;
        public Integer             used;
        public Integer             standard;
        public Integer             testCount;
        public List<ApexClassInfo> unusedClasses;
        public List<String>        usedClassNames;
        public List<String>        standardClassNames;
        public List<String>        testClassNames;
        public Integer             filteredTotal;
        public List<ApexClassInfo> filteredClasses;
        public String              namespaceFilter;
    }

    // ===============================
    // SHARED WRAPPER
    // ===============================
    public class DeleteResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
    }

    // ── Mass delete result wrapper ─────────────────────────────
    public class MassDeleteResult {
        @AuraEnabled public Integer          totalRequested;
        @AuraEnabled public Integer          successCount;
        @AuraEnabled public Integer          failureCount;
        @AuraEnabled public List<String>     succeeded;
        @AuraEnabled public List<String>     failed;
        @AuraEnabled public String           summary;
    }

    // ===============================
    // WRAPPERS — LWC COMPONENTS
    // ===============================
    public class LwcComponentInfo {
        public String  id;
        public String  name;
        public String  namespacePrefix;
        public String  lastModifiedDate;
        public String  apiVersion;
        public Boolean isReferenced;
        public String  referencedBy;
        // Enhanced detection fields
        public String  referenceSource;   // WHERE it was found: FlexiPage / LWC / Aura / Flow / Tab
        public Boolean isExposedTab;      // Has a custom tab → likely an entry point
        public Boolean isManagedPackage;  // Namespace != org namespace → never delete
        public String  safetyStatus;      // SAFE_TO_REVIEW / ENTRY_POINT / MANAGED / IN_USE
    }

    public class LwcSummary {
        public Integer                total;
        public Integer                withNamespace;
        public Integer                withoutNamespace;
        public Integer                unreferencedCount;
        public List<LwcComponentInfo> allComponents;
        public List<LwcComponentInfo> filteredComponents;
        public List<LwcComponentInfo> unreferencedComponents;
        public String                 namespaceFilter;
    }

    // ===============================
    // WRAPPERS — AURA COMPONENTS
    // ===============================
    public class AuraComponentInfo {
        public String  id;
        public String  name;
        public String  namespacePrefix;
        public String  lastModifiedDate;
        public String  apiVersion;
        public Boolean isReferenced;
        public String  referencedBy;
        // Enhanced detection fields
        public String  referenceSource;   // WHERE it was found: Aura markup / FlexiPage / Flow / Tab
        public Boolean isTopLevelApp;     // DefType=APPLICATION → entry point via URL, never unreferenced
        public Boolean isExposedTab;      // Has a custom tab → entry point
        public Boolean isManagedPackage;  // Namespace != org namespace → never delete
        public String  safetyStatus;      // SAFE_TO_REVIEW / ENTRY_POINT / MANAGED / IN_USE
    }

    public class AuraSummary {
        public Integer                 total;
        public Integer                 withNamespace;
        public Integer                 withoutNamespace;
        public Integer                 unreferencedCount;
        public List<AuraComponentInfo> allComponents;
        public List<AuraComponentInfo> filteredComponents;
        public List<AuraComponentInfo> unreferencedComponents;
        public String                  namespaceFilter;
    }

    // ===============================
    // WRAPPERS — PROFILES
    // ===============================
    public class ProfileInfo {
        public String  id;
        public String  name;
        public String  userLicenseName;
        public Integer assignedUserCount;
        public Boolean isCustom;
        // Enhanced fields
        public Boolean isSystemProfile;  // System Admin / Guest / Chatter → never delete
        public String  safetyStatus;     // IN_USE / SYSTEM / UNASSIGNED / SAFE_TO_REVIEW
    }

    public class ProfileSummary {
        public Integer           total;
        public Integer           unused;
        public Integer           used;
        public Integer           customCount;
        public Integer           standardCount;
        public List<ProfileInfo> unusedProfiles;
        public List<ProfileInfo> usedProfiles;
        public List<ProfileInfo> customProfiles;
        public List<ProfileInfo> standardProfiles;
        public List<ProfileInfo> filteredProfiles;
        public Integer           filteredTotal;
        public String            namespaceFilter;
    }

    // ===============================
    // WRAPPERS — PERMISSION SETS
    // ===============================
    public class PermissionSetInfo {
        public String  id;
        public String  name;
        public String  label;
        public Boolean isCustom;
        public Integer assignmentCount;
        public String  namespacePrefix;
        // Enhanced fields
        public Boolean isManagedPackage;  // Namespace present → never delete
        public String  safetyStatus;      // IN_USE / MANAGED / SAFE_TO_REVIEW
    }

    public class PermissionSetSummary {
        public Integer                 total;
        public Integer                 unused;
        public Integer                 used;
        public Integer                 withNamespace;
        public Integer                 withoutNamespace;
        public Integer                 filteredTotal;
        public String                  namespaceFilterApplied;
        public List<PermissionSetInfo> allPermSets;
        public List<PermissionSetInfo> unusedPermSets;
        public List<PermissionSetInfo> usedPermSets;
        public List<PermissionSetInfo> filteredPermSets;
    }

    // ===============================
    // WRAPPERS — CUSTOM FIELDS
    // ===============================
    public class CustomFieldInfo {
        public String  id;
        public String  name;
        public String  objectName;
        public String  dataType;
        public String  namespacePrefix;
        public String  lastModifiedDate;
        public Boolean hasData;
        public Integer nonNullCount;
        // Enhanced fields
        public Boolean isManagedPackage;   // Namespace present → never delete
        public Boolean isRequiredField;    // Required fields should not be deleted blindly
        public String  safetyStatus;       // IN_USE / MANAGED / HAS_DATA / SAFE_TO_REVIEW
    }

    public class CustomFieldSummary {
        public Integer               total;
        public Integer               withNamespace;
        public Integer               withoutNamespace;
        public Integer               emptyCount;
        public List<CustomFieldInfo> allFields;
        public List<CustomFieldInfo> filteredFields;
        public List<CustomFieldInfo> emptyFields;
        public String                namespaceFilter;
    }

    // ===============================
    // WRAPPERS — CUSTOM OBJECTS
    // ===============================
    public class CustomObjectInfo {
        public String  id;
        public String  name;
        public String  label;
        public String  namespacePrefix;
        public String  lastModifiedDate;
        public Integer recordCount;
        public Boolean isEmpty;
        // Enhanced fields
        public Boolean isManagedPackage;   // Namespace present → never delete
        public Boolean isReferencedByCode; // Found in MetadataComponentDependency
        public String  safetyStatus;       // IN_USE / MANAGED / HAS_DATA / SAFE_TO_REVIEW
    }

    public class CustomObjectSummary {
        public Integer                total;
        public Integer                withNamespace;
        public Integer                withoutNamespace;
        public Integer                emptyCount;
        public List<CustomObjectInfo> allObjects;
        public List<CustomObjectInfo> filteredObjects;
        public List<CustomObjectInfo> emptyObjects;
        public String                 namespaceFilter;
    }

    // ===============================
    // WRAPPERS — VALIDATION RULES
    // ===============================
    public class ValidationRuleInfo {
        public String  id;
        public String  name;
        public String  objectName;
        public Boolean isActive;
        public String  errorMessage;
        public String  namespacePrefix;
        public String  lastModifiedDate;
        // Enhanced fields
        public Boolean isManagedPackage;  // Namespace present → never delete
        public String  safetyStatus;      // IN_USE / INACTIVE / MANAGED / SAFE_TO_REVIEW
    }

    public class ValidationRuleSummary {
        public Integer                  total;
        public Integer                  active;
        public Integer                  inactive;
        public List<ValidationRuleInfo> activeRules;
        public List<ValidationRuleInfo> inactiveRules;
        public List<ValidationRuleInfo> filteredRules;
        public String                   namespaceFilter;
    }

    // ===============================
    // WRAPPERS — TRIGGERS
    // ===============================
    public class TriggerInfo {
        public String  id;
        public String  name;
        public String  objectName;
        public Boolean isActive;
        public Integer linesOfCode;
        public String  lastModifiedDate;
        public String  namespacePrefix;
        // Enhanced fields
        public Boolean isManagedPackage;  // Namespace present → never delete
        public Boolean hasHandlerClass;   // References a handler/helper Apex class
        public String  handlerClassName;   // Name of the handler/helper Apex class called by this trigger
        public Boolean isInDependency;    // Found in MetadataComponentDependency
        public String  safetyStatus;      // IN_USE / INACTIVE / EMPTY / MANAGED / SAFE_TO_REVIEW
    }

    public class TriggerSummary {
        public Integer           total;
        public Integer           active;
        public Integer           inactive;
        public Integer           used;
        public Integer           unused;
        public List<TriggerInfo> activeTriggers;
        public List<TriggerInfo> inactiveTriggers;
        public List<TriggerInfo> unusedTriggers;
        public List<String>      usedTriggerNames;
        public Integer           filteredTotal;
        public List<TriggerInfo> filteredTriggers;
        public String            namespaceFilter;
    }

    // ===============================
    // GET FLOWS
    // ===============================
    public static FlowSummary getFlows(String namespaceFilter) {

        Http         http               = new Http();
        List<String>             activeFlows           = new List<String>();
        List<String>             inactiveFlows         = new List<String>();
        List<String>             filteredActiveFlows   = new List<String>();
        List<String>             filteredInactiveFlows = new List<String>();
        List<MetadataEngine.FlowInfo> allFlowObjects   = new List<MetadataEngine.FlowInfo>();

        String soql = 'SELECT Label, ApiName, IsActive, ProcessType, NamespacePrefix, DurableId ' +
                      'FROM FlowDefinitionView ' +
                      'WHERE ProcessType != \'StandardInvocableAction\'';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) response.get('records');

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec      = (Map<String, Object>) obj;
                    Boolean             isActive = (Boolean) rec.get('IsActive');
                    String              label    = (String)  rec.get('Label');
                    String              apiName  = (String)  rec.get('ApiName');
                    String              procType = (String)  rec.get('ProcessType');
                    String              nsPrefix = (String)  rec.get('NamespacePrefix');
                    String              durId    = (String)  rec.get('DurableId');

                    String flowLabel = label + ' [' + procType + '] (' + apiName + ')' +
                                       (String.isNotBlank(nsPrefix) ? ' [ns:' + nsPrefix + ']' : '');

                    MetadataEngine.FlowInfo fi = new MetadataEngine.FlowInfo();
                    fi.apiName        = apiName;
                    fi.label          = label;
                    fi.processType    = procType;
                    fi.isActive       = isActive;
                    fi.namespacePrefix = nsPrefix;
                    fi.durableId      = durId;
                    allFlowObjects.add(fi);

                    if (isActive) {
                        activeFlows.add(flowLabel);
                    } else {
                        inactiveFlows.add(flowLabel);
                    }

                    String  flowNs = nsPrefix == null ? '' : nsPrefix;
                    String  flowNm = apiName == null ? '' : apiName.toLowerCase();
                    String  nsL    = namespaceFilter == null ? '' : namespaceFilter.toLowerCase();
                    Boolean matchesFilter = String.isBlank(namespaceFilter) || nsL.equalsIgnoreCase(flowNs) ||
                        flowNm.startsWith(nsL + '_') || (flowNm.startsWith(nsL) && flowNm.length() > nsL.length() &&
                        flowNm.substring(nsL.length(), nsL.length()+1) != flowNm.substring(nsL.length(), nsL.length()+1).toLowerCase());

                    if (matchesFilter) {
                        if (isActive) {
                            filteredActiveFlows.add(flowLabel);
                        } else {
                            filteredInactiveFlows.add(flowLabel);
                        }
                    }
                }
            }
        }

        Set<String> subflowRefs = new Set<String>();
        try {
            // FIX: RefMetadataComponentName is unreliable in many orgs — use RefMetadataComponentId
            // and cross-reference with the FlowDefinitionView.DurableId we already have.
            String depSoql = 'SELECT RefMetadataComponentId FROM MetadataComponentDependency ' +
                             'WHERE RefMetadataComponentType = \'Flow\'';
            HttpRequest depReq = new HttpRequest();
            depReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(depSoql, 'UTF-8'));
            depReq.setMethod('GET');
            depReq.setHeader('Content-Type', 'application/json');
            depReq.setTimeout(TIMEOUT_LONG);
            HttpResponse depRes = http.send(depReq);
            if (depRes.getStatusCode() >= 200 && depRes.getStatusCode() < 300) {
                Map<String, Object> depBody    = (Map<String, Object>) JSON.deserializeUntyped(depRes.getBody());
                List<Object>        depRecords = (List<Object>) depBody.get('records');
                if (depRecords != null) {
                    for (Object r : depRecords) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              refId = (String) row.get('RefMetadataComponentId');
                        if (String.isNotBlank(refId)) subflowRefs.add(refId.toLowerCase());
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'subflow check failed — continue: ' + ex.getMessage()); }

        for (MetadataEngine.FlowInfo fi : allFlowObjects) {
            Boolean isManaged   = String.isNotBlank(fi.namespacePrefix);
            // Match by DurableId — RefMetadataComponentId stores the DurableId for flows
            Boolean isSubflow   = String.isNotBlank(fi.durableId) &&
                                  subflowRefs.contains(fi.durableId.toLowerCase());
            Boolean isScheduled = 'ScheduledFlow'.equalsIgnoreCase(fi.processType) ||
                                  'AutoLaunchedFlow'.equalsIgnoreCase(fi.processType) ||
                                  'RecordTriggeredFlow'.equalsIgnoreCase(fi.processType);

            fi.isManagedPackage = isManaged;
            fi.isCalledByFlow   = isSubflow;
            fi.isScheduled      = isScheduled;

            if (isManaged) {
                fi.safetyStatus = 'MANAGED';
            } else if (!fi.isActive) {
                fi.safetyStatus = 'INACTIVE';
            } else if (isScheduled) {
                fi.safetyStatus = 'SCHEDULED';
            } else if (isSubflow) {
                fi.safetyStatus = 'IN_USE';
            } else {
                fi.safetyStatus = 'SAFE_TO_REVIEW';
            }
        }

        FlowSummary summary           = new FlowSummary();
        summary.active                = activeFlows.size();
        summary.inactive              = inactiveFlows.size();
        summary.total                 = summary.active + summary.inactive;
        summary.activeFlows           = activeFlows;
        summary.inactiveFlows         = inactiveFlows;
        summary.filteredActiveFlows   = filteredActiveFlows;
        summary.filteredInactiveFlows = filteredInactiveFlows;
        summary.filteredTotal         = filteredActiveFlows.size() + filteredInactiveFlows.size();
        summary.namespaceFilter       = namespaceFilter;
        summary.allFlowObjects        = allFlowObjects;

        return summary;
    }

    // ===============================
    // SAFETY CHECK HELPER
    // ===============================
    private static DeleteResult checkSafetyBeforeDelete(String safetyStatus, String componentLabel) {
        if (String.isBlank(safetyStatus)) return null;
        String s = safetyStatus.toUpperCase();
        DeleteResult block = new DeleteResult();
        if (s == 'MANAGED') {
            block.success = false;
            block.message = 'Blocked: "' + componentLabel + '" belongs to a managed package and cannot be deleted from this org.';
            return block;
        }
        if (s == 'ENTRY_POINT') {
            block.success = false;
            block.message = 'Blocked: "' + componentLabel + '" is an entry point (custom tab or top-level app) and is actively in use.';
            return block;
        }
        if (s == 'TEST_CLASS') {
            // Don't block here — let deleteApexClassByName handle it with full Test Suite lookup
            return null;
        }
        if (s == 'IN_USE') {
            block.success = false;
            block.message = 'Blocked: "' + componentLabel + '" is currently in use (referenced by another component, flow, or active user). Remove all references first.';
            return block;
        }
        if (s == 'SYSTEM') {
            block.success = false;
            block.message = 'Blocked: "' + componentLabel + '" is a system profile and cannot be deleted.';
            return block;
        }
        if (s == 'HAS_DATA') {
            block.success = false;
            block.message = 'Blocked: "' + componentLabel + '" contains data records or populated field values. Deleting it will permanently destroy that data. Remove or migrate all data first, then retry.';
            return block;
        }
        return null;
    }
    // ===============================
    // DELETE FLOW BY API NAME
    // ===============================

    // ── renderFlowInterviewOnlyMessage ───────────────────────────────────────
    //
    // Special-case renderer used when the ONLY thing blocking a flow delete
    // is one or more running/paused Flow Interviews.
    //
    // Why a separate message instead of the standard "N reference(s) must be
    // removed first" report:
    //   • A Flow Interview is a LIVE runtime instance, not a metadata
    //     reference.  Telling the user to "remove the reference" is wrong.
    //   • The fix is operational, not metadata: finish the interview, OR
    //     delete the FlowInterview row.  Standard report doesn't say either.
    //   • The generic group-listed format buries the actual action under
    //     boilerplate ("Tip: Setup > Flows > … > View Dependencies" — which
    //     does NOT show interviews) that's actively misleading here.
    //
    // Used by both:
    //   • the pre-delete blocking path  (deleteFlowByApiName, step 3)
    //   • the post-error fallback path  (deleteFlowByApiName, after version
    //     delete attempt returned DEPENDENCY_EXISTS)
    // ────────────────────────────────────────────────────────────────────────
    @TestVisible
    private static String renderFlowInterviewOnlyMessage(
            String flowLabel, List<ReferenceItem> interviewRefs, Boolean isActive) {
        Integer n = interviewRefs == null ? 0 : interviewRefs.size();

        // Collect interview Ids for the inline cleanup snippet.
        List<String> deleteIds = new List<String>();
        if (interviewRefs != null) {
            for (ReferenceItem ri : interviewRefs) {
                if (ri == null) continue;
                String nm = ri.name;
                if (nm != null && nm.contains('[Id: ')) {
                    String idPart = nm.substringAfter('[Id: ');
                    if (idPart.contains(']')) {
                        idPart = idPart.substringBefore(']').trim();
                        if (String.isNotBlank(idPart)) deleteIds.add(idPart);
                    }
                }
                if (deleteIds.isEmpty() && nm != null &&
                    nm.length() >= 15 && nm.length() <= 18 && nm.startsWithIgnoreCase('0Fo')) {
                    deleteIds.add(nm.trim());
                }
            }
        }

        // ── Build the message: ACTION-FIRST, minimal explanation ──
        //
        // The user just hit "delete" and saw it fail. The message should
        // answer in the order they're asking:
        //   1. What happened?  → "Delete blocked."
        //   2. Why?            → "A user has a paused interview in this flow."
        //   3. What now?       → one clear action.
        //
        // Old version led with "⏸️ Flow X has N interview(s)" and a wall
        // of explanation about what an interview is.  That sounded like
        // info, not an error — confusing when paired with a "Failed" tag.
        String word = (n == 1) ? 'interview' : 'interviews';

        String msg = '❌ Cannot delete "' + flowLabel + '" — ' + n +
                     ' user-started flow ' + word + ' still ' +
                     (n == 1 ? 'exists' : 'exist') + '.\n\n';

        msg += 'Paused ' + word + ':\n';
        if (interviewRefs != null) {
            for (ReferenceItem ri : interviewRefs) {
                if (ri == null) continue;
                msg += '  • ' + (ri.name == null ? '(unnamed)' : ri.name) + '\n';
            }
        }

        msg += '\nTo fix — pick ONE:\n' +
               '  (a) Ask the user to finish ' + (n == 1 ? 'it' : 'them') +
                   ' in their app, OR\n' +
               '  (b) Setup → Paused Flow Interviews → delete ' +
                   (n == 1 ? 'the interview' : 'each interview') + ', OR\n' +
               '  (c) Run in Anonymous Apex:\n';
        if (!deleteIds.isEmpty() && deleteIds.size() <= 5) {
            msg += '        delete [SELECT Id FROM FlowInterview WHERE Id IN (\'' +
                   String.join(deleteIds, '\', \'') + '\')];\n';
        } else {
            msg += '        delete [SELECT Id FROM FlowInterview WHERE Id = \'<Id>\'];\n';
        }
        msg += '\nThen ask me to delete the flow again.';

        if (isActive) {
            msg += '\n\nNote: the flow is still ACTIVE. I have not deactivated it.';
        }
        return msg;
    }

    // ── flexiPageContainsFlow ────────────────────────────────────────────────
    //
    // Determines whether a FlexiPage's Metadata embeds the given flow.
    //
    // FlexiPage Metadata is structured like:
    //   {
    //     "flexiPageRegions": [
    //       {
    //         "componentInstances": [
    //           {
    //             "componentName": "flowruntime:interview",
    //             "componentInstanceProperties": [
    //               { "name": "flowName",   "value": "My_Flow_Api_Name" },
    //               { "name": "flowLayout", "value": "oneColumn" }
    //             ]
    //           },
    //           ...
    //         ]
    //       }
    //     ]
    //   }
    //
    // In API 49+ "componentInstances" was renamed to "itemInstances" and the
    // inner object wrapped in "componentInstance":
    //   "itemInstances": [
    //     { "componentInstance": {
    //         "componentName": "flowruntime:interview",
    //         "componentInstanceProperties": [...]
    //     } }
    //   ]
    //
    // What we look for at each "component-instance-like" node:
    //   - componentName is one of the known Flow-embedding components:
    //       flowruntime:interview            (the standard one)
    //       flowruntime:flowRuntime
    //       flow:runtime_flow_flexipage_component
    //       force:flowComponent
    //       force:flow
    //   - AND inside its property list there is a property named one of
    //       flowName / flowApiName / flowDefinition
    //     whose VALUE equals the flow's ApiName / label (case-insensitive).
    //
    // We walk the entire JSON tree recursively because regions can be
    // nested (sections, tabs, accordions all wrap their child components).
    // ────────────────────────────────────────────────────────────────────
    @TestVisible
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static Boolean flexiPageContainsFlow(Map<String, Object> meta,
                                                  String apiNameLower,
                                                  String labelLower,
                                                  String normLabelLower) {
        if (meta == null || String.isBlank(apiNameLower)) return false;
        return flexiNodeContainsFlow(meta, apiNameLower, labelLower, normLabelLower);
    }

    // Returns true iff this node (or any descendant) is a Flow component
    // referencing the target flow.
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static Boolean flexiNodeContainsFlow(Object node,
                                                   String apiNameLower,
                                                   String labelLower,
                                                   String normLabelLower) {
        if (node == null) return false;

        if (node instanceof Map<String, Object>) {
            Map<String, Object> m = (Map<String, Object>) node;

            // If this node has a componentName + a property list, check it
            // as a component-instance unit.
            Object cnObj = m.get('componentName');
            if (cnObj instanceof String) {
                String cnLower = ((String) cnObj).toLowerCase();
                Boolean isFlowComp =
                    cnLower == 'flowruntime:interview' ||
                    cnLower == 'flowruntime:flowruntime' ||
                    cnLower == 'flow:runtime_flow_flexipage_component' ||
                    cnLower == 'force:flowcomponent' ||
                    cnLower == 'force:flow' ||
                    cnLower.endsWith(':flow') ||
                    cnLower.contains('runtime_flow') ||
                    cnLower.contains('flowruntime');

                if (isFlowComp) {
                    // Look for properties on THIS node (under either
                    // "componentInstanceProperties" or "itemInstanceProperties")
                    for (String propsKey : new List<String>{
                            'componentInstanceProperties',
                            'itemInstanceProperties',
                            'properties' }) {
                        Object propsObj = m.get(propsKey);
                        if (propsObj instanceof List<Object>) {
                            for (Object p : (List<Object>) propsObj) {
                                if (!(p instanceof Map<String, Object>)) continue;
                                Map<String, Object> pm = (Map<String, Object>) p;
                                Object pn = pm.get('name');
                                Object pv = pm.get('value');
                                if (!(pn instanceof String) || !(pv instanceof String)) continue;
                                String pnL = ((String) pn).toLowerCase();
                                String pvL = ((String) pv).trim().toLowerCase();
                                if (pnL == 'flowname' || pnL == 'flowapiname' ||
                                    pnL == 'flow'     || pnL == 'flowdefinition') {
                                    if (pvL == apiNameLower) return true;
                                    if (String.isNotBlank(labelLower) && pvL == labelLower) return true;
                                    if (String.isNotBlank(normLabelLower) && pvL == normLabelLower) return true;
                                }
                            }
                        }
                    }
                }
            }

            // Recurse into all child values regardless — flow components
            // can live arbitrarily deep inside facets, sections, regions.
            for (Object v : m.values()) {
                if (flexiNodeContainsFlow(v, apiNameLower, labelLower, normLabelLower)) {
                    return true;
                }
            }
            return false;
        }

        if (node instanceof List<Object>) {
            for (Object item : (List<Object>) node) {
                if (flexiNodeContainsFlow(item, apiNameLower, labelLower, normLabelLower)) {
                    return true;
                }
            }
        }
        return false;
    }

    // ── checkAllFlowReferences ────────────────────────────────────────────────
    //
    // Dedicated, exhaustive reference scan for a Flow before any delete attempt.
    //
    // WHY a separate method instead of inlining in deleteFlowByApiName:
    //   getReferencesFor() intentionally skips Id resolution for Flow and falls
    //   through to a name-only MCD query.  That works when MCD indexed the flow
    //   by ApiName, but fails when:
    //     • The name has spaces that were normalised to underscores (MCD may still
    //       store the original label string, or nothing at all for that key).
    //     • The flow is referenced only via FlexiPage body / subflow body / Process
    //       Builder nodes — none of which appear in MCD.
    //     • Active interviews or scheduled jobs exist (runtime state, not metadata).
    //
    // This method queries ALL of those sources and deduplicates across them:
    //   1.  MCD by 18-char Id  (FlowDefinitionView.Id)
    //   2.  MCD by DurableId   (15-char, belt-and-suspenders)
    //   3.  MCD by normalised ApiName  (RefMetadataComponentType IN Flow, FlowDefinition)
    //   4.  MCD by Label       (some orgs index by Label, not ApiName)
    //   5.  Subflow body scan  — Flow Metadata WHERE type = SubflowElement referencing this flow
    //   6.  FlexiPage body scan — App Builder pages embedding this flow
    //   7.  Active FlowInterviews (paused / waiting runs)
    //   8.  CronTrigger scheduled jobs for this flow
    //   9.  GenAiFunction (Agentforce Agent Actions)
    //  10.  Approval Processes — ApprovalProcess action step invoking the flow
    //  11.  Quick Actions — FlowAction type quick actions
    //  12.  Einstein Bots (BotVersion) — bot dialog steps that invoke flows
    //  13.  Experience Cloud pages (CommApp/CommFlex FlexiPage types)
    //  14.  Workflow Rules — FlowAction workflow actions (classic)
    //  15.  Process Builder (ProcessDefinition) — process nodes calling this flow as subprocess
    //  16.  Custom Permissions — permissions gating flow access
    //
    // Parameters (all resolved by the caller from FlowDefinitionView):
    //   flowId18   — 18-char Id  (FlowDefinitionView.Id)
    //   durableId  — 15-char DurableId  (FlowDefinitionView.DurableId)
    //   apiName    — normalised ApiName  (spaces already replaced with underscores)
    //   flowLabel  — human-readable Label (FlowDefinitionView.Label)
    //
    // Returns a de-duplicated List<ReferenceItem> (empty = safe to delete).
    // ─────────────────────────────────────────────────────────────────────────
    @TestVisible
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static List<ReferenceItem> checkAllFlowReferences(
            String flowId18, String durableId, String apiName, String flowLabel) {

        Http                http        = new Http();
        List<ReferenceItem> refs        = new List<ReferenceItem>();
        Set<String>         seenKeys    = new Set<String>();

        // Helper: add an item only if not yet seen
        // (inline closure not available in Apex — use a flag check pattern)
        // ── 1 & 2: MCD by Id (18-char) and by DurableId (15-char) ────────────
        for (String refId : new List<String>{ flowId18, durableId }) {
            if (String.isBlank(refId)) continue;
            try {
                String soql =
                    'SELECT MetadataComponentName, MetadataComponentType ' +
                    'FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentId = \'' + String.escapeSingleQuotes(refId) + '\' ' +
                    'AND MetadataComponentName != \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                    'ORDER BY MetadataComponentType, MetadataComponentName ' +
                    'LIMIT 200';
                HttpRequest req = new HttpRequest();
                req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
                req.setMethod('GET');
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(TIMEOUT_LONG);
                HttpResponse res = http.send(req);
                if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> recs = (List<Object>) body.get('records');
                    if (recs != null) {
                        for (Object r : recs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String cName = (String) row.get('MetadataComponentName');
                            String cType = (String) row.get('MetadataComponentType');
                            if (String.isBlank(cName) || String.isBlank(cType)) continue;
                            String dk = (cType + '|' + cName).toLowerCase();
                            if (!seenKeys.contains(dk)) { seenKeys.add(dk); refs.add(buildReferenceItem(cName, cType)); }
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'checkAllFlowReferences MCD by Id (' + refId + ') skipped: ' + ex.getMessage());
            }
        }

        // ── 3: MCD by normalised ApiName ──────────────────────────────────────
        // Catches orgs where MCD indexed the flow by ApiName rather than Id.
        // RefMetadataComponentType can be 'Flow' or 'FlowDefinition' — query both.
        try {
            String soqlByName =
                'SELECT MetadataComponentName, MetadataComponentType ' +
                'FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                'AND RefMetadataComponentType IN (\'Flow\', \'FlowDefinition\') ' +
                'AND MetadataComponentName != \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                'ORDER BY MetadataComponentType, MetadataComponentName ' +
                'LIMIT 200';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soqlByName, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> recs = (List<Object>) body.get('records');
                if (recs != null) {
                    for (Object r : recs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String cName = (String) row.get('MetadataComponentName');
                        String cType = (String) row.get('MetadataComponentType');
                        if (String.isBlank(cName) || String.isBlank(cType)) continue;
                        String dk = (cType + '|' + cName).toLowerCase();
                        if (!seenKeys.contains(dk)) { seenKeys.add(dk); refs.add(buildReferenceItem(cName, cType)); }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences MCD by ApiName skipped: ' + ex.getMessage());
        }

        // ── 4: MCD by Label ───────────────────────────────────────────────────
        // Some orgs (particularly older API versions or Process Builder-era flows)
        // index the flow under its Label rather than its normalised ApiName.
        // Only run if Label differs from ApiName (i.e. the label has spaces or
        // differs in casing).
        String normalisedLabel = flowLabel != null ? flowLabel.trim().replace(' ', '_') : null;
        if (String.isNotBlank(normalisedLabel) && !normalisedLabel.equalsIgnoreCase(apiName)) {
            for (String candidate : new List<String>{ flowLabel.trim(), normalisedLabel }) {
                try {
                    String soqlByLabel =
                        'SELECT MetadataComponentName, MetadataComponentType ' +
                        'FROM MetadataComponentDependency ' +
                        'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(candidate) + '\' ' +
                        'AND RefMetadataComponentType IN (\'Flow\', \'FlowDefinition\') ' +
                        'AND MetadataComponentName != \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                        'ORDER BY MetadataComponentType, MetadataComponentName ' +
                        'LIMIT 200';
                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soqlByLabel, 'UTF-8'));
                    req.setMethod('GET');
                    req.setHeader('Content-Type', 'application/json');
                    req.setTimeout(TIMEOUT_LONG);
                    HttpResponse res = http.send(req);
                    if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                        List<Object> recs = (List<Object>) body.get('records');
                        if (recs != null) {
                            for (Object r : recs) {
                                Map<String, Object> row = (Map<String, Object>) r;
                                String cName = (String) row.get('MetadataComponentName');
                                String cType = (String) row.get('MetadataComponentType');
                                if (String.isBlank(cName) || String.isBlank(cType)) continue;
                                String dk = (cType + '|' + cName).toLowerCase();
                                if (!seenKeys.contains(dk)) { seenKeys.add(dk); refs.add(buildReferenceItem(cName, cType)); }
                            }
                        }
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.WARN, 'checkAllFlowReferences MCD by label "' + candidate + '" skipped: ' + ex.getMessage());
                }
            }
        }

        // ── 5: Subflow body scan ──────────────────────────────────────────────
        // MCD does not always register subflow → parent-flow edges.
        // Query active flow Metadata for SubflowElement nodes referencing this flow.
        // We use FlowDefinitionView (not FlowDefinition) because it is queryable via
        // the standard REST /query endpoint without Tooling API.
        // Limit to active flows to keep cost reasonable; inactive callers cannot
        // actually trigger the flow anyway.
        try {
            String subflowSoql =
                'SELECT Id, ApiName, Label FROM FlowDefinitionView WHERE IsActive = true LIMIT 200';
            HttpRequest sfReq = new HttpRequest();
            sfReq.setEndpoint(BASE_URL + 'query?q=' + EncodingUtil.urlEncode(subflowSoql, 'UTF-8'));
            sfReq.setMethod('GET');
            sfReq.setHeader('Content-Type', 'application/json');
            sfReq.setTimeout(TIMEOUT_LONG);
            HttpResponse sfRes = http.send(sfReq);
            if (sfRes.getStatusCode() >= 200 && sfRes.getStatusCode() < 300) {
                Map<String, Object> sfBody = (Map<String, Object>) JSON.deserializeUntyped(sfRes.getBody());
                List<Object> sfRecs = (List<Object>) sfBody.get('records');
                if (sfRecs != null) {
                    // Collect Ids of active flows so we can fetch their Metadata bodies
                    List<String> activeFlowDurableIds = new List<String>();
                    Map<String, String> idToApiName   = new Map<String, String>();
                    Map<String, String> idToLabel      = new Map<String, String>();
                    for (Object r : sfRecs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String fId  = (String) row.get('Id');
                        String fApi = (String) row.get('ApiName');
                        String fLbl = (String) row.get('Label');
                        // Skip the flow we are about to delete — it cannot call itself via subflow
                        if (String.isBlank(fId) || apiName.equalsIgnoreCase(fApi)) continue;
                        activeFlowDurableIds.add(fId);
                        idToApiName.put(fId, fApi);
                        idToLabel.put(fId, fLbl);
                    }
                    // Fetch Metadata in batches; a single IN list avoids multiple callouts.
                    // FlowDefinition.Metadata is a Tooling API compound field.
                    if (!activeFlowDurableIds.isEmpty()) {
                        // Build a quoted CSV for the IN clause (Tooling SOQL, not SOSL)
                        List<String> quotedIds = new List<String>();
                        for (String fId : activeFlowDurableIds) {
                            quotedIds.add('\'' + fId + '\'');
                        }
                        String metaSoql =
                            'SELECT DurableId, Metadata FROM FlowDefinition WHERE DurableId IN (' +
                            String.join(quotedIds, ',') + ') LIMIT 200';
                        HttpRequest metaReq = new HttpRequest();
                        metaReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(metaSoql, 'UTF-8'));
                        metaReq.setMethod('GET');
                        metaReq.setHeader('Content-Type', 'application/json');
                        metaReq.setTimeout(TIMEOUT_LONG);
                        HttpResponse metaRes = http.send(metaReq);
                        if (metaRes.getStatusCode() >= 200 && metaRes.getStatusCode() < 300) {
                            Map<String, Object> metaBody = (Map<String, Object>) JSON.deserializeUntyped(metaRes.getBody());
                            List<Object> metaRecs = (List<Object>) metaBody.get('records');
                            if (metaRecs != null) {
                                for (Object mr : metaRecs) {
                                    Map<String, Object> mRow = (Map<String, Object>) mr;
                                    String mId   = (String) mRow.get('DurableId');
                                    Object meta  = mRow.get('Metadata');
                                    if (meta == null) continue;
                                    // Serialise to string for a fast contains() check
                                    String metaStr = JSON.serialize(meta).toLowerCase();
                                    // Look for any reference to this flow's apiName or label in
                                    // subflow node targets (both underscore and space variants)
                                    Boolean found = metaStr.contains(apiName.toLowerCase());
                                    if (!found && String.isNotBlank(normalisedLabel)) {
                                        found = metaStr.contains(normalisedLabel.toLowerCase());
                                    }
                                    if (!found && String.isNotBlank(flowLabel)) {
                                        found = metaStr.contains(flowLabel.trim().toLowerCase());
                                    }
                                    if (found) {
                                        String callerApi = idToApiName.get(mId);
                                        String callerLbl = idToLabel.get(mId);
                                        if (String.isBlank(callerApi)) callerApi = mId;
                                        String dk = ('flow|subflow|' + callerApi).toLowerCase();
                                        if (!seenKeys.contains(dk)) {
                                            seenKeys.add(dk);
                                            ReferenceItem item = new ReferenceItem();
                                            item.name         = (String.isNotBlank(callerLbl) ? callerLbl : callerApi) +
                                                                ' (' + callerApi + ')';
                                            item.type         = 'Flow';
                                            item.groupLabel   = 'Flows (Subflow Caller)';
                                            item.relationship = 'calls this flow as a Subflow element';
                                            refs.add(item);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences subflow body scan skipped: ' + ex.getMessage());
        }

        // ── 6: FlexiPage body scan ────────────────────────────────────────────
        // App Builder pages (FlexiPage) can embed a Flow in a Flow component.
        // MCD does not always capture this edge.
        //
        // FIX: previous code did a naive `.toLowerCase().contains(apiName)` over
        // the serialised JSON.  That:
        //   • produced false positives on partial-name matches,
        //   • produced false negatives when the label had spaces (apiName had
        //     underscores but the FlexiPage stored the flow by its API name only),
        //   • ignored FlexiPage.Type so it couldn't tell users WHICH kind of
        //     page is blocking (Record Page vs App Page vs Home Page vs
        //     Community page), and
        //   • didn't show users WHICH object's record page is involved.
        //
        // New approach:
        //   1. Pull `Type` and `EntityDefinitionId` (sObject for RecordPage) too.
        //   2. Walk the Metadata JSON properly — look at every node with a
        //      `componentName` ending in `:flow` or `flow:runtime_flow` etc.
        //      and check its `componentInstanceProperties` / `itemInstances`
        //      for `flowApiName` / `flowName` whose value EXACTLY matches the
        //      flow ApiName (case-insensitive, after underscore-normalisation).
        //   3. Build a group label specific to the FlexiPage Type:
        //          RecordPage → "Lightning Record Pages (FlexiPage)"
        //          AppPage    → "Lightning App Pages (FlexiPage)"
        //          HomePage   → "Lightning Home Pages (FlexiPage)"
        //          CommApp/CommFlex/CommPage → handled in check #13 below
        //   4. For RecordPage, append the sObject name so the user sees
        //      "Account Record Page: MyAccountPage" instead of just a name.
        try {
            String flexiSoql = 'SELECT Id, DeveloperName, MasterLabel, Type, EntityDefinitionId, Metadata ' +
                               'FROM FlexiPage LIMIT 300';
            HttpRequest fpReq = new HttpRequest();
            fpReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(flexiSoql, 'UTF-8'));
            fpReq.setMethod('GET');
            fpReq.setHeader('Content-Type', 'application/json');
            fpReq.setTimeout(TIMEOUT_LONG);
            HttpResponse fpRes = http.send(fpReq);

            // Resolve EntityDefinition Ids → DeveloperName (object label) in one extra call
            Map<String, String> entityIdToName = new Map<String, String>();
            if (fpRes.getStatusCode() >= 200 && fpRes.getStatusCode() < 300) {
                Map<String, Object> fpBody = (Map<String, Object>) JSON.deserializeUntyped(fpRes.getBody());
                List<Object> fpRecs = (List<Object>) fpBody.get('records');
                if (fpRecs != null) {
                    Set<String> entityIds = new Set<String>();
                    for (Object r : fpRecs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String eid = (String) row.get('EntityDefinitionId');
                        if (String.isNotBlank(eid)) entityIds.add(eid);
                    }
                    if (!entityIds.isEmpty()) {
                        try {
                            List<String> quoted = new List<String>();
                            for (String e : entityIds) {
                                quoted.add('\'' + e + '\'');
                            }
                            String entSoql = 'SELECT DurableId, QualifiedApiName FROM EntityDefinition WHERE DurableId IN (' +
                                             String.join(quoted, ',') + ') LIMIT 300';
                            HttpRequest entReq = new HttpRequest();
                            entReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(entSoql, 'UTF-8'));
                            entReq.setMethod('GET');
                            entReq.setHeader('Content-Type', 'application/json');
                            entReq.setTimeout(TIMEOUT_LONG);
                            HttpResponse entRes = http.send(entReq);
                            if (entRes.getStatusCode() >= 200 && entRes.getStatusCode() < 300) {
                                Map<String, Object> entBody = (Map<String, Object>) JSON.deserializeUntyped(entRes.getBody());
                                List<Object> entRecs = (List<Object>) entBody.get('records');
                                if (entRecs != null) {
                                    for (Object er : entRecs) {
                                        Map<String, Object> erow = (Map<String, Object>) er;
                                        String did = (String) erow.get('DurableId');
                                        String qn  = (String) erow.get('QualifiedApiName');
                                        if (String.isNotBlank(did) && String.isNotBlank(qn)) {
                                            entityIdToName.put(did, qn);
                                        }
                                    }
                                }
                            }
                        } catch (Exception ex) {
                            System.debug(LoggingLevel.WARN, 'EntityDefinition lookup skipped: ' + ex.getMessage());
                        }
                    }

                    // Now walk each FlexiPage
                    String apiNameLower      = apiName.toLowerCase();
                    String labelLower        = String.isNotBlank(flowLabel) ? flowLabel.trim().toLowerCase() : null;
                    String normLabelLower    = String.isNotBlank(normalisedLabel) ? normalisedLabel.toLowerCase() : null;

                    for (Object r : fpRecs) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String fpName              = (String) row.get('DeveloperName');
                        String fpMaster            = (String) row.get('MasterLabel');
                        String fpType              = (String) row.get('Type');
                        String fpEntityId          = (String) row.get('EntityDefinitionId');
                        Object meta                = row.get('Metadata');
                        if (String.isBlank(fpName) || meta == null) continue;

                        // PRIMARY: Walk the metadata JSON, looking for a Flow
                        // component whose property `flowName`/`flowApiName` is
                        // this flow.
                        Boolean matched = flexiPageContainsFlow((Map<String, Object>) meta,
                                                                 apiNameLower, labelLower, normLabelLower);

                        // FALLBACK: in case Salesforce changed the JSON shape
                        // or wraps the flow ref differently in a particular
                        // org/API version, do a textual check for the EXACT
                        // patterns Salesforce uses to encode the flow ref:
                        //   "flowName" ... "value":"<apiName>"
                        //   "flowApiName" ... "value":"<apiName>"
                        // The two-step contains() guards against the flow's
                        // ApiName accidentally appearing in unrelated rich
                        // text (we require BOTH the flowName property name
                        // AND the value to be present, even if not adjacent).
                        if (!matched) {
                            try {
                                String metaJson = JSON.serialize(meta);
                                String metaLower = metaJson.toLowerCase();
                                Boolean hasFlowProp = metaLower.contains('"flowname"') ||
                                                      metaLower.contains('"flowapiname"');
                                if (hasFlowProp) {
                                    // Quote-wrapped value match — safer than bare contains
                                    String quotedApi   = '"' + apiNameLower + '"';
                                    String quotedLabel = String.isNotBlank(labelLower)     ? '"' + labelLower     + '"' : null;
                                    String quotedNorm  = String.isNotBlank(normLabelLower) ? '"' + normLabelLower + '"' : null;
                                    if (metaLower.contains(quotedApi) ||
                                        (quotedLabel != null && metaLower.contains(quotedLabel)) ||
                                        (quotedNorm  != null && metaLower.contains(quotedNorm))) {
                                        matched = true;
                                    }
                                }
                            } catch (Exception ex) {
                                System.debug(LoggingLevel.WARN,
                                    'FlexiPage string-fallback skipped on ' + fpName + ': ' + ex.getMessage());
                            }
                        }
                        if (!matched) continue;

                        // Build a Type-aware group label and name
                        String typeForGroup = String.isBlank(fpType) ? 'FlexiPage' : fpType;
                        String groupLabel;
                        if ('RecordPage'.equalsIgnoreCase(typeForGroup)) {
                            groupLabel = 'Lightning Record Pages (FlexiPage)';
                        } else if ('AppPage'.equalsIgnoreCase(typeForGroup)) {
                            groupLabel = 'Lightning App Pages (FlexiPage)';
                        } else if ('HomePage'.equalsIgnoreCase(typeForGroup)) {
                            groupLabel = 'Lightning Home Pages (FlexiPage)';
                        } else if ('CommApp'.equalsIgnoreCase(typeForGroup) ||
                                   'CommFlex'.equalsIgnoreCase(typeForGroup) ||
                                   'CommPage'.equalsIgnoreCase(typeForGroup)) {
                            groupLabel = 'Experience Cloud Pages (FlexiPage)';
                        } else {
                            groupLabel = 'App Builder Pages (FlexiPage)';
                        }

                        // Build a display name.  For RecordPage prepend the
                        // sObject so the user sees "Account Record Page: …".
                        String label = String.isNotBlank(fpMaster) ? fpMaster : fpName;
                        String displayName;
                        if ('RecordPage'.equalsIgnoreCase(typeForGroup)) {
                            String obj = String.isNotBlank(fpEntityId) ? entityIdToName.get(fpEntityId) : null;
                            if (String.isBlank(obj)) obj = 'Object';
                            displayName = obj + ' Record Page: ' + label + ' (' + fpName + ')';
                        } else {
                            displayName = label + ' (' + fpName + ', ' + typeForGroup + ')';
                        }

                        String dk = ('flexipage|' + fpName).toLowerCase();
                        if (!seenKeys.contains(dk)) {
                            seenKeys.add(dk);
                            ReferenceItem item = new ReferenceItem();
                            item.name         = displayName;
                            item.type         = 'FlexiPage';
                            item.groupLabel   = groupLabel;
                            item.relationship = 'embeds this Flow via a Flow component on the Lightning page — ' +
                                                'remove the Flow component from the page in Lightning App Builder ' +
                                                '(or unassign the page) before deleting';
                            refs.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences FlexiPage scan skipped: ' + ex.getMessage());
        }

        // ── 7: Active FlowInterviews (paused / waiting runs) ─────────────────
        // Runtime state — not captured in MCD at all.
        //
        // HISTORY:
        // v1: WHERE Name = :apiName.   ← WRONG. FlowInterview.Name is the
        //     interview's auto-id (e.g. "0FogK..."), not the flow's ApiName.
        // v2: WHERE FlowVersionView.FlowDefinitionViewId = :flowId18.
        //     ← Still wrong on most orgs.  The dotted SOQL path mixes a
        //     standard object (FlowInterview) with a Tooling-only object
        //     (FlowVersionView) in a way the standard SOQL parser rejects
        //     in some API versions, throwing MALFORMED_QUERY which the
        //     try/catch silently swallowed.
        //
        // v3 (THIS CODE):  Two-step.  First fetch FlowVersionView ids that
        // belong to this flow (via Tooling API), then filter
        // FlowInterview.FlowVersionViewId IN those ids via standard SOQL.
        // FlowInterview.FlowVersionViewId is a real, directly-queryable
        // field; it does NOT require traversing into Tooling.
        try {
            // Step 1: get the Tooling FlowVersionView Ids for THIS flow
            Set<String> versionIds = new Set<String>();
            try {
                String fvvSoql = 'SELECT Id, DurableId FROM FlowVersionView ' +
                                 'WHERE FlowDefinitionViewId = \'' +
                                 String.escapeSingleQuotes(flowId18) + '\' LIMIT 200';
                HttpRequest fvvReq = new HttpRequest();
                fvvReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                                   EncodingUtil.urlEncode(fvvSoql, 'UTF-8'));
                fvvReq.setMethod('GET');
                fvvReq.setHeader('Content-Type', 'application/json');
                fvvReq.setTimeout(TIMEOUT_LONG);
                HttpResponse fvvRes = http.send(fvvReq);
                if (fvvRes.getStatusCode() >= 200 && fvvRes.getStatusCode() < 300) {
                    Map<String, Object> fvvBody =
                        (Map<String, Object>) JSON.deserializeUntyped(fvvRes.getBody());
                    List<Object> fvvRecs = (List<Object>) fvvBody.get('records');
                    if (fvvRecs != null) {
                        for (Object r : fvvRecs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String vId = (String) row.get('Id');
                            String dId = (String) row.get('DurableId');
                            if (String.isNotBlank(vId)) versionIds.add(vId);
                            if (String.isNotBlank(dId)) versionIds.add(dId);
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN,
                    'checkAllFlowReferences FlowVersionView prefetch skipped: ' + ex.getMessage());
            }

            // Step 2: filter FlowInterview by those version ids (standard SOQL)
            // Note: CreatedBy.UserType is selected so we can classify each
            // interview as user-started ('Standard') vs system/automated
            // (AutomatedProcess / PlatformIntegration / etc.).  System ones
            // are skipped entirely — they represent automation noise, not
            // real work the user needs to know about.
            List<FlowInterview> interviews = new List<FlowInterview>();
            if (!versionIds.isEmpty()) {
                interviews = [
                    SELECT Id, Name, InterviewLabel, CurrentElement,
                           InterviewStatus, CreatedDate, CreatedBy.Name,
                           CreatedBy.UserType, PauseLabel
                    FROM FlowInterview
                    WHERE FlowVersionViewId IN :versionIds
                    LIMIT 50
                ];
            }

            // Step 3 (belt-and-braces): if step-2 returned nothing AND there
            // ARE interviews in the org, do a final scan filtering by
            // InterviewLabel containing the flow label.  FlowInterview's
            // CurrentElement and InterviewLabel often contain identifying
            // strings, and orgs in older API versions sometimes store the
            // flow's API name under InterviewLabel rather than the FK.
            // This is a CHEAP last-chance pass and won't fire on most orgs.
            if (interviews.isEmpty() && String.isNotBlank(flowLabel)) {
                try {
                    String like1 = '%' + flowLabel.trim() + '%';
                    String like2 = '%' + apiName + '%';
                    interviews = [
                        SELECT Id, Name, InterviewLabel, CurrentElement,
                               InterviewStatus, CreatedDate, CreatedBy.Name,
                               CreatedBy.UserType, PauseLabel
                        FROM FlowInterview
                        WHERE InterviewLabel LIKE :like1
                           OR InterviewLabel LIKE :like2
                        LIMIT 50
                    ];
                } catch (Exception ex) {
                    System.debug(LoggingLevel.WARN,
                        'checkAllFlowReferences FlowInterview label fallback skipped: ' + ex.getMessage());
                }
            }

            // Track counts for diagnostics (debug log only — not user-facing
            // unless a user-started interview is also found).
            Integer skippedSystemCount = 0;

            for (FlowInterview fi : interviews) {
                // ── CLASSIFICATION: only user-started interviews count ──
                // CreatedBy.UserType == 'Standard'  → real user → block delete
                // anything else (AutomatedProcess, PlatformIntegration, System,
                // Guest, CsnOnly, SelfService) → system/automated → IGNORE
                //
                // Rationale: a system-started interview is automation noise.
                // The user asked to delete a flow, not to reason about
                // background-process state they don't own.  We don't surface
                // it, we don't block on it, we don't auto-delete it.  If
                // Salesforce itself rejects the delete with a system
                // interview ID, the fallback path will surface it then
                // (with admin context) — but the pre-scan stays clean.
                String userType = (fi.CreatedBy != null) ? fi.CreatedBy.UserType : null;
                Boolean isUserStarted = 'Standard'.equalsIgnoreCase(userType);
                if (!isUserStarted) {
                    skippedSystemCount++;
                    continue;
                }

                String dk = ('flowinterview|' + fi.Id).toLowerCase();
                if (!seenKeys.contains(dk)) {
                    seenKeys.add(dk);
                    // Build a readable display name.  Prefer InterviewLabel,
                    // then PauseLabel, then the auto-id Name.
                    String displayName = fi.InterviewLabel;
                    if (String.isBlank(displayName)) displayName = fi.PauseLabel;
                    if (String.isBlank(displayName)) displayName = fi.Name;
                    String suffix = '';
                    if (String.isNotBlank(fi.CurrentElement)) {
                        suffix += ' (paused at: ' + fi.CurrentElement + ')';
                    } else if (String.isNotBlank(fi.InterviewStatus)) {
                        suffix += ' (status: ' + fi.InterviewStatus + ')';
                    }
                    if (fi.CreatedBy != null && String.isNotBlank(fi.CreatedBy.Name)) {
                        // Tag as (user) so the renderer's classifier picks it up.
                        suffix += ' — started by ' + fi.CreatedBy.Name + ' (user)';
                    }
                    ReferenceItem item = new ReferenceItem();
                    item.name         = displayName + suffix + ' [Id: ' + fi.Id + ']';
                    item.type         = 'FlowInterview';
                    item.groupLabel   = 'Active Flow Interviews (Running)';
                    item.relationship = 'Flow has a running/paused interview started by a real user — ' +
                                        'finish or delete the interview before deleting the flow. ' +
                                        'Setup → Paused Flow Interviews, or DELETE ' +
                                        'FROM FlowInterview WHERE Id = \'' + fi.Id + '\'';
                    refs.add(item);
                }
            }

            if (skippedSystemCount > 0) {
                System.debug(LoggingLevel.INFO,
                    'checkAllFlowReferences: skipped ' + skippedSystemCount +
                    ' system/automated FlowInterview(s) for flow ' + apiName +
                    ' — these are not blocking, but Salesforce may still reject ' +
                    'the delete if they are active. Fallback path will handle that.');
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences FlowInterview check skipped: ' + ex.getMessage());
        }

        // ── 8: Scheduled Jobs (CronTrigger) ──────────────────────────────────
        // A flow scheduled via the Apex Scheduler or Setup → Scheduled Jobs
        // appears in CronTrigger — not in MCD.  Match on Label (Salesforce uses
        // the flow label as the job name, not the ApiName).
        try {
            List<CronTrigger> cronJobs = [
                SELECT Id, CronJobDetail.Name, State
                FROM CronTrigger
                WHERE CronJobDetail.Name = :flowLabel
                AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING', 'PAUSED', 'BLOCKED')
                LIMIT 10
            ];
            for (CronTrigger ct : cronJobs) {
                String dk = ('cron|' + ct.Id).toLowerCase();
                if (!seenKeys.contains(dk)) {
                    seenKeys.add(dk);
                    ReferenceItem item = new ReferenceItem();
                    item.name         = ct.CronJobDetail.Name + ' (State: ' + ct.State + ')';
                    item.type         = 'ScheduledJob';
                    item.groupLabel   = 'Scheduled Jobs (Live)';
                    item.relationship = 'Flow is scheduled to run — deactivate the scheduled job first';
                    refs.add(item);
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences CronTrigger check skipped: ' + ex.getMessage());
        }

        // ── 9: GenAiFunction (Agentforce Agent Actions) ───────────────────────────
        // GenAiFunction is NOT indexed in MetadataComponentDependency — it is invisible
        // to all MCD queries above.  Query it directly via Tooling API and search the
        // serialised Metadata body for any reference to this flow's ApiName or Label.
        // This gives us the real action/agent name BEFORE the delete attempt, so the
        // user sees "My_Agent_Action (in: My_Agent_Topic)" instead of just "Action".
        try {
            // GenAiFunction rows: DeveloperName = action API name, MasterLabel = display name
            // Metadata body contains the invocable target (flow apiName or Apex class name)
            String genAiSoql = 'SELECT DeveloperName, MasterLabel, Metadata FROM GenAiFunction LIMIT 200';
            HttpRequest gafReq = new HttpRequest();
            gafReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(genAiSoql, 'UTF-8'));
            gafReq.setMethod('GET');
            gafReq.setHeader('Content-Type', 'application/json');
            gafReq.setTimeout(TIMEOUT_LONG);
            HttpResponse gafRes = http.send(gafReq);
            if (gafRes.getStatusCode() >= 200 && gafRes.getStatusCode() < 300) {
                Map<String, Object> gafBody = (Map<String, Object>) JSON.deserializeUntyped(gafRes.getBody());
                List<Object> gafRecs = (List<Object>) gafBody.get('records');
                if (gafRecs != null) {
                    for (Object r : gafRecs) {
                        Map<String, Object> row  = (Map<String, Object>) r;
                        String devName    = (String) row.get('DeveloperName');
                        String masterLbl  = (String) row.get('MasterLabel');
                        Object meta       = row.get('Metadata');
                        if (meta == null) continue;
                        String metaStr = JSON.serialize(meta).toLowerCase();
                        // Match on apiName (underscore form) or label (space form) or normalised label
                        Boolean found = metaStr.contains(apiName.toLowerCase());
                        if (!found && String.isNotBlank(normalisedLabel)) {
                            found = metaStr.contains(normalisedLabel.toLowerCase());
                        }
                        if (!found && String.isNotBlank(flowLabel)) {
                            found = metaStr.contains(flowLabel.trim().toLowerCase());
                        }
                        if (found) {
                            String displayName = String.isNotBlank(masterLbl) ? masterLbl : devName;
                            if (String.isNotBlank(devName) && !devName.equalsIgnoreCase(masterLbl)) {
                                displayName += ' (' + devName + ')';
                            }
                            String dk = ('genaifunction|' + devName).toLowerCase();
                            if (!seenKeys.contains(dk)) {
                                seenKeys.add(dk);
                                ReferenceItem item = new ReferenceItem();
                                item.name         = displayName;
                                item.type         = 'GenAiFunction';
                                item.groupLabel   = 'Agentforce - Agent Actions';
                                item.relationship = 'Agent Action invoking this flow';
                                refs.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences GenAiFunction scan skipped: ' + ex.getMessage());
        }

        // ── 10: Approval Processes ────────────────────────────────────────────
        // ApprovalProcess can invoke a Flow as an action step.
        // MCD indexes this as MetadataComponentType = 'ApprovalProcess'
        // referencing the flow by RefMetadataComponentId or RefMetadataComponentName.
        try {
            for (String refId : new List<String>{ flowId18, durableId }) {
                if (String.isBlank(refId)) continue;
                String apSoql =
                    'SELECT MetadataComponentName, MetadataComponentType ' +
                    'FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentId = \'' + String.escapeSingleQuotes(refId) + '\' ' +
                    'AND MetadataComponentType = \'ApprovalProcess\' ' +
                    'LIMIT 50';
                HttpRequest apReq = new HttpRequest();
                apReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(apSoql, 'UTF-8'));
                apReq.setMethod('GET');
                apReq.setHeader('Content-Type', 'application/json');
                apReq.setTimeout(TIMEOUT_LONG);
                HttpResponse apRes = http.send(apReq);
                if (apRes.getStatusCode() >= 200 && apRes.getStatusCode() < 300) {
                    Map<String, Object> apBody = (Map<String, Object>) JSON.deserializeUntyped(apRes.getBody());
                    List<Object> apRecs = (List<Object>) apBody.get('records');
                    if (apRecs != null) {
                        for (Object r : apRecs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String cName = (String) row.get('MetadataComponentName');
                            if (String.isBlank(cName)) continue;
                            String dk = ('approvalprocess|' + cName).toLowerCase();
                            if (!seenKeys.contains(dk)) {
                                seenKeys.add(dk);
                                ReferenceItem item = new ReferenceItem();
                                item.name         = cName;
                                item.type         = 'ApprovalProcess';
                                item.groupLabel   = 'Approval Processes';
                                item.relationship = 'Approval Process invokes this flow as an action step';
                                refs.add(item);
                            }
                        }
                    }
                }
            }
            // Also scan by ApiName in case MCD indexed by name
            String apByNameSoql =
                'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                'AND RefMetadataComponentType IN (\'Flow\', \'FlowDefinition\') ' +
                'AND MetadataComponentType = \'ApprovalProcess\' LIMIT 50';
            HttpRequest apN = new HttpRequest();
            apN.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(apByNameSoql, 'UTF-8'));
            apN.setMethod('GET');
            apN.setHeader('Content-Type', 'application/json');
            apN.setTimeout(TIMEOUT_LONG);
            HttpResponse apNRes = http.send(apN);
            if (apNRes.getStatusCode() >= 200 && apNRes.getStatusCode() < 300) {
                Map<String, Object> apNBody = (Map<String, Object>) JSON.deserializeUntyped(apNRes.getBody());
                List<Object> apNRecs = (List<Object>) apNBody.get('records');
                if (apNRecs != null) {
                    for (Object r : apNRecs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String cName = (String) row.get('MetadataComponentName');
                        if (String.isBlank(cName)) continue;
                        String dk = ('approvalprocess|' + cName).toLowerCase();
                        if (!seenKeys.contains(dk)) {
                            seenKeys.add(dk);
                            ReferenceItem item = new ReferenceItem();
                            item.name         = cName;
                            item.type         = 'ApprovalProcess';
                            item.groupLabel   = 'Approval Processes';
                            item.relationship = 'Approval Process invokes this flow as an action step';
                            refs.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences ApprovalProcess scan skipped: ' + ex.getMessage());
        }

        // ── 11: Quick Actions (FlowAction type) ──────────────────────────────
        // QuickAction of type 'Flow' directly invokes a flow.
        //
        // HISTORY: previous version relied on MetadataComponentDependency
        // (MCD) — but MCD's coverage for QuickAction → Flow edges is
        // unreliable.  Many orgs return zero MCD rows even when a Flow
        // Quick Action exists, only for Salesforce to then block the delete
        // with "Quick Action: <Name>".
        //
        // CORRECT APPROACH: query QuickActionDefinition (Tooling) directly.
        //   - QuickActionDefinition.Type == 'Flow'  — only flow actions
        //   - The flow target is stored in QuickActionDefinition.Name, but
        //     OPTIONS_OBJECT-side this isn't directly a FK.  We must scan
        //     the action body. Two reliable strategies:
        //       (a) FlowDefinition column on QuickActionDefinition (some
        //           API versions only) — try first.
        //       (b) Fetch the full Metadata body and look at flowDefinition
        //           property — the Quick Action metadata XML stores the
        //           flow under <flowDefinition>{flowApiName}</flowDefinition>.
        //   - Also retain MCD-based check as a third source (cheap query).
        //
        // We use strategy (b) — fetch Metadata for Type=Flow quick actions
        // and parse out flowDefinition.  This is the most reliable.
        try {
            // Strategy A: direct Tooling SOQL on QuickActionDefinition
            String qaListSoql =
                'SELECT Id, DeveloperName, MasterLabel, Type, SobjectType, ' +
                'EntityDefinitionId ' +
                'FROM QuickActionDefinition ' +
                'WHERE Type = \'Flow\' LIMIT 500';
            HttpRequest qaListReq = new HttpRequest();
            qaListReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                                  EncodingUtil.urlEncode(qaListSoql, 'UTF-8'));
            qaListReq.setMethod('GET');
            qaListReq.setHeader('Content-Type', 'application/json');
            qaListReq.setTimeout(TIMEOUT_LONG);
            HttpResponse qaListRes = http.send(qaListReq);

            // Collect candidates: developerName, label, sobject, id
            Map<String, Map<String, String>> qaCandidates =
                new Map<String, Map<String, String>>();
            if (qaListRes.getStatusCode() >= 200 && qaListRes.getStatusCode() < 300) {
                Map<String, Object> qaListBody =
                    (Map<String, Object>) JSON.deserializeUntyped(qaListRes.getBody());
                List<Object> qaListRecs = (List<Object>) qaListBody.get('records');
                if (qaListRecs != null) {
                    for (Object rr : qaListRecs) {
                        Map<String, Object> row = (Map<String, Object>) rr;
                        String qaId = (String) row.get('Id');
                        if (String.isBlank(qaId)) continue;
                        Map<String, String> rec = new Map<String, String>();
                        rec.put('id',       qaId);
                        rec.put('dev',      (String) row.get('DeveloperName'));
                        rec.put('master',   (String) row.get('MasterLabel'));
                        rec.put('sobj',     (String) row.get('SobjectType'));
                        qaCandidates.put(qaId, rec);
                    }
                }
            }

            // For each candidate, fetch its Metadata.flowDefinition value.
            // Tooling lets us fetch Metadata one record at a time via the
            // /sobjects/QuickActionDefinition/{id} REST GET path with the
            // Metadata field included.  We batch via SOQL with the Id in
            // an IN list — Metadata IS queryable on QuickActionDefinition
            // when the query has a row-limit-1 effective filter (Id = ...).
            // The cheap path: one query per candidate.  Cap at 200 to bound cost.
            Integer probed = 0;
            for (String qaId : qaCandidates.keySet()) {
                if (probed >= 200) break;
                probed++;
                Map<String, String> rec = qaCandidates.get(qaId);
                try {
                    HttpRequest qaGet = new HttpRequest();
                    qaGet.setEndpoint(BASE_URL + 'tooling/sobjects/QuickActionDefinition/' + qaId);
                    qaGet.setMethod('GET');
                    qaGet.setHeader('Content-Type', 'application/json');
                    qaGet.setTimeout(TIMEOUT_LONG);
                    HttpResponse qaGetRes = http.send(qaGet);
                    if (qaGetRes.getStatusCode() < 200 || qaGetRes.getStatusCode() >= 300) continue;

                    Map<String, Object> qaRow =
                        (Map<String, Object>) JSON.deserializeUntyped(qaGetRes.getBody());
                    Object meta = qaRow.get('Metadata');
                    if (!(meta instanceof Map<String, Object>)) continue;
                    Map<String, Object> qaMeta = (Map<String, Object>) meta;

                    // The flow ApiName is at Metadata.flowDefinition for Type=Flow.
                    Object flowDefObj = qaMeta.get('flowDefinition');
                    if (!(flowDefObj instanceof String)) continue;
                    String flowDefVal = ((String) flowDefObj).trim();
                    if (String.isBlank(flowDefVal)) continue;

                    // Match against the flow's ApiName (case-insensitive).
                    Boolean matches = flowDefVal.equalsIgnoreCase(apiName);
                    if (!matches && String.isNotBlank(normalisedLabel) &&
                        flowDefVal.equalsIgnoreCase(normalisedLabel)) {
                        matches = true;
                    }
                    if (!matches) continue;

                    String dev    = rec.get('dev');
                    String master = rec.get('master');
                    String sobj   = rec.get('sobj');
                    if (String.isBlank(dev)) dev = qaId;

                    String displayName = String.isNotBlank(master) ? master : dev;
                    if (String.isNotBlank(dev) && !dev.equalsIgnoreCase(master)) {
                        displayName += ' (' + dev + ')';
                    }
                    if (String.isNotBlank(sobj)) {
                        displayName += ' [on ' + sobj + ']';
                    }

                    // Canonical dedup key — keyed by lowercase DeveloperName so
                    // Strategy A and the MCD-based Strategy B/C below collide
                    // on the same QuickAction (otherwise the same action shows
                    // up twice: once with the rich "[on Account]" annotation
                    // from Strategy A and once as the bare DeveloperName from
                    // MCD).  Fall back to qaId only if DeveloperName missing.
                    String dedupName = String.isNotBlank(dev) ? dev : qaId;
                    String dk = ('quickaction|' + dedupName).toLowerCase();
                    if (!seenKeys.contains(dk)) {
                        seenKeys.add(dk);
                        ReferenceItem item = new ReferenceItem();
                        item.name         = displayName;
                        item.type         = 'QuickAction';
                        item.groupLabel   = 'Quick Actions';
                        item.relationship = 'Quick Action of type Flow invokes this flow — ' +
                                            'delete or repoint the quick action ' +
                                            (String.isNotBlank(sobj)
                                              ? '(Setup → Object Manager → ' + sobj + ' → Buttons, Links, and Actions)'
                                              : '(Setup → Buttons, Links, and Actions)');
                        refs.add(item);
                    }
                } catch (Exception exInner) {
                    System.debug(LoggingLevel.WARN,
                        'QuickAction probe skipped on ' + qaId + ': ' + exInner.getMessage());
                }
            }

            // Strategy B (belt-and-braces): MCD lookup, in case Strategy A
            // missed something (rare, but cheap).
            //
            // Dedup: MCD returns either the bare DeveloperName ("CaseCreation")
            // or the sObject-qualified form ("Account.CaseCreation").  We strip
            // any "<Sobj>." prefix before keying so the dedup matches
            // Strategy A's canonical key.
            for (String refId : new List<String>{ flowId18, durableId }) {
                if (String.isBlank(refId)) continue;
                String qaSoql =
                    'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentId = \'' + String.escapeSingleQuotes(refId) + '\' ' +
                    'AND MetadataComponentType = \'QuickAction\' LIMIT 50';
                HttpRequest qaReq = new HttpRequest();
                qaReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(qaSoql, 'UTF-8'));
                qaReq.setMethod('GET');
                qaReq.setHeader('Content-Type', 'application/json');
                qaReq.setTimeout(TIMEOUT_LONG);
                HttpResponse qaRes = http.send(qaReq);
                if (qaRes.getStatusCode() >= 200 && qaRes.getStatusCode() < 300) {
                    Map<String, Object> qaBody = (Map<String, Object>) JSON.deserializeUntyped(qaRes.getBody());
                    List<Object> qaRecs = (List<Object>) qaBody.get('records');
                    if (qaRecs != null) {
                        for (Object r : qaRecs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String cName = (String) row.get('MetadataComponentName');
                            if (String.isBlank(cName)) continue;
                            // Strip "<Sobj>." prefix if present so MCD name and
                            // QuickActionDefinition.DeveloperName line up.
                            String bareName = cName.contains('.') ?
                                cName.substringAfter('.') : cName;
                            String dk = ('quickaction|' + bareName).toLowerCase();
                            if (!seenKeys.contains(dk)) {
                                seenKeys.add(dk);
                                ReferenceItem item = new ReferenceItem();
                                item.name         = cName;
                                item.type         = 'QuickAction';
                                item.groupLabel   = 'Quick Actions';
                                item.relationship = 'Quick Action of type Flow invokes this flow (via MCD)';
                                refs.add(item);
                            }
                        }
                    }
                }
            }
            // MCD by ApiName
            String qaByNameSoql =
                'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                'AND RefMetadataComponentType IN (\'Flow\', \'FlowDefinition\') ' +
                'AND MetadataComponentType = \'QuickAction\' LIMIT 50';
            HttpRequest qaN = new HttpRequest();
            qaN.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(qaByNameSoql, 'UTF-8'));
            qaN.setMethod('GET');
            qaN.setHeader('Content-Type', 'application/json');
            qaN.setTimeout(TIMEOUT_LONG);
            HttpResponse qaNRes = http.send(qaN);
            if (qaNRes.getStatusCode() >= 200 && qaNRes.getStatusCode() < 300) {
                Map<String, Object> qaNBody = (Map<String, Object>) JSON.deserializeUntyped(qaNRes.getBody());
                List<Object> qaNRecs = (List<Object>) qaNBody.get('records');
                if (qaNRecs != null) {
                    for (Object r : qaNRecs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String cName = (String) row.get('MetadataComponentName');
                        if (String.isBlank(cName)) continue;
                        // Canonical key — strip <Sobj>. prefix if present
                        String bareName = cName.contains('.') ?
                            cName.substringAfter('.') : cName;
                        String dk = ('quickaction|' + bareName).toLowerCase();
                        if (!seenKeys.contains(dk)) {
                            seenKeys.add(dk);
                            ReferenceItem item = new ReferenceItem();
                            item.name         = cName;
                            item.type         = 'QuickAction';
                            item.groupLabel   = 'Quick Actions';
                            item.relationship = 'Quick Action of type Flow invokes this flow (via MCD by name)';
                            refs.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences QuickAction scan skipped: ' + ex.getMessage());
        }

        // ── 12: Einstein Bots (BotVersion) ───────────────────────────────────
        // BotVersion dialog steps can invoke a flow.
        // Query BotVersion Metadata body and scan for the flow ApiName / Label.
        try {
            String botSoql = 'SELECT DeveloperName, Metadata FROM BotVersion LIMIT 100';
            HttpRequest botReq = new HttpRequest();
            botReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(botSoql, 'UTF-8'));
            botReq.setMethod('GET');
            botReq.setHeader('Content-Type', 'application/json');
            botReq.setTimeout(TIMEOUT_LONG);
            HttpResponse botRes = http.send(botReq);
            if (botRes.getStatusCode() >= 200 && botRes.getStatusCode() < 300) {
                Map<String, Object> botBody = (Map<String, Object>) JSON.deserializeUntyped(botRes.getBody());
                List<Object> botRecs = (List<Object>) botBody.get('records');
                if (botRecs != null) {
                    for (Object r : botRecs) {
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              bName   = (String) row.get('DeveloperName');
                        Object              meta    = row.get('Metadata');
                        if (meta == null) continue;
                        String metaStr = JSON.serialize(meta).toLowerCase();
                        Boolean found = metaStr.contains(apiName.toLowerCase());
                        if (!found && String.isNotBlank(normalisedLabel)) found = metaStr.contains(normalisedLabel.toLowerCase());
                        if (!found && String.isNotBlank(flowLabel))       found = metaStr.contains(flowLabel.trim().toLowerCase());
                        if (found && String.isNotBlank(bName)) {
                            String dk = ('botversion|' + bName).toLowerCase();
                            if (!seenKeys.contains(dk)) {
                                seenKeys.add(dk);
                                ReferenceItem item = new ReferenceItem();
                                item.name         = bName;
                                item.type         = 'BotVersion';
                                item.groupLabel   = 'Einstein Bots';
                                item.relationship = 'Einstein Bot dialog step invokes this flow';
                                refs.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences BotVersion scan skipped: ' + ex.getMessage());
        }

        // ── 13: Experience Cloud / Site pages ────────────────────────────────
        // FlexiPages of type CommApp / CommFlex / CommPage embed flows.
        // The base FlexiPage scan (check #6) already covers generic pages.
        // This targeted scan hits Community/Experience-specific page types.
        try {
            String expSoql = 'SELECT DeveloperName, Type, Metadata FROM FlexiPage ' +
                             'WHERE Type IN (\'CommApp\', \'CommFlex\', \'CommPage\', \'NavMenu\') LIMIT 200';
            HttpRequest expReq = new HttpRequest();
            expReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(expSoql, 'UTF-8'));
            expReq.setMethod('GET');
            expReq.setHeader('Content-Type', 'application/json');
            expReq.setTimeout(TIMEOUT_LONG);
            HttpResponse expRes = http.send(expReq);
            if (expRes.getStatusCode() >= 200 && expRes.getStatusCode() < 300) {
                Map<String, Object> expBody = (Map<String, Object>) JSON.deserializeUntyped(expRes.getBody());
                List<Object> expRecs = (List<Object>) expBody.get('records');
                if (expRecs != null) {
                    for (Object r : expRecs) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              eName  = (String) row.get('DeveloperName');
                        String              eType  = (String) row.get('Type');
                        Object              meta   = row.get('Metadata');
                        if (String.isBlank(eName) || meta == null) continue;
                        String metaStr = JSON.serialize(meta).toLowerCase();
                        Boolean found = metaStr.contains(apiName.toLowerCase());
                        if (!found && String.isNotBlank(normalisedLabel)) found = metaStr.contains(normalisedLabel.toLowerCase());
                        if (!found && String.isNotBlank(flowLabel))       found = metaStr.contains(flowLabel.trim().toLowerCase());
                        if (found) {
                            String dk = ('experiencepage|' + eName).toLowerCase();
                            if (!seenKeys.contains(dk)) {
                                seenKeys.add(dk);
                                ReferenceItem item = new ReferenceItem();
                                item.name         = eName + ' (' + eType + ')';
                                item.type         = 'FlexiPage';
                                item.groupLabel   = 'Experience Cloud Pages';
                                item.relationship = 'Experience Cloud page embeds this flow';
                                refs.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences ExperienceCloud scan skipped: ' + ex.getMessage());
        }

        // ── 14: Workflow Rules (classic) — FlowAction ────────────────────────
        // Classic Workflow Rules can have a Flow Action that invokes a flow.
        // MCD: MetadataComponentType = 'WorkflowRule' or 'WorkflowFlowAction'
        try {
            for (String refId : new List<String>{ flowId18, durableId }) {
                if (String.isBlank(refId)) continue;
                String wrSoql =
                    'SELECT MetadataComponentName, MetadataComponentType FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentId = \'' + String.escapeSingleQuotes(refId) + '\' ' +
                    'AND MetadataComponentType IN (\'WorkflowRule\', \'WorkflowFlowAction\') LIMIT 50';
                HttpRequest wrReq = new HttpRequest();
                wrReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(wrSoql, 'UTF-8'));
                wrReq.setMethod('GET');
                wrReq.setHeader('Content-Type', 'application/json');
                wrReq.setTimeout(TIMEOUT_LONG);
                HttpResponse wrRes = http.send(wrReq);
                if (wrRes.getStatusCode() >= 200 && wrRes.getStatusCode() < 300) {
                    Map<String, Object> wrBody = (Map<String, Object>) JSON.deserializeUntyped(wrRes.getBody());
                    List<Object> wrRecs = (List<Object>) wrBody.get('records');
                    if (wrRecs != null) {
                        for (Object r : wrRecs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String cName = (String) row.get('MetadataComponentName');
                            String cType = (String) row.get('MetadataComponentType');
                            if (String.isBlank(cName)) continue;
                            String dk = ('workflowrule|' + cName).toLowerCase();
                            if (!seenKeys.contains(dk)) {
                                seenKeys.add(dk);
                                ReferenceItem item = new ReferenceItem();
                                item.name         = cName;
                                item.type         = cType;
                                item.groupLabel   = 'Workflow / Process Builder';
                                item.relationship = 'Workflow Rule Flow Action invokes this flow';
                                refs.add(item);
                            }
                        }
                    }
                }
            }
            // Also by ApiName
            String wrByNameSoql =
                'SELECT MetadataComponentName, MetadataComponentType FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                'AND RefMetadataComponentType IN (\'Flow\', \'FlowDefinition\') ' +
                'AND MetadataComponentType IN (\'WorkflowRule\', \'WorkflowFlowAction\') LIMIT 50';
            HttpRequest wrN = new HttpRequest();
            wrN.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(wrByNameSoql, 'UTF-8'));
            wrN.setMethod('GET');
            wrN.setHeader('Content-Type', 'application/json');
            wrN.setTimeout(TIMEOUT_LONG);
            HttpResponse wrNRes = http.send(wrN);
            if (wrNRes.getStatusCode() >= 200 && wrNRes.getStatusCode() < 300) {
                Map<String, Object> wrNBody = (Map<String, Object>) JSON.deserializeUntyped(wrNRes.getBody());
                List<Object> wrNRecs = (List<Object>) wrNBody.get('records');
                if (wrNRecs != null) {
                    for (Object r : wrNRecs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String cName = (String) row.get('MetadataComponentName');
                        String cType = (String) row.get('MetadataComponentType');
                        if (String.isBlank(cName)) continue;
                        String dk = ('workflowrule|' + cName).toLowerCase();
                        if (!seenKeys.contains(dk)) {
                            seenKeys.add(dk);
                            ReferenceItem item = new ReferenceItem();
                            item.name         = cName;
                            item.type         = cType;
                            item.groupLabel   = 'Workflow / Process Builder';
                            item.relationship = 'Workflow Rule Flow Action invokes this flow';
                            refs.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences WorkflowRule scan skipped: ' + ex.getMessage());
        }

        // ── 15: Process Builder (ProcessDefinition) ───────────────────────────
        // Process Builder processes can call a flow as a subprocess node.
        // MCD: MetadataComponentType = 'Flow' WHERE MetadataComponentId = ProcessDefinition Id.
        // Alternatively query ProcessDefinition and scan Metadata body.
        try {
            for (String refId : new List<String>{ flowId18, durableId }) {
                if (String.isBlank(refId)) continue;
                String pbSoql =
                    'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentId = \'' + String.escapeSingleQuotes(refId) + '\' ' +
                    'AND MetadataComponentType = \'Flow\' ' +
                    'AND MetadataComponentName != \'' + String.escapeSingleQuotes(apiName) + '\' LIMIT 50';
                HttpRequest pbReq = new HttpRequest();
                pbReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(pbSoql, 'UTF-8'));
                pbReq.setMethod('GET');
                pbReq.setHeader('Content-Type', 'application/json');
                pbReq.setTimeout(TIMEOUT_LONG);
                HttpResponse pbRes = http.send(pbReq);
                if (pbRes.getStatusCode() >= 200 && pbRes.getStatusCode() < 300) {
                    Map<String, Object> pbBody = (Map<String, Object>) JSON.deserializeUntyped(pbRes.getBody());
                    List<Object> pbRecs = (List<Object>) pbBody.get('records');
                    if (pbRecs != null) {
                        for (Object r : pbRecs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String cName = (String) row.get('MetadataComponentName');
                            if (String.isBlank(cName)) continue;
                            String dk = ('processbuilder|' + cName).toLowerCase();
                            if (!seenKeys.contains(dk)) {
                                seenKeys.add(dk);
                                ReferenceItem item = new ReferenceItem();
                                item.name         = cName;
                                item.type         = 'Flow';
                                item.groupLabel   = 'Workflow / Process Builder';
                                item.relationship = 'Process Builder calls this flow as a subprocess';
                                refs.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences ProcessBuilder scan skipped: ' + ex.getMessage());
        }

        // ── 16: Custom Permissions ────────────────────────────────────────────
        // CustomPermission metadata can gate flow access.
        // MCD: MetadataComponentType = 'CustomPermission' referencing this flow.
        try {
            for (String refId : new List<String>{ flowId18, durableId }) {
                if (String.isBlank(refId)) continue;
                String cpSoql =
                    'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentId = \'' + String.escapeSingleQuotes(refId) + '\' ' +
                    'AND MetadataComponentType = \'CustomPermission\' LIMIT 50';
                HttpRequest cpReq = new HttpRequest();
                cpReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(cpSoql, 'UTF-8'));
                cpReq.setMethod('GET');
                cpReq.setHeader('Content-Type', 'application/json');
                cpReq.setTimeout(TIMEOUT_LONG);
                HttpResponse cpRes = http.send(cpReq);
                if (cpRes.getStatusCode() >= 200 && cpRes.getStatusCode() < 300) {
                    Map<String, Object> cpBody = (Map<String, Object>) JSON.deserializeUntyped(cpRes.getBody());
                    List<Object> cpRecs = (List<Object>) cpBody.get('records');
                    if (cpRecs != null) {
                        for (Object r : cpRecs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String cName = (String) row.get('MetadataComponentName');
                            if (String.isBlank(cName)) continue;
                            String dk = ('custompermission|' + cName).toLowerCase();
                            if (!seenKeys.contains(dk)) {
                                seenKeys.add(dk);
                                ReferenceItem item = new ReferenceItem();
                                item.name         = cName;
                                item.type         = 'CustomPermission';
                                item.groupLabel   = 'Custom Permissions';
                                item.relationship = 'Custom Permission gates access to this flow';
                                refs.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllFlowReferences CustomPermission scan skipped: ' + ex.getMessage());
        }

        return refs;
    }

    public static DeleteResult deleteFlowByApiName(String apiName) {
        // ── Normalize FIRST — reference check must use the same name as the lookup ──
        apiName = apiName.trim().replace(' ', '_');

        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        // ── STEP 1: Look up the flow to get DurableId, Label, IsActive ──────────
        // Must resolve DurableId first — MCD queries by Id are more reliable
        // than name-based queries (avoids Flow vs FlowDefinition type confusion).
        String lookupSoql = 'SELECT Id, DurableId, Label, ApiName, IsActive, ProcessType, TriggerType ' +
                            'FROM FlowDefinitionView ' +
                            'WHERE ApiName = \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                            'LIMIT 1';

        HttpRequest lookupReq = new HttpRequest();
        lookupReq.setEndpoint(BASE_URL + 'query?q=' +
            EncodingUtil.urlEncode(lookupSoql, 'UTF-8'));
        lookupReq.setMethod('GET');
        lookupReq.setHeader('Content-Type', 'application/json');

        HttpResponse lookupRes = http.send(lookupReq);

        if (lookupRes.getStatusCode() < 200 || lookupRes.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Failed to look up flow "' + apiName + '". HTTP ' + lookupRes.getStatusCode();
            return result;
        }

        Map<String, Object> lookupResponse =
            (Map<String, Object>) JSON.deserializeUntyped(lookupRes.getBody());
        List<Object> lookupRecords = (List<Object>) lookupResponse.get('records');

        if (lookupRecords == null || lookupRecords.isEmpty()) {
            result.success = false;
            result.message = 'No flow found with API Name: ' + apiName;
            return result;
        }

        Map<String, Object> flowDef     = (Map<String, Object>) lookupRecords[0];
        String              durableId   = (String)  flowDef.get('DurableId');
        Boolean             isActive    = (Boolean) flowDef.get('IsActive');
        String              flowLabel   = (String)  flowDef.get('Label');
        String              processType = (String)  flowDef.get('ProcessType');
        String              triggerType = (String)  flowDef.get('TriggerType');

        // ── STEP 2: Managed package check (single SOQL — no getFlows() org scan) ──
        // getFlows(null) was an expensive full org scan just to check one field.
        // FlowDefinitionView already has everything we need.
        // Check managed package via Tooling API — Flow is not a standard queryable SObject.
        // Query FlowDefinition by DurableId and check ManageableState.
        try {
            String managedSoql = 'SELECT ManageableState FROM FlowDefinition WHERE DurableId = \'' + durableId + '\' LIMIT 1';
            HttpRequest managedReq = new HttpRequest();
            managedReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(managedSoql, 'UTF-8'));
            managedReq.setMethod('GET');
            managedReq.setHeader('Content-Type', 'application/json');
            managedReq.setTimeout(TIMEOUT_LONG);
            HttpResponse managedRes = http.send(managedReq);
            if (managedRes.getStatusCode() >= 200 && managedRes.getStatusCode() < 300) {
                Map<String, Object> managedBody = (Map<String, Object>) JSON.deserializeUntyped(managedRes.getBody());
                List<Object> managedRecs = (List<Object>) managedBody.get('records');
                if (managedRecs != null && !managedRecs.isEmpty()) {
                    String manageableState = (String)((Map<String, Object>) managedRecs[0]).get('ManageableState');
                    if ('installed'.equalsIgnoreCase(manageableState)) {
                        result.success = false;
                        result.message = 'Blocked: "' + flowLabel + '" belongs to a managed package and cannot be deleted.';
                        return result;
                    }
                }
            }
        } catch (Exception ex) { /* non-critical — proceed */ }

        // ── STEP 3: FULL REFERENCE CHECK before touching anything ────────────────
        //
        // WHY THIS ORDER MATTERS:
        // Old code deactivated an active flow FIRST, then checked references.
        // If the flow was referenced, it was left deactivated in production — broken.
        //
        // Correct order: check ALL references → if any found → show full list and
        // block everything. Never touch the flow (active or not) until refs are clean.
        //
        // checkAllFlowReferences() queries every source:
        //   1.  MCD by 18-char Id  (FlowDefinitionView.Id)
        //   2.  MCD by DurableId   (15-char)
        //   3.  MCD by normalised ApiName
        //   4.  MCD by Label       (some orgs index flows by Label, not ApiName)
        //   5.  Subflow body scan  (active flows whose Metadata body references this flow)
        //   6.  FlexiPage body scan (App Builder pages embedding this flow)
        //   7.  Active FlowInterviews (paused / waiting runs)
        //   8.  CronTrigger scheduled jobs
        //   9.  GenAiFunction (Agentforce Agent Actions)
        //  10.  Approval Processes
        //  11.  Quick Actions (FlowAction type)
        //  12.  Einstein Bots (BotVersion)
        //  13.  Experience Cloud pages
        //  14.  Workflow Rules (FlowAction)
        //  15.  Process Builder subprocess calls
        //  16.  Custom Permissions
        // ─────────────────────────────────────────────────────────────
        String flowId18 = (String) flowDef.get('Id'); // 18-char Id from FlowDefinitionView
        List<ReferenceItem> flowRefs = checkAllFlowReferences(flowId18, durableId, apiName, flowLabel);

        // ── If ANY references found → block and show full list. DO NOT deactivate. ──
        if (!flowRefs.isEmpty()) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;

            // ── SPECIAL CASE: only blocker is running Flow Interviews ──
            // If every reference is a FlowInterview, skip the generic
            // "N reference(s) must be removed first" framing entirely.
            // A running interview is RUNTIME state, not a metadata
            // dependency — the user can't "remove a reference"; they
            // need to finish, pause, or delete the interview record.
            // So we render a Flow-Interview-specific message instead.
            Boolean onlyInterviews = true;
            for (ReferenceItem ri : flowRefs) {
                if (ri == null || ri.type == null || !'FlowInterview'.equalsIgnoreCase(ri.type)) {
                    onlyInterviews = false;
                    break;
                }
            }

            if (onlyInterviews) {
                blocked.message = renderFlowInterviewOnlyMessage(flowLabel, flowRefs, isActive);
                return blocked;
            }

            // Use the same buildFormattedReport used by Apex/Trigger/LWC delete paths.
            // For active flows, prepend an ACTIVE warning before the standard report.
            String report = buildFormattedReport(flowLabel, flowRefs, null, 'Flow');
            if (isActive) {
                report += '\n\n⚠️  This flow is currently ACTIVE and has NOT been deactivated.\n' +
                          'Remove all references above first — the agent will safely\n' +
                          'deactivate and delete once references are cleared.';
            }

            blocked.message = report;
            return blocked;
        }

        // ── All references clear — now safe to deactivate (if active) and delete ──
        if (isActive) {
            HttpRequest deactivateReq = new HttpRequest();
            deactivateReq.setEndpoint(BASE_URL + 'tooling/sobjects/FlowDefinition/' + durableId);
            deactivateReq.setMethod('PATCH');
            deactivateReq.setHeader('Content-Type', 'application/json');
            deactivateReq.setBody('{"Metadata": {"activeVersionNumber": 0}}');

            HttpResponse deactivateRes = http.send(deactivateReq);

            if (deactivateRes.getStatusCode() != 204 && deactivateRes.getStatusCode() != 200) {
                result.success = false;
                String deactivateBody = deactivateRes.getBody();

                // Salesforce returns the DEPENDENCY_EXISTS detail in the deactivation response —
                // this is the most reliable source of what is actually referencing the flow.
                // Parse it and show a clean reference report instead of a raw error.
                if (deactivateBody != null &&
                    (deactivateBody.containsIgnoreCase('referenced elsewhere') ||
                     deactivateBody.containsIgnoreCase('DEPENDENCY_EXISTS') ||
                     deactivateBody.containsIgnoreCase('Referenced by') ||
                     deactivateBody.containsIgnoreCase('DELETE_FAILED') ||
                     deactivateBody.containsIgnoreCase('Remove the usage'))) {

                    // Extract the "Referenced by..." sentence from the error
                    String refDetail = '';
                    try {
                        Object parsed = JSON.deserializeUntyped(deactivateBody);
                        List<Object> errList = parsed instanceof List<Object>
                            ? (List<Object>) parsed
                            : new List<Object>{ parsed };
                        for (Object e : errList) {
                            Map<String, Object> errMap = (Map<String, Object>) e;
                            String msg = (String) errMap.get('message');
                            if (msg == null) continue;
                            // Salesforce message format:
                            // "This flow is referenced elsewhere in Salesforce...Referenced by the X in Y: Z"
                            Integer refIdx = msg.indexOf('Referenced by');
                            if (refIdx >= 0) {
                                refDetail += msg.substring(refIdx) + '\n';
                            } else {
                                // Fallback — take the whole message
                                refDetail += msg + '\n';
                            }
                        }
                    } catch (Exception parseEx) {
                        refDetail = deactivateBody;
                    }

                    // If refDetail is empty, show full raw message — always better than nothing
                    String displayDetail = String.isNotBlank(refDetail)
                        ? refDetail.trim()
                        : deactivateBody.trim();

                    result.message =
                        '🚫 Cannot delete Flow "' + flowLabel + '" — it is referenced elsewhere.\n\n' +
                        'Salesforce blocked the deactivation with this reason:\n\n' +
                        displayDetail + '\n\n' +
                        'To fix:\n' +
                        '  1. Setup > Flows > "' + flowLabel + '" > View Dependencies\n' +
                        '  2. Remove each component listed above\n' +
                        '  3. Retry the delete';
                } else {
                    result.message = 'Flow "' + flowLabel + '" could not be deactivated. HTTP ' +
                                     deactivateRes.getStatusCode() + ': ' + deactivateBody;
                }
                return result;
            }
        }

        // Fetch versions with Status — Salesforce won't delete an Active version directly
        String versionSoql = 'SELECT Id, Status, VersionNumber FROM Flow WHERE DefinitionId = \'' + durableId + '\' ORDER BY VersionNumber ASC';

        HttpRequest versionReq = new HttpRequest();
        versionReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(versionSoql, 'UTF-8'));
        versionReq.setMethod('GET');
        versionReq.setHeader('Content-Type', 'application/json');

        HttpResponse versionRes = http.send(versionReq);

        if (versionRes.getStatusCode() < 200 || versionRes.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Failed to retrieve flow versions for "' + flowLabel + '". HTTP ' + versionRes.getStatusCode();
            return result;
        }

        Map<String, Object> versionResponse =
            (Map<String, Object>) JSON.deserializeUntyped(versionRes.getBody());
        List<Object> versionRecords = (List<Object>) versionResponse.get('records');

        if (versionRecords == null || versionRecords.isEmpty()) {
            result.success = false;
            result.message = 'No flow versions found for "' + flowLabel + '" (DurableId: ' + durableId + ')';
            return result;
        }

        List<String>  failedVersions = new List<String>();
        String        dependencyMsg  = null; // will hold the first DEPENDENCY_EXISTS message

        for (Object vObj : versionRecords) {
            Map<String, Object> vRec      = (Map<String, Object>) vObj;
            String              versionId = (String) vRec.get('Id');
            String              vStatus   = (String) vRec.get('Status');
            Integer             vNum      = (Integer) vRec.get('VersionNumber');

            // If still Active (deactivation PATCH may not have propagated), try to obsolete first
            if ('Active'.equalsIgnoreCase(vStatus)) {
                HttpRequest obsoleteReq = new HttpRequest();
                obsoleteReq.setEndpoint(BASE_URL + 'tooling/sobjects/Flow/' + versionId);
                obsoleteReq.setMethod('PATCH');
                obsoleteReq.setHeader('Content-Type', 'application/json');
                obsoleteReq.setBody('{"Status": "Obsolete"}');
                http.send(obsoleteReq); // best-effort; proceed to delete regardless
            }

            HttpRequest deleteReq = new HttpRequest();
            deleteReq.setEndpoint(BASE_URL + 'tooling/sobjects/Flow/' + versionId);
            deleteReq.setMethod('DELETE');
            deleteReq.setHeader('Content-Type', 'application/json');

            HttpResponse deleteRes = http.send(deleteReq);

            if (deleteRes.getStatusCode() != 204 && deleteRes.getStatusCode() != 200) {
                String errBody = deleteRes.getBody();
                // Capture the first DEPENDENCY_EXISTS message to surface to the user
                if (dependencyMsg == null && errBody != null &&
                    (errBody.containsIgnoreCase('referenced elsewhere') ||
                     errBody.containsIgnoreCase('DEPENDENCY_EXISTS') ||
                     errBody.containsIgnoreCase('Referenced by') ||
                     errBody.containsIgnoreCase('DELETE_FAILED') ||
                     errBody.containsIgnoreCase('Remove the usage'))) {
                    dependencyMsg = errBody;
                }
                failedVersions.add('v' + vNum + ' (' + vStatus + ')');
            }
        }

        if (!failedVersions.isEmpty()) {
            result.success = false;
            if (dependencyMsg != null) {
                // ── Parse what TYPE is blocking using the same helper as the Apex delete path ──
                // Salesforce format for flow version deletes:
                //   [{"message":"Cannot complete this operation...try again. : Action ","errorCode":"DELETE_FAILED"}]
                // The part after the last ': ' is the blocking type label (may be "Action",
                // "Generative AI Function Definition", "Flow", etc.).
                // "Referenced by..." is used for deactivation errors; version deletes use ': TypeLabel'.
                List<String> depTypes  = parseDepTypesFromError(dependencyMsg);
                List<String> agentTypes  = new List<String>(); // GenAi / Agentforce types
                List<String> otherTypes  = new List<String>(); // everything else

                for (String dt : depTypes) {
                    String dtl = dt.toLowerCase();
                    if (dtl.contains('action') || dtl.contains('generative') ||
                        dtl.contains('genai') || dtl.contains('agent') || dtl.contains('ai function') ||
                        dtl.contains('bot')) {
                        agentTypes.add(dt);
                    } else {
                        otherTypes.add(dt);
                    }
                }

                // Build a combined ReferenceItem list:
                //   • flowRefs from the pre-delete scan (already ran — reuse, do NOT re-scan)
                //   • otherTypes as synthetic ReferenceItems, classified by type so the
                //     user sees a meaningful group label instead of the catch-all
                //     "Other References (from Salesforce error)".
                // agentTypes are passed separately to buildFormattedReport as genAiTypes
                // so it renders them in the "Agentforce - Agent Actions" group with the
                // correct fix instructions — exactly as the Apex delete path does.
                //
                // CLASSIFICATION of Salesforce error tokens:
                // Salesforce returns things like:
                //    "Flow Interview - 0FogK000002b2Hp"
                //    "Account Record Page"
                //    "Lightning App Page"
                //    "Permission Set"
                //    "Process Builder"
                //    "Approval Process"
                //    "Workflow Rule"
                //    "Custom Permission"
                //    "Scheduled Job"
                // We map these to the same group labels used by the pre-delete scan
                // so the user gets a consistent experience whether the reference was
                // caught proactively or surfaced in the error.
                List<ReferenceItem> combinedRefs = new List<ReferenceItem>(flowRefs);
                for (String ot : otherTypes) {
                    if (String.isBlank(ot)) continue;
                    String otTrim  = ot.trim();
                    String otLower = otTrim.toLowerCase();

                    // Skip if a pre-delete reference already covered this kind of
                    // thing exactly — avoids "Flow Interview - 0Fo..." appearing
                    // BOTH in "Active Flow Interviews" AND in "Other References"
                    // for the same incident.
                    Boolean alreadyCovered = false;
                    for (ReferenceItem existing : flowRefs) {
                        if (existing == null || existing.type == null) continue;
                        String exType = existing.type.toLowerCase();
                        if (otLower.contains('flow interview') && exType == 'flowinterview') {
                            alreadyCovered = true; break;
                        }
                        if (otLower.contains('record page') && exType == 'flexipage' &&
                            existing.groupLabel != null &&
                            existing.groupLabel.toLowerCase().contains('record page')) {
                            alreadyCovered = true; break;
                        }
                        if (otLower.contains('lightning page') && exType == 'flexipage') {
                            alreadyCovered = true; break;
                        }
                    }
                    if (alreadyCovered) continue;

                    ReferenceItem ri = new ReferenceItem();
                    ri.name = otTrim;
                    ri.type = otTrim;

                    if (otLower.contains('flow interview')) {
                        // e.g. "Flow Interview - 0FogK000002b2Hp"
                        ri.type         = 'FlowInterview';
                        ri.groupLabel   = 'Active Flow Interviews (Running)';

                        // Try to surface the interview Id from the token so the
                        // user has something actionable.
                        String interviewId = otTrim.contains('-') ?
                            otTrim.substringAfterLast('-').trim() : null;

                        // ENRICH: query that specific interview to get its
                        // label, current step, status, and CreatedBy.  This
                        // lets us tell the user whether the interview was
                        // started by the system or a real person, what step
                        // it's stuck on, and what the original interview
                        // label was — instead of just showing a raw Id.
                        String enrichedName = otTrim;        // fallback to raw token
                        String startedBy    = null;          // null = unknown
                        Boolean isSystemRun = false;
                        if (String.isNotBlank(interviewId)) {
                            try {
                                List<FlowInterview> fis = [
                                    SELECT Id, Name, InterviewLabel, CurrentElement,
                                           InterviewStatus, CreatedDate, CreatedBy.Name,
                                           CreatedBy.UserType, PauseLabel
                                    FROM FlowInterview
                                    WHERE Id = :interviewId
                                    LIMIT 1
                                ];
                                if (!fis.isEmpty()) {
                                    FlowInterview fi = fis[0];
                                    String label = fi.InterviewLabel;
                                    if (String.isBlank(label)) label = fi.PauseLabel;
                                    if (String.isBlank(label)) label = fi.Name;

                                    String suffix = '';
                                    if (String.isNotBlank(fi.CurrentElement)) {
                                        suffix += ' (paused at: ' + fi.CurrentElement + ')';
                                    } else if (String.isNotBlank(fi.InterviewStatus)) {
                                        suffix += ' (status: ' + fi.InterviewStatus + ')';
                                    }
                                    if (fi.CreatedBy != null && String.isNotBlank(fi.CreatedBy.Name)) {
                                        startedBy = fi.CreatedBy.Name;
                                        // Classify: standard/system vs real user
                                        // CreatedBy.UserType == 'Standard' is a real user;
                                        // anything else (Automated, PlatformIntegration,
                                        // System, Guest) is system-initiated.
                                        String ut = fi.CreatedBy.UserType;
                                        if (String.isBlank(ut) || !'Standard'.equalsIgnoreCase(ut)) {
                                            isSystemRun = true;
                                        }
                                        suffix += ' — started by ' + startedBy +
                                                  (isSystemRun ? ' (system/automated)' : ' (user)');
                                    } else {
                                        isSystemRun = true; // no creator info → assume system
                                        suffix += ' — started by system';
                                    }
                                    enrichedName = label + suffix + ' [Id: ' + fi.Id + ']';
                                }
                            } catch (Exception exFi) {
                                System.debug(LoggingLevel.WARN,
                                    'FlowInterview fallback enrichment skipped on ' + interviewId +
                                    ': ' + exFi.getMessage());
                            }
                        }
                        ri.name = enrichedName;
                        ri.relationship = (isSystemRun
                            ? 'A system/automated process started this interview. '
                            : 'A user started this interview. ') +
                            'Finish or delete the interview before deleting the flow. ' +
                            'Setup → Paused Flow Interviews' +
                            (String.isNotBlank(interviewId)
                                ? ', or DELETE FROM FlowInterview WHERE Id = \'' + interviewId + '\''
                                : '');
                    } else if (otLower.contains('record page')) {
                        // e.g. "Account Record Page", "Opportunity Record Page"
                        ri.type         = 'FlexiPage';
                        ri.groupLabel   = 'Lightning Record Pages (FlexiPage)';
                        ri.relationship = 'A Lightning Record Page embeds this Flow via a Flow component. ' +
                                          'Open the page in Lightning App Builder and remove the Flow component, ' +
                                          'or unassign the page.';
                    } else if (otLower.contains('app page') || otLower.contains('home page') ||
                               otLower.contains('lightning page')) {
                        ri.type         = 'FlexiPage';
                        ri.groupLabel   = 'Lightning App/Home Pages (FlexiPage)';
                        ri.relationship = 'A Lightning page embeds this Flow via a Flow component. ' +
                                          'Open the page in Lightning App Builder and remove the Flow component.';
                    } else if (otLower.contains('experience') || otLower.contains('community')) {
                        ri.type         = 'FlexiPage';
                        ri.groupLabel   = 'Experience Cloud Pages (FlexiPage)';
                        ri.relationship = 'An Experience Cloud page embeds this Flow. Remove the Flow ' +
                                          'component from the Experience Builder page.';
                    } else if (otLower.contains('permission set')) {
                        ri.type         = 'PermissionSet';
                        ri.groupLabel   = 'Permission Sets';
                        ri.relationship = 'A Permission Set grants access to this Flow. Remove the Flow ' +
                                          'access entry from the Permission Set first.';
                    } else if (otLower.contains('custom permission')) {
                        ri.type         = 'CustomPermission';
                        ri.groupLabel   = 'Custom Permissions';
                        ri.relationship = 'A Custom Permission is referenced by this Flow. Update the Flow ' +
                                          'to stop using it.';
                    } else if (otLower.contains('approval')) {
                        ri.type         = 'ApprovalProcess';
                        ri.groupLabel   = 'Approval Processes';
                        ri.relationship = 'An Approval Process invokes this Flow. Edit the approval and ' +
                                          'remove the flow action.';
                    } else if (otLower.contains('process builder') || otLower == 'process') {
                        ri.type         = 'ProcessBuilder';
                        ri.groupLabel   = 'Process Builder';
                        ri.relationship = 'A Process Builder calls this Flow as a subprocess. ' +
                                          'Migrate or remove the process.';
                    } else if (otLower.contains('workflow')) {
                        ri.type         = 'WorkflowRule';
                        ri.groupLabel   = 'Workflow Rules (Classic)';
                        ri.relationship = 'A Workflow Rule includes a Flow Action calling this flow. ' +
                                          'Remove that action from the workflow.';
                    } else if (otLower.contains('quick action')) {
                        ri.type         = 'QuickAction';
                        ri.groupLabel   = 'Quick Actions';
                        ri.relationship = 'A Quick Action of type Flow points at this Flow. Edit the ' +
                                          'quick action or delete it.';
                    } else if (otLower.contains('scheduled job') || otLower.contains('cron')) {
                        ri.type         = 'ScheduledJob';
                        ri.groupLabel   = 'Scheduled Jobs (Live)';
                        ri.relationship = 'A scheduled job runs this Flow. Stop it in Setup → Scheduled Jobs.';
                    } else if (otLower.contains('flow') && !otLower.contains('interview')) {
                        // e.g. "Flow", "Flow Definition", "Subflow"
                        ri.type         = 'Flow';
                        ri.groupLabel   = 'Flows (Subflow Caller)';
                        ri.relationship = 'Another Flow calls this Flow as a Subflow.';
                    } else {
                        // Fall back to the generic group — only the truly unknown
                        // types land here, which is the original behaviour.
                        ri.groupLabel   = 'Other References (from Salesforce error)';
                        ri.relationship = 'Salesforce blocked the delete citing this component type';
                    }
                    combinedRefs.add(ri);
                }

                // If depTypes came back empty the message format was unrecognised —
                // agentTypes will also be empty, so buildFormattedReport will still
                // produce a clean report with just the setupPath tip and a raw fallback note.
                String rawFallback = '';
                if (depTypes.isEmpty()) {
                    try {
                        List<Object> errList = (List<Object>) JSON.deserializeUntyped(dependencyMsg);
                        for (Object e : errList) {
                            Map<String, Object> em = (Map<String, Object>) e;
                            String msg = (String) em.get('message');
                            if (String.isNotBlank(msg)) rawFallback += msg.trim() + '\n';
                        }
                    } catch (Exception ex) { rawFallback = dependencyMsg.trim(); }
                }

                // Use buildFormattedReport — same method as Apex/Trigger/LWC delete paths.
                // Produces: "Cannot delete "X". N reference(s) must be removed first." +
                // grouped list + Agentforce fix block + Tip: Setup > Flows > "X" > View Dependencies
                //
                // EXCEPTION: if every item in combinedRefs is a FlowInterview (and
                // there are no agentTypes), use the Flow-Interview-only renderer
                // instead — same as the pre-delete path.
                Boolean fallbackOnlyInterviews =
                    (agentTypes == null || agentTypes.isEmpty()) && !combinedRefs.isEmpty();
                if (fallbackOnlyInterviews) {
                    for (ReferenceItem ri : combinedRefs) {
                        if (ri == null || ri.type == null ||
                            !'FlowInterview'.equalsIgnoreCase(ri.type)) {
                            fallbackOnlyInterviews = false;
                            break;
                        }
                    }
                }
                String report;
                if (fallbackOnlyInterviews) {
                    report = renderFlowInterviewOnlyMessage(flowLabel, combinedRefs, isActive);
                } else {
                    report = buildFormattedReport(flowLabel, combinedRefs, agentTypes, 'Flow');
                }
                if (String.isNotBlank(rawFallback)) {
                    report += '\n\nSalesforce error detail (unparsed):\n  ' + rawFallback.trim();
                }
                result.message = report;

            } else {
                result.message = 'Flow "' + flowLabel + '" — ' +
                                 (versionRecords.size() - failedVersions.size()) + ' version(s) deleted, ' +
                                 failedVersions.size() + ' version(s) failed.\n' +
                                 'Failed: ' + String.join(failedVersions, ', ') + '\n' +
                                 'Tip: If the flow is scheduled or running, stop it in Setup → Scheduled Jobs first.';
            }
        } else {
            result.success = true;
            result.message = '✅ Flow "' + flowLabel + '" (' + apiName + ') and all ' +
                             versionRecords.size() + ' version(s) successfully deleted.';
        }

        return result;
    }

    // ── Mass delete flows ──────────────────────────────────────
    public static MassDeleteResult massDeleteFlows(List<String> apiNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = apiNames.size();
        mass.successCount   = 0;
        mass.failureCount   = 0;
        mass.succeeded      = new List<String>();
        mass.failed         = new List<String>();

        for (String apiName : apiNames) {
            if (String.isBlank(apiName)) continue;
            // Normalize spaces to underscores — Flow API names never contain spaces
            String normalizedName = apiName.trim().replace(' ', '_');
            DeleteResult r = deleteFlowByApiName(normalizedName);
            if (r.success) {
                mass.successCount++;
                mass.succeeded.add(normalizedName);
            } else {
                mass.failureCount++;
                mass.failed.add(apiName.trim() + ' (' + r.message + ')');
            }
        }

        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' +
                       mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET APEX CLASSES + DETECT UNUSED
    // ===============================
    public static ApexSummary getApexClasses(String namespaceFilter) {

        Http http = new Http();

        // FIXED: Removed separate countReq callout — trueTotal is set from
        // the classReq totalSize below, saving 1 callout.
        Integer trueTotal = 0;

        String      stdSoql = 'SELECT Id, Name, Status, LengthWithoutComments, LastModifiedDate, NamespacePrefix ' +
                              'FROM ApexClass WHERE NamespacePrefix != null ORDER BY Name ASC';
        HttpRequest stdReq  = new HttpRequest();
        stdReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(stdSoql, 'UTF-8'));
        stdReq.setMethod('GET');
        stdReq.setHeader('Content-Type', 'application/json');

        HttpResponse                stdRes             = http.send(stdReq);
        List<String>                standardClassNames = new List<String>();
        Map<String, ApexClassInfo>  standardClassMap   = new Map<String, ApexClassInfo>();

        if (stdRes.getStatusCode() >= 200 && stdRes.getStatusCode() < 300) {
            Map<String, Object> stdResponse =
                (Map<String, Object>) JSON.deserializeUntyped(stdRes.getBody());
            List<Object> stdRecords = (List<Object>) stdResponse.get('records');
            if (stdRecords != null) {
                for (Object obj : stdRecords) {
                    Map<String, Object> rec     = (Map<String, Object>) obj;
                    String              stdName = (String) rec.get('Name');
                    String              stdNs   = (String) rec.get('NamespacePrefix');
                    if (String.isNotBlank(stdName)) {
                        standardClassNames.add(stdName);
                        ApexClassInfo stdInfo    = new ApexClassInfo();
                        stdInfo.name             = stdName;
                        stdInfo.namespacePrefix  = stdNs;
                        stdInfo.status           = (String) rec.get('Status');
                        stdInfo.linesOfCode      = rec.get('LengthWithoutComments') != null
                                                     ? Integer.valueOf(String.valueOf(rec.get('LengthWithoutComments')))
                                                     : 0;
                        stdInfo.lastModifiedDate = (String) rec.get('LastModifiedDate');
                        standardClassMap.put(stdName, stdInfo);
                    }
                }
            }
        }

        String      soql     = 'SELECT Id, Name, Status, LengthWithoutComments, LastModifiedDate, SymbolTable ' +
                               'FROM ApexClass WHERE NamespacePrefix = null ORDER BY Name ASC';
        HttpRequest classReq = new HttpRequest();
        classReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        classReq.setMethod('GET');
        classReq.setHeader('Content-Type', 'application/json');

        HttpResponse               classRes        = http.send(classReq);
        Map<String, ApexClassInfo> allClassMap     = new Map<String, ApexClassInfo>();
        Set<String>                referencedNames = new Set<String>();

        if (classRes.getStatusCode() >= 200 && classRes.getStatusCode() < 300) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(classRes.getBody());
            // Capture total count from this response (avoids a separate countReq callout)
            Object totalSizeObj = response.get('totalSize');
            if (totalSizeObj != null) {
                trueTotal = Integer.valueOf(String.valueOf(totalSizeObj));
            }
            List<Object> records = (List<Object>) response.get('records');

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    ApexClassInfo info    = new ApexClassInfo();
                    info.id               = (String) rec.get('Id');
                    info.name             = (String) rec.get('Name');
                    info.status           = (String) rec.get('Status');
                    info.linesOfCode      = rec.get('LengthWithoutComments') != null
                                              ? Integer.valueOf(String.valueOf(rec.get('LengthWithoutComments')))
                                              : 0;
                    info.lastModifiedDate = (String) rec.get('LastModifiedDate');
                    allClassMap.put(info.name, info);

                    Object symbolTableObj = rec.get('SymbolTable');
                    if (symbolTableObj != null) {
                        Map<String, Object> symbolTable = (Map<String, Object>) symbolTableObj;

                        List<Object> extRefs = (List<Object>) symbolTable.get('externalReferences');
                        if (extRefs != null) {
                            for (Object extRef : extRefs) {
                                Map<String, Object> extRefMap = (Map<String, Object>) extRef;
                                String refName = (String) extRefMap.get('name');
                                if (String.isNotBlank(refName)) {
                                    referencedNames.add(refName);
                                }
                            }
                        }

                        List<Object> methods = (List<Object>) symbolTable.get('methods');
                        if (methods != null) {
                            for (Object mObj : methods) {
                                Map<String, Object> method      = (Map<String, Object>) mObj;
                                List<Object>        annotations = (List<Object>) method.get('annotations');
                                if (annotations != null) {
                                    for (Object aObj : annotations) {
                                        Map<String, Object> annotation = (Map<String, Object>) aObj;
                                        String aName = (String) annotation.get('name');
                                        if ('InvocableMethod'.equalsIgnoreCase(aName) ||
                                            'AuraEnabled'.equalsIgnoreCase(aName)     ||
                                            'RemoteAction'.equalsIgnoreCase(aName)) {
                                            referencedNames.add(info.name);
                                        }
                                    }
                                }
                            }
                        }

                        List<Object> innerClasses = (List<Object>) symbolTable.get('innerClasses');
                        if (innerClasses != null) {
                            for (Object icObj : innerClasses) {
                                Map<String, Object> ic        = (Map<String, Object>) icObj;
                                List<Object>        icMethods = (List<Object>) ic.get('methods');
                                if (icMethods != null) {
                                    for (Object mObj : icMethods) {
                                        Map<String, Object> method      = (Map<String, Object>) mObj;
                                        List<Object>        annotations = (List<Object>) method.get('annotations');
                                        if (annotations != null) {
                                            for (Object aObj : annotations) {
                                                Map<String, Object> annotation = (Map<String, Object>) aObj;
                                                String aName = (String) annotation.get('name');
                                                if ('InvocableMethod'.equalsIgnoreCase(aName) ||
                                                    'AuraEnabled'.equalsIgnoreCase(aName)) {
                                                    referencedNames.add(info.name);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // FIX: RefMetadataComponentName is unreliable — query RefMetadataComponentId instead.
        // We still need the class name, so we SELECT MetadataComponentName (the dependent side)
        // and use a SOQL cross-reference to get the referenced class name via ApexClass lookup.
        // Simpler approach: fetch RefMetadataComponentId, then resolve to names via a batch Id lookup.
        Set<String> refClassIds = new Set<String>();
        String      depSoql = 'SELECT RefMetadataComponentId, RefMetadataComponentType ' +
                              'FROM MetadataComponentDependency ' +
                              'WHERE RefMetadataComponentType = \'ApexClass\'';
        HttpRequest depReq  = new HttpRequest();
        depReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(depSoql, 'UTF-8'));
        depReq.setMethod('GET');
        depReq.setHeader('Content-Type', 'application/json');

        HttpResponse depRes = http.send(depReq);

        if (depRes.getStatusCode() >= 200 && depRes.getStatusCode() < 300) {
            Map<String, Object> depResponse =
                (Map<String, Object>) JSON.deserializeUntyped(depRes.getBody());
            List<Object> depRecords = (List<Object>) depResponse.get('records');
            if (depRecords != null) {
                for (Object obj : depRecords) {
                    Map<String, Object> rec   = (Map<String, Object>) obj;
                    String              refId = (String) rec.get('RefMetadataComponentId');
                    if (String.isNotBlank(refId)) {
                        refClassIds.add(refId);
                    }
                }
            }
        }
        // Resolve Ids → Names via SOQL (one query, all Ids at once)
        if (!refClassIds.isEmpty()) {
            try {
                for (ApexClass ac : [SELECT Id, Name FROM ApexClass WHERE Id IN :refClassIds]) {
                    referencedNames.add(ac.Name);
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'ApexClass Id→Name resolve failed: ' + ex.getMessage());
            }
        }


        for (String className : allClassMap.keySet()) {
            Boolean isTestClass = className.endsWith('Test') || className.endsWith('Tests');
            if (isTestClass) {
                String mainClassName = className.endsWith('Tests')
                    ? className.substring(0, className.length() - 5)
                    : className.substring(0, className.length() - 4);
                if (allClassMap.containsKey(mainClassName)) {
                    referencedNames.add(className);
                }
            }
        }

        // FIXED: Duplicate SymbolTable callout (annSoql) removed.
        // @InvocableMethod / @AuraEnabled classes are already captured in
        // referencedNames by the classReq SymbolTable loop above.
        // Removing this callout saves ~1 HTTP round-trip + full CPU of
        // re-deserializing every class SymbolTable a second time.

        for (String clsName : allClassMap.keySet()) {
            ApexClassInfo info   = allClassMap.get(clsName);
            Boolean isManaged    = String.isNotBlank(info.namespacePrefix);
            Boolean isTest       = clsName.endsWith('Test') || clsName.endsWith('Tests');
            // isInvocable / isAura already folded into referencedNames above
            Boolean isUsed       = referencedNames.contains(clsName);

            info.isManagedPackage = isManaged;
            info.isTestClass      = isTest;
            info.isInvocable      = isUsed;
            info.isAuraEnabled    = isUsed;

            if (isManaged) {
                info.safetyStatus = 'MANAGED';
            } else if (isTest) {
                info.safetyStatus = 'TEST_CLASS';
            } else if (isUsed) {
                info.safetyStatus = 'IN_USE';
            } else {
                info.safetyStatus = 'SAFE_TO_REVIEW';
            }
        }

        List<ApexClassInfo> unusedClasses   = new List<ApexClassInfo>();
        List<String>        usedClassNames  = new List<String>();
        List<String>        testClassNames  = new List<String>();
        List<ApexClassInfo> filteredClasses = new List<ApexClassInfo>();
        Integer             hiddenTestCount = 0;

        for (String className : allClassMap.keySet()) {
            Boolean isTestClass = className.endsWith('Test') || className.endsWith('Tests');

            if (isTestClass) {
                String mainClassName = className.endsWith('Tests')
                    ? className.substring(0, className.length() - 5)
                    : className.substring(0, className.length() - 4);

                if (allClassMap.containsKey(mainClassName)) {
                    hiddenTestCount++;
                    testClassNames.add(className);
                    continue;
                } else {
                    unusedClasses.add(allClassMap.get(className));
                    continue;
                }
            }

            if (referencedNames.contains(className)) {
                usedClassNames.add(className);
            } else {
                unusedClasses.add(allClassMap.get(className));
            }
        }

        if (String.isNotBlank(namespaceFilter)) {
            String nsLower  = namespaceFilter.toLowerCase();
            for (String stdName : standardClassNames) {
                ApexClassInfo stdInfo = standardClassMap.get(stdName);
                String        stdNs   = stdInfo != null && stdInfo.namespacePrefix != null
                                          ? stdInfo.namespacePrefix.toLowerCase() : '';
                if (stdNs.equals(nsLower)) {
                    filteredClasses.add(stdInfo);
                }
            }
            for (String className : allClassMap.keySet()) {
                String classLower = className.toLowerCase();
                if (classLower.startsWith(nsLower)) {
                    Integer nextIdx = nsLower.length();
                    if (nextIdx >= className.length()) {
                        filteredClasses.add(allClassMap.get(className));
                    } else {
                        String nextChar = className.substring(nextIdx, nextIdx + 1);
                        if (nextChar.equals('_') || nextChar.equals(nextChar.toUpperCase())) {
                            filteredClasses.add(allClassMap.get(className));
                        }
                    }
                }
            }
        } else {
            filteredClasses.addAll(unusedClasses);
            for (String n : usedClassNames) {
                filteredClasses.add(allClassMap.get(n));
            }
        }

        ApexSummary summary        = new ApexSummary();
        summary.total              = trueTotal;
        summary.standard           = standardClassNames.size();
        summary.used               = usedClassNames.size();
        summary.unused             = unusedClasses.size();
        summary.testCount          = hiddenTestCount;
        summary.unusedClasses      = unusedClasses;
        summary.usedClassNames     = usedClassNames;
        summary.standardClassNames = standardClassNames;
        summary.testClassNames     = testClassNames;
        summary.filteredClasses    = filteredClasses;
        summary.filteredTotal      = filteredClasses.size();
        summary.namespaceFilter    = namespaceFilter;

        return summary;
    }

    // ═══════════════════════════════════════════════════════════════
    public class ReferenceResult {
        public String              componentName;
        public String              componentType;
        public List<ReferenceItem> references;
        public Integer             referenceCount;
        public Boolean             hasReferences;
        public String              formattedReport;
        public List<String>        warningNotes;   // non-blocking advisories (e.g. system page warnings)
    }

    public class ReferenceItem {
        public String name;         // Name of the referencing component
        public String type;         // Raw metadata type
        public String groupLabel;   // Human-friendly group e.g. "Automation"
        public String emoji;        // Group emoji
        public String relationship; // e.g. "calls via Flow"
    }

    // ═══════════════════════════════════════════════════════════════
    // getReferencesFor — THE single authoritative reference lookup
    //
    // Strategy:
    //   1. Query MetadataComponentDependency with pagination (up to 2000)
    //      for ALL queryable types — covers: ApexClass, ApexTrigger,
    //      Flow, LWC, Aura, Visualforce, FlexiPage, WorkflowRule,
    //      CustomObject, CustomMetadata, QuickAction, ConnectedApp,
    //      PlatformEventSubscriberConfig, PromptTemplate, Bot, etc.
    //   2. GenAiFunction is NOT queryable — handled in deleteApexClassByName
    //      by intercepting the HTTP 400 DEPENDENCY_EXISTS error.
    //   3. Group results into friendly categories for display.
    //   4. Deduplicate across all queries.
    // ═══════════════════════════════════════════════════════════════
    public static ReferenceResult getReferencesFor(String componentName, String componentType) {
        ReferenceResult res = new ReferenceResult();
        res.componentName   = componentName;
        res.componentType   = componentType;
        res.references      = new List<ReferenceItem>();
        res.referenceCount  = 0;
        res.hasReferences   = false;

        if (String.isBlank(componentName)) return res;

        Http http = new Http();

        // ── Single MetadataComponentDependency query ─────────────────────
        // FIX: Use RefMetadataComponentId — RefMetadataComponentName causes INVALID_FIELD in many orgs.
        // Resolve the component Id via SOQL first, then filter MCD by Id.
        // Falls back to name-based query only if Id resolution fails (unknown componentType).
        Set<String> seenKeys = new Set<String>();
        String      resolvedComponentId = null;
        try {
            if ('ApexClass'.equalsIgnoreCase(componentType)) {
                List<ApexClass> apexLookup = [SELECT Id FROM ApexClass WHERE Name = :componentName LIMIT 1];
                if (!apexLookup.isEmpty()) resolvedComponentId = apexLookup[0].Id;
            } else if ('ApexTrigger'.equalsIgnoreCase(componentType)) {
                List<ApexTrigger> trgLookup = [SELECT Id FROM ApexTrigger WHERE Name = :componentName LIMIT 1];
                if (!trgLookup.isEmpty()) resolvedComponentId = trgLookup[0].Id;
            } else if ('LightningComponentBundle'.equalsIgnoreCase(componentType)) {
                // LightningComponentBundle is Tooling API only — use HTTP callout
                String lwcIdSoql = 'SELECT Id FROM LightningComponentBundle WHERE DeveloperName = \'' +
                                   String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
                HttpRequest lwcIdReq = new HttpRequest();
                lwcIdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(lwcIdSoql, 'UTF-8'));
                lwcIdReq.setMethod('GET');
                lwcIdReq.setHeader('Content-Type', 'application/json');
                lwcIdReq.setTimeout(TIMEOUT_SHORT);
                HttpResponse lwcIdRes = http.send(lwcIdReq);
                if (lwcIdRes.getStatusCode() >= 200 && lwcIdRes.getStatusCode() < 300) {
                    Map<String, Object> lwcBody = (Map<String, Object>) JSON.deserializeUntyped(lwcIdRes.getBody());
                    List<Object> lwcRecs = (List<Object>) lwcBody.get('records');
                    if (lwcRecs != null && !lwcRecs.isEmpty()) {
                        resolvedComponentId = (String) ((Map<String, Object>) lwcRecs[0]).get('Id');
                    }
                }
            } else if ('AuraDefinitionBundle'.equalsIgnoreCase(componentType)) {
                // AuraDefinitionBundle is Tooling API only — use HTTP callout
                String auraIdSoql = 'SELECT Id FROM AuraDefinitionBundle WHERE DeveloperName = \'' +
                                    String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
                HttpRequest auraIdReq = new HttpRequest();
                auraIdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(auraIdSoql, 'UTF-8'));
                auraIdReq.setMethod('GET');
                auraIdReq.setHeader('Content-Type', 'application/json');
                auraIdReq.setTimeout(TIMEOUT_SHORT);
                HttpResponse auraIdRes = http.send(auraIdReq);
                if (auraIdRes.getStatusCode() >= 200 && auraIdRes.getStatusCode() < 300) {
                    Map<String, Object> auraBody = (Map<String, Object>) JSON.deserializeUntyped(auraIdRes.getBody());
                    List<Object> auraRecs = (List<Object>) auraBody.get('records');
                    if (auraRecs != null && !auraRecs.isEmpty()) {
                        resolvedComponentId = (String) ((Map<String, Object>) auraRecs[0]).get('Id');
                    }
                }

            // ── Flow: resolve full identity from FlowDefinitionView then delegate ──
            // getReferencesFor() used to skip Id resolution for Flow and fall through
            // to a single name-only MCD query, missing: subflow body scan, FlexiPage
            // body scan, GenAiFunction (Agent Actions), FlowInterviews, and CronTrigger
            // scheduled jobs.
            // Fix: resolve Id + DurableId + Label here, then call checkAllFlowReferences
            // which covers all 9 sources. The result is assigned directly to res.references
            // and we return immediately — no further MCD query needed.
            } else if ('Flow'.equalsIgnoreCase(componentType)) {
                componentName = componentName.trim().replace(' ', '_');
                try {
                    String flowLookupSoql =
                        'SELECT Id, DurableId, Label FROM FlowDefinitionView ' +
                        'WHERE ApiName = \'' + String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
                    HttpRequest flowIdReq = new HttpRequest();
                    flowIdReq.setEndpoint(BASE_URL + 'query?q=' + EncodingUtil.urlEncode(flowLookupSoql, 'UTF-8'));
                    flowIdReq.setMethod('GET');
                    flowIdReq.setHeader('Content-Type', 'application/json');
                    flowIdReq.setTimeout(TIMEOUT_SHORT);
                    HttpResponse flowIdRes = http.send(flowIdReq);
                    if (flowIdRes.getStatusCode() >= 200 && flowIdRes.getStatusCode() < 300) {
                        Map<String, Object> flowIdBody = (Map<String, Object>) JSON.deserializeUntyped(flowIdRes.getBody());
                        List<Object> flowIdRecs = (List<Object>) flowIdBody.get('records');
                        if (flowIdRecs != null && !flowIdRecs.isEmpty()) {
                            Map<String, Object> flowRow = (Map<String, Object>) flowIdRecs[0];
                            String flowId18   = (String) flowRow.get('Id');
                            String durableId  = (String) flowRow.get('DurableId');
                            String flowLabel  = (String) flowRow.get('Label');
                            // Delegate to the exhaustive 9-source scanner
                            List<ReferenceItem> allFlowRefs =
                                checkAllFlowReferences(flowId18, durableId, componentName, flowLabel);
                            res.references     = allFlowRefs;
                            res.referenceCount = allFlowRefs.size();
                            res.hasReferences  = !allFlowRefs.isEmpty();
                            if (res.hasReferences) {
                                res.formattedReport = buildFormattedReport(
                                    String.isNotBlank(flowLabel) ? flowLabel : componentName,
                                    res.references, null, 'Flow');
                            }
                            return res;
                        }
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.WARN, 'getReferencesFor Flow Id lookup: ' + ex.getMessage());
                }
                // If FlowDefinitionView lookup failed, fall through to the name-based MCD query below
                // Leave resolvedComponentId = null → name-based fallback

            // ── FIX: CustomObject — was falling back to broken name query ──
            } else if ('CustomObject'.equalsIgnoreCase(componentType)) {
                String objName = componentName.endsWith('__c') ? componentName : componentName + '__c';
                String objIdSoql = 'SELECT Id FROM CustomObject WHERE DeveloperName = \'' +
                                   String.escapeSingleQuotes(componentName.replace('__c','')) + '\' LIMIT 1';
                HttpRequest objIdReq = new HttpRequest();
                objIdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(objIdSoql, 'UTF-8'));
                objIdReq.setMethod('GET');
                objIdReq.setHeader('Content-Type', 'application/json');
                objIdReq.setTimeout(TIMEOUT_SHORT);
                HttpResponse objIdRes = http.send(objIdReq);
                if (objIdRes.getStatusCode() >= 200 && objIdRes.getStatusCode() < 300) {
                    Map<String, Object> objBody = (Map<String, Object>) JSON.deserializeUntyped(objIdRes.getBody());
                    List<Object> objRecs = (List<Object>) objBody.get('records');
                    if (objRecs != null && !objRecs.isEmpty()) {
                        resolvedComponentId = (String) ((Map<String, Object>) objRecs[0]).get('Id');
                    }
                }

            // ── NEW: CustomField — Tooling API CustomField WHERE DeveloperName + EntityDefinition ──
            } else if ('CustomField'.equalsIgnoreCase(componentType)) {
                // componentName expected as ObjectName.FieldName (without __c)
                String[] parts = componentName.split('\\.');
                if (parts.size() >= 2) {
                    String objPart   = parts[0].replace('__c','');
                    String fieldPart = parts[1].replace('__c','');
                    String fldIdSoql = 'SELECT Id FROM CustomField WHERE DeveloperName = \'' +
                                       String.escapeSingleQuotes(fieldPart) + '\' ' +
                                       'AND EntityDefinition.QualifiedApiName = \'' +
                                       String.escapeSingleQuotes(parts[0]) + '\' LIMIT 1';
                    HttpRequest fldIdReq = new HttpRequest();
                    fldIdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(fldIdSoql, 'UTF-8'));
                    fldIdReq.setMethod('GET');
                    fldIdReq.setHeader('Content-Type', 'application/json');
                    fldIdReq.setTimeout(TIMEOUT_SHORT);
                    HttpResponse fldIdRes = http.send(fldIdReq);
                    if (fldIdRes.getStatusCode() >= 200 && fldIdRes.getStatusCode() < 300) {
                        Map<String, Object> fldBody = (Map<String, Object>) JSON.deserializeUntyped(fldIdRes.getBody());
                        List<Object> fldRecs = (List<Object>) fldBody.get('records');
                        if (fldRecs != null && !fldRecs.isEmpty()) {
                            resolvedComponentId = (String) ((Map<String, Object>) fldRecs[0]).get('Id');
                        }
                    }
                }

            // ── NEW: ValidationRule — Tooling API WHERE ValidationName + EntityDefinition ──
            } else if ('ValidationRule'.equalsIgnoreCase(componentType)) {
                String[] vrParts = componentName.split('\\.');
                if (vrParts.size() >= 2) {
                    String vrIdSoql = 'SELECT Id FROM ValidationRule WHERE ValidationName = \'' +
                                      String.escapeSingleQuotes(vrParts[1]) + '\' ' +
                                      'AND EntityDefinition.QualifiedApiName = \'' +
                                      String.escapeSingleQuotes(vrParts[0]) + '\' LIMIT 1';
                    HttpRequest vrIdReq = new HttpRequest();
                    vrIdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(vrIdSoql, 'UTF-8'));
                    vrIdReq.setMethod('GET');
                    vrIdReq.setHeader('Content-Type', 'application/json');
                    vrIdReq.setTimeout(TIMEOUT_SHORT);
                    HttpResponse vrIdRes = http.send(vrIdReq);
                    if (vrIdRes.getStatusCode() >= 200 && vrIdRes.getStatusCode() < 300) {
                        Map<String, Object> vrBody = (Map<String, Object>) JSON.deserializeUntyped(vrIdRes.getBody());
                        List<Object> vrRecs = (List<Object>) vrBody.get('records');
                        if (vrRecs != null && !vrRecs.isEmpty()) {
                            resolvedComponentId = (String) ((Map<String, Object>) vrRecs[0]).get('Id');
                        }
                    }
                }

            // ── NEW: PermissionSet — standard SOQL ──
            } else if ('PermissionSet'.equalsIgnoreCase(componentType)) {
                List<PermissionSet> psLookup = [
                    SELECT Id FROM PermissionSet
                    WHERE Name = :componentName AND IsOwnedByProfile = false LIMIT 1
                ];
                if (!psLookup.isEmpty()) resolvedComponentId = psLookup[0].Id;

            // ── NEW: Profile — standard SOQL ──
            } else if ('Profile'.equalsIgnoreCase(componentType)) {
                List<Profile> profLookup = [
                    SELECT Id FROM Profile WHERE Name = :componentName LIMIT 1
                ];
                if (!profLookup.isEmpty()) resolvedComponentId = profLookup[0].Id;
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getReferencesFor Id lookup: ' + ex.getMessage());
        }
        try {
            String depSoql = resolvedComponentId != null ?
                'SELECT MetadataComponentName, MetadataComponentType ' +
                'FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentId = \'' + resolvedComponentId + '\' ' +
                'AND MetadataComponentName != \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                'ORDER BY MetadataComponentType, MetadataComponentName ' +
                'LIMIT 200'
                :
                // For Flow: MCD may store RefMetadataComponentType as 'Flow' or 'FlowDefinition'
                // Use IN clause to catch both. For all other types use exact match.
                ( 'Flow'.equalsIgnoreCase(componentType) ?
                    'SELECT MetadataComponentName, MetadataComponentType ' +
                    'FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                    'AND RefMetadataComponentType IN (\'Flow\', \'FlowDefinition\') ' +
                    'AND MetadataComponentName != \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                    'ORDER BY MetadataComponentType, MetadataComponentName ' +
                    'LIMIT 200'
                :
                    'SELECT MetadataComponentName, MetadataComponentType ' +
                    'FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                    'AND MetadataComponentName != \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                    'ORDER BY MetadataComponentType, MetadataComponentName ' +
                    'LIMIT 200'
                );

            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(depSoql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse resp = http.send(req);

            if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        String              cType = (String) row.get('MetadataComponentType');
                        if (String.isBlank(cName) || String.isBlank(cType)) continue;
                        String dedupKey = (cType + '|' + cName).toLowerCase();
                        if (seenKeys.contains(dedupKey)) continue;
                        seenKeys.add(dedupKey);
                        res.references.add(buildReferenceItem(cName, cType));
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'MCD query failed: ' + ex.getMessage());
        }

        res.referenceCount = res.references.size();
        res.hasReferences  = res.referenceCount > 0;

        if (res.hasReferences) {
            res.formattedReport = buildFormattedReport(componentName, res.references, null, componentType);
        }

        return res;
    }

    // ═══════════════════════════════════════════════════════════════
    // checkAllApexReferences
    //
    // Comprehensive pre-delete reference scan for an Apex class.
    // Covers every real-time reference source that could be missed
    // by MetadataComponentDependency alone:
    //
    //   1.  MetadataComponentDependency  — Flows, LWC, Aura, VF, FlexiPage,
    //                                      Triggers, WorkflowRule, ConnectedApp,
    //                                      PromptTemplate, Bot, GenAI, etc.
    //   2.  SymbolTable (Apex-to-Apex)   — classes calling this via externalReferences
    //   3.  Live Scheduled Jobs          — CronTrigger WHERE ApexClass.Name = X
    //   4.  Active/Queued Async Jobs     — AsyncApexJob WHERE ApexClass.Name = X
    //   5.  Approval Processes           — ApprovalProcess body scan via Metadata API
    //   6.  Assignment Rules             — AssignmentRule query
    //   7.  Escalation Rules             — EscalationRule query
    //   8.  Auto-Response Rules          — AutoResponseRule query
    //   9.  Email Services               — EmailServicesFunction WHERE FunctionName = X
    //  10.  Dynamic Apex warning         — always appended (Type.forName undetectable)
    //
    // Returns: ApexReferenceCheckResult with all findings + confidence label
    // ═══════════════════════════════════════════════════════════════
    public class ApexReferenceCheckResult {
        @AuraEnabled public Boolean             hasBlockingReferences;
        @AuraEnabled public List<ReferenceItem> references;
        @AuraEnabled public Integer             referenceCount;
        @AuraEnabled public String              confidenceLevel;        // HIGH / MEDIUM / LOW
        @AuraEnabled public String              confidenceNote;
        @AuraEnabled public Boolean             dynamicUsagePossible;
        @AuraEnabled public String              formattedReport;
        @AuraEnabled public List<String>        warningNotes;           // non-blocking advisories
        // Class classification — used by deleteApexClassByName to avoid
        // a second getApexClasses() scan after checkAllApexReferences() runs.
        @AuraEnabled public Boolean             isTestClass;            // has @IsTest annotation
        @AuraEnabled public Boolean             isManagedPackage;       // has namespace → never delete
        @AuraEnabled public Boolean             isUnused;               // no references found anywhere
        @AuraEnabled public String              classId;                // Salesforce Id (used for suite lookup etc)
    }

    // ═══════════════════════════════════════════════════════════════
    // checkAllLwcReferences
    //
    // Pre-delete reference scan for an LWC component. Covers:
    //   1a. MCD by Id         — FlexiPages, Flows, parent LWCs, Aura
    //   1b. MCD by Name       — fallback for orgs that index by name
    //   1c. FlexiPage scan    — direct metadata scan (MCD often misses this)
    //   2.  LWC JS source     — other LWCs: import ... from 'c/componentName'
    //   3.  LWC HTML source   — other LWCs: <c-component-name> child tags
    // ═══════════════════════════════════════════════════════════════
    public static ReferenceResult checkAllLwcReferences(String componentName) {
        Http            http     = new Http();
        ReferenceResult res      = new ReferenceResult();
        res.componentName        = componentName;
        res.componentType        = 'LightningComponentBundle';
        res.references           = new List<ReferenceItem>();
        res.referenceCount       = 0;
        res.hasReferences        = false;
        Set<String>     seenKeys = new Set<String>();

        // ── CHECK 1: MCD by Id ─────────────────────────────────────────
        String resolvedId = null;
        try {
            String idSoql = 'SELECT Id FROM LightningComponentBundle WHERE DeveloperName = \'' +
                             String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
            HttpRequest idReq = new HttpRequest();
            idReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(idSoql, 'UTF-8'));
            idReq.setMethod('GET');
            idReq.setHeader('Content-Type', 'application/json');
            idReq.setTimeout(TIMEOUT_SHORT);
            HttpResponse idRes = http.send(idReq);
            if (idRes.getStatusCode() >= 200 && idRes.getStatusCode() < 300) {
                Map<String, Object> idBody = (Map<String, Object>) JSON.deserializeUntyped(idRes.getBody());
                List<Object> idRecs = (List<Object>) idBody.get('records');
                if (idRecs != null && !idRecs.isEmpty()) {
                    resolvedId = (String) ((Map<String, Object>) idRecs[0]).get('Id');
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'LWC Id resolution failed: ' + ex.getMessage());
        }

        if (resolvedId != null) {
            try {
                String mcdSoql = 'SELECT MetadataComponentName, MetadataComponentType ' +
                                 'FROM MetadataComponentDependency ' +
                                 'WHERE RefMetadataComponentId = \'' + resolvedId + '\' ' +
                                 'AND MetadataComponentName != \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                                 'ORDER BY MetadataComponentType, MetadataComponentName ' +
                                 'LIMIT 200';
                HttpRequest mcdReq = new HttpRequest();
                mcdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(mcdSoql, 'UTF-8'));
                mcdReq.setMethod('GET');
                mcdReq.setHeader('Content-Type', 'application/json');
                mcdReq.setTimeout(TIMEOUT_LONG);
                HttpResponse mcdRes = http.send(mcdReq);
                if (mcdRes.getStatusCode() >= 200 && mcdRes.getStatusCode() < 300) {
                    Map<String, Object> mcdBody = (Map<String, Object>) JSON.deserializeUntyped(mcdRes.getBody());
                    List<Object> mcdRecs = (List<Object>) mcdBody.get('records');
                    if (mcdRecs != null) {
                        for (Object r : mcdRecs) {
                            Map<String, Object> row   = (Map<String, Object>) r;
                            String              cName = (String) row.get('MetadataComponentName');
                            String              cType = (String) row.get('MetadataComponentType');
                            if (String.isBlank(cName) || String.isBlank(cType)) continue;
                            String key = (cType + '|' + cName).toLowerCase();
                            if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                res.references.add(buildReferenceItem(cName, cType));
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'LWC MCD query failed: ' + ex.getMessage());
            }
        }

        // ── CHECK 1b: MCD by RefMetadataComponentName ─────────────────
        // Some orgs index by name instead of Id — try both
        try {
            String mcdNameSoql = 'SELECT MetadataComponentName, MetadataComponentType ' +
                                 'FROM MetadataComponentDependency ' +
                                 'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                                 'AND RefMetadataComponentType = \'LightningComponentBundle\' ' +
                                 'AND MetadataComponentName != \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                                 'ORDER BY MetadataComponentType, MetadataComponentName ' +
                                 'LIMIT 200';
            HttpRequest mcdNReq = new HttpRequest();
            mcdNReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(mcdNameSoql, 'UTF-8'));
            mcdNReq.setMethod('GET');
            mcdNReq.setHeader('Content-Type', 'application/json');
            mcdNReq.setTimeout(TIMEOUT_LONG);
            HttpResponse mcdNRes = http.send(mcdNReq);
            if (mcdNRes.getStatusCode() >= 200 && mcdNRes.getStatusCode() < 300) {
                Map<String, Object> mcdNBody = (Map<String, Object>) JSON.deserializeUntyped(mcdNRes.getBody());
                List<Object> mcdNRecs = (List<Object>) mcdNBody.get('records');
                if (mcdNRecs != null) {
                    for (Object r : mcdNRecs) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        String              cType = (String) row.get('MetadataComponentType');
                        if (String.isBlank(cName) || String.isBlank(cType)) continue;
                        String key = (cType + '|' + cName).toLowerCase();
                        if (!seenKeys.contains(key)) {
                            seenKeys.add(key);
                            res.references.add(buildReferenceItem(cName, cType));
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'LWC MCD name query failed: ' + ex.getMessage());
        }

        // ── CHECK 1c: Direct FlexiPage scan ───────────────────────────
        // MCD frequently misses LWC-in-FlexiPage references.
        // Query FlexiPage records directly and scan their XML metadata
        // for the component name (both camelCase and kebab-case).
        try {
            // Convert camelCase → kebab for HTML tag matching
            String kebabName = componentName.replaceAll('([A-Z])', '-$1').toLowerCase().replaceAll('^-', '');

            // Include ManageableState and Type so we can:
            //   1. Skip MANAGED pages (belong to installed packages — not user pages)
            //   2. Skip standard Salesforce DEFAULT pages (system-generated, not user-built)
            //      e.g. "Home Page Default", "Account_Record_Page_Default"
            //   3. Show page Type in the reference so user knows which App Builder to open
            String fpSoql = 'SELECT Id, MasterLabel, DeveloperName, Type, ManageableState, NamespacePrefix, Metadata ' +
                            'FROM FlexiPage ' +
                            'LIMIT 200';
            HttpRequest fpReq = new HttpRequest();
            fpReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(fpSoql, 'UTF-8'));
            fpReq.setMethod('GET');
            fpReq.setHeader('Content-Type', 'application/json');
            fpReq.setTimeout(TIMEOUT_LONG);
            HttpResponse fpRes = http.send(fpReq);
            if (fpRes.getStatusCode() >= 200 && fpRes.getStatusCode() < 300) {
                Map<String, Object> fpBody = (Map<String, Object>) JSON.deserializeUntyped(fpRes.getBody());
                List<Object> fpRecs = (List<Object>) fpBody.get('records');
                if (fpRecs != null) {
                    String nameLower  = componentName.toLowerCase();
                    String kebabLower = kebabName.toLowerCase();

                    // Standard Salesforce default page name patterns — these are
                    // system-generated pages, NOT user-built pages.
                    // A component appearing on these is Salesforce putting it there
                    // automatically — not a real intentional user reference.
                    Set<String> standardPagePatterns = new Set<String>{
                        'home page default',
                        'home_page_default',
                        '_record_page_default',
                        '_list_page_default',
                        'default record page',
                        'default home page',
                        'standard home page'
                    };

                    for (Object r : fpRecs) {
                        Map<String, Object> row             = (Map<String, Object>) r;
                        String              fpLabel         = (String) row.get('MasterLabel');
                        String              fpDevName       = (String) row.get('DeveloperName');
                        String              fpType          = (String) row.get('Type');
                        String              manageableState = (String) row.get('ManageableState');
                        String              nsPrefix        = (String) row.get('NamespacePrefix');
                        Object              metadata        = row.get('Metadata');
                        if (metadata == null || fpLabel == null) continue;

                        // ── Skip MANAGED package pages — not user pages ──
                        if ('installed'.equalsIgnoreCase(manageableState) ||
                            'installedEditable'.equalsIgnoreCase(manageableState) ||
                            String.isNotBlank(nsPrefix)) continue;

                        // ── Skip standard Salesforce DEFAULT pages ──────
                        // These are system-generated pages that Salesforce creates
                        // automatically — not meaningful user references.
                        Boolean isStandardDefault = false;
                        String fpLabelLower   = fpLabel.toLowerCase();
                        String fpDevNameLower = (fpDevName != null ? fpDevName : '').toLowerCase();
                        for (String pattern : standardPagePatterns) {
                            if (fpLabelLower.contains(pattern) || fpDevNameLower.contains(pattern)) {
                                isStandardDefault = true;
                                break;
                            }
                        }
                        // Also skip if DeveloperName ends with common Salesforce default suffixes
                        if (!isStandardDefault && fpDevName != null) {
                            if (fpDevNameLower.endsWith('_default') &&
                                (fpDevNameLower.endsWith('_record_page_default') ||
                                 fpDevNameLower.endsWith('_list_page_default') ||
                                 fpDevNameLower.endsWith('_home_page_default'))) {
                                isStandardDefault = true;
                            }
                        }
                        // ── Scan metadata for component reference ───────
                        // Scan ALL pages — including standard/default ones.
                        // Standard default pages still block deletion; user must remove from App Builder.
                        String metaStr = JSON.serialize(metadata).toLowerCase();
                        if (metaStr.contains(nameLower) || metaStr.contains(kebabLower) ||
                            metaStr.contains('c:' + nameLower) || metaStr.contains('c-' + kebabLower)) {

                            // Build a descriptive label showing page type
                            String pageTypeLabel = 'Lightning Page';
                            if (isStandardDefault)                          pageTypeLabel = 'Salesforce System Page';
                            else if ('RecordPage'.equalsIgnoreCase(fpType)) pageTypeLabel = 'Lightning Record Page';
                            else if ('AppPage'.equalsIgnoreCase(fpType))    pageTypeLabel = 'Lightning App Page';
                            else if ('HomePage'.equalsIgnoreCase(fpType))   pageTypeLabel = 'Lightning Home Page';
                            else if ('CommApp'.equalsIgnoreCase(fpType) ||
                                     'CommFlex'.equalsIgnoreCase(fpType))   pageTypeLabel = 'Experience Cloud Page';
                            else if ('UtilityBar'.equalsIgnoreCase(fpType)) pageTypeLabel = 'Utility Bar';

                            // Build navigation tip
                            String navTip = 'Setup > Lightning App Builder > open "' + fpLabel + '" > remove component > Save';
                            if ('CommApp'.equalsIgnoreCase(fpType) || 'CommFlex'.equalsIgnoreCase(fpType)) {
                                navTip = 'Experience Builder > "' + fpLabel + '" > remove the component > Publish';
                            }

                            String key = ('flexipage|' + fpLabel).toLowerCase();
                            if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                ReferenceItem item = new ReferenceItem();
                                item.name          = fpLabel + ' (' + pageTypeLabel + ')';
                                item.type          = 'FlexiPage';
                                item.groupLabel    = pageTypeLabel + 's';
                                item.relationship  = navTip;
                                res.references.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'LWC FlexiPage scan failed: ' + ex.getMessage());
        }

        // ── CHECK 2: LWC JS source scan ────────────────────────────────
        // Scan all LWC JS files for: import ... from 'c/componentName'
        if (Limits.getCpuTime() < Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            try {
                String importPattern = 'c/' + componentName.toLowerCase();
                String jsSoql = 'SELECT Id, FilePath, Source, LightningComponentBundleId ' +
                                'FROM LightningComponentResource ' +
                                'WHERE FilePath LIKE \'%.js\' ' +
                                'LIMIT 300';
                HttpRequest jsReq = new HttpRequest();
                jsReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(jsSoql, 'UTF-8'));
                jsReq.setMethod('GET');
                jsReq.setHeader('Content-Type', 'application/json');
                jsReq.setTimeout(TIMEOUT_LONG);
                HttpResponse jsRes = http.send(jsReq);
                if (jsRes.getStatusCode() >= 200 && jsRes.getStatusCode() < 300) {
                    Map<String, Object> jsBody = (Map<String, Object>) JSON.deserializeUntyped(jsRes.getBody());
                    List<Object> jsRecs = (List<Object>) jsBody.get('records');
                    if (jsRecs != null) {
                        Set<String> matchedBundleIds = new Set<String>();
                        for (Object r : jsRecs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String src = (String) row.get('Source');
                            String bId = (String) row.get('LightningComponentBundleId');
                            if (String.isBlank(src) || String.isBlank(bId)) continue;
                            if (src.toLowerCase().contains(importPattern)) {
                                matchedBundleIds.add(bId);
                            }
                        }
                        if (!matchedBundleIds.isEmpty()) {
                            String idList = '(\'' + String.join(new List<String>(matchedBundleIds), '\',\'') + '\')';
                            String bundleSoql = 'SELECT Id, DeveloperName FROM LightningComponentBundle WHERE Id IN ' + idList;
                            HttpRequest bundleReq = new HttpRequest();
                            bundleReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(bundleSoql, 'UTF-8'));
                            bundleReq.setMethod('GET');
                            bundleReq.setHeader('Content-Type', 'application/json');
                            bundleReq.setTimeout(TIMEOUT_LONG);
                            HttpResponse bundleRes = http.send(bundleReq);
                            if (bundleRes.getStatusCode() >= 200 && bundleRes.getStatusCode() < 300) {
                                Map<String, Object> bundleBody = (Map<String, Object>) JSON.deserializeUntyped(bundleRes.getBody());
                                List<Object> bundleRecs = (List<Object>) bundleBody.get('records');
                                if (bundleRecs != null) {
                                    for (Object br : bundleRecs) {
                                        Map<String, Object> bRow  = (Map<String, Object>) br;
                                        String              bName = (String) bRow.get('DeveloperName');
                                        if (String.isBlank(bName) || bName.equalsIgnoreCase(componentName)) continue;
                                        String key = ('lightningcomponentbundle|' + bName).toLowerCase();
                                        if (!seenKeys.contains(key)) {
                                            seenKeys.add(key);
                                            ReferenceItem item = new ReferenceItem();
                                            item.name          = bName;
                                            item.type          = 'LightningComponentBundle';
                                            item.groupLabel    = 'LWC Components';
                                            item.relationship  = 'imports this component via: import ... from \'c/' + componentName + '\' — open the LWC in VS Code and remove the import';
                                            res.references.add(item);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'LWC JS source scan failed: ' + ex.getMessage());
            }
        }

        // ── CHECK 3: LWC HTML scan ─────────────────────────────────────
        // Scan HTML files for <c-component-name> tag usage
        if (Limits.getCpuTime() < Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            try {
                // Convert camelCase to kebab-case: accountRelatedData → account-related-data
                String kebab = componentName.replaceAll('([A-Z])', '-$1').toLowerCase().replaceAll('^-', '');
                String htmlTag = '<c-' + kebab;
                String htmlSoql = 'SELECT Id, FilePath, Source, LightningComponentBundleId ' +
                                  'FROM LightningComponentResource ' +
                                  'WHERE FilePath LIKE \'%.html\' ' +
                                  'LIMIT 300';
                HttpRequest htmlReq = new HttpRequest();
                htmlReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(htmlSoql, 'UTF-8'));
                htmlReq.setMethod('GET');
                htmlReq.setHeader('Content-Type', 'application/json');
                htmlReq.setTimeout(TIMEOUT_LONG);
                HttpResponse htmlRes = http.send(htmlReq);
                if (htmlRes.getStatusCode() >= 200 && htmlRes.getStatusCode() < 300) {
                    Map<String, Object> htmlBody = (Map<String, Object>) JSON.deserializeUntyped(htmlRes.getBody());
                    List<Object> htmlRecs = (List<Object>) htmlBody.get('records');
                    if (htmlRecs != null) {
                        Set<String> matchedBundleIds = new Set<String>();
                        for (Object r : htmlRecs) {
                            Map<String, Object> row = (Map<String, Object>) r;
                            String src = (String) row.get('Source');
                            String bId = (String) row.get('LightningComponentBundleId');
                            if (String.isBlank(src) || String.isBlank(bId)) continue;
                            if (src.toLowerCase().contains(htmlTag)) {
                                matchedBundleIds.add(bId);
                            }
                        }
                        if (!matchedBundleIds.isEmpty()) {
                            String idList = '(\'' + String.join(new List<String>(matchedBundleIds), '\',\'') + '\')';
                            String bundleSoql = 'SELECT Id, DeveloperName FROM LightningComponentBundle WHERE Id IN ' + idList;
                            HttpRequest bundleReq2 = new HttpRequest();
                            bundleReq2.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(bundleSoql, 'UTF-8'));
                            bundleReq2.setMethod('GET');
                            bundleReq2.setHeader('Content-Type', 'application/json');
                            bundleReq2.setTimeout(TIMEOUT_LONG);
                            HttpResponse bundleRes2 = http.send(bundleReq2);
                            if (bundleRes2.getStatusCode() >= 200 && bundleRes2.getStatusCode() < 300) {
                                Map<String, Object> b2Body = (Map<String, Object>) JSON.deserializeUntyped(bundleRes2.getBody());
                                List<Object> b2Recs = (List<Object>) b2Body.get('records');
                                if (b2Recs != null) {
                                    for (Object br : b2Recs) {
                                        Map<String, Object> bRow  = (Map<String, Object>) br;
                                        String              bName = (String) bRow.get('DeveloperName');
                                        if (String.isBlank(bName) || bName.equalsIgnoreCase(componentName)) continue;
                                        String key = ('lightningcomponentbundle|' + bName).toLowerCase();
                                        if (!seenKeys.contains(key)) {
                                            seenKeys.add(key);
                                            ReferenceItem item = new ReferenceItem();
                                            item.name          = bName;
                                            item.type          = 'LightningComponentBundle';
                                            item.groupLabel    = 'LWC Components';
                                            item.relationship  = 'uses as child component <c-' + kebab + '> — open the LWC in VS Code, remove the tag from the HTML template and the import from the JS file';
                                            res.references.add(item);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'LWC HTML scan failed: ' + ex.getMessage());
            }
        }

        res.referenceCount = res.references.size();
        res.hasReferences  = res.referenceCount > 0;
        if (res.hasReferences) {
            res.formattedReport = buildFormattedReport(componentName, res.references, null, 'LightningComponentBundle');
            // Append system page warnings if any
            if (res.warningNotes != null && !res.warningNotes.isEmpty()) {
                res.formattedReport += '\n';
                for (String w : res.warningNotes) {
                    res.formattedReport += w + '\n';
                }
            }
        } else if (res.warningNotes != null && !res.warningNotes.isEmpty()) {
            // No blocking references — but system page warning exists.
            // Show it BEFORE confirmation so user is not surprised after saying yes.
            res.formattedReport = '✅ No active custom references found. Safe to delete.\n\n';
            for (String w : res.warningNotes) {
                res.formattedReport += w + '\n';
            }
            res.formattedReport +=
                '\nYou will need to remove it from that system page via ' +
                'Setup > Lightning App Builder before the delete succeeds.';
        }
        return res;
    }

    public static ApexReferenceCheckResult checkAllApexReferences(String className) {

        ApexReferenceCheckResult result = new ApexReferenceCheckResult();
        result.hasBlockingReferences = false;
        result.references            = new List<ReferenceItem>();
        result.referenceCount        = 0;
        result.dynamicUsagePossible  = true;
        result.warningNotes          = new List<String>();
        result.isTestClass           = false;
        result.isManagedPackage      = false;
        result.isUnused              = false;
        result.classId               = null;

        // CPU GUARD — Salesforce limit: 10,000ms synchronous, 60,000ms async.
        // Each check tests remaining CPU before executing expensive operations.
        // If < CPU_RESERVE_MS remain, that check is skipped with a warning note
        // rather than risking a CPU limit exception mid-transaction.
        // Threshold: 3000ms reserve gives enough headroom for finalize + response.
        // CPU_RESERVE_MS is now a class-level constant (3000ms)

        // ── Single upfront query: org namespace + ApexClass Id + Body + namespace ──
        // Replaces 3 separate ApexClass queries (psMatch, selfLookup, isTestCheck)
        // and the Organization namespace query — all merged into 2 SOQLs at the top.
        String orgNamespace = '';
        try {
            List<Organization> orgNsList = [SELECT NamespacePrefix FROM Organization LIMIT 1];
            if (!orgNsList.isEmpty() && String.isNotBlank(orgNsList[0].NamespacePrefix)) {
                orgNamespace = orgNsList[0].NamespacePrefix;
            }
        } catch (Exception ex) { /* ignore */ }

        // Single ApexClass lookup — Id, Body, NamespacePrefix all in one query.
        // Used for: Permission Set check (Id), @IsTest detection (Body),
        //           managed package detection (NamespacePrefix), Test Suite lookup (Id).
        String  targetClassId   = null;
        Boolean targetIsTest    = false;
        Boolean targetIsManaged = false;
        try {
            List<ApexClass> targetLookup = [
                SELECT Id, Body, NamespacePrefix
                FROM ApexClass
                WHERE Name = :className
                LIMIT 1
            ];
            if (!targetLookup.isEmpty()) {
                targetClassId   = targetLookup[0].Id;
                String tBody    = targetLookup[0].Body;
                targetIsTest    = tBody != null && tBody.toLowerCase().contains('@istest');
                String tNs      = targetLookup[0].NamespacePrefix;
                targetIsManaged = String.isNotBlank(tNs) && !tNs.equalsIgnoreCase(orgNamespace);
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ ApexClass lookup skipped: ' + ex.getMessage());
        }

        // Populate result fields immediately from upfront lookup
        result.classId        = targetClassId;
        result.isTestClass    = targetIsTest;
        result.isManagedPackage = targetIsManaged;

        // Managed package class → return immediately, no further checks needed
        if (targetIsManaged) {
            result.formattedReport = '"' + className + '" belongs to a managed package and cannot be deleted.';
            return result;
        }

        Set<String> seenKeys  = new Set<String>();
        Http        http      = new Http();
        String      safeClass = String.escapeSingleQuotes(className);

        // ─────────────────────────────────────────────────────────────
        // CALLOUT 1 — MetadataComponentDependency (single query, all types)
        // Previously CHECKs 1, 5, 6, 7, 8, 11, 12, 13, 14 each made a
        // separate MCD callout with a MetadataComponentType filter.
        // Now: one query fetches ALL dependency types, routing is done
        // client-side. 9 callouts → 1.
        // ─────────────────────────────────────────────────────────────
        try {
            // FIX: Use RefMetadataComponentId — RefMetadataComponentName causes
            // INVALID_FIELD in many orgs. targetClassId already resolved at method top.
            String mcdSoql = targetClassId == null ? null :
                'SELECT MetadataComponentName, MetadataComponentType ' +
                'FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentId = \'' + targetClassId + '\' ' +
                'ORDER BY MetadataComponentType, MetadataComponentName ' +
                'LIMIT 500';
            if (mcdSoql == null) {
                result.warningNotes.add('⚠️ MCD scan skipped — class Id could not be resolved.');
            } else {

            HttpRequest mcdReq = new HttpRequest();
            mcdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(mcdSoql, 'UTF-8'));
            mcdReq.setMethod('GET');
            mcdReq.setHeader('Content-Type', 'application/json');
            mcdReq.setTimeout(TIMEOUT_LONG);
            HttpResponse mcdRes = http.send(mcdReq);

            if (mcdRes.getStatusCode() >= 200 && mcdRes.getStatusCode() < 300) {
                Map<String, Object> body      = (Map<String, Object>) JSON.deserializeUntyped(mcdRes.getBody());
                List<Object>        records   = (List<Object>) body.get('records');
                Object              totalSize = body.get('totalSize');
                // Warn if MCD result was truncated at LIMIT 500
                if (totalSize != null && Integer.valueOf(String.valueOf(totalSize)) > 500) {
                    result.warningNotes.add(
                        '⚠️ MCD scan truncated — this class has ' + totalSize + ' dependencies but only 500 were scanned. ' +
                        'Use Setup > Apex Classes > "' + className + '" > "Where is this used?" for the full list.'
                    );
                }
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        String              cType = (String) row.get('MetadataComponentType');
                        if (String.isBlank(cName) || String.isBlank(cType)) continue;
                        String dedupKey = (cType + '|' + cName).toLowerCase();
                        if (seenKeys.contains(dedupKey)) continue;
                        seenKeys.add(dedupKey);
                        result.references.add(buildReferenceItem(cName, cType));
                    }
                }
            }
            } // closes if (mcdSoql != null)
        } catch (Exception ex) {
            result.warningNotes.add('MCD scan skipped: ' + ex.getMessage());
        }

        // ── Permission Set + Profile access (fast SOQL — Tier 1) ───────
        // SetupEntityAccess is NOT in MCD. Uses targetClassId resolved at method top.
        // ─────────────────────────────────────────────────────────────
        try {
            if (targetClassId != null) {
                Id psApexId = targetClassId;
                List<SetupEntityAccess> psAccess = [
                    SELECT Parent.Name, Parent.IsOwnedByProfile, Parent.IsCustom
                    FROM SetupEntityAccess
                    WHERE SetupEntityId = :psApexId
                    LIMIT 100
                ];
                for (SetupEntityAccess sea : psAccess) {
                    if (sea.Parent == null) continue;
                    // Only block deletion for EXPLICITLY assigned Profiles/PermSets.
                    // IsCustom = false means Salesforce auto-manages this entry (default system profile).
                    // Blindly treating all SetupEntityAccess rows as blockers causes false failures.
                    if (sea.Parent.IsCustom == false) continue;
                    String  psName     = sea.Parent.Name;
                    Boolean isProfile  = sea.Parent.IsOwnedByProfile;
                    String  grpLabel   = isProfile ? 'Profiles' : 'Permission Sets';
                    String  relType    = isProfile ? 'Profile' : 'PermissionSet';
                    String  rel        = isProfile
                        ? 'Profile grants access to this Apex class — revoke before deleting'
                        : 'Permission Set grants access to this Apex class — remove Apex Class access before deleting';
                    String dedupKey = (relType + '|' + psName).toLowerCase();
                    if (!seenKeys.contains(dedupKey)) {
                        seenKeys.add(dedupKey);
                        ReferenceItem item  = new ReferenceItem();
                        item.name           = psName;
                        item.type           = relType;
                        item.groupLabel     = grpLabel;
                        item.relationship   = rel;
                        result.references.add(item);
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Permission Set / Profile check skipped: ' + ex.getMessage());
        }

        // ── EARLY EXIT — MCD found structural code references ────────
        // If MCD already found Flows, LWC, Aura, VF, Triggers, FlexiPages,
        // WorkflowRules, Bots, GenAI, ConnectedApps etc. referencing this class,
        // we KNOW it is in use. Skip the remaining 15+ callouts entirely.
        //
        // PermSet / Profile refs (from SetupEntityAccess above) are intentionally
        // excluded from this check — they are security config, not structural code
        // deps, and must NOT cause us to skip Apex-caller / LWC / Trigger scans.
        //
        // Track structural refs separately using mcdStructuralRefs count:
        // any ref whose type is NOT PermissionSet or Profile counts as structural.
        // ─────────────────────────────────────────────────────────────
        Integer mcdStructuralCount = 0;
        for (ReferenceItem ri : result.references) {
            if (ri.type != 'PermissionSet' && ri.type != 'Profile') {
                mcdStructuralCount++;
            }
        }
        if (mcdStructuralCount > 0) {
            // Structural code references found — return immediately
            result.referenceCount        = result.references.size();
            result.hasBlockingReferences = true;
            result.confidenceLevel       = 'HIGH';
            result.confidenceNote        = 'HIGH confidence — ' + result.referenceCount + ' reference(s) found.';
            result.formattedReport = buildFormattedReport(className, result.references, null, 'ApexClass');
            result.formattedReport +=
                '\n\n⚠️  Dynamic Reference Warning:\n' +
                '  Type.forName(), JSON.deserialize(), or string-based usage\n' +
                '  cannot be detected by any scan. Verify manually.\n';
            return result;
        }
        // MCD structural scan clean — run deep checks (Apex callers, Triggers, LWC, etc.)

        // ─────────────────────────────────────────────────────────────
        // CALLOUT 2 — Apex-to-Apex callers via MCD (targeted, no bulk fetch)
        //
        // OLD approach: fetch ALL 200 ApexClass SymbolTable objects → deserialize
        // each one → scan externalReferences. 200 * SymbolTable JSON = massive CPU.
        //
        // NEW approach: MCD already indexes ApexClass → ApexClass dependencies.
        // One targeted Tooling API query filtered to MetadataComponentType = 'ApexClass'
        // returns only the classes that call this class. Zero bulk deserialization.
        // ─────────────────────────────────────────────────────────────
        try {
            // FIX: Use RefMetadataComponentId — same fix as CALLOUT 1.
            String apexCallerSoql = targetClassId == null ? null :
                'SELECT MetadataComponentName, MetadataComponentType ' +
                'FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentId = \'' + targetClassId + '\' ' +
                'AND MetadataComponentType = \'ApexClass\' ' +
                'LIMIT 100';
            if (apexCallerSoql == null) {
                result.warningNotes.add('⚠️ Apex-to-Apex MCD scan skipped — class Id not resolved.');
            }
             else {
            HttpRequest apexReq = new HttpRequest();
            apexReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(apexCallerSoql, 'UTF-8'));
            apexReq.setMethod('GET');
            apexReq.setHeader('Content-Type', 'application/json');
            apexReq.setTimeout(TIMEOUT_LONG);
            HttpResponse apexRes = http.send(apexReq);

            if (apexRes.getStatusCode() >= 200 && apexRes.getStatusCode() < 300) {
                Map<String, Object> apexBody    = (Map<String, Object>) JSON.deserializeUntyped(apexRes.getBody());
                List<Object>        apexRecords = (List<Object>) apexBody.get('records');
                if (apexRecords != null) {
                    for (Object r : apexRecords) {
                        Map<String, Object> row       = (Map<String, Object>) r;
                        String              callerName = (String) row.get('MetadataComponentName');
                        if (String.isBlank(callerName)) continue;
                        String dedupKey = ('apexclass|' + callerName).toLowerCase();
                        if (!seenKeys.contains(dedupKey)) {
                            seenKeys.add(dedupKey);
                            ReferenceItem item  = buildReferenceItem(callerName, 'ApexClass');
                            item.relationship   = 'Apex class calls / extends / implements this class';
                            result.references.add(item);
                        }
                    }
                }
            }
         } // closes if (apexCallerSoql != null)
        } catch (Exception ex) {
            result.warningNotes.add('Apex-to-Apex caller scan skipped: ' + ex.getMessage());
        }

        // classId, isTestClass, isManagedPackage already resolved at method top.
        result.classId          = targetClassId;
        result.isTestClass      = targetIsTest;
        result.isManagedPackage = targetIsManaged;

        // ─────────────────────────────────────────────────────────────
        // CHECK 2b — ApexTrigger Body text search
        // SymbolTable is NOT supported on ApexTrigger in Tooling API.
        // Body text search is the only reliable way to detect
        // Trigger → Class dependencies.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Trigger body scan skipped — CPU limit approaching.');
        } else
        try {
            String trgSoql = 'SELECT Id, Name, Body FROM ApexTrigger WHERE NamespacePrefix = null LIMIT 200';
            HttpRequest trgReq = new HttpRequest();
            trgReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(trgSoql, 'UTF-8'));
            trgReq.setMethod('GET');
            trgReq.setHeader('Content-Type', 'application/json');
            trgReq.setTimeout(TIMEOUT_LONG);
            HttpResponse trgRes = http.send(trgReq);

            if (trgRes.getStatusCode() >= 200 && trgRes.getStatusCode() < 300) {
                Map<String, Object> trgBody    = (Map<String, Object>) JSON.deserializeUntyped(trgRes.getBody());
                List<Object>        trgRecords = (List<Object>) trgBody.get('records');
                if (trgRecords != null) {
                    // Simple contains() check — fast, no while loop, no CPU spike.
                    // Lowercase both sides to make it case-insensitive.
                    String lowerClass = className.toLowerCase();
                    for (Object tr : trgRecords) {
                        Map<String, Object> trMap      = (Map<String, Object>) tr;
                        String              trgName    = (String) trMap.get('Name');
                        String              trgBodyStr = (String) trMap.get('Body');
                        if (String.isBlank(trgName) || String.isBlank(trgBodyStr)) continue;
                        if (trgBodyStr.toLowerCase().contains(lowerClass)) {
                            String dedupKey = ('apextrigger|' + trgName).toLowerCase();
                            if (!seenKeys.contains(dedupKey)) {
                                seenKeys.add(dedupKey);
                                ReferenceItem item  = buildReferenceItem(trgName, 'ApexTrigger');
                                item.relationship   = 'calls class in trigger body';
                                result.references.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ ApexTrigger scan skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 3 — Live Scheduled Jobs (CronTrigger)
        // Catches classes scheduled via System.schedule() at runtime.
        // MCD does NOT track these — they are runtime, not metadata.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Scheduled job check skipped — CPU limit approaching.');
        } else
        try {
            String cronSoql =
                'SELECT Id, CronJobDetail.Name, State ' +
                'FROM CronTrigger ' +
                'WHERE CronJobDetail.JobType = \'7\' ' +
                'AND State IN (\'WAITING\', \'ACQUIRED\', \'EXECUTING\', \'PAUSED\', \'BLOCKED\', \'PAUSED_BLOCKED\')';
            // We match by querying AsyncApexJob for the class name to get the link
            List<CronTrigger> cronJobs = Database.query(cronSoql);
            for (CronTrigger ct : cronJobs) {
                // Cross-reference with AsyncApexJob to confirm the class name
                String cronName = ct.CronJobDetail.Name;
                // CronJobDetail.Name often matches class name directly for System.schedule() jobs
                if (cronName != null && cronName.equalsIgnoreCase(className)) {
                    String dedupKey = ('scheduledjob|' + cronName).toLowerCase();
                    if (!seenKeys.contains(dedupKey)) {
                        seenKeys.add(dedupKey);
                        ReferenceItem item  = new ReferenceItem();
                        item.name           = cronName + ' (State: ' + ct.State + ')';
                        item.type           = 'ScheduledJob';
                        item.groupLabel     = 'Scheduled Jobs (Live)';
                        item.relationship   = 'actively scheduled via System.schedule() — job is live in the org';
                        result.references.add(item);
                    }
                }
            }

            // Also query AsyncApexJob for this class name directly
            List<AsyncApexJob> scheduledJobs = [
                SELECT Id, ApexClass.Name, Status, JobType
                FROM AsyncApexJob
                WHERE ApexClass.Name = :className
                AND JobType = 'ScheduledApex'
                AND Status IN ('Queued', 'Processing', 'Preparing')
            ];
            for (AsyncApexJob job : scheduledJobs) {
                String dedupKey = ('asyncscheduled|' + job.Id).toLowerCase();
                if (!seenKeys.contains(dedupKey)) {
                    seenKeys.add(dedupKey);
                    ReferenceItem item  = new ReferenceItem();
                    item.name           = className + ' (Job ID: ' + job.Id + ', Status: ' + job.Status + ')';
                    item.type           = 'AsyncApexJob';
                    item.groupLabel     = 'Scheduled Jobs (Live)';
                    item.relationship   = 'scheduled Apex job currently active in org';
                    result.references.add(item);
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Scheduled job check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 4 — Active Batch / Queueable / Future jobs (AsyncApexJob)
        // Catches classes currently running or queued as batch,
        // queueable, or future jobs. Deleting a running class = data loss.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Active Async Job check skipped — CPU limit approaching. Re-run the check.');
        } else
        try {
            List<AsyncApexJob> activeJobs = [
                SELECT Id, ApexClass.Name, Status, JobType
                FROM AsyncApexJob
                WHERE ApexClass.Name = :className
                AND JobType IN ('BatchApex', 'Queueable', 'Future', 'BatchApexWorker')
                AND Status IN ('Queued', 'Processing', 'Preparing', 'Holding')
            ];
            for (AsyncApexJob job : activeJobs) {
                String dedupKey = ('asyncjob|' + job.Id).toLowerCase();
                if (!seenKeys.contains(dedupKey)) {
                    seenKeys.add(dedupKey);
                    ReferenceItem item  = new ReferenceItem();
                    item.name           = className + ' [' + job.JobType + '] (Status: ' + job.Status + ', ID: ' + job.Id + ')';
                    item.type           = 'AsyncApexJob';
                    item.groupLabel     = 'Active Async Jobs (Live)';
                    item.relationship   = 'class is currently executing or queued as ' + job.JobType + ' — deleting will corrupt this job';
                    result.references.add(item);
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Async job check skipped: ' + ex.getMessage());
        }





        // ─────────────────────────────────────────────────────────────
        // CHECK 5 — Approval Processes
        // MCD tracks ApprovalProcess → ApexClass dependencies reliably.
        // Query MCD WHERE RefMetadataComponentName = className
        // AND MetadataComponentType = 'ApprovalProcess'.
        // This covers entry criteria, approval/rejection/recall Apex actions.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Approval Process check skipped — CPU limit approaching.');
        } else
        try {
            String apSoql = 'SELECT MetadataComponentName, MetadataComponentType ' +
                            'FROM MetadataComponentDependency ' +
                            'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(className) + '\' ' +
                            'AND MetadataComponentType = \'ApprovalProcess\' ' +
                            'LIMIT 50';
            HttpRequest apReq = new HttpRequest();
            apReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(apSoql, 'UTF-8'));
            apReq.setMethod('GET');
            apReq.setHeader('Content-Type', 'application/json');
            apReq.setTimeout(TIMEOUT_LONG);
            HttpResponse apRes = http.send(apReq);
            if (apRes.getStatusCode() >= 200 && apRes.getStatusCode() < 300) {
                Map<String, Object> apBody    = (Map<String, Object>) JSON.deserializeUntyped(apRes.getBody());
                List<Object>        apRecords = (List<Object>) apBody.get('records');
                if (apRecords != null) {
                    for (Object r : apRecords) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              apName = (String) row.get('MetadataComponentName');
                        if (String.isBlank(apName)) continue;
                        String dedupKey = ('approvalprocess|' + apName).toLowerCase();
                        if (!seenKeys.contains(dedupKey)) {
                            seenKeys.add(dedupKey);
                            ReferenceItem item = new ReferenceItem();
                            item.name          = apName;
                            item.type          = 'ApprovalProcess';
                            item.groupLabel    = 'Approval Processes';
                            item.relationship  = 'Apex class referenced in approval process criteria or action';
                            result.references.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Approval Process check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 6 — Assignment Rules
        // AssignmentRule can invoke Apex via formula-based criteria or via
        // WorkflowAction. MCD does not track this link reliably.
        // Query AssignmentRule WHERE SobjectType != null and scan related
        // RuleEntry criteria for Apex references via Tooling API.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Assignment Rule check skipped — CPU limit approaching.');
        } else
        try {
            String arSoql = 'SELECT Id, Name, SobjectType, Active ' +
                            'FROM AssignmentRule ' +
                            'WHERE Active = true ' +
                            'LIMIT 200';
            HttpRequest arReq = new HttpRequest();
            arReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(arSoql, 'UTF-8'));
            arReq.setMethod('GET');
            arReq.setHeader('Content-Type', 'application/json');
            arReq.setTimeout(TIMEOUT_LONG);
            HttpResponse arRes = http.send(arReq);
            if (arRes.getStatusCode() >= 200 && arRes.getStatusCode() < 300) {
                Map<String, Object> arBody    = (Map<String, Object>) JSON.deserializeUntyped(arRes.getBody());
                List<Object>        arRecords = (List<Object>) arBody.get('records');
                if (arRecords != null) {
                    String lowerClass = className.toLowerCase();
                    for (Object r : arRecords) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              arName = (String) row.get('Name');
                        // Check MCD for this AssignmentRule → className link
                        String arId = (String) row.get('Id');
                        // Cross-check via MCD: does this rule depend on our class?
                        String mcdCheck = 'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                                          'WHERE MetadataComponentId = \'' + arId + '\' ' +
                                          'AND RefMetadataComponentName = \'' + String.escapeSingleQuotes(className) + '\' LIMIT 1';
                        HttpRequest mcdReq = new HttpRequest();
                        mcdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(mcdCheck, 'UTF-8'));
                        mcdReq.setMethod('GET');
                        mcdReq.setHeader('Content-Type', 'application/json');
                        mcdReq.setTimeout(TIMEOUT_SHORT);
                        HttpResponse mcdRes = http.send(mcdReq);
                        if (mcdRes.getStatusCode() >= 200 && mcdRes.getStatusCode() < 300) {
                            Map<String, Object> mb = (Map<String, Object>) JSON.deserializeUntyped(mcdRes.getBody());
                            List<Object> mr = (List<Object>) mb.get('records');
                            if (mr != null && !mr.isEmpty() && arName != null) {
                                String dedupKey = ('assignmentrule|' + arName).toLowerCase();
                                if (!seenKeys.contains(dedupKey)) {
                                    seenKeys.add(dedupKey);
                                    ReferenceItem item = new ReferenceItem();
                                    item.name          = arName;
                                    item.type          = 'AssignmentRule';
                                    item.groupLabel    = 'Assignment Rules';
                                    item.relationship  = 'Active assignment rule references this Apex class';
                                    result.references.add(item);
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Assignment Rule check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 7 — Escalation Rules
        // EscalationRule can fire Apex via EscalationAction. MCD does not
        // reliably surface this. Query active EscalationRules and check
        // MCD reverse dependency.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Escalation Rule check skipped — CPU limit approaching.');
        } else
        try {
            String erSoql = 'SELECT Id, Name, Active FROM EscalationRule WHERE Active = true LIMIT 200';
            HttpRequest erReq = new HttpRequest();
            erReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(erSoql, 'UTF-8'));
            erReq.setMethod('GET');
            erReq.setHeader('Content-Type', 'application/json');
            erReq.setTimeout(TIMEOUT_LONG);
            HttpResponse erRes = http.send(erReq);
            if (erRes.getStatusCode() >= 200 && erRes.getStatusCode() < 300) {
                Map<String, Object> erBody    = (Map<String, Object>) JSON.deserializeUntyped(erRes.getBody());
                List<Object>        erRecords = (List<Object>) erBody.get('records');
                if (erRecords != null) {
                    for (Object r : erRecords) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              erName = (String) row.get('Name');
                        String              erId   = (String) row.get('Id');
                        String mcdCheck = 'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                                          'WHERE MetadataComponentId = \'' + erId + '\' ' +
                                          'AND RefMetadataComponentName = \'' + String.escapeSingleQuotes(className) + '\' LIMIT 1';
                        HttpRequest mcdReq = new HttpRequest();
                        mcdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(mcdCheck, 'UTF-8'));
                        mcdReq.setMethod('GET');
                        mcdReq.setHeader('Content-Type', 'application/json');
                        mcdReq.setTimeout(TIMEOUT_SHORT);
                        HttpResponse mcdRes = http.send(mcdReq);
                        if (mcdRes.getStatusCode() >= 200 && mcdRes.getStatusCode() < 300) {
                            Map<String, Object> mb = (Map<String, Object>) JSON.deserializeUntyped(mcdRes.getBody());
                            List<Object> mr = (List<Object>) mb.get('records');
                            if (mr != null && !mr.isEmpty() && erName != null) {
                                String dedupKey = ('escalationrule|' + erName).toLowerCase();
                                if (!seenKeys.contains(dedupKey)) {
                                    seenKeys.add(dedupKey);
                                    ReferenceItem item = new ReferenceItem();
                                    item.name          = erName;
                                    item.type          = 'EscalationRule';
                                    item.groupLabel    = 'Escalation Rules';
                                    item.relationship  = 'Active escalation rule references this Apex class';
                                    result.references.add(item);
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Escalation Rule check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 8 — Auto-Response Rules
        // AutoResponseRule fires on inbound emails/cases/leads. The email
        // alert action can reference an Apex class indirectly. Check MCD.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Auto-Response Rule check skipped — CPU limit approaching.');
        } else
        try {
            String rrSoql = 'SELECT Id, Name, Active FROM AutoResponseRule WHERE Active = true LIMIT 200';
            HttpRequest rrReq = new HttpRequest();
            rrReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(rrSoql, 'UTF-8'));
            rrReq.setMethod('GET');
            rrReq.setHeader('Content-Type', 'application/json');
            rrReq.setTimeout(TIMEOUT_LONG);
            HttpResponse rrRes = http.send(rrReq);
            if (rrRes.getStatusCode() >= 200 && rrRes.getStatusCode() < 300) {
                Map<String, Object> rrBody    = (Map<String, Object>) JSON.deserializeUntyped(rrRes.getBody());
                List<Object>        rrRecords = (List<Object>) rrBody.get('records');
                if (rrRecords != null) {
                    for (Object r : rrRecords) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              rrName = (String) row.get('Name');
                        String              rrId   = (String) row.get('Id');
                        String mcdCheck = 'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                                          'WHERE MetadataComponentId = \'' + rrId + '\' ' +
                                          'AND RefMetadataComponentName = \'' + String.escapeSingleQuotes(className) + '\' LIMIT 1';
                        HttpRequest mcdReq = new HttpRequest();
                        mcdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(mcdCheck, 'UTF-8'));
                        mcdReq.setMethod('GET');
                        mcdReq.setHeader('Content-Type', 'application/json');
                        mcdReq.setTimeout(TIMEOUT_SHORT);
                        HttpResponse mcdRes = http.send(mcdReq);
                        if (mcdRes.getStatusCode() >= 200 && mcdRes.getStatusCode() < 300) {
                            Map<String, Object> mb = (Map<String, Object>) JSON.deserializeUntyped(mcdRes.getBody());
                            List<Object> mr = (List<Object>) mb.get('records');
                            if (mr != null && !mr.isEmpty() && rrName != null) {
                                String dedupKey = ('autoresponserule|' + rrName).toLowerCase();
                                if (!seenKeys.contains(dedupKey)) {
                                    seenKeys.add(dedupKey);
                                    ReferenceItem item = new ReferenceItem();
                                    item.name          = rrName;
                                    item.type          = 'AutoResponseRule';
                                    item.groupLabel    = 'Auto-Response Rules';
                                    item.relationship  = 'Active auto-response rule references this Apex class';
                                    result.references.add(item);
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Auto-Response Rule check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 9 — Email Services (EmailServicesFunction)
        // EmailServicesFunction stores the handler as ApexClassId (Id field),
        // NOT a traversable relationship — ApexClass.Name is not supported.
        // Fix: first look up the ApexClass Id by Name, then query
        // EmailServicesFunction WHERE ApexClassId = :classId.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Email Services check skipped — CPU limit approaching. Re-run the check.');
        } else
        try {
            // Step 1: resolve class name → Id via standard SOQL
            List<ApexClass> matchedClasses = [
                SELECT Id FROM ApexClass
                WHERE Name = :className
                LIMIT 1
            ];
            if (!matchedClasses.isEmpty()) {
                Id apexClassId = matchedClasses[0].Id;
                // Step 2: find any EmailServicesFunction using this class Id
                List<EmailServicesFunction> emailSvcs = [
                    SELECT Id, FunctionName, ApexClassId
                    FROM EmailServicesFunction
                    WHERE ApexClassId = :apexClassId
                    LIMIT 10
                ];
                for (EmailServicesFunction esf : emailSvcs) {
                    String dedupKey = ('emailservice|' + esf.FunctionName).toLowerCase();
                    if (!seenKeys.contains(dedupKey)) {
                        seenKeys.add(dedupKey);
                        ReferenceItem item  = new ReferenceItem();
                        item.name           = esf.FunctionName;
                        item.type           = 'EmailServicesFunction';
                        item.groupLabel     = 'Email Services';
                        item.relationship   = 'inbound email handler class — processes incoming emails routed to this service';
                        result.references.add(item);
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Email Services check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 9b — Named Credential callout handler
        // NamedCredential.CalloutClass = Apex class name (exact match)
        // NOT in MCD when queried from the Apex class side.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Named Credential check skipped — CPU limit approaching. Re-run the check.');
        } else
        try {
            String ncSoql = 'SELECT Id, DeveloperName, CalloutClass ' +
                            'FROM NamedCredential ' +
                            'WHERE CalloutClass = \'' + String.escapeSingleQuotes(className) + '\' ' +
                            'LIMIT 10';
            HttpRequest ncReq = new HttpRequest();
            ncReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(ncSoql, 'UTF-8'));
            ncReq.setMethod('GET');
            ncReq.setHeader('Content-Type', 'application/json');
            ncReq.setTimeout(TIMEOUT_LONG);
            HttpResponse ncRes = http.send(ncReq);
            if (ncRes.getStatusCode() >= 200 && ncRes.getStatusCode() < 300) {
                Map<String, Object> ncBody    = (Map<String, Object>) JSON.deserializeUntyped(ncRes.getBody());
                List<Object>        ncRecords = (List<Object>) ncBody.get('records');
                if (ncRecords != null) {
                    for (Object r : ncRecords) {
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              devName = (String) row.get('DeveloperName');
                        if (String.isBlank(devName)) continue;
                        String dedupKey = ('namedcredential|' + devName).toLowerCase();
                        if (!seenKeys.contains(dedupKey)) {
                            seenKeys.add(dedupKey);
                            ReferenceItem item = new ReferenceItem();
                            item.name         = devName;
                            item.type         = 'NamedCredential';
                            item.groupLabel   = 'Named Credentials';
                            item.relationship = 'Named Credential uses this class as callout handler';
                            result.references.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Named Credential check skipped: ' + ex.getMessage());
            System.debug(LoggingLevel.WARN, 'Named Credential check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 9c — Auth Provider registration handler
        // AuthProvider.RegistrationHandlerClass = Apex class name
        // NOT in MCD when queried from the Apex class side.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Auth Provider check skipped — CPU limit approaching. Re-run the check.');
        } else
        try {
            String apSoql = 'SELECT Id, DeveloperName, RegistrationHandlerClass ' +
                            'FROM AuthProvider ' +
                            'WHERE RegistrationHandlerClass = \'' + String.escapeSingleQuotes(className) + '\' ' +
                            'LIMIT 10';
            HttpRequest apReq = new HttpRequest();
            apReq.setEndpoint(BASE_URL + 'query?q=' + EncodingUtil.urlEncode(apSoql, 'UTF-8'));
            apReq.setMethod('GET');
            apReq.setHeader('Content-Type', 'application/json');
            HttpResponse apRes = http.send(apReq);
            if (apRes.getStatusCode() >= 200 && apRes.getStatusCode() < 300) {
                Map<String, Object> apBody    = (Map<String, Object>) JSON.deserializeUntyped(apRes.getBody());
                List<Object>        apRecords = (List<Object>) apBody.get('records');
                if (apRecords != null) {
                    for (Object r : apRecords) {
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              devName = (String) row.get('DeveloperName');
                        if (String.isBlank(devName)) continue;
                        String dedupKey = ('authprovider|' + devName).toLowerCase();
                        if (!seenKeys.contains(dedupKey)) {
                            seenKeys.add(dedupKey);
                            ReferenceItem item = new ReferenceItem();
                            item.name         = devName;
                            item.type         = 'AuthProvider';
                            item.groupLabel   = 'Auth Providers';
                            item.relationship = 'Auth Provider registration handler class';
                            result.references.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Auth Provider check skipped: ' + ex.getMessage());
            System.debug(LoggingLevel.WARN, 'Auth Provider check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 9d — Platform Event Subscriber Config (Tooling API)
        // ApexClassName field = exact class name match.
        // NOT in MCD when queried from the Apex class side.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Platform Event subscriber check skipped — CPU limit approaching. Re-run the check.');
        } else
        try {
            String peSoql = 'SELECT Id, DeveloperName, ApexClassName ' +
                            'FROM PlatformEventSubscriberConfig ' +
                            'WHERE ApexClassName = \'' + String.escapeSingleQuotes(className) + '\' ' +
                            'LIMIT 20';
            HttpRequest peReq = new HttpRequest();
            peReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(peSoql, 'UTF-8'));
            peReq.setMethod('GET');
            peReq.setHeader('Content-Type', 'application/json');
            peReq.setTimeout(TIMEOUT_LONG);
            HttpResponse peRes = http.send(peReq);
            if (peRes.getStatusCode() >= 200 && peRes.getStatusCode() < 300) {
                Map<String, Object> peBody    = (Map<String, Object>) JSON.deserializeUntyped(peRes.getBody());
                List<Object>        peRecords = (List<Object>) peBody.get('records');
                if (peRecords != null) {
                    for (Object r : peRecords) {
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              devName = (String) row.get('DeveloperName');
                        if (String.isBlank(devName)) continue;
                        String dedupKey = ('platformeventsub|' + devName).toLowerCase();
                        if (!seenKeys.contains(dedupKey)) {
                            seenKeys.add(dedupKey);
                            ReferenceItem item = new ReferenceItem();
                            item.name         = devName;
                            item.type         = 'PlatformEventSubscriberConfig';
                            item.groupLabel   = 'Platform Events';
                            item.relationship = 'Platform Event subscriber — handles incoming events';
                            result.references.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Platform Event subscriber check skipped: ' + ex.getMessage());
            System.debug(LoggingLevel.WARN, 'Platform Event subscriber check skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 9e — External Services (ExternalServiceRegistration)
        // ExternalServiceRegistration references Apex classes via
        // operations mapped to invocable methods. Query by class name
        // in the operations body is not reliably queryable via SOQL,
        // so we use MCD with MetadataComponentType = 'ExternalService'
        // as a targeted fallback already covered by CALLOUT 1.
        // Advisory note added here for awareness.
        // ─────────────────────────────────────────────────────────────
        result.warningNotes.add(
            '⚠️ External Services: If this class is used as an External Service operation handler, ' +
            'verify manually in Setup > External Services.'
        );


        // CHECK 10b — Test Suite Membership
        // isTestClass and classId already populated in CALLOUT 2.
        // Only runs if this is actually a test class — skipped for all others.
        if (result.isTestClass && result.classId != null) {
            if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
                result.warningNotes.add('⚠️ Test Suite membership check skipped — CPU limit approaching. Re-run the check.');
            } else
            try {
                String suiteSoql = 'SELECT ApexTestSuite.TestSuiteName FROM TestSuiteMembership ' +
                                   'WHERE ApexClassId = \'' + result.classId + '\' LIMIT 50';
                HttpRequest suiteReq = new HttpRequest();
                suiteReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(suiteSoql, 'UTF-8'));
                suiteReq.setMethod('GET');
                suiteReq.setHeader('Content-Type', 'application/json');
                suiteReq.setTimeout(TIMEOUT_LONG);
                HttpResponse suiteRes = http.send(suiteReq);

                if (suiteRes.getStatusCode() >= 200 && suiteRes.getStatusCode() < 300) {
                    Map<String, Object> suiteBody    = (Map<String, Object>) JSON.deserializeUntyped(suiteRes.getBody());
                    List<Object>        suiteRecords = (List<Object>) suiteBody.get('records');
                    if (suiteRecords != null) {
                        for (Object sr : suiteRecords) {
                            Map<String, Object> srMap  = (Map<String, Object>) sr;
                            Map<String, Object> suite  = (Map<String, Object>) srMap.get('ApexTestSuite');
                            if (suite == null) continue;
                            String suiteName = (String) suite.get('TestSuiteName');
                            if (String.isBlank(suiteName)) continue;
                            String dedupKey = ('testsuite|' + suiteName).toLowerCase();
                            if (!seenKeys.contains(dedupKey)) {
                                seenKeys.add(dedupKey);
                                ReferenceItem item  = new ReferenceItem();
                                item.name           = suiteName;
                                item.type           = 'ApexTestSuite';
                                item.groupLabel     = 'Test Suites';
                                item.relationship   = 'class is a member of this test suite — removing breaks suite coverage runs';
                                result.references.add(item);
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                result.warningNotes.add('Test Suite membership check skipped: ' + ex.getMessage());
            }
        } // end if (isTestClass)

        // CHECK 10d — Field-Level Security advisory (non-blocking, no callout needed)
        result.warningNotes.add(
            '\u26a0\ufe0f Field-Level Security: If this class exposes @AuraEnabled fields or ' +
            'is a VF controller, verify FLS-dependent UI won\'t break. ' +
            'Check Setup > Permission Sets > Field Permissions.'
        );

        // CHECK 15 — LWC JS Source Scan (@salesforce/apex imports)
        //
        // TWO PROBLEMS FIXED:
        //   1. Source LIKE in Tooling API → HTTP 400 (not supported on Source field)
        //   2. LightningComponentBundle.DeveloperName relationship traversal → HTTP 400
        //
        // FIX: Two-step approach —
        //   Step 1: Fetch all JS files (no Source filter in SOQL) +
        //           LightningComponentBundleId (flat Id — always works)
        //           Filter Source in Apex code instead.
        //   Step 2: Resolve bundle IDs → DeveloperNames via separate query.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ LWC JS source scan skipped — CPU limit approaching. Re-run the check.');
        } else
        try {
            String apexImportPattern = '@salesforce/apex/' + className.toLowerCase() + '.';
            String slashPattern      = '/' + className.toLowerCase() + '.';

            // Step 1 — fetch JS files with BundleId only (no Source filter, no relationship)
            String lwcResSoql =
                'SELECT Id, FilePath, Source, LightningComponentBundleId ' +
                'FROM LightningComponentResource ' +
                'WHERE FilePath LIKE \'%.js\' ' +
                'LIMIT 300';

            HttpRequest lwcResReq = new HttpRequest();
            lwcResReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(lwcResSoql, 'UTF-8'));
            lwcResReq.setMethod('GET');
            lwcResReq.setHeader('Content-Type', 'application/json');
            lwcResReq.setTimeout(TIMEOUT_LONG);
            HttpResponse lwcResRes = http.send(lwcResReq);

            if (lwcResRes.getStatusCode() >= 200 && lwcResRes.getStatusCode() < 300) {
                Map<String, Object> lwcResBody    = (Map<String, Object>) JSON.deserializeUntyped(lwcResRes.getBody());
                List<Object>        lwcResRecords = (List<Object>) lwcResBody.get('records');

                if (lwcResRecords != null) {
                    // Filter in Apex — check source for apex import pattern
                    Set<String> matchedBundleIds = new Set<String>();
                    for (Object r : lwcResRecords) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String              src = (String) row.get('Source');
                        String              bId = (String) row.get('LightningComponentBundleId');
                        if (String.isBlank(src) || String.isBlank(bId)) continue;
                        String srcLower = src.toLowerCase();
                        if (srcLower.contains(apexImportPattern) || srcLower.contains(slashPattern)) {
                            matchedBundleIds.add(bId);
                        }
                    }

                    // Step 2 — resolve bundle IDs → DeveloperNames
                    if (!matchedBundleIds.isEmpty()) {
                        String idList     = '(\'' + String.join(new List<String>(matchedBundleIds), '\',\'') + '\')';
                        String bundleSoql = 'SELECT Id, DeveloperName FROM LightningComponentBundle ' +
                                           'WHERE Id IN ' + idList;
                        HttpRequest bundleReq = new HttpRequest();
                        bundleReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(bundleSoql, 'UTF-8'));
                        bundleReq.setMethod('GET');
                        bundleReq.setHeader('Content-Type', 'application/json');
                        bundleReq.setTimeout(TIMEOUT_LONG);
                        HttpResponse bundleRes = http.send(bundleReq);

                        if (bundleRes.getStatusCode() >= 200 && bundleRes.getStatusCode() < 300) {
                            Map<String, Object> bundleBody    = (Map<String, Object>) JSON.deserializeUntyped(bundleRes.getBody());
                            List<Object>        bundleRecords = (List<Object>) bundleBody.get('records');
                            if (bundleRecords != null) {
                                for (Object br : bundleRecords) {
                                    Map<String, Object> bRow  = (Map<String, Object>) br;
                                    String              bName = (String) bRow.get('DeveloperName');
                                    if (String.isBlank(bName)) continue;
                                    String dedupKey = ('lightningcomponentbundle|' + bName).toLowerCase();
                                    if (!seenKeys.contains(dedupKey)) {
                                        seenKeys.add(dedupKey);
                                        ReferenceItem item  = new ReferenceItem();
                                        item.name           = bName;
                                        item.type           = 'LightningComponentBundle';
                                        item.groupLabel     = 'LWC Components';
                                        item.relationship   = 'imports via @salesforce/apex/' + className + '.*';
                                        result.references.add(item);
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                result.warningNotes.add('⚠️ LWC JS scan returned HTTP ' + lwcResRes.getStatusCode() + ' — check manually: Setup > Apex Classes > "' + className + '" > Where is this used?');
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ LWC JS scan skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CALLOUT 4 — Apex class body scan
        // MCD misses test classes that reference a class without a formal
        // metadata dependency. Also catches extends, implements, new X(),
        // static calls — anything MCD's index may not have registered.
        // Runs LAST — most CPU-expensive but catches what MCD misses.
        // CPU-guarded — skips with advisory if budget exhausted.
        // ─────────────────────────────────────────────────────────────
        if (Limits.getCpuTime() > Limits.getLimitCpuTime() - CPU_RESERVE_MS) {
            result.warningNotes.add('⚠️ Apex body scan skipped — CPU limit approaching. Use Setup > Apex Classes > "Where is this used?"');
        } else
        try {
            String lowerClass   = className.toLowerCase();
            String apexBodySoql =
                'SELECT Id, Name, Body ' +
                'FROM ApexClass ' +
                'WHERE Name != \'' + safeClass + '\' ' +
                'AND NamespacePrefix = null ' +
                'LIMIT 500';
            HttpRequest abReq = new HttpRequest();
            abReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(apexBodySoql, 'UTF-8'));
            abReq.setMethod('GET');
            abReq.setHeader('Content-Type', 'application/json');
            abReq.setTimeout(TIMEOUT_LONG);
            HttpResponse abRes = http.send(abReq);

            if (abRes.getStatusCode() >= 200 && abRes.getStatusCode() < 300) {
                Map<String, Object> abBody    = (Map<String, Object>) JSON.deserializeUntyped(abRes.getBody());
                List<Object>        abRecords = (List<Object>) abBody.get('records');
                if (abRecords != null) {
                    for (Object r : abRecords) {
                        Map<String, Object> row        = (Map<String, Object>) r;
                        String              callerName = (String) row.get('Name');
                        String              bodyStr    = (String) row.get('Body');
                        if (String.isBlank(bodyStr) || String.isBlank(callerName)) continue;
                        String bodyLower = bodyStr.toLowerCase();
                        if (!bodyLower.contains(lowerClass)) continue;
                        // Skip if already found via MCD
                        String dedupKey = ('apexclass|' + callerName).toLowerCase();
                        if (seenKeys.contains(dedupKey)) continue;
                        seenKeys.add(dedupKey);
                        // Classify relationship type
                        String rel = 'references this class in body';
                        if      (bodyLower.contains('extends '    + lowerClass)) rel = 'extends this class (inheritance)';
                        else if (bodyLower.contains('implements ' + lowerClass)) rel = 'implements this interface';
                        else if (bodyLower.contains('new '        + lowerClass + '(')) rel = 'instantiates this class';
                        else if (bodyLower.contains('@istest'))                    rel = 'test class — references and tests this class';
                        else if (bodyLower.contains(lowerClass    + '.'))          rel = 'calls static method on this class';
                        ReferenceItem item  = buildReferenceItem(callerName, 'ApexClass');
                        item.relationship   = rel;
                        result.references.add(item);
                    }
                }
            }
        } catch (Exception ex) {
            result.warningNotes.add('⚠️ Apex body scan skipped: ' + ex.getMessage());
        }

        // ─────────────────────────────────────────────────────────────
        // CHECK 16 — Dynamic Apex / Reflection Warning (always added)
        // Type.forName(), Database.query(), JSON.deserialize(),
        // string-based class instantiation — NEVER detectable statically.
        // ─────────────────────────────────────────────────────────────
        result.warningNotes.add(
            '⚠️ Dynamic references cannot be detected: Type.forName(\'' + className + '\'), ' +
            'JSON.deserialize(), string-based instantiation, or API calls using the class name ' +
            'as a string will NOT appear in any reference scan. Verify manually if this class ' +
            'is used in any factory patterns, handler registries, or middleware integrations.'
        );

        // ─────────────────────────────────────────────────────────────
        // FINALIZE — Count, classify, confidence level
        // ─────────────────────────────────────────────────────────────
        result.referenceCount        = result.references.size();
        result.hasBlockingReferences = result.referenceCount > 0;
        // isUnused = no references found AND not managed AND not a test class
        result.isUnused = !result.hasBlockingReferences
            && !result.isManagedPackage
            && !result.isTestClass;

        if (result.hasBlockingReferences) {
            // References found — HIGH confidence it is in use
            result.confidenceLevel = 'HIGH';
            result.confidenceNote  =
                'HIGH confidence — ' + result.referenceCount + ' reference(s) found across ' +
                result.referenceCount + ' component(s). This class is actively referenced and ' +
                'CANNOT be safely deleted until all references are removed.';
            result.formattedReport = buildFormattedReport(className, result.references, null, 'ApexClass');

            // Append dynamic warning to report
            result.formattedReport +=
                '\n\n⚠️  Dynamic Reference Warning:\n' +
                '  Type.forName(), JSON.deserialize(), or string-based usage\n' +
                '  cannot be detected by any scan. Verify manually.\n';

            // Append advisory notes
            if (!result.warningNotes.isEmpty()) {
                result.formattedReport += '\n📋 Additional Advisories:\n';
                for (String note : result.warningNotes) {
                    if (!note.startsWith('⚠️ Dynamic')) { // already added above
                        result.formattedReport += '  ' + note + '\n';
                    }
                }
            }

        } else {
            // No references found — label as POTENTIALLY UNUSED, not definitively
            result.confidenceLevel = 'MEDIUM';
            result.confidenceNote  =
                'No references detected across all check categories (MCD, SymbolTable, ' +
                'Interface/extends, Flow types, Scheduled/Async jobs, Email Services, ' +
                'Test Suites, Permission Sets, Profiles, Field-Level Security, LWC JS scan, ' +
                'Formula Fields, Layouts, List Views, Email Templates, Static Resources). ' +
                'Labeled as "Potentially Unused" — dynamic Apex usage (Type.forName, ' +
                'string-based instantiation, middleware API calls) cannot be scanned. ' +
                'Safe to delete only after manual confirmation.';
            result.formattedReport =
                '✅ "' + className + '" appears POTENTIALLY UNUSED.\n\n' +
                'Checks completed (0 references found):\n' +
                '  ✔ MetadataComponentDependency (Flows, LWC, Aura, VF, FlexiPages, Triggers,\n' +
                '       Record-Triggered Flows, Screen Flows, Subflows, Formula Fields,\n' +
                '       Layouts, Compact Layouts, List Views, Email Templates, Static Resources)\n' +
                '  ✔ SymbolTable — Apex-to-Apex callers (calls / extends / implements)\n' +
                '  ✔ Interface & parentClass detection (extends + implements)\n' +
                '  ✔ Live Scheduled Jobs (CronTrigger / AsyncApexJob)\n' +
                '  ✔ Active Batch / Queueable / Future jobs\n' +
                '  ✔ Email Services\n' +
                '  ✔ Test Suite Membership\n' +
                '  ✔ Permission Sets & Profiles (SetupEntityAccess)\n' +
                '  ✔ Field-Level Security advisory\n' +
                '  ✔ LWC JS @salesforce/apex import scan\n' +
                '  ✔ AI / Agentforce components\n\n' +
                '⚠️  Cannot detect: Type.forName(\'' + className + '\'), ' +
                'JSON.deserialize(), string-based instantiation, or external API ' +
                'calls using the class name as a string.\n\n' +
                'Confidence: MEDIUM — no static references found, but dynamic usage is unverifiable.\n\n' +
                'Proceed with deletion only after confirming no dynamic usage exists.';
        }

        return result;
    }

    // ── Map a raw metadata type to a human-friendly group ────────
    // Covers every MetadataComponentType that can reference an Apex class
    // as returned by MetadataComponentDependency tooling API.
    private static ReferenceItem buildReferenceItem(String cName, String cType) {
        ReferenceItem item = new ReferenceItem();
        item.name = cName;
        item.type = cType;

        String t = cType.toLowerCase();

        // ── CODE ─────────────────────────────────────────────────────
        if (t == 'apexclass') {
            item.groupLabel   = 'Apex Classes';
            item.relationship = 'Setup > Apex Classes > "' + cName + '" > open and remove the reference';

        } else if (t == 'apextrigger') {
            item.groupLabel   = 'Triggers';
            item.relationship = 'Setup > Apex Triggers > "' + cName + '" > open and remove the reference';

        } else if (t == 'apextestsuite') {
            item.groupLabel   = 'Test Suites';
            item.relationship = 'Developer Console > Test > Suites > "' + cName + '" > remove this class from the suite';

        // ── AUTOMATION ───────────────────────────────────────────────
        } else if (t == 'flow' || t == 'flowdefinition') {
            item.groupLabel   = 'Flows';
            item.relationship = 'Setup > Flows > "' + cName + '" > open > remove the Apex Action element > Save';

        } else if (t == 'recordtriggeredflow') {
            item.groupLabel   = 'Flows';
            item.relationship = 'Setup > Flows > "' + cName + '" > open > remove the Apex Action > Save & Activate';

        } else if (t == 'screenflow') {
            item.groupLabel   = 'Flows';
            item.relationship = 'Setup > Flows > "' + cName + '" > open > remove the Apex Action > Save & Activate';

        } else if (t == 'subflow') {
            item.groupLabel   = 'Flows';
            item.relationship = 'Setup > Flows > "' + cName + '" > open > remove the Subflow element > Save';

        } else if (t.contains('workflowrule') || t.contains('workflowalert')
                || t.contains('workflowtask') || t.contains('workflowoutbound')
                || t.contains('processbuilder') || t.contains('process')) {
            item.groupLabel   = 'Workflow / Process Builder';
            item.relationship = 'Setup > Process Automation > Workflow Rules > "' + cName + '" > deactivate and remove';

        // ── UI COMPONENTS ────────────────────────────────────────────
        } else if (t == 'lightningcomponentbundle') {
            item.groupLabel   = 'LWC Components';
            item.relationship = 'Open "' + cName + '" LWC in VS Code > remove the import or usage reference';

        } else if (t == 'auradefinitionbundle') {
            item.groupLabel   = 'Aura Components';
            item.relationship = 'Open Aura component "' + cName + '" > remove the reference from controller/markup';

        } else if (t == 'apexpage') {
            item.groupLabel   = 'Visualforce Pages';
            item.relationship = 'Setup > Visualforce Pages > "' + cName + '" > edit > remove controller/extension attribute';

        } else if (t == 'apexcomponent') {
            item.groupLabel   = 'Visualforce Components';
            item.relationship = 'Setup > Visualforce Components > "' + cName + '" > edit > remove controller reference';

        } else if (t == 'flexipage') {
            item.groupLabel   = 'Lightning Pages';
            item.relationship = 'Setup > Lightning App Builder > "' + cName + '" > remove the component > Save';

        } else if (t == 'customtab') {
            item.groupLabel   = 'Tabs';
            item.relationship = 'Setup > Tabs > "' + cName + '" > edit > change or remove the page reference';

        // ── ACTIONS / INVOCABLE ──────────────────────────────────────
        } else if (t == 'quickaction') {
            item.groupLabel   = 'Quick Actions';
            item.relationship = 'Setup > Object Manager > find the object > Buttons, Links and Actions > "' + cName + '" > edit or delete';

        } else if (t == 'actionlinkgrouptemplate') {
            item.groupLabel   = 'Action Links';
            item.relationship = 'Setup > Action Link Templates > "' + cName + '" > edit and remove the reference';

        // ── CONFIGURATION / SCHEMA ───────────────────────────────────
        } else if (t == 'customobject') {
            item.groupLabel   = 'Custom Objects';
            item.relationship = 'Setup > Object Manager > "' + cName + '" > View Dependencies';

        } else if (t == 'customfield') {
            item.groupLabel   = 'Custom Fields';
            item.relationship = 'Setup > Object Manager > find object > Fields > "' + cName + '" > edit formula';

        } else if (t == 'validationrule') {
            item.groupLabel   = 'Validation Rules';
            item.relationship = 'Setup > Object Manager > find object > Validation Rules > "' + cName + '" > edit and remove reference';

        } else if (t == 'fieldset') {
            item.groupLabel   = 'Field Sets';
            item.relationship = 'Setup > Object Manager > find object > Field Sets > "' + cName + '" > edit';

        } else if (t == 'formulafield' || t == 'formula') {
            item.groupLabel   = 'Formula Fields';
            item.relationship = 'Setup > Object Manager > find object > Fields > "' + cName + '" > edit formula';

        } else if (t == 'layout' || t == 'pagelayout') {
            item.groupLabel   = 'Page Layouts';
            item.relationship = 'Setup > Object Manager > find object > Page Layouts > "' + cName + '" > remove component';

        } else if (t == 'compactlayout') {
            item.groupLabel   = 'Compact Layouts';
            item.relationship = 'Setup > Object Manager > find object > Compact Layouts > "' + cName + '" > edit';

        } else if (t == 'listview') {
            item.groupLabel   = 'List Views';
            item.relationship = 'Open the "' + cName + '" list view > Edit > remove the filter';

        } else if (t == 'emailtemplate') {
            item.groupLabel   = 'Email Templates';
            item.relationship = 'Setup > Email Templates > "' + cName + '" > edit and remove the reference';

        } else if (t == 'staticresource') {
            item.groupLabel   = 'Static Resources';
            item.relationship = 'Setup > Static Resources > "' + cName + '" > view and update references';

        } else if (t == 'fieldpermissions' || t == 'fieldsecurity' || t == 'fieldlevelSecurity') {
            item.groupLabel   = 'Field-Level Security';
            item.relationship = 'Setup > Permission Sets / Profiles > Field Permissions > remove access';

        } else if (t == 'custommetadata' || t == 'custommetadatatype') {
            item.groupLabel   = 'Custom Metadata';
            item.relationship = 'Setup > Custom Metadata Types > find type > Manage Records > "' + cName + '" > edit or delete';

        } else if (t == 'customsetting') {
            item.groupLabel   = 'Custom Settings';
            item.relationship = 'Setup > Custom Settings > "' + cName + '" > Manage > edit the value';

        } else if (t == 'custompermission') {
            item.groupLabel   = 'Custom Permissions';
            item.relationship = 'Setup > Custom Permissions > "' + cName + '" > edit or remove from Permission Sets';

        } else if (t == 'globalvalueset' || t == 'standardvalueset') {
            item.groupLabel   = 'Value Sets / Picklists';
            item.relationship = 'Setup > Picklist Value Sets > "' + cName + '" > edit values';

        // ── SECURITY / ACCESS ────────────────────────────────────────
        } else if (t == 'permissionset') {
            item.groupLabel   = 'Permission Sets';
            item.relationship = 'Setup > Permission Sets > "' + cName + '" > Apex Class Access > remove "' + item.name + '"';

        } else if (t == 'profile') {
            item.groupLabel   = 'Profiles';
            item.relationship = 'Setup > Profiles > "' + cName + '" > Apex Class Access > remove the class';

        } else if (t == 'muting permissionset' || t == 'mutingpermissionset') {
            item.groupLabel   = 'Muting Permission Sets';
            item.relationship = 'Setup > Permission Sets > "' + cName + '" > edit muting rules';

        // ── INTEGRATION ──────────────────────────────────────────────
        } else if (t == 'externalservice') {
            item.groupLabel   = 'External Services';
            item.relationship = 'Setup > External Services > "' + cName + '" > edit and remove the Apex reference';

        } else if (t == 'namedcredential') {
            item.groupLabel   = 'Named Credentials';
            item.relationship = 'Setup > Named Credentials > "' + cName + '" > edit to update callout class';

        } else if (t == 'authprovider') {
            item.groupLabel   = 'Auth Providers';
            item.relationship = 'registration handler class';

        } else if (t == 'connectedapp') {
            item.groupLabel   = 'Connected Apps';
            item.relationship = 'canvas app or OAuth handler';

        } else if (t == 'csptrustsite') {
            item.groupLabel   = 'CSP Trusted Sites';
            item.relationship = 'referenced in CSP policy';

        // ── EVENTS / MESSAGING ───────────────────────────────────────
        } else if (t == 'platformeventchannel' || t.contains('platformevent')) {
            item.groupLabel   = 'Platform Events';
            item.relationship = 'event subscriber / publisher class';

        } else if (t.contains('eventsubscriber') || t.contains('changedatacapture')) {
            item.groupLabel   = 'Change Data Capture';
            item.relationship = 'CDC subscriber class';

        } else if (t == 'notificationtype') {
            item.groupLabel   = 'Custom Notifications';
            item.relationship = 'notification sender class';

        // ── EMAIL ────────────────────────────────────────────────────
        } else if (t == 'emailservicesfunction' || t.contains('emailservice')) {
            item.groupLabel   = 'Email Services';
            item.relationship = 'inbound email handler class';

        } else if (t.contains('apexemailnotif')) {
            item.groupLabel   = 'Email Services';
            item.relationship = 'Apex email notification handler';

        // ── BATCH / SCHEDULED ────────────────────────────────────────
        } else if (t == 'scheduledapex' || t.contains('scheduledjob')) {
            item.groupLabel   = 'Scheduled Jobs';
            item.relationship = 'scheduled Apex class';

        // ── COMMUNITIES / EXPERIENCE ─────────────────────────────────
        } else if (t.contains('network') || t.contains('community') || t.contains('experience')) {
            item.groupLabel   = 'Communities / Experience';
            item.relationship = 'community controller or handler';

        } else if (t == 'sitedotcom' || t == 'site') {
            item.groupLabel   = 'Sites';
            item.relationship = 'Site.com page class or handler';

        // ── REPORTING / ANALYTICS ────────────────────────────────────
        } else if (t == 'report' || t == 'reporttype') {
            item.groupLabel   = 'Reports';
            item.relationship = 'custom report type class';

        } else if (t == 'dashboard') {
            item.groupLabel   = 'Dashboards';
            item.relationship = 'dashboard component class';

        // ── AI / AGENTFORCE ──────────────────────────────────────────
        // GenAiFunction      = Agent Action (directly wraps this Apex class)
        // GenAiPlugin        = Agent Topic (groups actions)
        // GenAiPlanner       = AI Agent / Planner (older API v60-63)
        // GenAiPlannerBundle = AI Agent bundle (API v64+)
        // GenAiPromptTemplate= Prompt Template
        // AiApplication      = AI Application config
        } else if (t == 'genaifunction') {
            item.groupLabel   = 'Agentforce - Agent Actions';
            item.relationship = 'Agent Action directly wrapping this Apex class';

        } else if (t == 'genaiplugin') {
            item.groupLabel   = 'Agentforce - Topics';
            item.relationship = 'Agent Topic grouping actions using this class';

        } else if (t == 'genaiplanner' || t == 'genaiplannerbundle') {
            item.groupLabel   = 'Agentforce - AI Agent';
            item.relationship = 'AI Agent / Planner referencing this class';

        } else if (t == 'genaiprompttemplate' || t.contains('prompttemplate')) {
            item.groupLabel   = 'Agentforce - Prompt Templates';
            item.relationship = 'Prompt Template using this class';

        } else if (t.contains('genai') || t.contains('aiapplication')) {
            item.groupLabel   = 'AI / Agentforce';
            item.relationship = 'AI component referencing this class';

        // ── BOTS / EINSTEIN (classic chatbots) ───────────────────────
        } else if (t == 'botversion' || t == 'bot') {
            item.groupLabel   = 'Einstein Bots';
            item.relationship = 'bot Apex action';

        } else if (t.contains('einstein') || t.contains('aiinsight')) {
            item.groupLabel   = 'Einstein Features';
            item.relationship = 'Einstein feature handler';

        // ── MANAGED PACKAGES ─────────────────────────────────────────
        } else if (t == 'installedpackage') {
            item.groupLabel   = 'Installed Packages';
            item.relationship = 'class included in managed package';

        // ── CATCH-ALL ────────────────────────────────────────────────
        } else {
            item.groupLabel   = 'Other (' + cType + ')';
            item.relationship = 'references';
        }

        return item;
    }

    // ── Build the clean formatted report string ───────────────────
    // genAiTypes = list of type strings from the HTTP 400 error (may be null)
    @SuppressWarnings('PMD.ExcessiveParameterList')
    // ── Public wrapper for use by OrgCleanupAgentAction.checkReferences ──
    public static String buildFormattedReportPublic(String componentName, List<ReferenceItem> items, String componentType) {
        return buildFormattedReport(componentName, items, null, componentType);
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String buildFormattedReport(String className, List<ReferenceItem> items, List<String> genAiTypes, String componentType) {
        // Group items
        Map<String, List<ReferenceItem>> groups = new Map<String, List<ReferenceItem>>();
        Map<String, String>              emojis  = new Map<String, String>();

        for (ReferenceItem item : items) {
            if (!groups.containsKey(item.groupLabel)) {
                groups.put(item.groupLabel, new List<ReferenceItem>());
                emojis.put(item.groupLabel, item.emoji);
            }
            groups.get(item.groupLabel).add(item);
        }

        // Ordered group display
        List<String> groupOrder = new List<String>{
            // AI / Agentforce first — most likely blocker in modern orgs
            'Agentforce - Agent Actions', 'Agentforce - Topics', 'Agentforce - AI Agent',
            'Agentforce - Prompt Templates', 'AI / Agentforce', 'Einstein Bots', 'Einstein Features',
            // Automation
            'Flows', 'Flows (referencing this trigger)', 'Flows (Subflow Caller)', 'Workflow / Process Builder', 'Approval Processes',
            // Code
            'Apex Classes', 'Apex Classes (called by this trigger)', 'Triggers', 'Test Suites', 'Test Classes (referencing trigger)', 'Test Classes',
            // UI
            'LWC Components', 'Aura Components', 'Visualforce Pages', 'Visualforce Components',
            'Lightning Pages', 'Tabs',
            // Actions
            'Quick Actions', 'Action Links',
            // Experience Cloud
            'Experience Cloud Pages',
            // Schema / Config
            'Custom Objects', 'Custom Fields', 'Formula Fields', 'Validation Rules',
            'Field Sets', 'Page Layouts', 'Compact Layouts', 'List Views',
            'Custom Metadata', 'Custom Settings', 'Custom Permissions', 'Value Sets / Picklists',
            // Security
            'Permission Sets', 'Profiles', 'Muting Permission Sets', 'Field-Level Security',
            // Integration
            'External Services', 'Named Credentials', 'Auth Providers',
            'Connected Apps', 'CSP Trusted Sites', 'Static Resources',
            // Events / Messaging
            'Platform Events', 'Platform Event Subscriber Config', 'Change Data Capture', 'Custom Notifications',
            // Email
            'Email Services', 'Email Templates',
            // Batch / Scheduled
            'Scheduled Jobs',
            // Communities
            'Communities / Experience', 'Sites',
            // Reporting
            'Reports', 'Dashboards',
            // Packages
            'Installed Packages'
        };

        // Count derived from exactly what will be displayed:
        // items (SOQL/MCD found refs) + genAiTypes (from HTTP error body).
        // These are de-duped before reaching here via seenKeys, so the
        // count always matches the list shown to the user — no mismatch.
        Integer total = items.size();
        if (genAiTypes != null) {
            for (String genAiType : genAiTypes) {
                if (String.isNotBlank(genAiType)) total++;
            }
        }

        String report = '';
        report += 'Cannot delete "' + className + '". ' + total + ' reference(s) must be removed first.\n\n';

        // Known groups in order
        for (String groupLabel : groupOrder) {
            if (!groups.containsKey(groupLabel)) continue;
            List<ReferenceItem> grpItems = groups.get(groupLabel);
            report += groupLabel + ':\n';
            Integer idx = 1;
            for (ReferenceItem it : grpItems) {
                report += '  ' + idx++ + '. ' + it.name + '\n';
                // Show navigation tip if available
                if (String.isNotBlank(it.relationship)) {
                    report += '     → ' + it.relationship + '\n';
                }
            }
            report += '\n';
            groups.remove(groupLabel);
        }

        // Any remaining groups not in the ordered list
        for (String groupLabel : groups.keySet()) {
            List<ReferenceItem> grpItems = groups.get(groupLabel);
            report += groupLabel + ':\n';
            Integer idx = 1;
            for (ReferenceItem it : grpItems) {
                report += '  ' + idx++ + '. ' + it.name + '\n';
                if (String.isNotBlank(it.relationship)) {
                    report += '     → ' + it.relationship + '\n';
                }
            }
            report += '\n';
        }

        // GenAI types from error body — shown when Tooling query couldn't resolve real names
        // (e.g. GenAiFunction is not accessible in this org's API version, or returned no rows).
        // When checkAllFlowReferences/checkAllApexReferences DID resolve names, they arrive
        // as normal ReferenceItems in `items` under groupLabel 'Agentforce - Agent Actions'
        // and are already rendered in the grouped block above — genAiTypes will be empty.
        if (genAiTypes != null && !genAiTypes.isEmpty()) {
            report += 'Agentforce - Agent Actions:\n';
            for (String t : genAiTypes) {
                // t is a raw type label from the error body (e.g. "Action", "Generative AI Function Definition")
                // Show it as a placeholder with a note that the real name could not be resolved.
                String displayT = t.equalsIgnoreCase('Action') ? 'Agent Action (name could not be resolved)' : t;
                report += '  - ' + displayT + '\n';
            }
            report += '  To fix: Setup > Agents > find Agent using "' + className + '" > Topics & Actions > remove this Action > retry delete\n\n';
        }

        // Dynamic tip based on component type
        String setupPath = '';
        if (componentType == null || componentType == '' || componentType == 'ApexClass') {
            setupPath = 'Setup > Apex Classes > "' + className + '" > "Where is this used?"';
        } else if (componentType == 'Flow') {
            setupPath = 'Setup > Flows > "' + className + '" > "View Dependencies"';
        } else if (componentType == 'ApexTrigger') {
            setupPath = 'Setup > Apex Triggers > "' + className + '" > "Where is this used?"';
        } else if (componentType == 'LightningComponentBundle') {
            setupPath = 'Setup > Lightning Components > "' + className + '" > "Where is this used?"';
        } else if (componentType == 'AuraDefinitionBundle') {
            setupPath = 'Setup > Lightning Components (Aura) > "' + className + '" > "Where is this used?"';
        } else if (componentType == 'CustomObject') {
            setupPath = 'Setup > Object Manager > "' + className + '" > "View Dependencies"';
        } else if (componentType == 'CustomField') {
            setupPath = 'Setup > Object Manager > field "' + className + '" > "Where is this used?"';
        } else if (componentType == 'ValidationRule') {
            setupPath = 'Setup > Object Manager > Validation Rules > "' + className + '" > "Where is this used?"';
        } else if (componentType == 'PermissionSet') {
            setupPath = 'Setup > Permission Sets > "' + className + '" > "Where is this used?"';
        } else if (componentType == 'Profile') {
            setupPath = 'Setup > Profiles > "' + className + '" > "Where is this used?"';
        } else {
            setupPath = 'Setup > "' + className + '" > "Where is this used?"';
        }
        report += 'Tip: ' + setupPath + ' for the full list.';


        return report;
    }

    // ── Parse DEPENDENCY_EXISTS error body → list of dep type strings ──
    private static List<String> parseDepTypesFromError(String responseBody) {
        List<String> depTypes = new List<String>();
        if (String.isBlank(responseBody)) return depTypes;
        try {
            // Error format: [{"message":"...Remove the usage...: TypeA \nTypeB","errorCode":"DEPENDENCY_EXISTS"}]
            Object parsed = JSON.deserializeUntyped(responseBody);
            List<Object> errList;
            if (parsed instanceof List<Object>) {
                errList = (List<Object>) parsed;
            } else {
                return depTypes;
            }
            for (Object e : errList) {
                Map<String, Object> errMap = (Map<String, Object>) e;
                String errMsg = (String) errMap.get('message');
                if (String.isBlank(errMsg)) continue;
                // Types come after the last ': ' separator
                if (!errMsg.contains(': ')) continue;
                String typePart = errMsg.substringAfterLast(': ').trim();
                for (String t : typePart.split('\n')) {
                    String cleaned = t.replace('[','').replace(']','').replace('{','').replace('}','').replace('"','').trim();
                    if (String.isNotBlank(cleaned) && !cleaned.containsIgnoreCase('remove')
                        && !cleaned.containsIgnoreCase('cannot') && !cleaned.containsIgnoreCase('operation')) {
                        depTypes.add(cleaned);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'parseDepTypesFromError failed: ' + ex.getMessage());
        }
        return depTypes;
    }


    // ═══════════════════════════════════════════════════════════════
    // DEBUG — call once from Anonymous Apex to diagnose trigger scan
    // Usage: System.debug(MetadataEngine.debugTriggerScan('YourClassName'));
    // DELETE after diagnosis.
    // ═══════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=false)
    public static String debugTriggerScan(String className) {
        String out = 'TRIGGER SCAN DEBUG for: ' + className + '\n\n';
        try {
            Http http = new Http();
            String soql = 'SELECT Id, Name, Body FROM ApexTrigger WHERE NamespacePrefix = null LIMIT 200';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            out += 'HTTP Status: ' + res.getStatusCode() + '\n';
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                out += 'Total triggers found: ' + (records != null ? records.size() : 0) + '\n\n';
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              trgName = (String) row.get('Name');
                        String              trgBody = (String) row.get('Body');
                        Object              stObj   = row.get('SymbolTable');
                        out += 'Trigger: ' + trgName + '\n';
                        out += '  SymbolTable null? ' + (stObj == null) + '\n';
                        // Check Body contains class name
                        Boolean bodyMatch = String.isNotBlank(trgBody) &&
                            trgBody.toLowerCase().contains(className.toLowerCase());
                        out += '  Body contains "' + className + '"? ' + bodyMatch + '\n';
                        // Check SymbolTable externalReferences
                        if (stObj != null) {
                            Map<String, Object> st      = (Map<String, Object>) stObj;
                            List<Object>        extRefs = (List<Object>) st.get('externalReferences');
                            out += '  externalReferences count: ' + (extRefs != null ? extRefs.size() : 0) + '\n';
                            if (extRefs != null) {
                                for (Object er : extRefs) {
                                    Map<String, Object> erm     = (Map<String, Object>) er;
                                    String              refName = (String) erm.get('name');
                                    out += '    ref: ' + refName + '\n';
                                }
                            }
                        }
                        out += '\n';
                    }
                }
            } else {
                out += 'ERROR: ' + res.getBody() + '\n';
            }
        } catch (Exception ex) {
            out += 'EXCEPTION: ' + ex.getMessage() + '\n' + ex.getStackTraceString();
        }
        return out;
    }

    public static DeleteResult deleteApexClassByName(String className) {
        // ── Single Organization query: namespace strip + org type detection ──
        String  strippedClassName = className;
        Boolean isSandbox         = false;
        Boolean isDeveloperEdition = false;
        try {
            List<Organization> orgInfo = [SELECT NamespacePrefix, IsSandbox, OrganizationType FROM Organization LIMIT 1];
            if (!orgInfo.isEmpty()) {
                String ns = orgInfo[0].NamespacePrefix;
                if (String.isNotBlank(ns) && strippedClassName.startsWith(ns + '_')) {
                    strippedClassName = strippedClassName.substring(ns.length() + 1);
                }
                isSandbox          = orgInfo[0].IsSandbox;
                isDeveloperEdition = (orgInfo[0].OrganizationType == 'Developer Edition');
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'org query failed: ' + ex.getMessage()); }

        // ── Comprehensive reference check FIRST — before production guard ──
        // Runs ALL 16 reference checks:
        //   1.  MetadataComponentDependency   — Flows, LWC, Aura, VF, FlexiPages, Triggers,
        //                                       WorkflowRules, PermissionSets, Profiles,
        //                                       NamedCredentials, PlatformEvents, GenAI, Bots...
        //   2.  SymbolTable                   — Apex-to-Apex callers (extends/implements/calls)
        //   3.  Live Scheduled Jobs           — CronTrigger + AsyncApexJob (ScheduledApex)
        //   4.  Active Batch/Queueable jobs   — AsyncApexJob (Queued/Processing)
        //   5.  Approval Processes            — entry criteria, approval/rejection actions
        //   6.  Assignment Rules
        //   7.  Escalation Rules
        //   8.  Auto-Response Rules
        //   9.  Email Services                — EmailServicesFunction handler
        //  10.  Test Suite Membership         — TestSuiteMembership
        //  11.  Sharing Rules
        //  12.  Experience Cloud / Sites
        //  13.  Custom Metadata Records       — factory/handler registry patterns
        //  14.  Reports & Dashboards
        //  15.  LWC Static Resource advisory  — non-blocking warning if LWC found
        //  16.  Dynamic Apex warning          — Type.forName / string-based usage (always shown)
        //
        // If ANY blocking reference found → show full report, DO NOT attempt delete.
        // If NONE found → label as "Potentially Unused" + confidence note, then proceed.
        // ── Run all 16 checks in one pass ────────────────────────────
        // checkAllApexReferences now returns:
        //   hasBlockingReferences  — any reference found → block delete
        //   isTestClass            — has @IsTest → apply coverage rules
        //   isManagedPackage       — has foreign namespace → never delete
        //   isUnused               — no refs, not test, not managed → safe to delete
        //   classId                — Salesforce Id (no extra lookup needed)
        ApexReferenceCheckResult allRefs = checkAllApexReferences(strippedClassName);

        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        // ── Step 1: Managed package — never deletable ─────────────────
        if (allRefs.isManagedPackage) {
            result.success = false;
            result.message = '"' + strippedClassName + '" belongs to a managed package and cannot be deleted from this org.';
            return result;
        }

        // ── Step 2: Has references — show full report, stop ───────────
        if (allRefs.hasBlockingReferences) {
            result.success = false;
            result.message = allRefs.formattedReport;
            return result;
        }

        // ── Step 3: Class not found in org ────────────────────────────
        if (allRefs.classId == null) {
            result.success = false;
            result.message = 'No Apex class found with name: ' + strippedClassName;
            return result;
        }

        String classId = allRefs.classId;

        // ── Step 4: Test class rules ───────────────────────────────────
        // (test suite blocking handled inside checkAllApexReferences CHECK 10b)
        // Here we apply the production coverage warning if needed.
        // Note: CHECK 10b already adds Test Suite references to allRefs.references
        // if any exist — so if we reach here, test suites are clear.

        // ── Safety classification: allRefs has everything ────────────
        // allRefs.isTestClass, allRefs.isManagedPackage, allRefs.classId
        // and allRefs.hasBlockingReferences are all already populated by
        // checkAllApexReferences() above. No further scan needed.

        // ── Step 5: Production org + test class = coverage risk ─────
        if (allRefs.isTestClass && !isSandbox && !isDeveloperEdition) {
            result.success = false;
            result.message = '"' + strippedClassName + '" is a test class in a Production org.\n\n' +
                'Deleting it may drop code coverage below 75%, which will block all future deployments.\n\n' +
                'Check coverage impact first:\n' +
                '  Setup > Apex Classes > ' + strippedClassName + ' > "Where is this used?"\n\n' +
                'If coverage is safe, delete via: Setup > Apex Classes > ' + strippedClassName + ' > Delete.';
            return result;
        }

        // ── Step 6: Proceed to delete ─────────────────────────────────
        // Reaches here only if:
        //   - Not managed
        //   - No blocking references (all 16 checks passed)
        //   - Not a production test class (or sandbox/DE)
        //   - classId is known

        HttpRequest deleteReq = new HttpRequest();
        deleteReq.setEndpoint(BASE_URL + 'tooling/sobjects/ApexClass/' + classId);
        deleteReq.setMethod('DELETE');
        deleteReq.setHeader('Content-Type', 'application/json');

        HttpResponse deleteRes = http.send(deleteReq);

        if (deleteRes.getStatusCode() == 204 || deleteRes.getStatusCode() == 200) {
            // ── Success ──
            result.success = true;
            result.message = 'Apex class "' + className + '" successfully deleted.';

        } else if (deleteRes.getStatusCode() == 400 &&
                   deleteRes.getBody() != null &&
                   (deleteRes.getBody().containsIgnoreCase('DEPENDENCY_EXISTS') ||
                    deleteRes.getBody().containsIgnoreCase('referenced elsewhere'))) {

            // ── Salesforce blocked the delete: DEPENDENCY_EXISTS ──────────────────
            // Step 1: Parse the dependency TYPE(s) from the error message.
            //         Salesforce always tells us WHAT is blocking (e.g. "Generative AI Function Definition").
            // Step 2: Run getReferencesFor to get the actual NAMES of queryable references
            //         (Flows, Triggers, Apex Classes, LWC, etc. — all via MetadataComponentDependency).
            // Step 3: GenAI Function Definition is NOT queryable — we show the type from
            //         the error plus Setup navigation instructions.
            // Step 4: Build one clean combined report.

            String       responseBody = deleteRes.getBody();
            List<String> genAiTypes   = new List<String>();
            List<String> depTypes     = parseDepTypesFromError(responseBody);

            // Separate GenAI types (not queryable) from others
            List<String> unknownTypes = new List<String>();
            for (String dt : depTypes) {
                if (dt.containsIgnoreCase('Generative AI') || dt.containsIgnoreCase('GenAi')
                    || dt.containsIgnoreCase('Agent') || dt.containsIgnoreCase('AI Function')) {
                    genAiTypes.add(dt);
                } else {
                    unknownTypes.add(dt);
                }
            }

            // ── Reuse allRefs from pre-delete scan — no second full scan ──
            // Running checkAllApexReferences twice causes CPU time limit exceeded.
            // The pre-delete scan already ran all checks — reuse those results.
            result.success = false;

            if (allRefs.hasBlockingReferences || !genAiTypes.isEmpty()) {
                // Combine pre-delete reference results + GenAI types from error body
                List<ReferenceItem> combinedRefs = new List<ReferenceItem>(allRefs.references);
                if (!genAiTypes.isEmpty()) {
                    for (String gt : genAiTypes) {
                        ReferenceItem genAiItem = new ReferenceItem();
                        genAiItem.name         = gt;
                        genAiItem.type         = 'GenAiFunction';
                        genAiItem.groupLabel   = 'Agentforce - Agent Actions';
                        genAiItem.relationship = 'Agent Action referencing this Apex class';
                        combinedRefs.add(genAiItem);
                    }
                }
                result.message = buildFormattedReport(strippedClassName, combinedRefs, null, 'ApexClass');

            } else {
                // Full scan still returned nothing — Salesforce blocked but we cannot resolve names.
                // Build smart message based on the TYPE from the error, not always blame Agents.
                String allTypes = '';
                for (String dt : depTypes) {
                    allTypes += '  🔗 ' + dt + '\n';
                }
                if (String.isBlank(allTypes)) allTypes = '  🔗 One or more metadata components\n';

                // Detect what type is blocking and give targeted fix steps
                Boolean hasLwcAura    = false;
                Boolean hasFlow       = false;
                Boolean hasVf         = false;
                Boolean hasPermission = false;
                Boolean hasGenAiType  = false;
                for (String dt : depTypes) {
                    String dtl = dt.toLowerCase();
                    if (dtl.contains('lightning') || dtl.contains('lwc') || dtl.contains('aura') || dtl.contains('module')) hasLwcAura = true;
                    if (dtl.contains('flow') || dtl.contains('process')) hasFlow = true;
                    if (dtl.contains('visualforce') || dtl.contains('page')) hasVf = true;
                    if (dtl.contains('permission') || dtl.contains('profile')) hasPermission = true;
                    if (dtl.contains('generative') || dtl.contains('genai') || dtl.contains('agent') || dtl.contains('ai function')) hasGenAiType = true;
                }

                String fixSteps = '';
                Integer stepNum = 1;
                fixSteps += '  ' + stepNum++ + '. Setup > Apex Classes > "' + strippedClassName + '" > Where is this used?\n';
                if (hasLwcAura)    fixSteps += '  ' + stepNum++ + '. Open the LWC/Aura component and remove the @AuraEnabled import or controller reference\n';
                if (hasFlow)       fixSteps += '  ' + stepNum++ + '. Setup > Flows > open the Flow > remove the Apex Action for "' + strippedClassName + '" > Save & Activate\n';
                if (hasVf)         fixSteps += '  ' + stepNum++ + '. Setup > Visualforce Pages > remove controller="' + strippedClassName + '" from the page tag\n';
                if (hasPermission) fixSteps += '  ' + stepNum++ + '. Setup > Permission Sets / Profiles > remove Apex Class access for "' + strippedClassName + '"\n';
                if (hasGenAiType)  fixSteps += '  ' + stepNum++ + '. Setup > Agents > find Agent using this class > Topics & Actions > remove the action\n';
                if (!hasLwcAura && !hasFlow && !hasVf && !hasPermission && !hasGenAiType)
                    fixSteps += '  ' + stepNum++ + '. Remove all references shown above\n';
                fixSteps += '  ' + stepNum++ + '. Then retry the delete.';

                result.message =
                    'Cannot delete "' + strippedClassName + '". Salesforce blocked the delete.\n\n' +
                    'Blocking reference type(s) reported by Salesforce:\n' +
                    allTypes + '\n' +
                    '⚠️  Component name could not be resolved — may use dynamic instantiation or is not exposed via Tooling API.\n\n' +
                    'To fix:\n' + fixSteps;
            }

        } else {
            // ── Other HTTP error ──
            result.success = false;
            result.message = 'Failed to delete "' + className + '". HTTP ' +
                              deleteRes.getStatusCode() + ': ' + deleteRes.getBody();
        }

        return result;
    }

    // ── Mass delete Apex classes ───────────────────────────────
    // ── Profile/PermSet strip result — per class ──────────────
    public class ApexClassStripResult {
        @AuraEnabled public String       className;
        @AuraEnabled public String       classId;
        @AuraEnabled public List<String> profilesStripped;
        @AuraEnabled public List<String> permSetsStripped;
        @AuraEnabled public List<String> stripErrors;
        @AuraEnabled public Boolean      stripAttempted;
    }

    /**
     * massDeleteApexClasses — v2
     *
     * Enhanced flow:
     *   1. For each class, query SetupEntityAccess to find all Profile/PermSet references.
     *   2. If any references found → auto-strip them by deleting SetupEntityAccess records.
     *   3. Track what was stripped per class (for reporting).
     *   4. After stripping → attempt the actual class deletion.
     *   5. Return enriched MassDeleteResult that includes strip details in failure messages.
     *
     * If strip itself fails for a given class (permission error, locked profile etc.)
     * we still attempt the delete — Salesforce will return a clean error if it's still blocked.
     */
    public static MassDeleteResult massDeleteApexClasses(List<String> classNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested   = classNames.size();
        mass.successCount     = 0;
        mass.failureCount     = 0;
        mass.succeeded        = new List<String>();
        mass.failed           = new List<String>();

        for (String className : classNames) {
            if (String.isBlank(className)) continue;

            // ── Callout limit guard ───────────────────────────────────────
            // Salesforce allows max 100 HTTP callouts per transaction.
            // Each deleteApexClassByName uses ~10 callouts via checkAllApexReferences.
            // Reserve 15 as a safety buffer to avoid System.LimitException mid-loop.
            if (Limits.getCallouts() >= Limits.getLimitCallouts() - 15) {
                mass.failureCount++;
                mass.failed.add(className + ' (Skipped — callout limit approaching. Run in smaller batches.)');
                continue;
            }

            String normalizedName = className.trim().replace(' ', '_');

            // ── Step 1: Resolve the class Id (need it for SetupEntityAccess query) ──
            String classId = null;
            try {
                List<ApexClass> found = [
                    SELECT Id FROM ApexClass
                    WHERE Name = :normalizedName
                    AND NamespacePrefix = null
                    LIMIT 1
                ];
                if (!found.isEmpty()) {
                    classId = found[0].Id;
                }
            } catch (Exception ex) {
                // classId stays null — deleteApexClassByName will handle "not found"
            }

            // ── Step 2: Strip Profile + PermSet access via SetupEntityAccess ──
            ApexClassStripResult stripResult = new ApexClassStripResult();
            stripResult.className        = normalizedName;
            stripResult.classId          = classId;
            stripResult.profilesStripped = new List<String>();
            stripResult.permSetsStripped = new List<String>();
            stripResult.stripErrors      = new List<String>();
            stripResult.stripAttempted   = false;

            if (classId != null) {
                try {
                    // ── Step 2a: Fetch SetupEntityAccess rows — only Id + Parent fields ──
                    // NOTE: ParentId cannot be SELECT-ed but CAN be used in WHERE bind.
                    // We read Parent.Name + Parent.IsOwnedByProfile to identify the parent,
                    // then separately query Profile/PermissionSet by Name to get their Ids
                    // for filtering. This avoids all semi-join and ParentId select issues.
                    List<SetupEntityAccess> allAccess = [
                        SELECT Id, Parent.Name, Parent.IsOwnedByProfile
                        FROM SetupEntityAccess
                        WHERE SetupEntityId = :classId
                        LIMIT 500
                    ];

                    if (!allAccess.isEmpty()) {
                        // ── Step 2b: Split parent names by type ──
                        Set<String> profileNames = new Set<String>();
                        Set<String> permSetNames = new Set<String>();
                        for (SetupEntityAccess sea : allAccess) {
                            if (sea.Parent == null) continue;
                            if (sea.Parent.IsOwnedByProfile) {
                                profileNames.add(sea.Parent.Name);
                            } else {
                                permSetNames.add(sea.Parent.Name);
                            }
                        }

                        // ── Step 2c: Resolve profile Ids — only UserType = Standard ──
                        // Excludes: Guest, Chatter Free, Partner Portal (system profiles)
                        Set<Id> userProfileIds = new Set<Id>();
                        if (!profileNames.isEmpty()) {
                            for (Profile p : [
                                SELECT Id, Name FROM Profile
                                WHERE Name IN :profileNames
                                AND UserType = 'Standard'
                            ]) {
                                userProfileIds.add(p.Id);
                                stripResult.profilesStripped.add(p.Name);
                            }
                        }

                        // ── Step 2d: Resolve permset Ids — only user-created custom ones ──
                        // Excludes: profile-backed permsets, Salesforce standard permsets
                        Set<Id> userPermSetIds = new Set<Id>();
                        if (!permSetNames.isEmpty()) {
                            for (PermissionSet ps : [
                                SELECT Id, Name FROM PermissionSet
                                WHERE Name IN :permSetNames
                                AND IsOwnedByProfile = false
                                AND IsCustom = true
                            ]) {
                                userPermSetIds.add(ps.Id);
                                stripResult.permSetsStripped.add(ps.Name);
                            }
                        }

                        // ── Step 2e: Fetch only the rows to delete using Id IN bind ──
                        // ParentId CAN be used in WHERE clause (just not in SELECT)
                        Set<Id> allParentIds = new Set<Id>();
                        allParentIds.addAll(userProfileIds);
                        allParentIds.addAll(userPermSetIds);

                        // ── Step 2e: Delete matching SetupEntityAccess rows ──
                        // ParentId IS allowed in WHERE bind (just not in SELECT)
                        if (!allParentIds.isEmpty()) {
                            List<SetupEntityAccess> rowsToDelete = [
                                SELECT Id
                                FROM SetupEntityAccess
                                WHERE SetupEntityId = :classId
                                AND ParentId IN :allParentIds
                                LIMIT 200
                            ];
                            if (!rowsToDelete.isEmpty()) {
                                stripResult.stripAttempted = true;
                                Database.DeleteResult[] stripDml = Database.delete(rowsToDelete, false);
                                for (Integer i = 0; i < stripDml.size(); i++) {
                                    if (!stripDml[i].isSuccess()) {
                                        for (Database.Error e : stripDml[i].getErrors()) {
                                            stripResult.stripErrors.add(e.getMessage());
                                        }
                                    }
                                }
                            }
                        }
                    } // end if (!allAccess.isEmpty())
                } catch (Exception ex) {
                    stripResult.stripErrors.add('Strip query/delete failed: ' + ex.getMessage());
                }
            }

            // ── Step 3: Attempt the actual class deletion ──────────────────────
            DeleteResult r = deleteApexClassByName(normalizedName);

            // ── Step 4: Build enriched result message ──────────────────────────
            if (r.success) {
                mass.successCount++;

                // Build success note if we stripped anything first
                String successMsg = normalizedName;
                if (stripResult.stripAttempted) {
                    List<String> stripped = new List<String>();
                    stripped.addAll(stripResult.profilesStripped);
                    stripped.addAll(stripResult.permSetsStripped);
                    if (!stripped.isEmpty()) {
                        successMsg += ' (auto-removed access from: ' + String.join(stripped, ', ') + ')';
                    }
                }
                mass.succeeded.add(successMsg);

            } else {
                mass.failureCount++;

                // Enrich failure message with strip context
                String failMsg = normalizedName + ' (' + r.message;

                if (stripResult.stripAttempted && !stripResult.stripErrors.isEmpty()) {
                    // Strip was attempted but had errors — likely the remaining block
                    failMsg += '\n⚠️  Auto-strip of Profile/PermSet access encountered errors:\n';
                    for (String se : stripResult.stripErrors) {
                        failMsg += '    • ' + se + '\n';
                    }
                    failMsg += '  Fix: manually remove Apex Class access from the blocking Profile/PermSet, then retry.';
                } else if (!stripResult.stripAttempted && classId != null) {
                    // Class exists but delete still failed — references other than Profile/PermSet
                    failMsg += '\n  No Profile/PermSet access found — check other references listed above.';
                }

                failMsg += ')';
                mass.failed.add(failMsg);
            }
        }

        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' +
                       mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET TRIGGERS + DETECT UNUSED
    // ===============================
    public static TriggerSummary getTriggers(String namespaceFilter) {

        Http http = new Http();

        String      classSoql = 'SELECT Name FROM ApexClass WHERE NamespacePrefix = null';
        HttpRequest classReq  = new HttpRequest();
        classReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(classSoql, 'UTF-8'));
        classReq.setMethod('GET');
        classReq.setHeader('Content-Type', 'application/json');

        HttpResponse classRes           = http.send(classReq);
        Set<String>  existingClassNames = new Set<String>();

        if (classRes.getStatusCode() >= 200 && classRes.getStatusCode() < 300) {
            Map<String, Object> classResponse =
                (Map<String, Object>) JSON.deserializeUntyped(classRes.getBody());
            List<Object> classRecords = (List<Object>) classResponse.get('records');
            if (classRecords != null) {
                for (Object obj : classRecords) {
                    Map<String, Object> rec   = (Map<String, Object>) obj;
                    String              cName = (String) rec.get('Name');
                    if (String.isNotBlank(cName)) {
                        existingClassNames.add(cName.toLowerCase());
                    }
                }
            }
        }

        String      soql    = 'SELECT Id, Name, TableEnumOrId, Status, Body, LengthWithoutComments, LastModifiedDate, NamespacePrefix ' +
                              'FROM ApexTrigger WHERE NamespacePrefix = null ORDER BY Name ASC';
        HttpRequest trigReq = new HttpRequest();
        trigReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        trigReq.setMethod('GET');
        trigReq.setHeader('Content-Type', 'application/json');

        HttpResponse trigRes = http.send(trigReq);

        Set<String> trigDepNames = new Set<String>();
        try {
            String tDepSoql = 'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                              'WHERE MetadataComponentType = \'ApexTrigger\'';
            HttpRequest tDepReq = new HttpRequest();
            tDepReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(tDepSoql, 'UTF-8'));
            tDepReq.setMethod('GET');
            tDepReq.setHeader('Content-Type', 'application/json');
            tDepReq.setTimeout(TIMEOUT_LONG);
            HttpResponse tDepRes = http.send(tDepReq);
            if (tDepRes.getStatusCode() >= 200 && tDepRes.getStatusCode() < 300) {
                Map<String, Object> tDepBody    = (Map<String, Object>) JSON.deserializeUntyped(tDepRes.getBody());
                List<Object>        tDepRecords = (List<Object>) tDepBody.get('records');
                if (tDepRecords != null) {
                    for (Object r : tDepRecords) {
                        Map<String, Object> row  = (Map<String, Object>) r;
                        String              tName = (String) row.get('MetadataComponentName');
                        if (String.isNotBlank(tName)) trigDepNames.add(tName.toLowerCase());
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'dep check failed — continue: ' + ex.getMessage()); }

        List<TriggerInfo> activeTriggers   = new List<TriggerInfo>();
        List<TriggerInfo> inactiveTriggers = new List<TriggerInfo>();
        List<TriggerInfo> unusedTriggers   = new List<TriggerInfo>();
        List<String>      usedTriggerNames = new List<String>();
        List<TriggerInfo> filteredTriggers = new List<TriggerInfo>();
        Integer           totalCount       = 0;

        if (trigRes.getStatusCode() >= 200 && trigRes.getStatusCode() < 300) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(trigRes.getBody());
            List<Object> records = (List<Object>) response.get('records');
            totalCount = records != null ? records.size() : 0;

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    TriggerInfo info      = new TriggerInfo();
                    info.id               = (String) rec.get('Id');
                    info.name             = (String) rec.get('Name');
                    info.objectName       = (String) rec.get('TableEnumOrId');
                    info.isActive         = 'Active'.equalsIgnoreCase((String) rec.get('Status'));
                    info.linesOfCode      = rec.get('LengthWithoutComments') != null
                                              ? Integer.valueOf(String.valueOf(rec.get('LengthWithoutComments')))
                                              : 0;
                    info.lastModifiedDate = (String) rec.get('LastModifiedDate');
                    info.namespacePrefix  = (String) rec.get('NamespacePrefix');

                    String  body            = (String) rec.get('Body');
                    Boolean referencesClass = false;
                    Boolean hasRealLogic    = false;
                    String  referencedClass = '';

                    if (String.isNotBlank(body)) {
                        String strippedBody = body
                            .replaceAll('(?i)trigger\\s+\\w+\\s+on\\s+\\w+\\s*\\([^)]*\\)', '')
                            .replaceAll('[{}]', '')
                            .replaceAll('//[^\n]*', '')
                            .replaceAll('/\\*[\\s\\S]*?\\*/', '')
                            .trim();

                        hasRealLogic = String.isNotBlank(strippedBody) && strippedBody.length() > 3;

                        if (hasRealLogic && !existingClassNames.isEmpty()) {
                            String       cleanBody = body.replaceAll('[^a-zA-Z0-9_]', ' ');
                            List<String> tokens    = cleanBody.split('\\s+');

                            for (String token : tokens) {
                                if (String.isNotBlank(token) && token.length() > 2 &&
                                    existingClassNames.contains(token.toLowerCase())) {
                                    referencesClass = true;
                                    referencedClass = token;
                                    break;
                                }
                            }
                        }
                    }

                    Boolean isManaged   = String.isNotBlank(info.namespacePrefix);
                    Boolean isInDep     = trigDepNames.contains((info.name != null ? info.name : '').toLowerCase());

                    info.isManagedPackage = isManaged;
                    info.hasHandlerClass  = referencesClass;
                    info.handlerClassName = referencedClass;
                    info.isInDependency   = isInDep;

                    if (isManaged) {
                        info.safetyStatus = 'MANAGED';
                    } else if (!info.isActive) {
                        info.safetyStatus = 'INACTIVE';
                    } else if (!hasRealLogic) {
                        info.safetyStatus = 'EMPTY';
                    } else if (referencesClass || isInDep) {
                        info.safetyStatus = 'IN_USE';
                    } else {
                        info.safetyStatus = 'SAFE_TO_REVIEW';
                    }

                    if (!info.isActive) {
                        inactiveTriggers.add(info);
                        unusedTriggers.add(info);
                    } else if (!hasRealLogic) {
                        activeTriggers.add(info);
                        unusedTriggers.add(info);
                    } else if (referencesClass) {
                        activeTriggers.add(info);
                        usedTriggerNames.add(info.name);
                    } else {
                        activeTriggers.add(info);
                        unusedTriggers.add(info);
                    }
                }
            }
        }

        List<TriggerInfo> allTriggers = new List<TriggerInfo>();
        allTriggers.addAll(activeTriggers);
        for (TriggerInfo t : inactiveTriggers) {
            if (!t.isActive) {
                allTriggers.add(t);
            }
        }
        for (TriggerInfo t : allTriggers) {
            String  tNs    = t.namespacePrefix == null ? '' : t.namespacePrefix;
            String  tName  = t.name == null ? '' : t.name.toLowerCase();
            String  nsL    = namespaceFilter == null ? '' : namespaceFilter.toLowerCase();
            Boolean matchesFilter = String.isBlank(namespaceFilter) || nsL.equals(tNs.toLowerCase()) ||
                tName.startsWith(nsL + '_') || (tName.startsWith(nsL) && tName.length() > nsL.length() &&
                tName.substring(nsL.length(), nsL.length()+1) != tName.substring(nsL.length(), nsL.length()+1).toLowerCase());
            if (matchesFilter) {
                filteredTriggers.add(t);
            }
        }

        TriggerSummary summary   = new TriggerSummary();
        summary.total            = totalCount;
        summary.active           = activeTriggers.size();
        summary.inactive         = inactiveTriggers.size();
        summary.used             = usedTriggerNames.size();
        summary.unused           = unusedTriggers.size();
        summary.activeTriggers   = activeTriggers;
        summary.inactiveTriggers = inactiveTriggers;
        summary.unusedTriggers   = unusedTriggers;
        summary.usedTriggerNames = usedTriggerNames;
        summary.filteredTriggers = filteredTriggers;
        summary.filteredTotal    = filteredTriggers.size();
        summary.namespaceFilter  = namespaceFilter;

        return summary;
    }

    // ── checkAllTriggerReferences ─────────────────────────────────────────────
    //
    // Dedicated, exhaustive reference scan for an ApexTrigger before any
    // delete attempt — mirroring the design of checkAllFlowReferences.
    //
    // WHY a separate method instead of relying on getReferencesFor():
    //   getReferencesFor() runs a single MetadataComponentDependency (MCD)
    //   lookup.  That misses:
    //     • References built via dynamic SOQL / string concatenation
    //       (the trigger name only appears inside a quoted string in the
    //        caller's Apex body — MCD does not index string literals).
    //     • References via TriggerHandler-style frameworks where the trigger
    //       hands off to a class via reflection or naming convention.
    //     • Test classes that test the trigger but whose dependency edge
    //       is not always indexed.
    //     • Managed-package state (must block delete with a clear message,
    //       not let Salesforce return an opaque error).
    //
    // This method queries ALL of those sources and deduplicates across them:
    //   1.  MCD by 18-char Id  (ApexTrigger.Id)
    //   2.  MCD by Name        (RefMetadataComponentName)
    //   3.  ApexClass body scan      — Body LIKE '%TriggerName%' across all classes
    //   4.  ApexTrigger body scan    — other triggers mentioning this trigger
    //   5.  Test-class body scan     — IsTest=true classes mentioning the trigger
    //                                  (surfaced under its own group so the user
    //                                   sees what tests will be left orphaned)
    //   6.  Managed-package guard    — ManageableState == 'installed' blocks delete
    //   7.  CustomObject pending delete — if the trigger's object is queued for
    //                                     delete, surface that (informational)
    //
    // Parameters (all resolved by the caller from ApexTrigger lookup):
    //   triggerId   — 18-char Id   (ApexTrigger.Id)
    //   triggerName — DeveloperName (ApexTrigger.Name)
    //   objectName  — TableEnumOrId of the object this trigger fires on
    //
    // Returns a de-duplicated List<ReferenceItem> (empty = safe to delete).
    // ─────────────────────────────────────────────────────────────────────────
    @TestVisible
    private static List<ReferenceItem> checkAllTriggerReferences(
            String triggerId, String triggerName, String objectName) {

        Http                http        = new Http();
        List<ReferenceItem> refs        = new List<ReferenceItem>();
        Set<String>         seenKeys    = new Set<String>();

        // ── 1 & 2: MCD by Id and by Name ──────────────────────────────────────
        // Cover the standard "compile-time visible" references first.
        try {
            for (String soqlBody : new List<String>{
                    // by Id (most reliable)
                    'SELECT MetadataComponentName, MetadataComponentType ' +
                    'FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentId = \'' + String.escapeSingleQuotes(triggerId) + '\' LIMIT 200',
                    // by Name (some orgs index this when Id is unavailable)
                    'SELECT MetadataComponentName, MetadataComponentType ' +
                    'FROM MetadataComponentDependency ' +
                    'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(triggerName) + '\' ' +
                    'AND RefMetadataComponentType = \'ApexTrigger\' LIMIT 200'
            }) {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soqlBody, 'UTF-8'));
                req.setMethod('GET');
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(TIMEOUT_LONG);
                HttpResponse res = http.send(req);
                if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) continue;
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> recs = (List<Object>) body.get('records');
                if (recs == null) continue;
                for (Object r : recs) {
                    Map<String, Object> row = (Map<String, Object>) r;
                    String cName = (String) row.get('MetadataComponentName');
                    String cType = (String) row.get('MetadataComponentType');
                    if (String.isBlank(cName) || String.isBlank(cType)) continue;
                    String dk = ('mcd|' + cType + '|' + cName).toLowerCase();
                    if (seenKeys.contains(dk)) continue;
                    seenKeys.add(dk);
                    refs.add(buildReferenceItem(cName, cType));
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences MCD scan skipped: ' + ex.getMessage());
        }

        // ── 3 + 5: ApexClass body scan (production + test classes) ────────────
        //
        // HISTORY of this scan:
        // v1: WHERE Body LIKE '%TriggerName%'  — broken.  Tooling SOQL does not
        //     reliably support LIKE filters on long-text Body fields.  Result:
        //     empty results, the trigger deleted despite references existing.
        // v2: List Ids, then GET /sobjects/ApexClass/{id} per row — correct,
        //     but exploded callout count and hit "Too many callouts: 101"
        //     on mass deletes.
        // v3 (THIS CODE): Single bulk Tooling SOQL pulling Id, Name, AND Body
        //     in one callout.  Body IS queryable on ApexClass via Tooling
        //     SOQL — the limitation is only on LIKE/contains FILTERS on
        //     Body, not on SELECTing it.  We then filter in Apex.
        //
        // This is one HTTP callout regardless of class count, so it works
        // safely inside mass delete loops.
        try {
            String classSoql = 'SELECT Id, Name, Body FROM ApexClass ' +
                               'WHERE NamespacePrefix = null LIMIT 1000';
            HttpRequest classReq = new HttpRequest();
            classReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(classSoql, 'UTF-8'));
            classReq.setMethod('GET');
            classReq.setHeader('Content-Type', 'application/json');
            classReq.setTimeout(TIMEOUT_LONG);
            HttpResponse classRes = http.send(classReq);
            if (classRes.getStatusCode() >= 200 && classRes.getStatusCode() < 300) {
                Map<String, Object> classBody = (Map<String, Object>) JSON.deserializeUntyped(classRes.getBody());
                List<Object> classRecs = (List<Object>) classBody.get('records');
                String tnLower = triggerName.toLowerCase();

                if (classRecs != null) {
                    for (Object r : classRecs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String cName = (String) row.get('Name');
                        String cBody = (String) row.get('Body');
                        if (String.isBlank(cName) || String.isBlank(cBody)) continue;
                        if (triggerName.equalsIgnoreCase(cName)) continue; // skip self

                        String bLower = cBody.toLowerCase();
                        if (!bLower.contains(tnLower)) continue;

                        // Word-boundary check to avoid "MyTrigger" matching
                        // inside "MyTriggerHandler" / "MyTriggerName" etc.
                        Boolean wordMatch = false;
                        Integer idx = bLower.indexOf(tnLower);
                        while (idx >= 0) {
                            Boolean leftOk  = (idx == 0)
                                            || !isIdentChar(bLower.substring(idx - 1, idx));
                            Integer endIdx = idx + tnLower.length();
                            Boolean rightOk = (endIdx >= bLower.length())
                                            || !isIdentChar(bLower.substring(endIdx, endIdx + 1));
                            if (leftOk && rightOk) { wordMatch = true; break; }
                            idx = bLower.indexOf(tnLower, idx + 1);
                        }
                        if (!wordMatch) continue;

                        // Test-class detection from body annotations
                        Boolean isTestClass = bLower.contains('@istest') ||
                                              bLower.contains('@ istest') ||
                                              bLower.contains('testmethod');

                        String dk = ('apexclass|' + cName).toLowerCase();
                        if (seenKeys.contains(dk)) continue;
                        seenKeys.add(dk);

                        ReferenceItem item = new ReferenceItem();
                        item.name         = cName;
                        item.type         = 'ApexClass';
                        if (isTestClass) {
                            item.groupLabel   = 'Test Classes (referencing trigger)';
                            item.relationship = 'Test class references this trigger by name. Deleting ' +
                                                'the trigger will leave the test broken or invalid.';
                        } else {
                            item.groupLabel   = 'Apex Classes';
                            item.relationship = 'Apex class references this trigger in its body — ' +
                                                'remove or update the reference first.';
                        }
                        refs.add(item);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences ApexClass scan skipped: ' + ex.getMessage());
        }

        // ── 4: ApexTrigger body scan (other triggers mentioning this one) ─────
        // Same bulk-SELECT pattern as #3.  Body IS queryable on ApexTrigger
        // via Tooling SOQL.
        try {
            String trgSoql = 'SELECT Id, Name, Body FROM ApexTrigger ' +
                             'WHERE NamespacePrefix = null LIMIT 500';
            HttpRequest trgReq = new HttpRequest();
            trgReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(trgSoql, 'UTF-8'));
            trgReq.setMethod('GET');
            trgReq.setHeader('Content-Type', 'application/json');
            trgReq.setTimeout(TIMEOUT_LONG);
            HttpResponse trgRes = http.send(trgReq);
            if (trgRes.getStatusCode() >= 200 && trgRes.getStatusCode() < 300) {
                Map<String, Object> trgBody = (Map<String, Object>) JSON.deserializeUntyped(trgRes.getBody());
                List<Object> trgRecs = (List<Object>) trgBody.get('records');
                String tnLower = triggerName.toLowerCase();
                if (trgRecs != null) {
                    for (Object r : trgRecs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String otherName = (String) row.get('Name');
                        String otherBody = (String) row.get('Body');
                        if (String.isBlank(otherName) || String.isBlank(otherBody)) continue;
                        if (triggerName.equalsIgnoreCase(otherName)) continue;  // skip self

                        String bLower = otherBody.toLowerCase();
                        if (!bLower.contains(tnLower)) continue;

                        Boolean wordMatch = false;
                        Integer idx = bLower.indexOf(tnLower);
                        while (idx >= 0) {
                            Boolean leftOk  = (idx == 0) || !isIdentChar(bLower.substring(idx - 1, idx));
                            Integer endIdx = idx + tnLower.length();
                            Boolean rightOk = (endIdx >= bLower.length()) || !isIdentChar(bLower.substring(endIdx, endIdx + 1));
                            if (leftOk && rightOk) { wordMatch = true; break; }
                            idx = bLower.indexOf(tnLower, idx + 1);
                        }
                        if (!wordMatch) continue;

                        String dk = ('apextrigger|' + otherName).toLowerCase();
                        if (seenKeys.contains(dk)) continue;
                        seenKeys.add(dk);
                        ReferenceItem item = new ReferenceItem();
                        item.name         = otherName;
                        item.type         = 'ApexTrigger';
                        item.groupLabel   = 'Apex Triggers (referencing this trigger)';
                        item.relationship = 'Another trigger references this one by name.';
                        refs.add(item);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences ApexTrigger scan skipped: ' + ex.getMessage());
        }

        // ── 5b: Active-Flow metadata scan ────────────────────────────────────
        // Flows can reference triggers by name inside ApexAction / InvocableAction
        // nodes (e.g. calling an @InvocableMethod handler that is tied to this
        // trigger, or referencing the trigger name in a custom Apex action).
        // MetadataComponentDependency rarely indexes these, so we scan the
        // serialised Metadata JSON of every active Flow — same technique used
        // by checkAllFlowReferences for subflow detection.
        try {
            String activeFlowSoql =
                'SELECT Id, ApiName, Label FROM FlowDefinitionView WHERE IsActive = true LIMIT 200';
            HttpRequest afReq = new HttpRequest();
            afReq.setEndpoint(BASE_URL + 'query?q=' + EncodingUtil.urlEncode(activeFlowSoql, 'UTF-8'));
            afReq.setMethod('GET');
            afReq.setHeader('Content-Type', 'application/json');
            afReq.setTimeout(TIMEOUT_LONG);
            HttpResponse afRes = http.send(afReq);
            if (afRes.getStatusCode() >= 200 && afRes.getStatusCode() < 300) {
                Map<String, Object> afBody = (Map<String, Object>) JSON.deserializeUntyped(afRes.getBody());
                List<Object> afRecs = (List<Object>) afBody.get('records');
                if (afRecs != null && !afRecs.isEmpty()) {
                    List<String> flowIds = new List<String>();
                    Map<String, String> flowIdToApi   = new Map<String, String>();
                    Map<String, String> flowIdToLabel = new Map<String, String>();
                    for (Object r : afRecs) {
                        Map<String, Object> row = (Map<String, Object>) r;
                        String fId  = (String) row.get('Id');
                        String fApi = (String) row.get('ApiName');
                        String fLbl = (String) row.get('Label');
                        if (String.isBlank(fId)) continue;
                        flowIds.add(fId);
                        flowIdToApi.put(fId, fApi);
                        flowIdToLabel.put(fId, fLbl);
                    }
                    if (!flowIds.isEmpty()) {
                        List<String> quotedIds = new List<String>();
                        for (String fId : flowIds) { quotedIds.add('\'' + fId + '\''); }
                        String metaSoql =
                            'SELECT DurableId, Metadata FROM FlowDefinition WHERE DurableId IN (' +
                            String.join(quotedIds, ',') + ') LIMIT 200';
                        HttpRequest fmReq = new HttpRequest();
                        fmReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(metaSoql, 'UTF-8'));
                        fmReq.setMethod('GET');
                        fmReq.setHeader('Content-Type', 'application/json');
                        fmReq.setTimeout(TIMEOUT_LONG);
                        HttpResponse fmRes = http.send(fmReq);
                        if (fmRes.getStatusCode() >= 200 && fmRes.getStatusCode() < 300) {
                            Map<String, Object> fmBody = (Map<String, Object>) JSON.deserializeUntyped(fmRes.getBody());
                            List<Object> fmRecs = (List<Object>) fmBody.get('records');
                            if (fmRecs != null) {
                                String tnLower = triggerName.toLowerCase();
                                for (Object mr : fmRecs) {
                                    Map<String, Object> mRow = (Map<String, Object>) mr;
                                    String mId  = (String) mRow.get('DurableId');
                                    Object meta = mRow.get('Metadata');
                                    if (meta == null) continue;
                                    String metaStr = JSON.serialize(meta).toLowerCase();
                                    if (!metaStr.contains(tnLower)) continue;
                                    String callerApi = flowIdToApi.get(mId);
                                    String callerLbl = flowIdToLabel.get(mId);
                                    if (String.isBlank(callerApi)) callerApi = mId;
                                    String dk = ('flow|trigger|' + callerApi).toLowerCase();
                                    if (seenKeys.contains(dk)) continue;
                                    seenKeys.add(dk);
                                    ReferenceItem item = new ReferenceItem();
                                    item.name         = (String.isNotBlank(callerLbl) ? callerLbl : callerApi) +
                                                        ' (' + callerApi + ')';
                                    item.type         = 'Flow';
                                    item.groupLabel   = 'Flows (referencing this trigger)';
                                    item.relationship = 'Active Flow references this trigger — ' +
                                                        'remove the trigger reference from the Flow first.';
                                    refs.add(item);
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences Flow scan skipped: ' + ex.getMessage());
        }

        // ── 6: Managed-package guard ──────────────────────────────────────────
        // Surface managed-package state as a "reference" so the user gets a
        // clear blocking reason instead of a Salesforce raw error.
        try {
            String mpSoql = 'SELECT ManageableState, NamespacePrefix FROM ApexTrigger ' +
                            'WHERE Id = \'' + String.escapeSingleQuotes(triggerId) + '\' LIMIT 1';
            HttpRequest mpReq = new HttpRequest();
            mpReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(mpSoql, 'UTF-8'));
            mpReq.setMethod('GET');
            mpReq.setHeader('Content-Type', 'application/json');
            mpReq.setTimeout(TIMEOUT_LONG);
            HttpResponse mpRes = http.send(mpReq);
            if (mpRes.getStatusCode() >= 200 && mpRes.getStatusCode() < 300) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(mpRes.getBody());
                List<Object> recs = (List<Object>) body.get('records');
                if (recs != null && !recs.isEmpty()) {
                    Map<String, Object> row = (Map<String, Object>) recs[0];
                    String state = (String) row.get('ManageableState');
                    String ns    = (String) row.get('NamespacePrefix');
                    if ('installed'.equalsIgnoreCase(state)) {
                        ReferenceItem item = new ReferenceItem();
                        item.name         = (String.isNotBlank(ns) ? ns + '__' : '') + triggerName;
                        item.type         = 'ManagedPackage';
                        item.groupLabel   = 'Managed Package (cannot delete)';
                        item.relationship = 'This trigger belongs to an installed managed package' +
                                            (String.isNotBlank(ns) ? ' (namespace: ' + ns + ')' : '') +
                                            ' and CANNOT be deleted from this org. ' +
                                            'Uninstall the package or contact the package owner.';
                        refs.add(item);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences ManagedPackage check skipped: ' + ex.getMessage());
        }

        // ── 8: Approval Processes ─────────────────────────────────────────────
        // MCD tracks ApprovalProcess → ApexTrigger dependencies via
        // RefMetadataComponentName. Covers entry criteria and apex actions
        // that fire on records also handled by this trigger.
        try {
            String apSoql = 'SELECT MetadataComponentName FROM MetadataComponentDependency ' +
                            'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(triggerName) + '\' ' +
                            'AND RefMetadataComponentType = \'ApexTrigger\' ' +
                            'AND MetadataComponentType = \'ApprovalProcess\' LIMIT 50';
            HttpRequest apReq = new HttpRequest();
            apReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(apSoql, 'UTF-8'));
            apReq.setMethod('GET');
            apReq.setHeader('Content-Type', 'application/json');
            apReq.setTimeout(TIMEOUT_LONG);
            HttpResponse apRes = http.send(apReq);
            if (apRes.getStatusCode() >= 200 && apRes.getStatusCode() < 300) {
                Map<String, Object> apBody    = (Map<String, Object>) JSON.deserializeUntyped(apRes.getBody());
                List<Object>        apRecords = (List<Object>) apBody.get('records');
                if (apRecords != null) {
                    for (Object r : apRecords) {
                        String apName = (String) ((Map<String, Object>) r).get('MetadataComponentName');
                        if (String.isBlank(apName)) continue;
                        String dk = ('approvalprocess|' + apName).toLowerCase();
                        if (seenKeys.contains(dk)) continue;
                        seenKeys.add(dk);
                        ReferenceItem item = new ReferenceItem();
                        item.name         = apName;
                        item.type         = 'ApprovalProcess';
                        item.groupLabel   = 'Approval Processes';
                        item.relationship = 'Approval process references this trigger — remove the reference first.';
                        refs.add(item);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences Approval Process check skipped: ' + ex.getMessage());
        }

        // ── 9: Platform Event Subscriber Config ───────────────────────────────
        // If this trigger is registered as a Platform Event subscriber
        // (ApexClassName field on PlatformEventSubscriberConfig = triggerName),
        // deleting it will break the event subscription.
        try {
            String peSoql = 'SELECT Id, DeveloperName FROM PlatformEventSubscriberConfig ' +
                            'WHERE ApexClassName = \'' + String.escapeSingleQuotes(triggerName) + '\' LIMIT 20';
            HttpRequest peReq = new HttpRequest();
            peReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(peSoql, 'UTF-8'));
            peReq.setMethod('GET');
            peReq.setHeader('Content-Type', 'application/json');
            peReq.setTimeout(TIMEOUT_LONG);
            HttpResponse peRes = http.send(peReq);
            if (peRes.getStatusCode() >= 200 && peRes.getStatusCode() < 300) {
                Map<String, Object> peBody    = (Map<String, Object>) JSON.deserializeUntyped(peRes.getBody());
                List<Object>        peRecords = (List<Object>) peBody.get('records');
                if (peRecords != null) {
                    for (Object r : peRecords) {
                        String devName = (String) ((Map<String, Object>) r).get('DeveloperName');
                        if (String.isBlank(devName)) continue;
                        String dk = ('platformeventsub|' + devName).toLowerCase();
                        if (seenKeys.contains(dk)) continue;
                        seenKeys.add(dk);
                        ReferenceItem item = new ReferenceItem();
                        item.name         = devName;
                        item.type         = 'PlatformEventSubscriberConfig';
                        item.groupLabel   = 'Platform Events';
                        item.relationship = 'This trigger is registered as a Platform Event subscriber — ' +
                                            'deleting it will break the event subscription.';
                        refs.add(item);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences Platform Event subscriber check skipped: ' + ex.getMessage());
        }

        // ── 10: Test Suite Membership ──────────────────────────────────────────
        // If test classes that reference this trigger are members of a Test Suite,
        // surface those suites — deleting the trigger will break coverage runs.
        // We find test class IDs from the ApexClass body scan (refs already populated)
        // and look up their TestSuiteMembership.
        try {
            // Collect IDs of test classes already found in refs
            List<String> testClassNames = new List<String>();
            for (ReferenceItem ri : refs) {
                if ('Test Classes (referencing trigger)'.equals(ri.groupLabel) ||
                    ('ApexClass'.equals(ri.type) && ri.groupLabel != null &&
                     ri.groupLabel.toLowerCase().contains('test'))) {
                    testClassNames.add(ri.name);
                }
            }
            if (!testClassNames.isEmpty()) {
                // Look up their Ids first
                List<String> quotedNames = new List<String>();
                for (String n : testClassNames) { quotedNames.add('\'' + String.escapeSingleQuotes(n) + '\''); }
                String tcIdSoql = 'SELECT Id, Name FROM ApexClass WHERE Name IN (' +
                                  String.join(quotedNames, ',') + ') LIMIT 50';
                HttpRequest tcIdReq = new HttpRequest();
                tcIdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(tcIdSoql, 'UTF-8'));
                tcIdReq.setMethod('GET');
                tcIdReq.setHeader('Content-Type', 'application/json');
                tcIdReq.setTimeout(TIMEOUT_LONG);
                HttpResponse tcIdRes = http.send(tcIdReq);
                if (tcIdRes.getStatusCode() >= 200 && tcIdRes.getStatusCode() < 300) {
                    Map<String, Object> tcIdBody = (Map<String, Object>) JSON.deserializeUntyped(tcIdRes.getBody());
                    List<Object> tcIdRecs = (List<Object>) tcIdBody.get('records');
                    if (tcIdRecs != null && !tcIdRecs.isEmpty()) {
                        List<String> quotedIds = new List<String>();
                        for (Object r : tcIdRecs) {
                            String tcId = (String) ((Map<String, Object>) r).get('Id');
                            if (String.isNotBlank(tcId)) quotedIds.add('\'' + tcId + '\'');
                        }
                        if (!quotedIds.isEmpty()) {
                            String suiteSoql = 'SELECT ApexTestSuite.TestSuiteName FROM TestSuiteMembership ' +
                                               'WHERE ApexClassId IN (' + String.join(quotedIds, ',') + ') LIMIT 50';
                            HttpRequest suiteReq = new HttpRequest();
                            suiteReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(suiteSoql, 'UTF-8'));
                            suiteReq.setMethod('GET');
                            suiteReq.setHeader('Content-Type', 'application/json');
                            suiteReq.setTimeout(TIMEOUT_LONG);
                            HttpResponse suiteRes = http.send(suiteReq);
                            if (suiteRes.getStatusCode() >= 200 && suiteRes.getStatusCode() < 300) {
                                Map<String, Object> suiteBody    = (Map<String, Object>) JSON.deserializeUntyped(suiteRes.getBody());
                                List<Object>        suiteRecords = (List<Object>) suiteBody.get('records');
                                if (suiteRecords != null) {
                                    for (Object sr : suiteRecords) {
                                        Map<String, Object> srMap = (Map<String, Object>) sr;
                                        Map<String, Object> suite = (Map<String, Object>) srMap.get('ApexTestSuite');
                                        if (suite == null) continue;
                                        String suiteName = (String) suite.get('TestSuiteName');
                                        if (String.isBlank(suiteName)) continue;
                                        String dk = ('testsuite|' + suiteName).toLowerCase();
                                        if (seenKeys.contains(dk)) continue;
                                        seenKeys.add(dk);
                                        ReferenceItem item = new ReferenceItem();
                                        item.name         = suiteName;
                                        item.type         = 'ApexTestSuite';
                                        item.groupLabel   = 'Test Suites';
                                        item.relationship = 'A test class referencing this trigger is a member of this suite — ' +
                                                            'deleting the trigger will break suite coverage runs.';
                                        refs.add(item);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences Test Suite check skipped: ' + ex.getMessage());
        }

        // ── 7: CustomObject pending delete ────────────────────────────────────
        // Informational: if the trigger fires on an object that is in the
        // delete queue, surface that — deleting the trigger first is fine
        // but the user may not realise the object is going away anyway.
        // We only emit if the object name looks like a custom object (ends __c).
        try {
            if (String.isNotBlank(objectName) && objectName.endsWithIgnoreCase('__c')) {
                String objSoql = 'SELECT Id, DeveloperName, ManageableState FROM CustomObject ' +
                                 'WHERE DeveloperName = \'' +
                                 String.escapeSingleQuotes(objectName.removeEnd('__c')) +
                                 '\' LIMIT 1';
                HttpRequest objReq = new HttpRequest();
                objReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(objSoql, 'UTF-8'));
                objReq.setMethod('GET');
                objReq.setHeader('Content-Type', 'application/json');
                objReq.setTimeout(TIMEOUT_LONG);
                HttpResponse objRes = http.send(objReq);
                if (objRes.getStatusCode() >= 200 && objRes.getStatusCode() < 300) {
                    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(objRes.getBody());
                    List<Object> recs = (List<Object>) body.get('records');
                    if (recs != null && !recs.isEmpty()) {
                        Map<String, Object> row = (Map<String, Object>) recs[0];
                        String mState = (String) row.get('ManageableState');
                        if ('deleted'.equalsIgnoreCase(mState)) {
                            ReferenceItem item = new ReferenceItem();
                            item.name         = objectName;
                            item.type         = 'CustomObject';
                            item.groupLabel   = 'Notes';
                            item.relationship = 'The custom object this trigger fires on is queued for ' +
                                                'deletion. Trigger delete will proceed; this is informational only.';
                            refs.add(item);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkAllTriggerReferences CustomObject pending check skipped: ' + ex.getMessage());
        }

        return refs;
    }

    // Helper: is this single char a Java/Apex identifier char (letter/digit/_)?
    private static Boolean isIdentChar(String ch) {
        if (String.isBlank(ch)) return false;
        Integer c = ch.charAt(0);
        return (c >= 48 && c <= 57)    // 0-9
            || (c >= 65 && c <= 90)    // A-Z
            || (c >= 97 && c <= 122)   // a-z
            || c == 95;                // _
    }

    // ===============================
    // DELETE TRIGGER BY NAME
    // ===============================
    public static DeleteResult deleteTriggerByName(String triggerName) {
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        // ── STEP 1: Look up the trigger ─────────────────────────────────────
        String lookupSoql = 'SELECT Id, Name, TableEnumOrId, Status, ManageableState, Body ' +
                            'FROM ApexTrigger ' +
                            'WHERE Name = \'' + String.escapeSingleQuotes(triggerName) + '\' ' +
                            'AND NamespacePrefix = null LIMIT 1';

        HttpRequest lookupReq = new HttpRequest();
        lookupReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(lookupSoql, 'UTF-8'));
        lookupReq.setMethod('GET');
        lookupReq.setHeader('Content-Type', 'application/json');

        HttpResponse lookupRes = http.send(lookupReq);

        if (lookupRes.getStatusCode() < 200 || lookupRes.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Failed to look up Trigger "' + triggerName + '". HTTP ' + lookupRes.getStatusCode();
            return result;
        }

        Map<String, Object> lookupResponse =
            (Map<String, Object>) JSON.deserializeUntyped(lookupRes.getBody());
        List<Object> lookupRecords = (List<Object>) lookupResponse.get('records');

        if (lookupRecords == null || lookupRecords.isEmpty()) {
            result.success = false;
            result.message = 'No Trigger found with name: ' + triggerName;
            return result;
        }

        Map<String, Object> trigDef    = (Map<String, Object>) lookupRecords[0];
        String              triggerId  = (String) trigDef.get('Id');
        String              objectName = (String) trigDef.get('TableEnumOrId');
        String              trigBody   = (String) trigDef.get('Body');

        // ── STEP 2: Exhaustive reference check BEFORE any delete attempt ───
        // Mirrors the flow flow: check all sources, block with a grouped
        // report if any reference is found.  Never touch the trigger until
        // refs are clean.
        List<ReferenceItem> trigRefs = checkAllTriggerReferences(triggerId, triggerName, objectName);

        // ── STEP 2b: Handler-class warning ────────────────────────────────────
        // If the trigger body calls a handler/helper Apex class, that class will
        // become orphaned when the trigger is deleted. Surface it as a blocking
        // reference so the user can decide whether to delete the handler too.
        // trigBody is already fetched from STEP 1 — no extra callout needed.
        // We only need one extra callout here: fetch all Apex class names to
        // cross-reference tokens found in the trigger body.
        if (String.isNotBlank(trigBody)) {
            try {
                String classNameSoql = 'SELECT Name FROM ApexClass WHERE NamespacePrefix = null LIMIT 1000';
                HttpRequest cnReq = new HttpRequest();
                cnReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(classNameSoql, 'UTF-8'));
                cnReq.setMethod('GET');
                cnReq.setHeader('Content-Type', 'application/json');
                cnReq.setTimeout(TIMEOUT_LONG);
                HttpResponse cnRes = http.send(cnReq);
                if (cnRes.getStatusCode() >= 200 && cnRes.getStatusCode() < 300) {
                    Map<String, Object> cnJson = (Map<String, Object>) JSON.deserializeUntyped(cnRes.getBody());
                    List<Object> cnRecs = (List<Object>) cnJson.get('records');
                    if (cnRecs != null) {
                        Set<String> classNamesLower = new Set<String>();
                        Map<String, String> lowerToOriginal = new Map<String, String>();
                        for (Object r : cnRecs) {
                            String cn = (String) ((Map<String, Object>) r).get('Name');
                            if (String.isNotBlank(cn)) {
                                classNamesLower.add(cn.toLowerCase());
                                lowerToOriginal.put(cn.toLowerCase(), cn);
                            }
                        }
                        // Token scan — same logic as getTriggers()
                        String cleanBody = trigBody.replaceAll('[^a-zA-Z0-9_]', ' ');
                        List<String> tokens = cleanBody.split('\\s+');
                        Set<String> seenHandlers = new Set<String>();
                        for (String token : tokens) {
                            if (String.isBlank(token) || token.length() <= 2) continue;
                            String tokenLower = token.toLowerCase();
                            if (!classNamesLower.contains(tokenLower)) continue;
                            if (triggerName.equalsIgnoreCase(token)) continue; // skip self
                            if (seenHandlers.contains(tokenLower)) continue;
                            seenHandlers.add(tokenLower);
                            String originalName = lowerToOriginal.get(tokenLower);
                            ReferenceItem handlerRef = new ReferenceItem();
                            handlerRef.name         = originalName;
                            handlerRef.type         = 'ApexClass';
                            handlerRef.groupLabel   = 'Apex Classes (called by this trigger)';
                            handlerRef.relationship = 'This trigger calls "' + originalName + '" as its handler. ' +
                                                      'Deleting the trigger will leave this class orphaned. ' +
                                                      'Delete the handler class separately if it is no longer needed.';
                            if (trigRefs == null) trigRefs = new List<ReferenceItem>();
                            trigRefs.add(handlerRef);
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'deleteTriggerByName handler-class check skipped: ' + ex.getMessage());
            }
        }

        if (trigRefs != null && !trigRefs.isEmpty()) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;
            blocked.message = buildFormattedReport(triggerName, trigRefs, null, 'ApexTrigger') +
                              '\n\n⚠️  Dynamic Reference Warning:\n' +
                              '  Type.forName(), JSON.deserialize(), or string-based usage\n' +
                              '  cannot be detected by any scan. Verify manually.';
            return blocked;
        }

        // ── STEP 3 (removed): legacy production safety guard ────────────────
        // Previously called checkSafetyBeforeDelete(safetyStatus) using the
        // TriggerInfo.safetyStatus flag set by getTriggers().  That flag
        // returned 'IN_USE' for any trigger that called a handler class —
        // which is a USEFUL signal for the org-cleanup dashboard ("does
        // this trigger do real work?") but NOT a delete blocker (a trigger
        // that calls a handler can still be safely deleted if nothing
        // references the trigger itself).
        //
        // It produced a contradictory UX: checkAllTriggerReferences said
        // "no refs, safe to delete" but the safety guard then blocked with
        // a generic "currently in use" message that had no actionable info.
        //
        // checkAllTriggerReferences already covers every real blocker:
        //   • MANAGED state            → check #6
        //   • Any inbound reference    → checks #1-#5
        // So this guard is fully redundant.

        // ── STEP 4: Perform the delete ─────────────────────────────────────
        HttpRequest deleteReq = new HttpRequest();
        deleteReq.setEndpoint(BASE_URL + 'tooling/sobjects/ApexTrigger/' + triggerId);
        deleteReq.setMethod('DELETE');
        deleteReq.setHeader('Content-Type', 'application/json');

        HttpResponse deleteRes = http.send(deleteReq);

        if (deleteRes.getStatusCode() == 204 || deleteRes.getStatusCode() == 200) {
            result.success = true;
            result.message = 'Trigger "' + triggerName + '" on ' + objectName +
                             ' (Id: ' + triggerId + ') successfully deleted.';
        } else {
            // ── If Salesforce STILL blocks (post-check race or undetected ref) ──
            // Parse the error body the same way the flow path does so users get
            // grouped output instead of a raw JSON dump.
            String errBody = deleteRes.getBody();
            result.success = false;
            if (errBody != null &&
                (errBody.containsIgnoreCase('DEPENDENCY_EXISTS') ||
                 errBody.containsIgnoreCase('referenced elsewhere') ||
                 errBody.containsIgnoreCase('Referenced by'))) {
                List<String> depTypes = parseDepTypesFromError(errBody);
                List<ReferenceItem> errRefs = new List<ReferenceItem>();
                for (String dt : depTypes) {
                    if (String.isBlank(dt)) continue;
                    ReferenceItem ri = new ReferenceItem();
                    ri.name         = dt.trim();
                    ri.type         = dt.trim();
                    ri.groupLabel   = 'Other References (from Salesforce error)';
                    ri.relationship = 'Salesforce blocked the delete citing this component type';
                    errRefs.add(ri);
                }
                result.message = buildFormattedReport(triggerName, errRefs, null, 'ApexTrigger');
            } else {
                result.message = 'Failed to delete Trigger "' + triggerName + '". HTTP ' +
                                  deleteRes.getStatusCode() + ': ' + deleteRes.getBody();
            }
        }

        return result;
    }

    // ── Mass delete Triggers ───────────────────────────────────
    public static MassDeleteResult massDeleteTriggers(List<String> triggerNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = triggerNames.size();
        mass.successCount = 0; mass.failureCount = 0;
        mass.succeeded = new List<String>(); mass.failed = new List<String>();
        for (String name : triggerNames) {
            if (String.isBlank(name)) continue;
            String n = name.trim().replace(' ', '_');
            DeleteResult r = deleteTriggerByName(n);
            if (r.success) { mass.successCount++; mass.succeeded.add(n); }
            else           { mass.failureCount++; mass.failed.add(name.trim() + ' (' + r.message + ')'); }
        }
        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' + mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET LWC COMPONENTS
    // ===============================
    public static LwcSummary getLwcComponents(String namespaceFilter) {

        Http   http = new Http();
        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate, ApiVersion ' +
                      'FROM LightningComponentBundle ORDER BY DeveloperName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        List<LwcComponentInfo> allComponents      = new List<LwcComponentInfo>();
        List<LwcComponentInfo> filteredComponents = new List<LwcComponentInfo>();
        Integer withNamespace    = 0;
        Integer withoutNamespace = 0;

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) response.get('records');

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    LwcComponentInfo info  = new LwcComponentInfo();
                    info.id               = (String) rec.get('Id');
                    info.name             = (String) rec.get('DeveloperName');
                    info.namespacePrefix  = (String) rec.get('NamespacePrefix');
                    info.lastModifiedDate = (String) rec.get('LastModifiedDate');
                    info.apiVersion       = rec.get('ApiVersion') != null
                                             ? String.valueOf(rec.get('ApiVersion')) : '';

                    allComponents.add(info);

                    if (String.isNotBlank(info.namespacePrefix)) {
                        withNamespace++;
                    } else {
                        withoutNamespace++;
                    }

                    String  lwcNs = info.namespacePrefix == null ? '' : info.namespacePrefix;
                    String  lwcNm = info.name == null ? '' : info.name.toLowerCase();
                    String  nsL   = namespaceFilter == null ? '' : namespaceFilter.toLowerCase();
                    Boolean matchesFilter = String.isBlank(namespaceFilter) || nsL.equals(lwcNs.toLowerCase()) ||
                        lwcNm.startsWith(nsL + '_') || (lwcNm.startsWith(nsL) && lwcNm.length() > nsL.length() &&
                        lwcNm.substring(nsL.length(), nsL.length()+1) != lwcNm.substring(nsL.length(), nsL.length()+1).toLowerCase());

                    if (matchesFilter) {
                        filteredComponents.add(info);
                    }
                }
            }
        }

        LwcSummary summary         = new LwcSummary();
        summary.total              = allComponents.size();
        summary.withNamespace      = withNamespace;
        summary.withoutNamespace   = withoutNamespace;
        summary.allComponents      = allComponents;
        summary.filteredComponents = filteredComponents;
        summary.namespaceFilter    = namespaceFilter;

        Map<String, List<String>> refMap    = new Map<String, List<String>>();
        Set<String>               tabLwcSet = new Set<String>();
        Set<String>               flowLwcSet= new Set<String>();

        // ── Check 1: LightningComponentReference ──
        try {
            String refSoql = 'SELECT LightningComponentBundle.DeveloperName, ' +
                             'PageOrComponent.DeveloperName, PageOrComponent.Type ' +
                             'FROM LightningComponentReference';
            HttpRequest refReq = new HttpRequest();
            refReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                EncodingUtil.urlEncode(refSoql, 'UTF-8'));
            refReq.setMethod('GET');
            refReq.setHeader('Content-Type', 'application/json');
            refReq.setTimeout(TIMEOUT_LONG);
            HttpResponse refRes = http.send(refReq);
            if (refRes.getStatusCode() >= 200 && refRes.getStatusCode() < 300) {
                Map<String, Object> refBody    = (Map<String, Object>) JSON.deserializeUntyped(refRes.getBody());
                List<Object>        refRecords = (List<Object>) refBody.get('records');
                if (refRecords != null) {
                    for (Object r : refRecords) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        Map<String, Object> bundle = (Map<String, Object>) row.get('LightningComponentBundle');
                        Map<String, Object> page   = (Map<String, Object>) row.get('PageOrComponent');
                        if (bundle == null) continue;
                        String bName = (String) bundle.get('DeveloperName');
                        String pName = page != null ? (String) page.get('DeveloperName') : 'Unknown';
                        String pType = page != null ? (String) page.get('Type') : '';
                        String entry = String.isNotBlank(pType) ? pName + ' (' + pType + ')' : pName;
                        if (!refMap.containsKey(bName)) refMap.put(bName, new List<String>());
                        refMap.get(bName).add(entry);
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'Check 1 failed — continue: ' + ex.getMessage()); }

        // ── Check 2: Flow Screen Components ──
        try {
            String flowSoql = 'SELECT Metadata FROM FlowDefinition WHERE ActiveVersionId != null LIMIT 200';
            HttpRequest flowReq = new HttpRequest();
            flowReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                EncodingUtil.urlEncode(flowSoql, 'UTF-8'));
            flowReq.setMethod('GET');
            flowReq.setHeader('Content-Type', 'application/json');
            flowReq.setTimeout(TIMEOUT_LONG);
            HttpResponse flowRes = http.send(flowReq);
            if (flowRes.getStatusCode() >= 200 && flowRes.getStatusCode() < 300) {
                Map<String, Object> flowBody    = (Map<String, Object>) JSON.deserializeUntyped(flowRes.getBody());
                List<Object>        flowRecords = (List<Object>) flowBody.get('records');
                if (flowRecords != null) {
                    for (Object r : flowRecords) {
                        Map<String, Object> row      = (Map<String, Object>) r;
                        Map<String, Object> metadata = (Map<String, Object>) row.get('Metadata');
                        if (metadata == null) continue;
                        String metaStr = JSON.serialize(metadata);
                        for (LwcComponentInfo info : allComponents) {
                            if (String.isNotBlank(info.name) && metaStr.containsIgnoreCase(info.name)) {
                                flowLwcSet.add(info.name);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'Check 2 failed — continue: ' + ex.getMessage()); }

        // ── Check 3: Custom Tabs ──
        try {
            String tabSoql = 'SELECT DeveloperName, LightningComponent.DeveloperName ' +
                             'FROM CustomTab WHERE LightningComponentId != null';
            HttpRequest tabReq = new HttpRequest();
            tabReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                EncodingUtil.urlEncode(tabSoql, 'UTF-8'));
            tabReq.setMethod('GET');
            tabReq.setHeader('Content-Type', 'application/json');
            tabReq.setTimeout(TIMEOUT_LONG);
            HttpResponse tabRes = http.send(tabReq);
            if (tabRes.getStatusCode() >= 200 && tabRes.getStatusCode() < 300) {
                Map<String, Object> tabBody    = (Map<String, Object>) JSON.deserializeUntyped(tabRes.getBody());
                List<Object>        tabRecords = (List<Object>) tabBody.get('records');
                if (tabRecords != null) {
                    for (Object r : tabRecords) {
                        Map<String, Object> row  = (Map<String, Object>) r;
                        Map<String, Object> comp = (Map<String, Object>) row.get('LightningComponent');
                        if (comp != null) {
                            String lwcName = (String) comp.get('DeveloperName');
                            if (String.isNotBlank(lwcName)) tabLwcSet.add(lwcName);
                        }
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'Check 3 failed — continue: ' + ex.getMessage()); }

        // ── Check 4: FlexiPage body scan ──
        try {
            String flexiSoql = 'SELECT DeveloperName, Metadata FROM FlexiPage LIMIT 300';
            HttpRequest flexiReq = new HttpRequest();
            flexiReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                EncodingUtil.urlEncode(flexiSoql, 'UTF-8'));
            flexiReq.setMethod('GET');
            flexiReq.setHeader('Content-Type', 'application/json');
            flexiReq.setTimeout(TIMEOUT_LONG);
            HttpResponse flexiRes = http.send(flexiReq);
            if (flexiRes.getStatusCode() >= 200 && flexiRes.getStatusCode() < 300) {
                Map<String, Object> flexiBody    = (Map<String, Object>) JSON.deserializeUntyped(flexiRes.getBody());
                List<Object>        flexiRecords = (List<Object>) flexiBody.get('records');
                if (flexiRecords != null) {
                    for (Object r : flexiRecords) {
                        Map<String, Object> row      = (Map<String, Object>) r;
                        Map<String, Object> metadata = (Map<String, Object>) row.get('Metadata');
                        if (metadata == null) continue;
                        String metaStr = JSON.serialize(metadata);
                        String flexiName = (String) row.get('DeveloperName');
                        for (LwcComponentInfo info : allComponents) {
                            if (String.isNotBlank(info.name) && metaStr.containsIgnoreCase(info.name)) {
                                if (!refMap.containsKey(info.name)) refMap.put(info.name, new List<String>());
                                if (!refMap.get(info.name).contains(flexiName + ' (FlexiPage-scan)')) {
                                    refMap.get(info.name).add(flexiName + ' (FlexiPage-scan)');
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'Check 4 failed — continue: ' + ex.getMessage()); }

        // ── Final: Combine all checks + assign safety status ──
        List<LwcComponentInfo> unreferencedComponents = new List<LwcComponentInfo>();
        Integer unreferencedCount = 0;

        for (LwcComponentInfo info : allComponents) {
            Boolean inRefMap  = refMap.containsKey(info.name);
            Boolean inFlowSet = flowLwcSet.contains(info.name);
            Boolean inTabSet  = tabLwcSet.contains(info.name);
            Boolean isManaged = String.isNotBlank(info.namespacePrefix);

            info.isManagedPackage = isManaged;
            info.isExposedTab     = inTabSet;

            if (isManaged) {
                info.isReferenced    = true;
                info.referencedBy    = 'Managed Package (' + info.namespacePrefix + ')';
                info.referenceSource = 'Managed Package';
                info.safetyStatus    = 'MANAGED';
            } else if (inTabSet) {
                info.isReferenced    = true;
                info.referencedBy    = 'Custom Tab (entry point)';
                info.referenceSource = 'Tab';
                info.safetyStatus    = 'ENTRY_POINT';
            } else if (inFlowSet) {
                info.isReferenced    = true;
                info.referencedBy    = 'Flow Screen Component';
                info.referenceSource = 'Flow';
                info.safetyStatus    = 'IN_USE';
            } else if (inRefMap) {
                List<String> sources = refMap.get(info.name);
                info.isReferenced    = true;
                info.referencedBy    = String.join(sources, ', ');
                info.referenceSource = sources[0];
                info.safetyStatus    = 'IN_USE';
            } else {
                Set<String> selfComponents = new Set<String>{
                    'metadatadashboard', 'metadatadasboard'
                };
                if (selfComponents.contains(info.name != null ? info.name.toLowerCase() : '')) {
                    info.isReferenced    = true;
                    info.referencedBy    = 'This Dashboard App (self-excluded from unreferenced list)';
                    info.referenceSource = 'Self';
                    info.safetyStatus    = 'ENTRY_POINT';
                } else {
                    info.isReferenced    = false;
                    info.referencedBy    = '';
                    info.referenceSource = 'None';
                    info.safetyStatus    = 'SAFE_TO_REVIEW';
                    unreferencedComponents.add(info);
                    unreferencedCount++;
                }
            }
        }   // ← FIX: closes the for loop over allComponents

        summary.unreferencedCount      = unreferencedCount;
        summary.unreferencedComponents = unreferencedComponents;
        return summary;
    }   // ← FIX: closes getLwcComponents

    // ── Mass delete LWC components ─────────────────────────────
    public static MassDeleteResult massDeleteLwcComponents(List<String> componentNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = componentNames.size();
        mass.successCount = 0; mass.failureCount = 0;
        mass.succeeded = new List<String>(); mass.failed = new List<String>();
        for (String name : componentNames) {
            if (String.isBlank(name)) continue;
            String n = name.trim().replace(' ', '_');
            DeleteResult r = deleteLwcByName(n);
            if (r.success) { mass.successCount++; mass.succeeded.add(n); }
            else           { mass.failureCount++; mass.failed.add(name.trim() + ' (' + r.message + ')'); }
        }
        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' + mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET AURA COMPONENTS
    // ===============================
    public static AuraSummary getAuraComponents(String namespaceFilter) {

        Http   http = new Http();
        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate, ApiVersion ' +
                      'FROM AuraDefinitionBundle ORDER BY DeveloperName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        List<AuraComponentInfo> allComponents      = new List<AuraComponentInfo>();
        List<AuraComponentInfo> filteredComponents = new List<AuraComponentInfo>();
        Integer withNamespace    = 0;
        Integer withoutNamespace = 0;

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) response.get('records');

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    AuraComponentInfo info = new AuraComponentInfo();
                    info.id               = (String) rec.get('Id');
                    info.name             = (String) rec.get('DeveloperName');
                    info.namespacePrefix  = (String) rec.get('NamespacePrefix');
                    info.lastModifiedDate = (String) rec.get('LastModifiedDate');
                    info.apiVersion       = rec.get('ApiVersion') != null
                                             ? String.valueOf(rec.get('ApiVersion')) : '';

                    allComponents.add(info);

                    if (String.isNotBlank(info.namespacePrefix)) {
                        withNamespace++;
                    } else {
                        withoutNamespace++;
                    }

                    String  auraNs = info.namespacePrefix == null ? '' : info.namespacePrefix;
                    String  auraNm = info.name == null ? '' : info.name.toLowerCase();
                    String  nsL    = namespaceFilter == null ? '' : namespaceFilter.toLowerCase();
                    Boolean matchesFilter = String.isBlank(namespaceFilter) || nsL.equals(auraNs.toLowerCase()) ||
                        auraNm.startsWith(nsL + '_') || (auraNm.startsWith(nsL) && auraNm.length() > nsL.length() &&
                        auraNm.substring(nsL.length(), nsL.length()+1) != auraNm.substring(nsL.length(), nsL.length()+1).toLowerCase());

                    if (matchesFilter) {
                        filteredComponents.add(info);
                    }
                }
            }
        }

        AuraSummary summary        = new AuraSummary();
        summary.total              = allComponents.size();
        summary.withNamespace      = withNamespace;
        summary.withoutNamespace   = withoutNamespace;
        summary.allComponents      = allComponents;
        summary.filteredComponents = filteredComponents;
        summary.namespaceFilter    = namespaceFilter;

        Set<String> referencedNames  = new Set<String>();
        Set<String> topLevelAppNames = new Set<String>();
        Set<String> auraTabSet       = new Set<String>();

        // ── Check 1: AuraDefinition source scan ──
        try {
            String auraSoql = 'SELECT Source, AuraDefinitionBundle.DeveloperName, DefType ' +
                              'FROM AuraDefinition ' +
                              'WHERE DefType IN (\'APPLICATION\', \'COMPONENT\') ' +
                              'LIMIT 500';
            HttpRequest auraRefReq = new HttpRequest();
            auraRefReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                EncodingUtil.urlEncode(auraSoql, 'UTF-8'));
            auraRefReq.setMethod('GET');
            auraRefReq.setHeader('Content-Type', 'application/json');
            auraRefReq.setTimeout(TIMEOUT_LONG);
            HttpResponse auraRefRes = http.send(auraRefReq);
            if (auraRefRes.getStatusCode() >= 200 && auraRefRes.getStatusCode() < 300) {
                Map<String, Object> auraBody    = (Map<String, Object>) JSON.deserializeUntyped(auraRefRes.getBody());
                List<Object>        auraRecords = (List<Object>) auraBody.get('records');
                if (auraRecords != null) {
                    for (Object r : auraRecords) {
                        Map<String, Object> row       = (Map<String, Object>) r;
                        String              source    = (String) row.get('Source');
                        String              defType   = (String) row.get('DefType');
                        Map<String, Object> bundle    = (Map<String, Object>) row.get('AuraDefinitionBundle');
                        String              ownerName = bundle != null ? (String) bundle.get('DeveloperName') : '';

                        // Check 2: Top-level App guard
                        if ('APPLICATION'.equals(defType) && String.isNotBlank(ownerName)) {
                            topLevelAppNames.add(ownerName.toLowerCase());
                        }

                        if (String.isBlank(source)) continue;

                        Integer i = 0;
                        while (i < source.length()) {
                            Integer tagStart = source.indexOf('<c:', i);
                            if (tagStart == -1) break;
                            Integer nameEnd = tagStart + 3;
                            while (nameEnd < source.length() &&
                                   source.substring(nameEnd, nameEnd+1) != ' ' &&
                                   source.substring(nameEnd, nameEnd+1) != '>' &&
                                   source.substring(nameEnd, nameEnd+1) != '/') {
                                nameEnd++;
                            }
                            String refName   = source.substring(tagStart + 3, nameEnd);
                            String camelName = '';
                            Boolean capNext  = false;
                            for (Integer ci = 0; ci < refName.length(); ci++) {
                                String ch = refName.substring(ci, ci+1);
                                if (ch == '-') { capNext = true; }
                                else { camelName += capNext ? ch.toUpperCase() : ch; capNext = false; }
                            }
                            if (String.isNotBlank(camelName) && !camelName.equalsIgnoreCase(ownerName)) {
                                referencedNames.add(camelName.toLowerCase());
                            }
                            i = nameEnd;
                        }
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'Check 1 failed — continue: ' + ex.getMessage()); }

        // ── Check 3: Custom Tabs ──
        try {
            String tabSoql = 'SELECT DeveloperName, Url FROM CustomTab WHERE Type = \'lightning\' LIMIT 200';
            HttpRequest tabReq = new HttpRequest();
            tabReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                EncodingUtil.urlEncode(tabSoql, 'UTF-8'));
            tabReq.setMethod('GET');
            tabReq.setHeader('Content-Type', 'application/json');
            tabReq.setTimeout(TIMEOUT_LONG);
            HttpResponse tabRes = http.send(tabReq);
            if (tabRes.getStatusCode() >= 200 && tabRes.getStatusCode() < 300) {
                Map<String, Object> tabBody    = (Map<String, Object>) JSON.deserializeUntyped(tabRes.getBody());
                List<Object>        tabRecords = (List<Object>) tabBody.get('records');
                if (tabRecords != null) {
                    for (Object r : tabRecords) {
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              tabName = (String) row.get('DeveloperName');
                        if (String.isNotBlank(tabName)) auraTabSet.add(tabName.toLowerCase());
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'Check 3 failed — continue: ' + ex.getMessage()); }

        // ── Check 4: FlexiPage metadata scan ──
        try {
            String flexiSoql = 'SELECT DeveloperName, Metadata FROM FlexiPage LIMIT 300';
            HttpRequest flexiReq = new HttpRequest();
            flexiReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                EncodingUtil.urlEncode(flexiSoql, 'UTF-8'));
            flexiReq.setMethod('GET');
            flexiReq.setHeader('Content-Type', 'application/json');
            flexiReq.setTimeout(TIMEOUT_LONG);
            HttpResponse flexiRes = http.send(flexiReq);
            if (flexiRes.getStatusCode() >= 200 && flexiRes.getStatusCode() < 300) {
                Map<String, Object> flexiBody    = (Map<String, Object>) JSON.deserializeUntyped(flexiRes.getBody());
                List<Object>        flexiRecords = (List<Object>) flexiBody.get('records');
                if (flexiRecords != null) {
                    for (Object r : flexiRecords) {
                        Map<String, Object> row      = (Map<String, Object>) r;
                        Map<String, Object> metadata = (Map<String, Object>) row.get('Metadata');
                        if (metadata == null) continue;
                        String metaStr = JSON.serialize(metadata).toLowerCase();
                        for (AuraComponentInfo info : allComponents) {
                            if (String.isNotBlank(info.name) && metaStr.containsIgnoreCase(info.name)) {
                                referencedNames.add(info.name.toLowerCase());
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'Check 4 failed — continue: ' + ex.getMessage()); }

        // ── Final: Combine all checks + assign safety status ──
        List<AuraComponentInfo> unreferencedComponents = new List<AuraComponentInfo>();
        Integer unreferencedCount = 0;

        for (AuraComponentInfo info : allComponents) {
            Boolean isManaged    = String.isNotBlank(info.namespacePrefix);
            Boolean isTopApp     = topLevelAppNames.contains(info.name.toLowerCase());
            Boolean isTab        = auraTabSet.contains(info.name.toLowerCase());
            Boolean isReferenced = referencedNames.contains(info.name.toLowerCase());

            info.isManagedPackage = isManaged;
            info.isTopLevelApp    = isTopApp;
            info.isExposedTab     = isTab;

            if (isManaged) {
                info.isReferenced    = true;
                info.referencedBy    = 'Managed Package (' + info.namespacePrefix + ')';
                info.referenceSource = 'Managed Package';
                info.safetyStatus    = 'MANAGED';
            } else if (isTopApp) {
                info.isReferenced    = true;
                info.referencedBy    = 'Top-level Aura App (entry point via URL)';
                info.referenceSource = 'App Entry Point';
                info.safetyStatus    = 'ENTRY_POINT';
            } else if (isTab) {
                info.isReferenced    = true;
                info.referencedBy    = 'Custom Tab (entry point)';
                info.referenceSource = 'Tab';
                info.safetyStatus    = 'ENTRY_POINT';
            } else if (isReferenced) {
                info.isReferenced    = true;
                info.referencedBy    = 'Referenced in app/component markup or FlexiPage';
                info.referenceSource = 'Aura Markup / FlexiPage';
                info.safetyStatus    = 'IN_USE';
            } else {
                Set<String> selfComponents = new Set<String>{
                    'metadatadashboardapp'
                };
                if (selfComponents.contains(info.name != null ? info.name.toLowerCase() : '')) {
                    info.isReferenced    = true;
                    info.referencedBy    = 'This Dashboard App (self-excluded from unreferenced list)';
                    info.referenceSource = 'Self';
                    info.safetyStatus    = 'ENTRY_POINT';
                } else {
                    info.isReferenced    = false;
                    info.referencedBy    = '';
                    info.referenceSource = 'None';
                    info.safetyStatus    = 'SAFE_TO_REVIEW';
                    unreferencedComponents.add(info);
                    unreferencedCount++;
                }
            }
        }   // ← FIX: closes the for loop over allComponents

        summary.unreferencedCount      = unreferencedCount;
        summary.unreferencedComponents = unreferencedComponents;
        return summary;
    }   // ← FIX: closes getAuraComponents

    // ── Mass delete Aura components ────────────────────────────
    public static MassDeleteResult massDeleteAuraComponents(List<String> componentNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = componentNames.size();
        mass.successCount = 0; mass.failureCount = 0;
        mass.succeeded = new List<String>(); mass.failed = new List<String>();
        for (String name : componentNames) {
            if (String.isBlank(name)) continue;
            String n = name.trim().replace(' ', '_');
            DeleteResult r = deleteAuraByName(n);
            if (r.success) { mass.successCount++; mass.succeeded.add(n); }
            else           { mass.failureCount++; mass.failed.add(name.trim() + ' (' + r.message + ')'); }
        }
        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' + mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET PROFILES + DETECT UNUSED
    // ===============================
    public static ProfileSummary getProfiles() {
        return getProfiles(null);
    }

    public static ProfileSummary getProfiles(String namespaceFilter) {

        Http http = new Http();

        String profileSoql = 'SELECT Id, Name, UserLicenseId, UserLicense.Name, UserType FROM Profile ORDER BY Name ASC';
        Map<String, ProfileInfo> profileMap = new Map<String, ProfileInfo>();

        String  prEndpoint = BASE_URL + 'query?q=' + EncodingUtil.urlEncode(profileSoql, 'UTF-8');
        Boolean prDone     = false;
        while (!prDone) {
            HttpRequest profileReq = new HttpRequest();
            profileReq.setEndpoint(prEndpoint);
            profileReq.setMethod('GET');
            profileReq.setHeader('Content-Type', 'application/json');

            HttpResponse profileRes = http.send(profileReq);
            if (profileRes.getStatusCode() < 200 || profileRes.getStatusCode() >= 300) break;

            Map<String, Object> profileResponse =
                (Map<String, Object>) JSON.deserializeUntyped(profileRes.getBody());
            List<Object> profileRecords = (List<Object>) profileResponse.get('records');

            if (profileRecords != null) {
                for (Object obj : profileRecords) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    ProfileInfo info       = new ProfileInfo();
                    info.id                = (String) rec.get('Id');
                    info.name              = (String) rec.get('Name');
                    info.assignedUserCount = 0;
                    String userType        = (String) rec.get('UserType');
                    info.isCustom          = (userType == null || userType == 'Standard');

                    Map<String, Object> licMap = (Map<String, Object>) rec.get('UserLicense');
                    info.userLicenseName = licMap != null ? (String) licMap.get('Name') : 'Unknown';

                    profileMap.put(info.id, info);
                }
            }

            prDone = (profileResponse.get('done') == true);
            if (!prDone) {
                prEndpoint = 'callout:' + NAMED_CRED + (String) profileResponse.get('nextRecordsUrl');
            }
        }

        String      userSoql = 'SELECT ProfileId, COUNT(Id) userCount FROM User WHERE IsActive = true GROUP BY ProfileId';
        HttpRequest userReq  = new HttpRequest();
        userReq.setEndpoint(BASE_URL + 'query?q=' +
            EncodingUtil.urlEncode(userSoql, 'UTF-8'));
        userReq.setMethod('GET');
        userReq.setHeader('Content-Type', 'application/json');

        HttpResponse userRes = http.send(userReq);

        if (userRes.getStatusCode() >= 200 && userRes.getStatusCode() < 300) {
            Map<String, Object> userResponse =
                (Map<String, Object>) JSON.deserializeUntyped(userRes.getBody());
            List<Object> userRecords = (List<Object>) userResponse.get('records');

            if (userRecords != null) {
                for (Object obj : userRecords) {
                    Map<String, Object> rec       = (Map<String, Object>) obj;
                    String              profileId = (String) rec.get('ProfileId');
                    Integer             cnt       = Integer.valueOf(String.valueOf(rec.get('userCount')));

                    if (profileMap.containsKey(profileId)) {
                        profileMap.get(profileId).assignedUserCount = cnt;
                    }
                }
            }
        }

        Set<String> systemProfiles = new Set<String>{
            'system administrator', 'standard user', 'guest user',
            'chatter free user', 'chatter external user', 'minimum access - salesforce',
            'contract manager', 'solution manager', 'read only',
            'marketing user', 'platform portal user'
        };

        List<ProfileInfo> unusedProfiles   = new List<ProfileInfo>();
        List<ProfileInfo> usedProfiles     = new List<ProfileInfo>();
        List<ProfileInfo> customProfiles   = new List<ProfileInfo>();
        List<ProfileInfo> standardProfiles = new List<ProfileInfo>();
        List<ProfileInfo> filteredProfiles = new List<ProfileInfo>();

        String nsL = String.isNotBlank(namespaceFilter) ? namespaceFilter.toLowerCase() : '';

        for (ProfileInfo info : profileMap.values()) {
            Boolean isSys = systemProfiles.contains(info.name != null ? info.name.toLowerCase() : '');
            info.isSystemProfile = isSys;

            if (info.assignedUserCount == 0 && !isSys) {
                unusedProfiles.add(info);
                info.safetyStatus = 'SAFE_TO_REVIEW';
            } else if (isSys) {
                usedProfiles.add(info);
                info.safetyStatus = 'SYSTEM';
            } else {
                usedProfiles.add(info);
                info.safetyStatus = 'IN_USE';
            }
            if (info.isCustom == true) {
                customProfiles.add(info);
            } else {
                standardProfiles.add(info);
            }

            if (String.isNotBlank(namespaceFilter)) {
                String  profNm = info.name == null ? '' : info.name.toLowerCase();
                Boolean matchesFilter = false;
                if (profNm.startsWith(nsL)) {
                    Integer nextIdx = nsL.length();
                    if (nextIdx >= profNm.length()) {
                        matchesFilter = true;
                    } else {
                        String nextChar = info.name.substring(nextIdx, nextIdx + 1);
                        if (nextChar.equals('_') || nextChar.equals(nextChar.toUpperCase())) {
                            matchesFilter = true;
                        }
                    }
                }
                if (matchesFilter) {
                    filteredProfiles.add(info);
                }
            }
        }

        ProfileSummary summary    = new ProfileSummary();
        summary.total             = profileMap.size();
        summary.unused            = unusedProfiles.size();
        summary.used              = usedProfiles.size();
        summary.customCount       = customProfiles.size();
        summary.standardCount     = standardProfiles.size();
        summary.unusedProfiles    = unusedProfiles;
        summary.usedProfiles      = usedProfiles;
        summary.customProfiles    = customProfiles;
        summary.standardProfiles  = standardProfiles;
        summary.filteredProfiles  = filteredProfiles;
        summary.filteredTotal     = filteredProfiles.size();
        summary.namespaceFilter   = namespaceFilter;

        return summary;
    }

    // ── Mass deactivate Profiles ───────────────────────────────
    public static MassDeleteResult massDeactivateProfiles(List<String> profileNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = profileNames.size();
        mass.successCount = 0; mass.failureCount = 0;
        mass.succeeded = new List<String>(); mass.failed = new List<String>();
        String fallback = MetadataConstants.DEFAULT_PROFILE;
        for (String name : profileNames) {
            if (String.isBlank(name)) continue;
            DeleteResult r = deactivateProfileByName(name.trim(), fallback);
            if (r.success) { mass.successCount++; mass.succeeded.add(name.trim()); }
            else           { mass.failureCount++; mass.failed.add(name.trim() + ' (' + r.message + ')'); }
        }
        mass.summary = 'Mass deactivate complete: ' + mass.successCount + ' succeeded, ' + mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET PERMISSION SETS + DETECT UNUSED
    // ===============================
    public static PermissionSetSummary getPermissionSets() {
        return getPermissionSets(null);
    }

    public static PermissionSetSummary getPermissionSets(String namespaceFilter) {

        Http http = new Http();

        String permSetSoql = 'SELECT Id, Name, Label, IsCustom, NamespacePrefix FROM PermissionSet ' +
                             'WHERE IsOwnedByProfile = false ORDER BY Label ASC';
        Map<String, PermissionSetInfo> permSetMap = new Map<String, PermissionSetInfo>();

        String  psEndpoint = BASE_URL + 'query?q=' + EncodingUtil.urlEncode(permSetSoql, 'UTF-8');
        Boolean psDone     = false;
        while (!psDone) {
            HttpRequest permSetReq = new HttpRequest();
            permSetReq.setEndpoint(psEndpoint);
            permSetReq.setMethod('GET');
            permSetReq.setHeader('Content-Type', 'application/json');

            HttpResponse permSetRes = http.send(permSetReq);
            if (permSetRes.getStatusCode() < 200 || permSetRes.getStatusCode() >= 300) break;

            Map<String, Object> permSetResponse =
                (Map<String, Object>) JSON.deserializeUntyped(permSetRes.getBody());
            List<Object> permSetRecords = (List<Object>) permSetResponse.get('records');

            if (permSetRecords != null) {
                for (Object obj : permSetRecords) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    PermissionSetInfo info = new PermissionSetInfo();
                    info.id              = (String)  rec.get('Id');
                    info.name            = (String)  rec.get('Name');
                    info.label           = (String)  rec.get('Label');
                    info.isCustom        = (Boolean) rec.get('IsCustom');
                    info.namespacePrefix = (String)  rec.get('NamespacePrefix');
                    info.assignmentCount = 0;

                    permSetMap.put(info.id, info);
                }
            }

            psDone = (permSetResponse.get('done') == true);
            if (!psDone) {
                psEndpoint = 'callout:' + NAMED_CRED + (String) permSetResponse.get('nextRecordsUrl');
            }
        }

        String      assignSoql = 'SELECT PermissionSetId, COUNT(Id) assignCount FROM PermissionSetAssignment GROUP BY PermissionSetId';
        HttpRequest assignReq  = new HttpRequest();
        assignReq.setEndpoint(BASE_URL + 'query?q=' +
            EncodingUtil.urlEncode(assignSoql, 'UTF-8'));
        assignReq.setMethod('GET');
        assignReq.setHeader('Content-Type', 'application/json');

        HttpResponse assignRes = http.send(assignReq);

        if (assignRes.getStatusCode() >= 200 && assignRes.getStatusCode() < 300) {
            Map<String, Object> assignResponse =
                (Map<String, Object>) JSON.deserializeUntyped(assignRes.getBody());
            List<Object> assignRecords = (List<Object>) assignResponse.get('records');

            if (assignRecords != null) {
                for (Object obj : assignRecords) {
                    Map<String, Object> rec  = (Map<String, Object>) obj;
                    String              psId = (String) rec.get('PermissionSetId');
                    Integer             cnt  = Integer.valueOf(String.valueOf(rec.get('assignCount')));

                    if (permSetMap.containsKey(psId)) {
                        permSetMap.get(psId).assignmentCount = cnt;
                    }
                }
            }
        }

        List<PermissionSetInfo> unusedPermSets   = new List<PermissionSetInfo>();
        List<PermissionSetInfo> usedPermSets     = new List<PermissionSetInfo>();
        List<PermissionSetInfo> filteredPermSets = new List<PermissionSetInfo>();
        Integer withNs    = 0;
        Integer withoutNs = 0;

        String nsLower = String.isNotBlank(namespaceFilter) ? namespaceFilter.toLowerCase() : null;

        for (PermissionSetInfo info : permSetMap.values()) {
            if (String.isNotBlank(info.namespacePrefix)) {
                withNs++;
            } else {
                withoutNs++;
            }
            Boolean isManaged = String.isNotBlank(info.namespacePrefix);
            info.isManagedPackage = isManaged;

            if (isManaged) {
                info.safetyStatus = 'MANAGED';
                usedPermSets.add(info);
            } else if (info.assignmentCount == 0) {
                info.safetyStatus = 'SAFE_TO_REVIEW';
                unusedPermSets.add(info);
            } else {
                info.safetyStatus = 'IN_USE';
                usedPermSets.add(info);
            }
            String  psNs   = info.namespacePrefix == null ? '' : info.namespacePrefix;
            String  psNm   = info.name == null ? '' : info.name.toLowerCase();
            Boolean psMatch = nsLower != null && nsLower.equals(psNs.toLowerCase());
            if (!psMatch && nsLower != null && psNm.startsWith(nsLower)) {
                Integer nextIdx = nsLower.length();
                if (nextIdx >= psNm.length()) {
                    psMatch = true;
                } else {
                    String nextChar = info.name.substring(nextIdx, nextIdx + 1);
                    if (nextChar.equals('_') || nextChar.equals(nextChar.toUpperCase())) {
                        psMatch = true;
                    }
                }
            }
            if (nsLower != null && psMatch) {
                filteredPermSets.add(info);
            }
        }

        PermissionSetSummary summary    = new PermissionSetSummary();
        summary.total                   = permSetMap.size();
        summary.unused                  = unusedPermSets.size();
        summary.used                    = usedPermSets.size();
        summary.withNamespace           = withNs;
        summary.withoutNamespace        = withoutNs;
        summary.filteredTotal           = filteredPermSets.size();
        summary.namespaceFilterApplied  = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';
        summary.allPermSets             = new List<PermissionSetInfo>(usedPermSets);
        summary.allPermSets.addAll(unusedPermSets);
        summary.unusedPermSets          = unusedPermSets;
        summary.usedPermSets            = usedPermSets;
        summary.filteredPermSets        = filteredPermSets;

        return summary;
    }

    // ── Mass delete Permission Sets ────────────────────────────
    public static MassDeleteResult massDeletePermissionSets(List<String> permSetNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = permSetNames.size();
        mass.successCount = 0; mass.failureCount = 0;
        mass.succeeded = new List<String>(); mass.failed = new List<String>();
        for (String name : permSetNames) {
            if (String.isBlank(name)) continue;
            DeleteResult r = deletePermissionSetByName(name.trim());
            if (r.success) { mass.successCount++; mass.succeeded.add(name.trim()); }
            else           { mass.failureCount++; mass.failed.add(name.trim() + ' (' + r.message + ')'); }
        }
        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' + mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET CUSTOM OBJECTS
    // ===============================
    public static CustomObjectSummary getCustomObjects(String namespaceFilter) {

        Http http = new Http();

        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate ' +
                    'FROM CustomObject ' +
                    'ORDER BY DeveloperName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(TIMEOUT_LONG);

        HttpResponse res = http.send(req);

        List<CustomObjectInfo> allObjects      = new List<CustomObjectInfo>();
        List<CustomObjectInfo> filteredObjects = new List<CustomObjectInfo>();
        Integer withNamespace    = 0;
        Integer withoutNamespace = 0;

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) response.get('records');

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec     = (Map<String, Object>) obj;
                    String              devName = (String) rec.get('DeveloperName');

                    Boolean exists = false;
                    try {
                        Schema.describeSObjects(new List<String>{ devName + '__c' });
                        exists = true;
                    } catch (Exception ex) {
                        exists = false;
                    }

                    if (!exists) {
                        continue;
                    }

                    CustomObjectInfo info  = new CustomObjectInfo();
                    info.name             = devName;
                    info.id               = (String) rec.get('Id');
                    info.label            = devName.replace('_', ' ');
                    info.namespacePrefix  = (String) rec.get('NamespacePrefix');
                    info.lastModifiedDate = (String) rec.get('LastModifiedDate');

                    allObjects.add(info);

                    if (String.isNotBlank(info.namespacePrefix)) {
                        withNamespace++;
                    } else {
                        withoutNamespace++;
                    }

                    String  objNs = info.namespacePrefix == null ? '' : info.namespacePrefix;
                    String  objNm = info.name == null ? '' : info.name.toLowerCase();
                    String  nsL   = namespaceFilter == null ? '' : namespaceFilter.toLowerCase();
                    Boolean matchesFilter = String.isBlank(namespaceFilter) || nsL.equals(objNs.toLowerCase()) ||
                        objNm.startsWith(nsL + '_') || (objNm.startsWith(nsL) && objNm.length() > nsL.length() &&
                        objNm.substring(nsL.length(), nsL.length()+1) != objNm.substring(nsL.length(), nsL.length()+1).toLowerCase());

                    if (matchesFilter) {
                        filteredObjects.add(info);
                    }
                }
            }
        }

        CustomObjectSummary summary = new CustomObjectSummary();
        summary.total               = allObjects.size();
        summary.withNamespace       = withNamespace;
        summary.withoutNamespace    = withoutNamespace;
        summary.allObjects          = allObjects;
        summary.filteredObjects     = filteredObjects;
        summary.namespaceFilter     = namespaceFilter;

        List<CustomObjectInfo> emptyObjects = new List<CustomObjectInfo>();
        Integer emptyCount = 0;
        for (CustomObjectInfo info : allObjects) {
            try {
                Integer cnt      = Database.countQuery('SELECT COUNT() FROM ' + info.name + '__c LIMIT 1');
                info.recordCount = cnt;
                info.isEmpty     = (cnt == 0);
                if (cnt == 0) { emptyObjects.add(info); emptyCount++; }
            } catch (Exception ex) {
                info.recordCount = -1;
                info.isEmpty     = false;
            }
        }
        summary.emptyCount   = emptyCount;
        summary.emptyObjects = emptyObjects;

        // Build Id→name map from allObjects so we can match by RefMetadataComponentId
        Map<String, String> objIdToName = new Map<String, String>();
        for (CustomObjectInfo coi : allObjects) {
            if (String.isNotBlank(coi.id)) objIdToName.put(coi.id.toLowerCase(), coi.name);
        }

        Set<String> objDepIds = new Set<String>();
        try {
            // FIX: Use RefMetadataComponentId — RefMetadataComponentName is unreliable in many orgs
            String objDepSoql = 'SELECT RefMetadataComponentId FROM MetadataComponentDependency ' +
                                'WHERE RefMetadataComponentType = \'CustomObject\'';
            HttpRequest objDepReq = new HttpRequest();
            objDepReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(objDepSoql, 'UTF-8'));
            objDepReq.setMethod('GET');
            objDepReq.setHeader('Content-Type', 'application/json');
            objDepReq.setTimeout(TIMEOUT_LONG);
            HttpResponse objDepRes = http.send(objDepReq);
            if (objDepRes.getStatusCode() >= 200 && objDepRes.getStatusCode() < 300) {
                Map<String, Object> objDepBody    = (Map<String, Object>) JSON.deserializeUntyped(objDepRes.getBody());
                List<Object>        objDepRecords = (List<Object>) objDepBody.get('records');
                if (objDepRecords != null) {
                    for (Object r : objDepRecords) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              refId = (String) row.get('RefMetadataComponentId');
                        if (String.isNotBlank(refId)) objDepIds.add(refId.toLowerCase());
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'dep check failed — continue: ' + ex.getMessage()); }

        for (CustomObjectInfo info : allObjects) {
            Boolean isManaged  = String.isNotBlank(info.namespacePrefix);
            Boolean isInDep    = String.isNotBlank(info.id) && objDepIds.contains(info.id.toLowerCase());
            info.isManagedPackage   = isManaged;
            info.isReferencedByCode = isInDep;

            if (isManaged) {
                info.safetyStatus = 'MANAGED';
            } else if (isInDep) {
                info.safetyStatus = 'IN_USE';
            } else if (!info.isEmpty) {
                info.safetyStatus = 'HAS_DATA';
            } else {
                info.safetyStatus = 'SAFE_TO_REVIEW';
            }
        }

        return summary;
    }

    // ── Mass delete Custom Objects ─────────────────────────────
    public static MassDeleteResult massDeleteCustomObjects(List<String> objectNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = objectNames.size();
        mass.successCount = 0; mass.failureCount = 0;
        mass.succeeded = new List<String>(); mass.failed = new List<String>();
        for (String name : objectNames) {
            if (String.isBlank(name)) continue;
            DeleteResult r = deleteCustomObjectByName(name.trim().replace(' ', '_'));
            if (r.success) { mass.successCount++; mass.succeeded.add(name.trim()); }
            else           { mass.failureCount++; mass.failed.add(name.trim() + ' (' + r.message + ')'); }
        }
        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' + mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET CUSTOM FIELDS
    // ===============================
    public static CustomFieldSummary getCustomFields(String namespaceFilter) {

        Http http = new Http();

        Set<String> sampleFields = new Set<String>{
            'active', 'customerpriority', 'numberoflocations', 'sla',
            'slaexpirationdate', 'slaserialnumber', 'upsellOpportunity',
            'engineeringreqnumber', 'potentialliability', 'product',
            'slaviolation', 'languages', 'level', 'currentgenerators',
            'primary', 'productinterest', 'siccode', 'origgoalid',
            'origmetricid', 'deliveryinstallationstatus', 'maincompetitors',
            'ordernumber', 'trackingnumber', 'naicsdesc', 'sicdesc'
        };

        Set<String> knownStandardObjects = new Set<String>{
            'Account', 'Contact', 'Lead', 'Opportunity', 'Case',
            'Task', 'Event', 'Campaign', 'Contract', 'Order',
            'Product2', 'Pricebook2', 'Quote', 'Asset', 'Entitlement',
            'Goal', 'Metric', 'User', 'UserRole', 'Group',
            'CampaignMember', 'OpportunityLineItem', 'CaseComment',
            'Solution', 'Idea', 'IdeaComment', 'Question', 'Reply',
            'WorkOrder', 'WorkOrderLineItem', 'ServiceAppointment',
            'ReturnOrder', 'ReturnOrderLineItem', 'OperatingHours',
            'ServiceTerritory', 'ServiceResource', 'AssignedResource',
            'ResourceAbsence', 'Shift', 'ServiceContract', 'ContractLineItem',
            'EntitlementContact', 'Milestone', 'CaseMilestone'
        };

        Set<String> systemPrefixes = new Set<String>{
            '9sdg', '0Hf', '0Mo', '0Ho', '0Db', '0Dt', '0XO'
        };

        Map<String, String> validObjectIds = new Map<String, String>();

        HttpRequest objReq = new HttpRequest();
        objReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(
                'SELECT Id, DeveloperName FROM CustomObject ORDER BY DeveloperName ASC',
                'UTF-8'
            ));
        objReq.setMethod('GET');
        objReq.setHeader('Content-Type', 'application/json');
        objReq.setTimeout(TIMEOUT_LONG);

        HttpResponse objRes = http.send(objReq);
        if (objRes.getStatusCode() >= 200 && objRes.getStatusCode() < 300) {
            Map<String, Object> objBody    = (Map<String, Object>) JSON.deserializeUntyped(objRes.getBody());
            List<Object>        objRecords = (List<Object>) objBody.get('records');
            if (objRecords != null) {
                for (Object o : objRecords) {
                    Map<String, Object> rec     = (Map<String, Object>) o;
                    String              objId   = (String) rec.get('Id');
                    String              devName = (String) rec.get('DeveloperName');
                    Boolean             exists  = false;
                    try {
                        Schema.describeSObjects(new List<String>{ devName + '__c' });
                        exists = true;
                    } catch (Exception ex) {
                        exists = false;
                    }
                    if (exists) {
                        validObjectIds.put(objId, devName + '__c');
                    }
                }
            }
        }

        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate, TableEnumOrId ' +
                    'FROM CustomField ' +
                    'WHERE ManageableState = \'unmanaged\' ' +
                    'ORDER BY TableEnumOrId, DeveloperName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(TIMEOUT_LONG);

        HttpResponse res = http.send(req);

        List<CustomFieldInfo> allFields      = new List<CustomFieldInfo>();
        List<CustomFieldInfo> filteredFields = new List<CustomFieldInfo>();
        Integer withNamespace    = 0;
        Integer withoutNamespace = 0;

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Object parsed = JSON.deserializeUntyped(res.getBody());
            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> response = (Map<String, Object>) parsed;
                List<Object>        records  = (List<Object>) response.get('records');

                if (records != null) {
                    for (Object obj : records) {
                        Map<String, Object> rec     = (Map<String, Object>) obj;
                        String              tableId = (String) rec.get('TableEnumOrId');
                        String              field   = (String) rec.get('DeveloperName');

                        if (String.isBlank(tableId) || String.isBlank(field)) continue;
                        if (field.endsWith('_del')) continue;

                        Boolean isSystemPrefix = false;
                        for (String prefix : systemPrefixes) {
                            if (tableId.startsWith(prefix)) {
                                isSystemPrefix = true;
                                break;
                            }
                        }
                        if (isSystemPrefix) continue;

                        String objectName = null;

                        if (validObjectIds.containsKey(tableId)) {
                            objectName = validObjectIds.get(tableId);
                        } else if (knownStandardObjects.contains(tableId)) {
                            if (sampleFields.contains(field.toLowerCase())) continue;
                            objectName = tableId;
                        } else {
                            continue;
                        }

                        CustomFieldInfo info  = new CustomFieldInfo();
                        info.id               = (String) rec.get('Id');
                        info.name             = field;
                        info.objectName       = objectName;
                        info.dataType         = null;
                        info.namespacePrefix  = (String) rec.get('NamespacePrefix');
                        info.lastModifiedDate = (String) rec.get('LastModifiedDate');

                        allFields.add(info);

                        if (String.isNotBlank(info.namespacePrefix)) {
                            withNamespace++;
                        } else {
                            withoutNamespace++;
                        }

                        String  fldNs = info.namespacePrefix == null ? '' : info.namespacePrefix;
                        String  fldNm = info.name == null ? '' : info.name.toLowerCase();
                        String  nsL   = namespaceFilter == null ? '' : namespaceFilter.toLowerCase();
                        Boolean matchesFilter = String.isBlank(namespaceFilter) || nsL.equals(fldNs.toLowerCase()) ||
                            fldNm.startsWith(nsL + '_') || (fldNm.startsWith(nsL) && fldNm.length() > nsL.length() &&
                            fldNm.substring(nsL.length(), nsL.length()+1) != fldNm.substring(nsL.length(), nsL.length()+1).toLowerCase());

                        if (matchesFilter) {
                            filteredFields.add(info);
                        }
                    }
                }
            }
        }

        CustomFieldSummary summary = new CustomFieldSummary();
        summary.total              = allFields.size();
        summary.withNamespace      = withNamespace;
        summary.withoutNamespace   = withoutNamespace;
        summary.allFields          = allFields;
        summary.filteredFields     = filteredFields;
        summary.namespaceFilter    = namespaceFilter;

        Map<String, List<CustomFieldInfo>> byObject = new Map<String, List<CustomFieldInfo>>();
        for (CustomFieldInfo f : allFields) {
            String key = f.objectName;
            if (!byObject.containsKey(key)) byObject.put(key, new List<CustomFieldInfo>());
            byObject.get(key).add(f);
        }

        List<CustomFieldInfo> emptyFields = new List<CustomFieldInfo>();
        Integer emptyCount = 0;

        for (String objName : byObject.keySet()) {
            List<CustomFieldInfo> objFields = byObject.get(objName);
            for (CustomFieldInfo f : objFields) {
                String fieldApi = f.name + '__c';
                Boolean isManaged = String.isNotBlank(f.namespacePrefix);
                f.isManagedPackage = isManaged;
                try {
                    String q   = 'SELECT COUNT() FROM ' + String.escapeSingleQuotes(objName) + ' WHERE ' + String.escapeSingleQuotes(fieldApi) + ' != null LIMIT 1';
                    Integer cnt = Database.countQuery(q);
                    f.nonNullCount = cnt;
                    f.hasData      = (cnt > 0);
                    if (cnt == 0) { emptyFields.add(f); emptyCount++; }
                } catch (Exception ex) {
                    f.nonNullCount = -1;
                    f.hasData      = true;
                }
                if (isManaged) {
                    f.safetyStatus = 'MANAGED';
                } else if (f.hasData == true) {
                    f.safetyStatus = 'HAS_DATA';
                } else if (f.nonNullCount == -1) {
                    f.safetyStatus = 'IN_USE';
                } else {
                    f.safetyStatus = 'SAFE_TO_REVIEW';
                }
            }
        }

        summary.emptyCount  = emptyCount;
        summary.emptyFields = emptyFields;

        return summary;
    }

    // ── Mass delete Custom Fields ──────────────────────────────
    public static MassDeleteResult massDeleteCustomFields(List<String> dotNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = dotNames.size();
        mass.successCount = 0; mass.failureCount = 0;
        mass.succeeded = new List<String>(); mass.failed = new List<String>();
        for (String dotName : dotNames) {
            if (String.isBlank(dotName)) continue;
            List<String> parts = dotName.trim().split('\\.');
            if (parts.size() < 2) {
                mass.failureCount++;
                mass.failed.add(dotName.trim() + ' (invalid format — use ObjectName.FieldName)');
                continue;
            }
            DeleteResult r = deleteCustomFieldByName(parts[0].trim(), parts[1].trim());
            if (r.success) { mass.successCount++; mass.succeeded.add(dotName.trim()); }
            else           { mass.failureCount++; mass.failed.add(dotName.trim() + ' (' + r.message + ')'); }
        }
        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' + mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ── Mass delete Validation Rules ───────────────────────────
    public static MassDeleteResult massDeleteValidationRules(List<String> dotNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = dotNames.size();
        mass.successCount = 0; mass.failureCount = 0;
        mass.succeeded = new List<String>(); mass.failed = new List<String>();
        for (String dotName : dotNames) {
            if (String.isBlank(dotName)) continue;
            List<String> parts = dotName.trim().split('\\.');
            if (parts.size() < 2) {
                mass.failureCount++;
                mass.failed.add(dotName.trim() + ' (invalid format — use ObjectName.RuleName)');
                continue;
            }
            DeleteResult r = deleteValidationRuleByName(parts[0].trim(), parts[1].trim());
            if (r.success) { mass.successCount++; mass.succeeded.add(dotName.trim()); }
            else           { mass.failureCount++; mass.failed.add(dotName.trim() + ' (' + r.message + ')'); }
        }
        mass.summary = 'Mass delete complete: ' + mass.successCount + ' succeeded, ' + mass.failureCount + ' failed out of ' + mass.totalRequested + ' requested.';
        return mass;
    }

    // ===============================
    // GET VALIDATION RULES
    // ===============================
    public static ValidationRuleSummary getValidationRules(String namespaceFilter) {

        Http   http = new Http();
        String soql = 'SELECT Id, ValidationName, EntityDefinition.QualifiedApiName, Active, ErrorMessage, NamespacePrefix, LastModifiedDate ' +
                      'FROM ValidationRule ORDER BY ValidationName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        List<ValidationRuleInfo> activeRules   = new List<ValidationRuleInfo>();
        List<ValidationRuleInfo> inactiveRules = new List<ValidationRuleInfo>();
        List<ValidationRuleInfo> filteredRules = new List<ValidationRuleInfo>();

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) response.get('records');

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    ValidationRuleInfo info = new ValidationRuleInfo();
                    info.id                 = (String)  rec.get('Id');
                    info.name               = (String)  rec.get('ValidationName');

                    Map<String, Object> entityDef = (Map<String, Object>) rec.get('EntityDefinition');
                    info.objectName         = entityDef != null ? (String) entityDef.get('QualifiedApiName') : null;

                    info.isActive           = (Boolean) rec.get('Active');
                    info.errorMessage       = (String)  rec.get('ErrorMessage');
                    info.namespacePrefix    = (String)  rec.get('NamespacePrefix');
                    info.lastModifiedDate   = (String)  rec.get('LastModifiedDate');

                    Boolean vrIsManaged = String.isNotBlank(info.namespacePrefix);
                    info.isManagedPackage = vrIsManaged;
                    if (vrIsManaged) {
                        info.safetyStatus = 'MANAGED';
                    } else if (info.isActive) {
                        info.safetyStatus = 'IN_USE';
                    } else {
                        info.safetyStatus = 'SAFE_TO_REVIEW';
                    }

                    if (info.isActive) {
                        activeRules.add(info);
                    } else {
                        inactiveRules.add(info);
                    }

                    String  vrNs = info.namespacePrefix == null ? '' : info.namespacePrefix;
                    String  vrNm = info.name == null ? '' : info.name.toLowerCase();
                    String  nsL  = namespaceFilter == null ? '' : namespaceFilter.toLowerCase();
                    Boolean matchesFilter = String.isBlank(namespaceFilter) || nsL.equals(vrNs.toLowerCase()) ||
                        vrNm.startsWith(nsL + '_') || (vrNm.startsWith(nsL) && vrNm.length() > nsL.length() &&
                        vrNm.substring(nsL.length(), nsL.length()+1) != vrNm.substring(nsL.length(), nsL.length()+1).toLowerCase());

                    if (matchesFilter) {
                        filteredRules.add(info);
                    }
                }
            }
        }

        ValidationRuleSummary summary = new ValidationRuleSummary();
        summary.total                 = activeRules.size() + inactiveRules.size();
        summary.active                = activeRules.size();
        summary.inactive              = inactiveRules.size();
        summary.activeRules           = activeRules;
        summary.inactiveRules         = inactiveRules;
        summary.filteredRules         = filteredRules;
        summary.namespaceFilter       = namespaceFilter;

        return summary;
    }

    // ===============================
    // DELETE CUSTOM OBJECT BY NAME
    // ===============================
    public static DeleteResult deleteCustomObjectByName(String objectName) {
        // ── Reference check FIRST — before production guard ──
        ReferenceResult objectRefs = getReferencesFor(objectName, 'CustomObject');
        if (objectRefs.hasReferences) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;
            blocked.message = buildFormattedReport(objectName, objectRefs.references, null, 'CustomObject');
            return blocked;
        }

        // ── Production guard \u2014 only fires if no references block ──
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();


        String cleanName = objectName.trim().endsWith('__c')
            ? objectName.trim().substring(0, objectName.trim().length() - 3)
            : objectName.trim();
        cleanName = cleanName.replace(' ', '_');

        String fullApiName = cleanName + '__c';

        String soql = 'SELECT Id, DeveloperName, NamespacePrefix FROM CustomObject ' +
                    'WHERE DeveloperName = \'' + String.escapeSingleQuotes(cleanName) + '\' LIMIT 1';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(TIMEOUT_LONG);

        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Lookup failed for Object "' + fullApiName + '". HTTP '
                            + res.getStatusCode() + ': ' + parseErrorBody(res.getBody());
            return result;
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object>        records     = (List<Object>) responseMap.get('records');

        if (records == null || records.isEmpty()) {
            result.success = false;
            result.message = 'No Custom Object found with DeveloperName "' + cleanName
                            + '". Make sure you pass the name WITHOUT __c.';
            return result;
        }

        Map<String, Object> objRec    = (Map<String, Object>) records[0];
        String              nsPrefix  = (String) objRec.get('NamespacePrefix');
        Boolean             isManaged = String.isNotBlank(nsPrefix);

        CustomObjectSummary objCheck = getCustomObjects(null);
        for (CustomObjectInfo oi : objCheck.allObjects) {
            if (cleanName.equalsIgnoreCase(oi.name)) {
                DeleteResult blocked = checkSafetyBeforeDelete(oi.safetyStatus, fullApiName);
                if (blocked != null) return blocked;
                break;
            }
        }

        System.debug('Object found   : ' + fullApiName);
        System.debug('NamespacePrefix: ' + nsPrefix);
        System.debug('Is Managed     : ' + isManaged);

        if (isManaged) {
            HttpRequest pkgReq = new HttpRequest();
            pkgReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
                EncodingUtil.urlEncode(
                    'SELECT Id, SubscriberPackageId, SubscriberPackage.Name, SubscriberPackage.NamespacePrefix ' +
                    'FROM InstalledSubscriberPackage ' +
                    'WHERE SubscriberPackage.NamespacePrefix = \'' + String.escapeSingleQuotes(nsPrefix) + '\'',
                    'UTF-8'
                ));
            pkgReq.setMethod('GET');
            pkgReq.setHeader('Content-Type', 'application/json');
            pkgReq.setTimeout(TIMEOUT_SHORT);

            HttpResponse pkgRes = http.send(pkgReq);

            if (pkgRes.getStatusCode() >= 200 && pkgRes.getStatusCode() < 300) {
                Map<String, Object> pkgMap     = (Map<String, Object>) JSON.deserializeUntyped(pkgRes.getBody());
                List<Object>        pkgRecords = (List<Object>) pkgMap.get('records');

                if (pkgRecords != null && !pkgRecords.isEmpty()) {
                    Map<String, Object> pkgRec  = (Map<String, Object>) pkgRecords[0];
                    String              pkgId   = (String) pkgRec.get('Id');
                    Map<String, Object> subPkg  = (Map<String, Object>) pkgRec.get('SubscriberPackage');
                    String              pkgName = (String) subPkg.get('Name');

                    HttpRequest uninstallReq = new HttpRequest();
                    uninstallReq.setEndpoint(BASE_URL + 'tooling/sobjects/InstalledSubscriberPackage/' + pkgId);
                    uninstallReq.setMethod('DELETE');
                    uninstallReq.setHeader('Content-Type', 'application/json');
                    uninstallReq.setTimeout(TIMEOUT_LONG);

                    HttpResponse uninstallRes = http.send(uninstallReq);

                    if (uninstallRes.getStatusCode() == 200 || uninstallRes.getStatusCode() == 204) {
                        result.success = true;
                        result.message = 'Package "' + pkgName + '" uninstalled successfully. ' +
                                        '"' + fullApiName + '" and all related components have been removed.';
                    } else {
                        result.success = false;
                        result.message = 'Failed to uninstall package "' + pkgName + '". HTTP ' +
                                        uninstallRes.getStatusCode() + ': ' + uninstallRes.getBody();
                    }
                    return result;
                } else {
                    result.success = false;
                    result.message = 'Object "' + fullApiName + '" belongs to namespace "' + nsPrefix +
                                    '" but no installed package found. ' +
                                    'Go to Setup → Installed Packages to uninstall manually.';
                    return result;
                }
            }
        }

        String sessionId         = null;
        String metadataServerUrl = null;

        try {
            SF_Credential__mdt cred = [
                SELECT Username__c, ConsumerKey__c, Certificate__c
                FROM SF_Credential__mdt
                WHERE DeveloperName = 'MetadataAdmin'
                LIMIT 1
            ];

            String header = EncodingUtil.base64Encode(Blob.valueOf('{"alg":"RS256","typ":"JWT"}'))
                .replace('+', '-').replace('/', '_').replace('=', '');

            Long   expTime = DateTime.now().addMinutes(JWT_EXPIRY_MIN).getTime() / 1000;
            String payload = EncodingUtil.base64Encode(Blob.valueOf(
                '{"iss":"' + cred.ConsumerKey__c + '",' +
                '"sub":"' + cred.Username__c + '",' +
                '"aud":"' + LOGIN_URL + '",' +
                '"exp":' + expTime + '}'
            )).replace('+', '-').replace('/', '_').replace('=', '');

            String signingInput   = header + '.' + payload;
            Blob   privateKeyBlob = EncodingUtil.base64Decode(cred.Certificate__c);
            Blob   signature      = Crypto.sign('RSA-SHA256', Blob.valueOf(signingInput), privateKeyBlob);

            String jwt = signingInput + '.' + EncodingUtil.base64Encode(signature)
                .replace('+', '-').replace('/', '_').replace('=', '');

            HttpRequest jwtReq = new HttpRequest();
            jwtReq.setEndpoint(LOGIN_URL + '/services/oauth2/token');
            jwtReq.setMethod('POST');
            jwtReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            jwtReq.setTimeout(TIMEOUT_SHORT);
            jwtReq.setBody(
                'grant_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8') +
                '&assertion='  + EncodingUtil.urlEncode(jwt, 'UTF-8')
            );

            HttpResponse jwtRes = http.send(jwtReq);
            System.debug('JWT Status: ' + jwtRes.getStatusCode());

            if (jwtRes.getStatusCode() == 200) {
                Map<String, Object> tokenMap  = (Map<String, Object>) JSON.deserializeUntyped(jwtRes.getBody());
                sessionId                     = (String) tokenMap.get('access_token');
                String instanceUrl            = (String) tokenMap.get('instance_url');
                metadataServerUrl             = instanceUrl + '/services/Soap/m/60.0';
                System.debug('JWT Access Token obtained: YES');
            }

        } catch (Exception ex) {
            System.debug('JWT Exception: ' + ex.getMessage());
        }

        if (String.isBlank(sessionId)) {
            try {
                sessionId         = UserInfo.getSessionId();
                metadataServerUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/60.0';
                System.debug('Fallback to UserInfo session: YES');
            } catch (Exception ex) {
                System.debug('UserInfo fallback failed: ' + ex.getMessage());
            }
        }

        if (String.isBlank(sessionId) || String.isBlank(metadataServerUrl)) {
            result.success = false;
            result.message = 'Could not retrieve session ID or metadata URL.';
            return result;
        }

        String soapBody =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            '                  xmlns:met="http://soap.sforce.com/2006/04/metadata">' +
            '  <soapenv:Header>' +
            '    <met:CallOptions><met:client>ApexDeletion</met:client></met:CallOptions>' +
            '    <met:SessionHeader>' +
            '      <met:sessionId>' + sessionId + '</met:sessionId>' +
            '    </met:SessionHeader>' +
            '  </soapenv:Header>' +
            '  <soapenv:Body>' +
            '    <met:deleteMetadata>' +
            '      <met:type>CustomObject</met:type>' +
            '      <met:fullNames>' + fullApiName + '</met:fullNames>' +
            '    </met:deleteMetadata>' +
            '  </soapenv:Body>' +
            '</soapenv:Envelope>';

        HttpRequest del = new HttpRequest();
        del.setEndpoint(metadataServerUrl);
        del.setMethod('POST');
        del.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        del.setHeader('SOAPAction', '""');
        del.setTimeout(TIMEOUT_LONG);
        del.setBody(soapBody);

        HttpResponse dr = http.send(del);

        System.debug('SOAP DELETE Status: ' + dr.getStatusCode());
        System.debug('SOAP DELETE Body  : ' + dr.getBody());

        if (dr.getStatusCode() < 200 || dr.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'SOAP call failed. HTTP ' + dr.getStatusCode() + ': ' + dr.getBody();
            return result;
        }

        String body = dr.getBody();

        if (body.contains('<success>true</success>')) {
            result.success = true;
            result.message = 'Custom Object "' + fullApiName + '" permanently deleted successfully.';
        } else {
            String errorMsg = '';
            if (body.contains('<message>')) {
                errorMsg = body.substringBetween('<message>', '</message>');
            } else if (body.contains('<faultstring>')) {
                errorMsg = body.substringBetween('<faultstring>', '</faultstring>');
            } else {
                errorMsg = body;
            }
            result.success = false;
            result.message = 'Failed to delete "' + fullApiName + '": ' + errorMsg;
        }

        return result;
    }

    // ===============================
    // DELETE LWC COMPONENT BY NAME
    // ===============================
    // ── Shared helper: parse DEPENDENCY_EXISTS error body into a clean message ──
    private static String parseDependencyError(String componentName, String componentType, String errBody) {
        String sfMsg = '';
        try {
            Object parsed = JSON.deserializeUntyped(errBody);
            List<Object> errList = parsed instanceof List<Object>
                ? (List<Object>) parsed : new List<Object>{ parsed };
            for (Object e : errList) {
                Map<String, Object> em  = (Map<String, Object>) e;
                String              msg = (String) em.get('message');
                if (String.isNotBlank(msg)) sfMsg += msg.trim() + '\n';
            }
        } catch (Exception ex) { sfMsg = errBody; }

        String setupPath = '';
        if      (componentType == 'LightningComponentBundle') setupPath = 'Setup > Lightning Components > "' + componentName + '" > Where is this used?';
        else if (componentType == 'AuraDefinitionBundle')     setupPath = 'Setup > Lightning Components (Aura) > "' + componentName + '" > Where is this used?';
        else if (componentType == 'ApexTrigger')              setupPath = 'Setup > Apex Triggers > "' + componentName + '" > Where is this used?';
        else if (componentType == 'CustomObject')             setupPath = 'Setup > Object Manager > "' + componentName + '" > View Dependencies';
        else                                                  setupPath = 'Setup > "' + componentName + '" > Where is this used?';

        return '🚫 Cannot delete "' + componentName + '" — it is referenced.\n\n' +
               (String.isNotBlank(sfMsg) ? sfMsg.trim() + '\n\n' : '') +
               'Remove the reference(s) above, then retry.\n' +
               'Tip: ' + setupPath;
    }

    public static DeleteResult deleteLwcByName(String componentName) {
        // ── Deep reference check (MCD + JS source scan + HTML scan) ───
        ReferenceResult compRefs = checkAllLwcReferences(componentName);
        if (compRefs.hasReferences) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;
            blocked.message = compRefs.formattedReport;
            return blocked;
        }

        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        String      soql = 'SELECT Id FROM LightningComponentBundle WHERE DeveloperName = \'' +
                           String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
        HttpRequest req  = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Lookup failed for LWC "' + componentName + '". HTTP ' + res.getStatusCode();
            return result;
        }

        List<Object> records = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('records');

        if (records == null || records.isEmpty()) {
            result.success = false;
            result.message = 'No LWC found: ' + componentName;
            return result;
        }

        String cId = (String)((Map<String, Object>) records[0]).get('Id');

        // NOTE: Do NOT call checkSafetyBeforeDelete here — it blocks IN_USE components
        // before we can show them what is using it. Reference check above handles blocking.

        HttpRequest del = new HttpRequest();
        del.setEndpoint(BASE_URL + 'tooling/sobjects/LightningComponentBundle/' + cId);
        del.setMethod('DELETE');
        del.setHeader('Content-Type', 'application/json');

        HttpResponse dr = http.send(del);

        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true;
            result.message = '✅ LWC "' + componentName + '" deleted successfully.';
        } else {
            result.success = false;
            String errBody = dr.getBody();
            if (errBody != null && (errBody.containsIgnoreCase('DEPENDENCY_EXISTS') ||
                                    errBody.containsIgnoreCase('Referenced by') ||
                                    errBody.containsIgnoreCase('referenced elsewhere'))) {

                // ── Detect if the blocking reference is a STANDARD SYSTEM PAGE ───
                // Salesforce error message contains the page name e.g.
                // "Referenced by a component instance inside the Lightning page Home Page Default"
                // If the blocker is a standard/default page, it is NOT a user-created reference.
                // Show a clear explanation and exact removal steps — not a generic error.
                String sfErrLower = errBody.toLowerCase();
                Boolean blockedByStandardPage = false;
                String  standardPageName = '';

                Set<String> standardPageKeywords = new Set<String>{
                    'home page default', 'home_page_default',
                    '_record_page_default', '_list_page_default',
                    'default record page', 'standard home page'
                };
                for (String kw : standardPageKeywords) {
                    if (sfErrLower.contains(kw)) {
                        blockedByStandardPage = true;
                        // Extract the page name from the error message
                        Integer pgIdx = sfErrLower.indexOf(kw);
                        // Walk back to find start of page name
                        Integer nameStart = sfErrLower.lastIndexOf('lightning page', pgIdx);
                        if (nameStart >= 0) {
                            standardPageName = errBody.substring(nameStart + 'lightning page'.length(), pgIdx + kw.length()).trim();
                        }
                        if (String.isBlank(standardPageName)) standardPageName = kw;
                        break;
                    }
                }

                if (blockedByStandardPage) {
                    // Standard/system page blocking — explain clearly + give removal steps
                    result.message =
                        '⚠️ "' + componentName + '" is on a Salesforce system page ("' + standardPageName + '").\n\n' +
                        'This is a standard Salesforce default page — NOT a page you built.\n' +
                        'Salesforce placed this component there automatically.\n\n' +
                        'To remove it and complete the delete:\n' +
                        '  1. Setup > Lightning App Builder\n' +
                        '  2. Open "' + standardPageName + '"\n' +
                        '  3. Find the "' + componentName + '" component and remove it\n' +
                        '  4. Click Save, then retry the delete\n\n' +
                        'Alternatively:\n' +
                        '  Setup > Lightning Components > "' + componentName + '" > Where is this used?';
                } else {
                    // Real user-created reference — run reference check to get full list
                    ReferenceResult refsAfterFail = checkAllLwcReferences(componentName);
                    if (refsAfterFail.hasReferences) {
                        result.message = refsAfterFail.formattedReport;
                    } else {
                        result.message = parseDependencyError(componentName, 'LightningComponentBundle', errBody);
                    }
                }
            } else {
                result.message = 'Failed to delete LWC "' + componentName + '". HTTP ' +
                                 dr.getStatusCode() + ': ' + errBody;
            }
        }

        return result;
    }

    // ===============================
    // DELETE AURA COMPONENT BY NAME
    // ===============================
    public static DeleteResult deleteAuraByName(String componentName) {
        // ── Reference check FIRST — before production guard ──
        ReferenceResult auraRefs = getReferencesFor(componentName, 'AuraDefinitionBundle');
        if (auraRefs.hasReferences) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;
            blocked.message = buildFormattedReport(componentName, auraRefs.references, null, 'AuraDefinitionBundle');
            return blocked;
        }

        // ── Production guard \u2014 only fires if no references block ──
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();


        String      soql = 'SELECT Id FROM AuraDefinitionBundle WHERE DeveloperName = \'' +
                           String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
        HttpRequest req  = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Lookup failed for Aura "' + componentName + '". HTTP ' + res.getStatusCode();
            return result;
        }

        List<Object> records = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('records');

        if (records == null || records.isEmpty()) {
            result.success = false;
            result.message = 'No Aura component found: ' + componentName;
            return result;
        }

        String cId = (String)((Map<String, Object>) records[0]).get('Id');

        AuraSummary auraCheck = getAuraComponents(null);
        for (AuraComponentInfo ai : auraCheck.allComponents) {
            if (componentName.equalsIgnoreCase(ai.name)) {
                DeleteResult blocked = checkSafetyBeforeDelete(ai.safetyStatus, componentName);
                if (blocked != null) return blocked;
                break;
            }
        }

        HttpRequest del = new HttpRequest();
        del.setEndpoint(BASE_URL + 'tooling/sobjects/AuraDefinitionBundle/' + cId);
        del.setMethod('DELETE');
        del.setHeader('Content-Type', 'application/json');

        HttpResponse dr = http.send(del);

        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true;
            result.message = 'Aura component "' + componentName + '" (Id: ' + cId + ') deleted successfully.';
        } else {
            result.success = false;
            String errBody = dr.getBody();
            result.message = (errBody != null && (errBody.containsIgnoreCase('DEPENDENCY_EXISTS') || errBody.containsIgnoreCase('Referenced by')))
                ? parseDependencyError(componentName, 'AuraDefinitionBundle', errBody)
                : 'Failed to delete Aura "' + componentName + '". HTTP ' + dr.getStatusCode() + ': ' + errBody;
        }

        return result;
    }

    // ===============================
    // DELETE CUSTOM FIELD BY OBJECT + FIELD NAME
    // ===============================
    public static DeleteResult deleteCustomFieldByName(String objectName, String fieldName) {
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        // ── Reference check FIRST — before any destructive operation ──
        String fieldRef = objectName.trim() + '.' + fieldName.trim();
        ReferenceResult fieldRefs = getReferencesFor(fieldRef, 'CustomField');
        if (fieldRefs.hasReferences) {
            result.success = false;
            result.message = buildFormattedReport(fieldRef, fieldRefs.references, null, 'CustomField');
            return result;
        }

        String cleanObject = objectName.trim().endsWith('__c')
            ? objectName.trim().substring(0, objectName.trim().length() - 3)
            : objectName.trim();
        cleanObject = cleanObject.replace(' ', '_');

        String cleanField = fieldName.trim().endsWith('__c')
            ? fieldName.trim().substring(0, fieldName.trim().length() - 3)
            : fieldName.trim();
        cleanField = cleanField.replace(' ', '_');

        Boolean isCustomObject = objectName.trim().endsWith('__c') || objectName.trim().contains('__');

        String fullObjectName = isCustomObject ? cleanObject + '__c' : cleanObject;
        String fullFieldName  = cleanField + '__c';
        String fullApiName    = fullObjectName + '.' + cleanField + '__c';

        System.debug('Object API Name : ' + fullObjectName);
        System.debug('Field API Name  : ' + fullFieldName);
        System.debug('Metadata Full   : ' + fullApiName);

        String soql = 'SELECT Id, DeveloperName FROM CustomField ' +
              'WHERE DeveloperName = \'' + String.escapeSingleQuotes(cleanField) + '\' ' +
              'AND EntityDefinition.QualifiedApiName = \'' + String.escapeSingleQuotes(fullObjectName) + '\' ' +
              'LIMIT 1';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(TIMEOUT_LONG);

        HttpResponse res = http.send(req);

        System.debug('FIELD LOOKUP Status: ' + res.getStatusCode());
        System.debug('FIELD LOOKUP Body  : ' + res.getBody());

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Lookup failed for Field "' + fullFieldName + '" on "' + fullObjectName + '". HTTP '
                            + res.getStatusCode() + ': ' + parseErrorBody(res.getBody());
            return result;
        }

        List<Object> records = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('records');

        if (records == null || records.isEmpty()) {
            result.success = false;
            result.message = 'No Custom Field found: "' + fullFieldName + '" on "' + fullObjectName + '". ' +
                            'Check Object and Field DeveloperName (without __c).';
            return result;
        }

        System.debug('Field found: ' + fullApiName);

        CustomFieldSummary fieldCheck = getCustomFields(null);
        for (CustomFieldInfo fi : fieldCheck.allFields) {
            if (cleanField.equalsIgnoreCase(fi.name) && fullObjectName.equalsIgnoreCase(fi.objectName)) {
                DeleteResult blocked = checkSafetyBeforeDelete(fi.safetyStatus, fullApiName);
                if (blocked != null) return blocked;
                break;
            }
        }

        String sessionId         = null;
        String metadataServerUrl = null;

        try {
            SF_Credential__mdt cred = [
                SELECT Username__c, ConsumerKey__c, Certificate__c
                FROM SF_Credential__mdt
                WHERE DeveloperName = 'MetadataAdmin'
                LIMIT 1
            ];

            String header = EncodingUtil.base64Encode(Blob.valueOf('{"alg":"RS256","typ":"JWT"}'))
                .replace('+', '-').replace('/', '_').replace('=', '');

            Long   expTime = DateTime.now().addMinutes(JWT_EXPIRY_MIN).getTime() / 1000;
            String payload = EncodingUtil.base64Encode(Blob.valueOf(
                '{"iss":"' + cred.ConsumerKey__c + '",' +
                '"sub":"' + cred.Username__c + '",' +
                '"aud":"' + LOGIN_URL + '",' +
                '"exp":' + expTime + '}'
            )).replace('+', '-').replace('/', '_').replace('=', '');

            String signingInput   = header + '.' + payload;
            Blob   privateKeyBlob = EncodingUtil.base64Decode(cred.Certificate__c);
            Blob   signature      = Crypto.sign('RSA-SHA256', Blob.valueOf(signingInput), privateKeyBlob);

            String jwt = signingInput + '.' + EncodingUtil.base64Encode(signature)
                .replace('+', '-').replace('/', '_').replace('=', '');

            HttpRequest jwtReq = new HttpRequest();
            jwtReq.setEndpoint(LOGIN_URL + '/services/oauth2/token');
            jwtReq.setMethod('POST');
            jwtReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            jwtReq.setTimeout(TIMEOUT_SHORT);
            jwtReq.setBody(
                'grant_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8') +
                '&assertion='  + EncodingUtil.urlEncode(jwt, 'UTF-8')
            );

            HttpResponse jwtRes = http.send(jwtReq);
            System.debug('JWT Status: ' + jwtRes.getStatusCode());

            if (jwtRes.getStatusCode() == 200) {
                Map<String, Object> tokenMap  = (Map<String, Object>) JSON.deserializeUntyped(jwtRes.getBody());
                sessionId                     = (String) tokenMap.get('access_token');
                String instanceUrl            = (String) tokenMap.get('instance_url');
                metadataServerUrl             = instanceUrl + '/services/Soap/m/60.0';
                System.debug('JWT Access Token obtained: YES');
            }

        } catch (Exception ex) {
            System.debug('JWT Exception: ' + ex.getMessage());
        }

        if (String.isBlank(sessionId)) {
            try {
                sessionId         = UserInfo.getSessionId();
                metadataServerUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/60.0';
                System.debug('Fallback to UserInfo session: YES');
            } catch (Exception ex) {
                System.debug('UserInfo fallback failed: ' + ex.getMessage());
            }
        }

        if (String.isBlank(sessionId) || String.isBlank(metadataServerUrl)) {
            result.success = false;
            result.message = 'Could not retrieve session ID or metadata URL.';
            return result;
        }

        System.debug('Session ID resolved: YES');
        System.debug('Metadata URL: ' + metadataServerUrl);

        String soapBody =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            '                  xmlns:met="http://soap.sforce.com/2006/04/metadata">' +
            '  <soapenv:Header>' +
            '    <met:CallOptions><met:client>ApexDeletion</met:client></met:CallOptions>' +
            '    <met:SessionHeader>' +
            '      <met:sessionId>' + sessionId + '</met:sessionId>' +
            '    </met:SessionHeader>' +
            '  </soapenv:Header>' +
            '  <soapenv:Body>' +
            '    <met:deleteMetadata>' +
            '      <met:type>CustomField</met:type>' +
            '      <met:fullNames>' + fullApiName + '</met:fullNames>' +
            '    </met:deleteMetadata>' +
            '  </soapenv:Body>' +
            '</soapenv:Envelope>';

        HttpRequest del = new HttpRequest();
        del.setEndpoint(metadataServerUrl);
        del.setMethod('POST');
        del.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        del.setHeader('SOAPAction', '""');
        del.setTimeout(TIMEOUT_LONG);
        del.setBody(soapBody);

        HttpResponse dr = http.send(del);

        System.debug('SOAP DELETE Status: ' + dr.getStatusCode());
        System.debug('SOAP DELETE Body  : ' + dr.getBody());

        if (dr.getStatusCode() < 200 || dr.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'SOAP call failed. HTTP ' + dr.getStatusCode() + ': ' + dr.getBody();
            return result;
        }

        String body = dr.getBody();

        if (body.contains('<success>true</success>')) {
            result.success = true;
            result.message = 'Custom field "' + fullFieldName + '" on "' + fullObjectName +
                            '" permanently deleted successfully.';
        } else {
            String errorMsg = '';
            if (body.contains('<message>')) {
                errorMsg = body.substringBetween('<message>', '</message>');
            } else if (body.contains('<faultstring>')) {
                errorMsg = body.substringBetween('<faultstring>', '</faultstring>');
            } else {
                errorMsg = body;
            }
            result.success = false;
            result.message = 'Failed to delete "' + fullFieldName + '" on "' + fullObjectName + '": ' + errorMsg;
        }

        return result;
    }

    // ===============================
    // DELETE VALIDATION RULE BY OBJECT + RULE NAME
    // ===============================
    public static DeleteResult deleteValidationRuleByName(String objectName, String ruleName) {
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        // ── Reference check FIRST — VRs can be referenced by other metadata ──
        String vrRef = objectName.trim() + '.' + ruleName.trim();
        ReferenceResult vrRefs = getReferencesFor(vrRef, 'ValidationRule');
        if (vrRefs.hasReferences) {
            result.success = false;
            result.message = buildFormattedReport(vrRef, vrRefs.references, null, 'ValidationRule');
            return result;
        }

        String soql = 'SELECT Id FROM ValidationRule ' +
                      'WHERE ValidationName = \'' + String.escapeSingleQuotes(ruleName) + '\' ' +
                      'AND EntityDefinition.QualifiedApiName = \'' + String.escapeSingleQuotes(objectName) + '\' ' +
                      'LIMIT 1';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Lookup failed for VR "' + objectName + '.' + ruleName + '". HTTP ' + res.getStatusCode();
            return result;
        }

        List<Object> records = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('records');

        if (records == null || records.isEmpty()) {
            result.success = false;
            result.message = 'No Validation Rule found: ' + objectName + '.' + ruleName;
            return result;
        }

        String rId = (String)((Map<String, Object>) records[0]).get('Id');

        ValidationRuleSummary vrCheck = getValidationRules(null);
        List<ValidationRuleInfo> allVrs = new List<ValidationRuleInfo>();
        if (vrCheck.activeRules   != null) allVrs.addAll(vrCheck.activeRules);
        if (vrCheck.inactiveRules != null) allVrs.addAll(vrCheck.inactiveRules);
        for (ValidationRuleInfo vi : allVrs) {
            if (ruleName.equalsIgnoreCase(vi.name) && objectName.equalsIgnoreCase(vi.objectName)) {
                DeleteResult blocked = checkSafetyBeforeDelete(vi.safetyStatus, objectName + '.' + ruleName);
                if (blocked != null) return blocked;
                break;
            }
        }

        HttpRequest del = new HttpRequest();
        del.setEndpoint(BASE_URL + 'tooling/sobjects/ValidationRule/' + rId);
        del.setMethod('DELETE');
        del.setHeader('Content-Type', 'application/json');

        HttpResponse dr = http.send(del);

        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true;
            result.message = 'Validation Rule "' + objectName + '.' + ruleName + '" deleted.';
        } else {
            result.success = false;
            String errBody = dr.getBody();
            result.message = (errBody != null && (errBody.containsIgnoreCase('DEPENDENCY_EXISTS') || errBody.containsIgnoreCase('Referenced by')))
                ? parseDependencyError(objectName + '.' + ruleName, 'ValidationRule', errBody)
                : 'Failed to delete VR "' + objectName + '.' + ruleName + '". HTTP ' + dr.getStatusCode() + ': ' + errBody;
        }

        return result;
    }

    // ===============================
    // DELETE PERMISSION SET BY NAME
    // ===============================
    public static DeleteResult deletePermissionSetByName(String permSetName) {
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        // ── Reference check FIRST — catch any metadata depending on this PermSet ──
        ReferenceResult psRefs = getReferencesFor(permSetName, 'PermissionSet');
        if (psRefs.hasReferences) {
            result.success = false;
            result.message = buildFormattedReport(permSetName, psRefs.references, null, 'PermissionSet');
            return result;
        }

        // ── Active user assignment check — cannot delete if users are assigned ──
        Integer assignedCount = [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE PermissionSet.Name = :permSetName
            AND AssigneeId != null
        ];
        if (assignedCount > 0) {
            result.success = false;
            result.message = '🔒 Cannot delete Permission Set "' + permSetName + '" — it is assigned to ' +
                             assignedCount + ' user(s). Remove all assignments before deleting.';
            return result;
        }

        String      lookSoql = 'SELECT Id, Label FROM PermissionSet WHERE Name = \'' +
                               String.escapeSingleQuotes(permSetName) + '\' AND IsOwnedByProfile = false LIMIT 1';
        HttpRequest lReq     = new HttpRequest();
        lReq.setEndpoint(BASE_URL + 'query?q=' +
            EncodingUtil.urlEncode(lookSoql, 'UTF-8'));
        lReq.setMethod('GET');
        lReq.setHeader('Content-Type', 'application/json');

        HttpResponse lRes = http.send(lReq);

        if (lRes.getStatusCode() < 200 || lRes.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Lookup failed for PermSet "' + permSetName + '". HTTP ' + lRes.getStatusCode();
            return result;
        }

        List<Object> records = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(lRes.getBody())).get('records');

        if (records == null || records.isEmpty()) {
            result.success = false;
            result.message = 'No custom PermissionSet found: ' + permSetName;
            return result;
        }

        String psId    = (String)((Map<String, Object>) records[0]).get('Id');
        String psLabel = (String)((Map<String, Object>) records[0]).get('Label');

        PermissionSetSummary psCheck = getPermissionSets(null);
        for (PermissionSetInfo pi : psCheck.allPermSets) {
            if (permSetName.equalsIgnoreCase(pi.name)) {
                DeleteResult blocked = checkSafetyBeforeDelete(pi.safetyStatus, psLabel);
                if (blocked != null) return blocked;
                break;
            }
        }

        String      aSoql = 'SELECT Id FROM PermissionSetAssignment WHERE PermissionSetId = \'' + psId + '\'';
        HttpRequest aReq  = new HttpRequest();
        aReq.setEndpoint(BASE_URL + 'query?q=' +
            EncodingUtil.urlEncode(aSoql, 'UTF-8'));
        aReq.setMethod('GET');
        aReq.setHeader('Content-Type', 'application/json');

        HttpResponse aRes    = http.send(aReq);
        Integer      removed = 0;

        if (aRes.getStatusCode() >= 200 && aRes.getStatusCode() < 300) {
            List<Object> aRecs = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(aRes.getBody())).get('records');
            if (aRecs != null) {
                for (Object o : aRecs) {
                    String      aId   = (String)((Map<String, Object>) o).get('Id');
                    HttpRequest dAReq = new HttpRequest();
                    dAReq.setEndpoint(BASE_URL + 'sobjects/PermissionSetAssignment/' + aId);
                    dAReq.setMethod('DELETE');
                    dAReq.setHeader('Content-Type', 'application/json');

                    HttpResponse dARes = http.send(dAReq);
                    if (dARes.getStatusCode() == 204 || dARes.getStatusCode() == 200) {
                        removed++;
                    }
                }
            }
        }

        HttpRequest delReq = new HttpRequest();
        delReq.setEndpoint(BASE_URL + 'sobjects/PermissionSet/' + psId);
        delReq.setMethod('DELETE');
        delReq.setHeader('Content-Type', 'application/json');

        HttpResponse delRes = http.send(delReq);

        if (delRes.getStatusCode() == 204 || delRes.getStatusCode() == 200) {
            result.success = true;
            result.message = 'Permission Set "' + psLabel + '" deleted. ' + removed + ' assignment(s) removed.';
        } else {
            result.success = false;
            result.message = 'Failed to delete PermSet "' + permSetName + '". HTTP ' +
                              delRes.getStatusCode() + ': ' + delRes.getBody();
        }

        return result;
    }

    // ===============================
    // DEACTIVATE PROFILE
    // ===============================
    public static DeleteResult deactivateProfileByName(String profileName, String fallbackProfileName) {
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        // ── Reference check FIRST — catch metadata depending on this Profile ──
        ReferenceResult profRefs = getReferencesFor(profileName, 'Profile');
        if (profRefs.hasReferences) {
            result.success = false;
            result.message = buildFormattedReport(profileName, profRefs.references, null, 'Profile');
            return result;
        }

        // ── Active user check — cannot deactivate if users are still assigned ──
        Integer activeUserCount = [
            SELECT COUNT() FROM User
            WHERE ProfileId IN (SELECT Id FROM Profile WHERE Name = :profileName)
            AND IsActive = true
        ];
        if (activeUserCount > 0) {
            result.success = false;
            result.message = '🔒 Cannot deactivate Profile "' + profileName + '" — ' +
                             activeUserCount + ' active user(s) are assigned to it. ' +
                             'Reassign them to another profile before deactivating.';
            return result;
        }

        String      pSoql = 'SELECT Id FROM Profile WHERE Name = \'' +
                            String.escapeSingleQuotes(profileName) + '\' LIMIT 1';
        HttpRequest pReq  = new HttpRequest();
        pReq.setEndpoint(BASE_URL + 'query?q=' +
            EncodingUtil.urlEncode(pSoql, 'UTF-8'));
        pReq.setMethod('GET');
        pReq.setHeader('Content-Type', 'application/json');

        HttpResponse pRes = http.send(pReq);

        if (pRes.getStatusCode() < 200 || pRes.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Lookup failed for Profile "' + profileName + '". HTTP ' + pRes.getStatusCode();
            return result;
        }

        List<Object> pRecs = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(pRes.getBody())).get('records');

        if (pRecs == null || pRecs.isEmpty()) {
            result.success = false;
            result.message = 'Profile not found: ' + profileName;
            return result;
        }

        String profileId = (String)((Map<String, Object>) pRecs[0]).get('Id');

        ProfileSummary profCheck = getProfiles(null);
        for (ProfileInfo pi : profCheck.usedProfiles) {
            if (profileName.equalsIgnoreCase(pi.name)) {
                DeleteResult blocked = checkSafetyBeforeDelete(pi.safetyStatus, profileName);
                if (blocked != null) return blocked;
                break;
            }
        }
        for (ProfileInfo pi : profCheck.unusedProfiles) {
            if (profileName.equalsIgnoreCase(pi.name)) {
                DeleteResult blocked = checkSafetyBeforeDelete(pi.safetyStatus, profileName);
                if (blocked != null) return blocked;
                break;
            }
        }

        String      uSoql = 'SELECT Id FROM User WHERE ProfileId = \'' + profileId + '\' AND IsActive = true LIMIT 1';
        HttpRequest uReq  = new HttpRequest();
        uReq.setEndpoint(BASE_URL + 'query?q=' +
            EncodingUtil.urlEncode(uSoql, 'UTF-8'));
        uReq.setMethod('GET');
        uReq.setHeader('Content-Type', 'application/json');

        HttpResponse uRes  = http.send(uReq);
        Integer      moved = 0;

        if (uRes.getStatusCode() >= 200 && uRes.getStatusCode() < 300) {
            List<Object> uRecs = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(uRes.getBody())).get('records');

            if (uRecs != null && !uRecs.isEmpty()) {
                if (String.isBlank(fallbackProfileName)) {
                    result.success = false;
                    result.message = 'Profile "' + profileName + '" has active users. ' +
                                     'Please provide a fallback profile.\n' +
                                     'Example: deactivate profile ' + profileName + ' fallback StandardUser';
                    return result;
                }

                String      fSoql = 'SELECT Id FROM Profile WHERE Name = \'' +
                                    String.escapeSingleQuotes(fallbackProfileName) + '\' LIMIT 1';
                HttpRequest fReq  = new HttpRequest();
                fReq.setEndpoint(BASE_URL + 'query?q=' +
                    EncodingUtil.urlEncode(fSoql, 'UTF-8'));
                fReq.setMethod('GET');
                fReq.setHeader('Content-Type', 'application/json');

                HttpResponse fRes  = http.send(fReq);
                List<Object> fRecs = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(fRes.getBody())).get('records');

                if (fRecs == null || fRecs.isEmpty()) {
                    result.success = false;
                    result.message = 'Fallback Profile not found: ' + fallbackProfileName;
                    return result;
                }

                String fallbackId = (String)((Map<String, Object>) fRecs[0]).get('Id');

                String      allUSoql = 'SELECT Id FROM User WHERE ProfileId = \'' + profileId + '\' AND IsActive = true';
                HttpRequest allUReq  = new HttpRequest();
                allUReq.setEndpoint(BASE_URL + 'query?q=' +
                    EncodingUtil.urlEncode(allUSoql, 'UTF-8'));
                allUReq.setMethod('GET');
                allUReq.setHeader('Content-Type', 'application/json');

                HttpResponse allURes = http.send(allUReq);
                if (allURes.getStatusCode() >= 200 && allURes.getStatusCode() < 300) {
                    List<Object> allURecs = (List<Object>)((Map<String, Object>) JSON.deserializeUntyped(allURes.getBody())).get('records');
                    if (allURecs != null) {
                        for (Object o : allURecs) {
                            String      uid      = (String)((Map<String, Object>) o).get('Id');
                            HttpRequest patchReq = new HttpRequest();
                            patchReq.setEndpoint(BASE_URL + 'sobjects/User/' + uid);
                            patchReq.setMethod('PATCH');
                            patchReq.setHeader('Content-Type', 'application/json');
                            patchReq.setBody('{"ProfileId":"' + fallbackId + '"}');
                            HttpResponse patchRes = http.send(patchReq);
                            if (patchRes.getStatusCode() == 204 || patchRes.getStatusCode() == 200) moved++;
                        }
                    }
                }
            }
        }

        String sessionId         = null;
        String metadataServerUrl = null;

        try {
            SF_Credential__mdt cred = [
                SELECT Username__c, ConsumerKey__c, Certificate__c
                FROM SF_Credential__mdt
                WHERE DeveloperName = 'MetadataAdmin'
                LIMIT 1
            ];

            String header = EncodingUtil.base64Encode(Blob.valueOf('{"alg":"RS256","typ":"JWT"}'))
                .replace('+', '-').replace('/', '_').replace('=', '');

            Long   expTime = DateTime.now().addMinutes(JWT_EXPIRY_MIN).getTime() / 1000;
            String payload = EncodingUtil.base64Encode(Blob.valueOf(
                '{"iss":"' + cred.ConsumerKey__c + '",' +
                '"sub":"' + cred.Username__c + '",' +
                '"aud":"' + LOGIN_URL + '",' +
                '"exp":' + expTime + '}'
            )).replace('+', '-').replace('/', '_').replace('=', '');

            String signingInput   = header + '.' + payload;
            Blob   privateKeyBlob = EncodingUtil.base64Decode(cred.Certificate__c);
            Blob   signature      = Crypto.sign('RSA-SHA256', Blob.valueOf(signingInput), privateKeyBlob);

            String jwt = signingInput + '.' + EncodingUtil.base64Encode(signature)
                .replace('+', '-').replace('/', '_').replace('=', '');

            HttpRequest jwtReq = new HttpRequest();
            jwtReq.setEndpoint(LOGIN_URL + '/services/oauth2/token');
            jwtReq.setMethod('POST');
            jwtReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            jwtReq.setTimeout(TIMEOUT_SHORT);
            jwtReq.setBody(
                'grant_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8') +
                '&assertion='  + EncodingUtil.urlEncode(jwt, 'UTF-8')
            );

            HttpResponse jwtRes = http.send(jwtReq);
            if (jwtRes.getStatusCode() == 200) {
                Map<String, Object> tokenMap = (Map<String, Object>) JSON.deserializeUntyped(jwtRes.getBody());
                sessionId         = (String) tokenMap.get('access_token');
                metadataServerUrl = (String) tokenMap.get('instance_url') + '/services/Soap/m/60.0';
            }
        } catch (Exception ex) {
            System.debug('JWT Exception: ' + ex.getMessage());
        }

        if (String.isBlank(sessionId)) {
            try {
                sessionId         = UserInfo.getSessionId();
                metadataServerUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/60.0';
            } catch (Exception ex) {
                System.debug('UserInfo fallback failed: ' + ex.getMessage());
            }
        }

        if (String.isBlank(sessionId) || String.isBlank(metadataServerUrl)) {
            result.success = false;
            result.message = 'Could not retrieve session ID or metadata URL.';
            return result;
        }

        String soapBody =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            '                  xmlns:met="http://soap.sforce.com/2006/04/metadata">' +
            '  <soapenv:Header>' +
            '    <met:CallOptions><met:client>ApexDeletion</met:client></met:CallOptions>' +
            '    <met:SessionHeader>' +
            '      <met:sessionId>' + sessionId + '</met:sessionId>' +
            '    </met:SessionHeader>' +
            '  </soapenv:Header>' +
            '  <soapenv:Body>' +
            '    <met:deleteMetadata>' +
            '      <met:type>Profile</met:type>' +
            '      <met:fullNames>' + profileName + '</met:fullNames>' +
            '    </met:deleteMetadata>' +
            '  </soapenv:Body>' +
            '</soapenv:Envelope>';

        HttpRequest delReq = new HttpRequest();
        delReq.setEndpoint(metadataServerUrl);
        delReq.setMethod('POST');
        delReq.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        delReq.setHeader('SOAPAction', '""');
        delReq.setTimeout(TIMEOUT_LONG);
        delReq.setBody(soapBody);

        HttpResponse delRes = http.send(delReq);

        if (delRes.getStatusCode() < 200 || delRes.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'SOAP call failed. HTTP ' + delRes.getStatusCode() + ': ' + delRes.getBody();
            return result;
        }

        String body = delRes.getBody();

        if (body.contains('<success>true</success>')) {
            result.success = true;
            result.message = 'Profile "' + profileName + '" has been successfully deleted.' +
                             (moved > 0 ? ' ' + moved + ' user(s) moved to "' + fallbackProfileName + '".' : '');
        } else {
            String errorMsg = '';
            if (body.contains('<message>')) {
                errorMsg = body.substringBetween('<message>', '</message>');
            } else if (body.contains('<faultstring>')) {
                errorMsg = body.substringBetween('<faultstring>', '</faultstring>');
            } else {
                errorMsg = body;
            }
            result.success = false;
            result.message = 'Failed to delete profile "' + profileName + '": ' + errorMsg;
        }

        return result;
    }

    // ── Helper: Base64 URL Encode ──────────────────────────────

    // ═══════════════════════════════════════════════════════════════
    // EXTENDED REFERENCE CHECKS — Missing categories added
    // Covers: Dynamic Apex, Parent-child LWC, Experience Cloud,
    //         JS Remoting, Field-level deps, Sharing Rules,
    //         Workflow/Process Builder/Approval, Connected Apps,
    //         Reports/Dashboards, VF Pages, Test class refs,
    //         Interface/extends detection, Static resources
    // ═══════════════════════════════════════════════════════════════

    // ── Wrapper for extended reference results ────────────────────
    public class ExtendedReferenceResult {
        @AuraEnabled public String       componentName;
        @AuraEnabled public List<String> dynamicApexWarnings;       // Type.forName / JSON.deserialize hits
        @AuraEnabled public List<String> lwcParentChildRefs;        // c-tag usage in LWC templates
        @AuraEnabled public List<String> experienceCloudRefs;       // ExperienceBundle MCD hits
        @AuraEnabled public List<String> jsRemotingRefs;            // VF pages with @RemoteAction
        @AuraEnabled public List<String> fieldValidationRuleRefs;   // Validation rules using field
        @AuraEnabled public List<String> fieldFormulaRefs;          // Formula fields referencing field
        @AuraEnabled public List<String> fieldReportRefs;           // Reports using field (MCD)
        @AuraEnabled public List<String> sharingRuleRefs;           // Sharing rules on object
        @AuraEnabled public List<String> workflowRuleRefs;          // WorkflowRule MCD hits
        @AuraEnabled public List<String> processBuilderRefs;        // ProcessDefinition MCD hits
        @AuraEnabled public List<String> approvalProcessRefs;       // ApprovalProcess MCD hits
        @AuraEnabled public List<String> connectedAppRefs;          // ConnectedApp MCD hits
        @AuraEnabled public List<String> reportDashboardRefs;       // Report/Dashboard MCD hits
        @AuraEnabled public List<String> vfPageRefs;                // ApexPage MCD hits
        @AuraEnabled public List<String> testClassRefs;             // @isTest classes referencing this
        @AuraEnabled public List<String> interfaceImplementors;     // Classes that implement/extend this
        @AuraEnabled public List<String> staticResourceRefs;        // StaticResource MCD hits
        @AuraEnabled public List<String> warningNotes;
    }

    // ── 1. Dynamic Apex detection (body scan) ────────────────────
    // Scans all ApexClass bodies for Type.forName(), JSON.deserialize(),
    // Database.query(), and string-based class references.
    @AuraEnabled
    public static List<String> getDynamicApexReferences(String targetClassName) {
        List<String> hits = new List<String>();
        if (String.isBlank(targetClassName)) return hits;
        String lowerTarget = targetClassName.toLowerCase();
        try {
            List<ApexClass> classes = [
                SELECT Name, Body FROM ApexClass
                WHERE NamespacePrefix = null
                LIMIT 500
            ];
            for (ApexClass ac : classes) {
                if (ac.Name.equalsIgnoreCase(targetClassName)) continue;
                String body = ac.Body == null ? '' : ac.Body.toLowerCase();
                Boolean hasTypeForName   = body.contains('type.forname(') &&
                                           body.contains('\'' + lowerTarget + '\'');
                Boolean hasJsonDeser     = body.contains('json.deserialize') &&
                                           body.contains(lowerTarget + '.class');
                Boolean hasDbQuery       = body.contains('database.query(') &&
                                           body.contains(lowerTarget);
                Boolean hasStringRef     = body.contains('\'' + lowerTarget + '\'') &&
                                           (body.contains('type.forname') || body.contains('apexclassid'));
                if (hasTypeForName || hasJsonDeser || hasDbQuery || hasStringRef) {
                    String reason = hasTypeForName ? 'Type.forName()' :
                                    hasJsonDeser   ? 'JSON.deserialize()' :
                                    hasDbQuery     ? 'Database.query()' : 'string reference';
                    hits.add(ac.Name + ' [' + reason + ']');
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getDynamicApexReferences failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 2. Test class references ─────────────────────────────────
    // Finds @isTest classes that reference targetClassName in their body.
    @AuraEnabled
    public static List<String> getTestClassReferences(String targetClassName) {
        List<String> hits = new List<String>();
        if (String.isBlank(targetClassName)) return hits;
        String lowerTarget = targetClassName.toLowerCase();
        try {
            List<ApexClass> testClasses = [
                SELECT Name, Body FROM ApexClass
                WHERE NamespacePrefix = null
                LIMIT 500
            ];
            for (ApexClass ac : testClasses) {
                String body = ac.Body == null ? '' : ac.Body.toLowerCase();
                if (!body.contains('@istest')) continue;
                if (body.contains(lowerTarget)) {
                    hits.add(ac.Name);
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getTestClassReferences failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 3. Interface / extends detection ─────────────────────────
    // Finds classes that implement or extend targetClassName.
    @AuraEnabled
    public static List<String> getInterfaceImplementors(String targetClassName) {
        List<String> hits = new List<String>();
        if (String.isBlank(targetClassName)) return hits;
        String lower = targetClassName.toLowerCase();
        try {
            List<ApexClass> classes = [
                SELECT Name, Body FROM ApexClass
                WHERE NamespacePrefix = null
                LIMIT 500
            ];
            for (ApexClass ac : classes) {
                if (ac.Name.equalsIgnoreCase(targetClassName)) continue;
                String body = ac.Body == null ? '' : ac.Body.toLowerCase();
                // Look for "implements TargetClass" or "extends TargetClass"
                Boolean isImpl = body.contains('implements ' + lower) ||
                                 body.contains('implements ' + lower + ',') ||
                                 body.contains(', ' + lower + ' {') ||
                                 body.contains(', ' + lower + '{');
                Boolean isExt  = body.contains('extends ' + lower);
                if (isImpl || isExt) {
                    hits.add(ac.Name + (isExt ? ' [extends]' : ' [implements]'));
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getInterfaceImplementors failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 4. Parent-child LWC references ───────────────────────────
    // Scans LWC HTML templates for <c-targetComponent> tag usage.
    @AuraEnabled
    public static List<String> getLwcParentChildReferences(String targetLwcName) {
        List<String> hits = new List<String>();
        if (String.isBlank(targetLwcName)) return hits;
        // LWC component names in HTML use kebab-case
        String kebab = targetLwcName.replaceAll('([A-Z])', '-$1').toLowerCase();
        if (kebab.startsWith('-')) kebab = kebab.substring(1);
        String searchTag = '<c-' + kebab;
        Http http = new Http();
        try {
            // Fetch all LWC source files (HTML templates)
            String soql = 'SELECT LightningComponentBundle.DeveloperName, FilePath, Source ' +
                          'FROM LightningComponentResource ' +
                          'WHERE FilePath LIKE \'%.html\' ' +
                          'ORDER BY LightningComponentBundle.DeveloperName';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              source = (String) row.get('Source');
                        Map<String, Object> bundle = (Map<String, Object>) row.get('LightningComponentBundle');
                        String              bName  = bundle != null ? (String) bundle.get('DeveloperName') : 'Unknown';
                        if (source != null && source.toLowerCase().contains(searchTag)) {
                            hits.add(bName);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getLwcParentChildReferences failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 5. Sharing rule references for an object ─────────────────
    // Uses MCD to find SharingRule components referencing the object.
    @AuraEnabled
    public static List<String> getSharingRuleReferences(String objectName) {
        List<String> hits = new List<String>();
        if (String.isBlank(objectName)) return hits;
        Http http = new Http();
        try {
            String soql = 'SELECT MetadataComponentName, MetadataComponentType ' +
                          'FROM MetadataComponentDependency ' +
                          'WHERE RefMetadataComponentType = \'CustomObject\' ' +
                          'AND MetadataComponentType IN (\'SharingCriteriaRule\', \'SharingOwnerRule\', ' +
                          '\'SharingGuestRule\', \'SharingTerritoryRule\')';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        String              cType = (String) row.get('MetadataComponentType');
                        if (String.isNotBlank(cName) && cName.toLowerCase().startsWith(objectName.toLowerCase())) {
                            hits.add(cName + ' [' + cType + ']');
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getSharingRuleReferences failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 6. Workflow / Process Builder / Approval Process refs ────
    @AuraEnabled
    public static List<String> getAutomationReferences(String componentName, String componentType) {
        List<String> hits = new List<String>();
        if (String.isBlank(componentName)) return hits;
        Http http = new Http();
        try {
            String soql = 'SELECT MetadataComponentName, MetadataComponentType ' +
                          'FROM MetadataComponentDependency ' +
                          'WHERE MetadataComponentType IN (' +
                          '\'WorkflowRule\', \'WorkflowFieldUpdate\', \'WorkflowAlert\', ' +
                          '\'ProcessDefinition\', \'ApprovalProcess\', \'EscalationRule\', ' +
                          '\'AssignmentRule\', \'AutoResponseRule\') ' +
                          'AND RefMetadataComponentType = \'' + String.escapeSingleQuotes(componentType) + '\'';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        String              cType = (String) row.get('MetadataComponentType');
                        if (String.isNotBlank(cName)) {
                            hits.add(cName + ' [' + cType + ']');
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getAutomationReferences failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 7. Connected App references ──────────────────────────────
    @AuraEnabled
    public static List<String> getConnectedAppReferences(String componentName, String componentType) {
        List<String> hits = new List<String>();
        if (String.isBlank(componentName)) return hits;
        Http http = new Http();
        try {
            String soql = 'SELECT MetadataComponentName, MetadataComponentType ' +
                          'FROM MetadataComponentDependency ' +
                          'WHERE MetadataComponentType = \'ConnectedApp\' ' +
                          'AND RefMetadataComponentType = \'' + String.escapeSingleQuotes(componentType) + '\'';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        if (String.isNotBlank(cName)) hits.add(cName);
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getConnectedAppReferences failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 8. Report / Dashboard references ─────────────────────────
    // Uses MCD to find Report and Dashboard metadata depending on a component.
    @AuraEnabled
    public static List<String> getReportAndDashboardReferences(String componentName, String componentType) {
        List<String> hits = new List<String>();
        if (String.isBlank(componentName)) return hits;
        Http http = new Http();
        try {
            String soql = 'SELECT MetadataComponentName, MetadataComponentType ' +
                          'FROM MetadataComponentDependency ' +
                          'WHERE MetadataComponentType IN (\'Report\', \'Dashboard\', \'ReportType\') ' +
                          'AND RefMetadataComponentType = \'' + String.escapeSingleQuotes(componentType) + '\'';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        String              cType = (String) row.get('MetadataComponentType');
                        if (String.isNotBlank(cName)) hits.add(cName + ' [' + cType + ']');
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getReportAndDashboardReferences failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 9. Visualforce page references ───────────────────────────
    // Finds VF pages using an Apex class as controller or extension,
    // and scans for JS remoting (@RemoteAction).
    @AuraEnabled
    public static List<String> getVisualforceReferences(String targetClassName) {
        List<String> hits       = new List<String>();
        List<String> remoteHits = new List<String>();
        if (String.isBlank(targetClassName)) return hits;
        Http http = new Http();
        try {
            // MCD: VF pages/components depending on this Apex class
            String mcdSoql = 'SELECT MetadataComponentName, MetadataComponentType ' +
                             'FROM MetadataComponentDependency ' +
                             'WHERE MetadataComponentType IN (\'ApexPage\', \'ApexComponent\') ' +
                             'AND RefMetadataComponentType = \'ApexClass\'';
            HttpRequest mcdReq = new HttpRequest();
            mcdReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(mcdSoql, 'UTF-8'));
            mcdReq.setMethod('GET');
            mcdReq.setHeader('Content-Type', 'application/json');
            mcdReq.setTimeout(TIMEOUT_LONG);
            HttpResponse mcdRes = http.send(mcdReq);
            if (mcdRes.getStatusCode() >= 200 && mcdRes.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(mcdRes.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        String              cType = (String) row.get('MetadataComponentType');
                        if (String.isNotBlank(cName)) hits.add(cName + ' [' + cType + ']');
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getVisualforceReferences MCD failed: ' + ex.getMessage());
        }
        // Scan VF page markup for JS Remoting usage (@RemoteAction class references)
        try {
            String pageSoql = 'SELECT Name, Markup FROM ApexPage WHERE NamespacePrefix = null LIMIT 200';
            HttpRequest pgReq = new HttpRequest();
            pgReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(pageSoql, 'UTF-8'));
            pgReq.setMethod('GET');
            pgReq.setHeader('Content-Type', 'application/json');
            pgReq.setTimeout(TIMEOUT_LONG);
            HttpResponse pgRes = http.send(pgReq);
            if (pgRes.getStatusCode() >= 200 && pgRes.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(pgRes.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              pgName = (String) row.get('Name');
                        String              markup = (String) row.get('Markup');
                        if (markup != null && markup.toLowerCase().contains(targetClassName.toLowerCase() + '.')) {
                            String label = pgName + ' [JS Remoting]';
                            if (!hits.contains(pgName + ' [ApexPage]') && !hits.contains(label)) {
                                hits.add(label);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getVisualforceReferences page scan failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 10. LWC in Experience Cloud / Utility Bar ─────────────────
    // Scans ExperienceBundle and AppPage FlexiPage metadata for LWC references.
    @AuraEnabled
    public static List<String> getExperienceCloudReferences(String lwcName) {
        List<String> hits = new List<String>();
        if (String.isBlank(lwcName)) return hits;
        String lowerName = lwcName.toLowerCase();
        Http http = new Http();
        try {
            // Query FlexiPage metadata for App Pages and Experience pages
            String soql = 'SELECT DeveloperName, Type, Metadata FROM FlexiPage ' +
                          'WHERE Type IN (\'AppPage\', \'CommApp\', \'CommFlex\', ' +
                          '\'UtilityBar\', \'NavMenu\') LIMIT 300';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              devName = (String) row.get('DeveloperName');
                        String              fpType  = (String) row.get('Type');
                        Object              meta    = row.get('Metadata');
                        String              metaStr = meta != null ? JSON.serialize(meta).toLowerCase() : '';
                        if (metaStr.contains(lowerName)) {
                            hits.add(devName + ' [' + fpType + ']');
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getExperienceCloudReferences failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 11. Field-level references: Validation Rules & Formulas ──
    // Finds Validation Rules and Formula fields that reference a given field.
    @AuraEnabled
    public static List<String> getFieldDependencyReferences(String objectName, String fieldName) {
        List<String> hits = new List<String>();
        if (String.isBlank(objectName) || String.isBlank(fieldName)) return hits;
        String searchToken = fieldName.toLowerCase();
        Http http = new Http();
        // Validation Rules
        try {
            String soql = 'SELECT Id, ValidationName, ErrorConditionFormula ' +
                          'FROM ValidationRule WHERE EntityDefinition.QualifiedApiName = \'' +
                          String.escapeSingleQuotes(objectName) + '\' LIMIT 200';
            List<SObject> rules = Database.query(soql);
            for (SObject rule : rules) {
                String formula = (String) rule.get('ErrorConditionFormula');
                if (formula != null && formula.toLowerCase().contains(searchToken)) {
                    hits.add((String) rule.get('ValidationName') + ' [ValidationRule]');
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getFieldDependencyReferences VR failed: ' + ex.getMessage());
        }
        // Formula fields via MCD
        try {
            String soql2 = 'SELECT MetadataComponentName, MetadataComponentType ' +
                           'FROM MetadataComponentDependency ' +
                           'WHERE RefMetadataComponentType = \'CustomField\' ' +
                           'AND MetadataComponentType = \'CustomField\'';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql2, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              cName = (String) row.get('MetadataComponentName');
                        if (String.isNotBlank(cName) && cName.toLowerCase().contains(searchToken)) {
                            hits.add(cName + ' [FormulaField]');
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getFieldDependencyReferences formula MCD failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 12. Static resource references ───────────────────────────
    // Finds LWC, Aura, and VF files importing a named static resource.
    @AuraEnabled
    public static List<String> getStaticResourceReferences(String resourceName) {
        List<String> hits = new List<String>();
        if (String.isBlank(resourceName)) return hits;
        String lower = resourceName.toLowerCase();
        Http http = new Http();
        // LWC JS files
        try {
            String soql = 'SELECT LightningComponentBundle.DeveloperName, FilePath, Source ' +
                          'FROM LightningComponentResource ' +
                          'WHERE FilePath LIKE \'%.js\' LIMIT 500';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_LONG);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              source = (String) row.get('Source');
                        Map<String, Object> bundle = (Map<String, Object>) row.get('LightningComponentBundle');
                        String              bName  = bundle != null ? (String) bundle.get('DeveloperName') : 'Unknown';
                        if (source != null && source.toLowerCase().contains(lower)) {
                            hits.add(bName + ' [LWC]');
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getStaticResourceReferences LWC failed: ' + ex.getMessage());
        }
        // Aura components
        try {
            String auraSoql = 'SELECT AuraDefinitionBundle.DeveloperName, Source, DefType ' +
                              'FROM AuraDefinition WHERE DefType IN (\'COMPONENT\', \'APPLICATION\', \'CONTROLLER\', \'HELPER\') LIMIT 400';
            HttpRequest aReq = new HttpRequest();
            aReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(auraSoql, 'UTF-8'));
            aReq.setMethod('GET');
            aReq.setHeader('Content-Type', 'application/json');
            aReq.setTimeout(TIMEOUT_LONG);
            HttpResponse aRes = http.send(aReq);
            if (aRes.getStatusCode() >= 200 && aRes.getStatusCode() < 300) {
                Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(aRes.getBody());
                List<Object>        records = (List<Object>) body.get('records');
                if (records != null) {
                    for (Object r : records) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              source = (String) row.get('Source');
                        Map<String, Object> bundle = (Map<String, Object>) row.get('AuraDefinitionBundle');
                        String              bName  = bundle != null ? (String) bundle.get('DeveloperName') : 'Unknown';
                        if (source != null && source.toLowerCase().contains(lower)) {
                            hits.add(bName + ' [Aura]');
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'getStaticResourceReferences Aura failed: ' + ex.getMessage());
        }
        return hits;
    }

    // ── 13. Full extended reference check (aggregates all above) ─
    @AuraEnabled
    public static ExtendedReferenceResult getExtendedReferencesFor(
            String componentName, String componentType, String objectContext) {
        ExtendedReferenceResult result     = new ExtendedReferenceResult();
        result.componentName               = componentName;
        result.dynamicApexWarnings         = new List<String>();
        result.lwcParentChildRefs          = new List<String>();
        result.experienceCloudRefs         = new List<String>();
        result.jsRemotingRefs              = new List<String>();
        result.fieldValidationRuleRefs     = new List<String>();
        result.fieldFormulaRefs            = new List<String>();
        result.fieldReportRefs             = new List<String>();
        result.sharingRuleRefs             = new List<String>();
        result.workflowRuleRefs            = new List<String>();
        result.processBuilderRefs          = new List<String>();
        result.approvalProcessRefs         = new List<String>();
        result.connectedAppRefs            = new List<String>();
        result.reportDashboardRefs         = new List<String>();
        result.vfPageRefs                  = new List<String>();
        result.testClassRefs               = new List<String>();
        result.interfaceImplementors       = new List<String>();
        result.staticResourceRefs          = new List<String>();
        result.warningNotes                = new List<String>();

        if ('ApexClass'.equalsIgnoreCase(componentType)) {
            result.dynamicApexWarnings   = getDynamicApexReferences(componentName);
            result.testClassRefs         = getTestClassReferences(componentName);
            result.interfaceImplementors = getInterfaceImplementors(componentName);
            result.vfPageRefs            = getVisualforceReferences(componentName);
            result.connectedAppRefs      = getConnectedAppReferences(componentName, componentType);
            result.reportDashboardRefs   = getReportAndDashboardReferences(componentName, componentType);
            result.workflowRuleRefs      = getAutomationReferences(componentName, componentType);
        }
        if ('LightningComponentBundle'.equalsIgnoreCase(componentType)) {
            result.lwcParentChildRefs    = getLwcParentChildReferences(componentName);
            result.experienceCloudRefs   = getExperienceCloudReferences(componentName);
            result.staticResourceRefs    = getStaticResourceReferences(componentName);
        }
        if ('CustomObject'.equalsIgnoreCase(componentType)) {
            result.sharingRuleRefs       = getSharingRuleReferences(componentName);
            result.workflowRuleRefs      = getAutomationReferences(componentName, componentType);
            result.approvalProcessRefs   = getAutomationReferences(componentName, 'ApprovalProcess');
            result.reportDashboardRefs   = getReportAndDashboardReferences(componentName, componentType);
        }
        if ('CustomField'.equalsIgnoreCase(componentType) && String.isNotBlank(objectContext)) {
            result.fieldValidationRuleRefs = getFieldDependencyReferences(objectContext, componentName);
            result.fieldReportRefs         = getReportAndDashboardReferences(componentName, componentType);
        }
        if ('StaticResource'.equalsIgnoreCase(componentType)) {
            result.staticResourceRefs = getStaticResourceReferences(componentName);
        }
        result.warningNotes.add('⚠️ Dynamic Apex (Type.forName, JSON.deserialize, string-based) uses body scan — verify manually.');
        result.warningNotes.add('⚠️ Experience Cloud refs depend on FlexiPage metadata availability.');
        return result;
    }

    private static String base64UrlEncode(Blob input) {
        return EncodingUtil.base64Encode(input)
            .replace('+', '-')
            .replace('/', '_')
            .replace('=', '');
    }

    // ── Parses Salesforce REST error response body ─────────────
    private static String parseErrorBody(String body) {
        if (String.isBlank(body)) return 'No error details returned.';

        try {
            List<Object> errors = (List<Object>) JSON.deserializeUntyped(body);
            List<String> messages = new List<String>();
            for (Object err : errors) {
                Map<String, Object> errMap = (Map<String, Object>) err;
                String code = (String) errMap.get('errorCode');
                String msg  = (String) errMap.get('message');
                messages.add((code != null ? '[' + code + '] ' : '') + (msg != null ? msg : ''));
            }
            return String.join(messages, ' | ');
        } catch (Exception e) {
            return body;
        }
    }
}