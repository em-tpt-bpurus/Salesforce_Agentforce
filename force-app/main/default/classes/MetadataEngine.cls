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

        String soql = 'SELECT Label, ApiName, IsActive, ProcessType, NamespacePrefix ' +
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

                    String flowLabel = label + ' [' + procType + '] (' + apiName + ')' +
                                       (String.isNotBlank(nsPrefix) ? ' [ns:' + nsPrefix + ']' : '');

                    MetadataEngine.FlowInfo fi = new MetadataEngine.FlowInfo();
                    fi.apiName        = apiName;
                    fi.label          = label;
                    fi.processType    = procType;
                    fi.isActive       = isActive;
                    fi.namespacePrefix = nsPrefix;
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
            String depSoql = 'SELECT RefMetadataComponentName FROM MetadataComponentDependency ' +
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
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              refName = (String) row.get('RefMetadataComponentName');
                        if (String.isNotBlank(refName)) subflowRefs.add(refName.toLowerCase());
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'subflow check failed — continue: ' + ex.getMessage()); }

        for (MetadataEngine.FlowInfo fi : allFlowObjects) {
            Boolean isManaged   = String.isNotBlank(fi.namespacePrefix);
            Boolean isSubflow   = subflowRefs.contains((fi.apiName != null ? fi.apiName : '').toLowerCase());
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
            block.message = '🚫 Blocked: "' + componentLabel + '" belongs to a managed package and cannot be deleted from this org.';
            return block;
        }
        if (s == 'ENTRY_POINT') {
            block.success = false;
            block.message = '🚫 Blocked: "' + componentLabel + '" is an entry point (custom tab or top-level app) and is actively in use.';
            return block;
        }
        if (s == 'IN_USE') {
            block.success = false;
            block.message = '🚫 Blocked: "' + componentLabel + '" is currently in use (referenced by another component, flow, or active user). Remove all references first.';
            return block;
        }
        if (s == 'SYSTEM') {
            block.success = false;
            block.message = '🚫 Blocked: "' + componentLabel + '" is a system profile and cannot be deleted.';
            return block;
        }
        if (s == 'HAS_DATA') {
            block.success = false;
            block.message = '🚫 Blocked: "' + componentLabel + '" contains data records or populated field values. Deleting it will permanently destroy that data. Remove or migrate all data first, then retry.';
            return block;
        }
        return null;
    }
    // ===============================
    // DELETE FLOW BY API NAME
    // ===============================
    public static DeleteResult deleteFlowByApiName(String apiName) {
        // ── Reference check FIRST — before production guard ──
        ReferenceResult flowRefs = getReferencesFor(apiName, 'Flow');
        if (flowRefs.hasReferences) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;
            String msg = '\U0001f6ab Cannot delete "' + apiName + '" \u2014 it is referenced by ' + flowRefs.referenceCount + ' component(s).\n\n';
            msg += '\U0001f4cb REFERENCES BLOCKING DELETE (' + flowRefs.referenceCount + ' found):\n';
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            Integer flowIdx = 1;
            for (ReferenceItem ref : flowRefs.references) {
                msg += flowIdx++ + '. ' + ref.name + '\n';
                msg += '   Type         : ' + ref.type + '\n';
                msg += '   Relationship : ' + ref.relationship + '\n\n';
            }
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            msg += '\U0001f4a1 Remove "' + apiName + '" from the above component(s) first, then retry.';
            blocked.message = msg;
            return blocked;
        }

        // ── Production guard \u2014 only fires if no references block ──
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();


        String lookupSoql = 'SELECT Id, DurableId, Label, ApiName, IsActive ' +
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

        Map<String, Object> flowDef   = (Map<String, Object>) lookupRecords[0];
        String              durableId = (String)  flowDef.get('DurableId');
        Boolean             isActive  = (Boolean) flowDef.get('IsActive');
        String              flowLabel = (String)  flowDef.get('Label');

        FlowSummary flowCheck = getFlows(null);
        for (FlowInfo fi : flowCheck.allFlowObjects) {
            if (apiName.equalsIgnoreCase(fi.apiName)) {
                DeleteResult blocked = checkSafetyBeforeDelete(fi.safetyStatus, flowLabel);
                if (blocked != null) return blocked;
                break;
            }
        }

        if (isActive) {
            HttpRequest deactivateReq = new HttpRequest();
            deactivateReq.setEndpoint(BASE_URL + 'tooling/sobjects/FlowDefinition/' + durableId);
            deactivateReq.setMethod('PATCH');
            deactivateReq.setHeader('Content-Type', 'application/json');
            deactivateReq.setBody('{"Metadata": {"activeVersionNumber": 0}}');

            HttpResponse deactivateRes = http.send(deactivateReq);

            if (deactivateRes.getStatusCode() != 204 && deactivateRes.getStatusCode() != 200) {
                result.success = false;
                result.message = 'Flow "' + flowLabel + '" could not be deactivated. HTTP ' +
                                  deactivateRes.getStatusCode() + ': ' + deactivateRes.getBody();
                return result;
            }
        }

        String versionSoql = 'SELECT Id FROM Flow WHERE DefinitionId = \'' + durableId + '\'';

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

        List<String> failedVersions = new List<String>();

        for (Object vObj : versionRecords) {
            Map<String, Object> vRec      = (Map<String, Object>) vObj;
            String              versionId = (String) vRec.get('Id');

            HttpRequest deleteReq = new HttpRequest();
            deleteReq.setEndpoint(BASE_URL + 'tooling/sobjects/Flow/' + versionId);
            deleteReq.setMethod('DELETE');
            deleteReq.setHeader('Content-Type', 'application/json');

            HttpResponse deleteRes = http.send(deleteReq);

            if (deleteRes.getStatusCode() != 204 && deleteRes.getStatusCode() != 200) {
                failedVersions.add(versionId);
            }
        }

        if (!failedVersions.isEmpty()) {
            result.success = false;
            result.message = 'Flow "' + flowLabel + '" — ' +
                             (versionRecords.size() - failedVersions.size()) + ' version(s) deleted, ' +
                             failedVersions.size() + ' version(s) failed: ' + String.join(failedVersions, ', ');
        } else {
            result.success = true;
            result.message = 'Flow "' + flowLabel + '" (' + apiName + ') and all ' +
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
            DeleteResult r = deleteFlowByApiName(apiName.trim());
            if (r.success) {
                mass.successCount++;
                mass.succeeded.add(apiName.trim());
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

        String      countSoql = 'SELECT Id FROM ApexClass';
        HttpRequest countReq  = new HttpRequest();
        countReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(countSoql, 'UTF-8'));
        countReq.setMethod('GET');
        countReq.setHeader('Content-Type', 'application/json');

        HttpResponse countRes  = http.send(countReq);
        Integer      trueTotal = 0;

        if (countRes.getStatusCode() >= 200 && countRes.getStatusCode() < 300) {
            Map<String, Object> countResponse =
                (Map<String, Object>) JSON.deserializeUntyped(countRes.getBody());
            Object totalSize = countResponse.get('totalSize');
            if (totalSize != null) {
                trueTotal = Integer.valueOf(String.valueOf(totalSize));
            }
        }

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

        String      depSoql = 'SELECT RefMetadataComponentName, RefMetadataComponentType ' +
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
                    Map<String, Object> rec     = (Map<String, Object>) obj;
                    String              refName = (String) rec.get('RefMetadataComponentName');
                    if (String.isNotBlank(refName)) {
                        referencedNames.add(refName);
                    }
                }
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

        Set<String> invocableClasses   = new Set<String>();
        Set<String> auraEnabledClasses = new Set<String>();
        try {
            String annSoql = 'SELECT Id, Name, SymbolTable FROM ApexClass WHERE NamespacePrefix = null';
            HttpRequest annReq = new HttpRequest();
            annReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(annSoql, 'UTF-8'));
            annReq.setMethod('GET');
            annReq.setHeader('Content-Type', 'application/json');
            HttpResponse annRes = http.send(annReq);
            if (annRes.getStatusCode() >= 200 && annRes.getStatusCode() < 300) {
                Map<String, Object> annBody    = (Map<String, Object>) JSON.deserializeUntyped(annRes.getBody());
                List<Object>        annRecords = (List<Object>) annBody.get('records');
                if (annRecords != null) {
                    for (Object r : annRecords) {
                        Map<String, Object> rec = (Map<String, Object>) r;
                        String clsName = (String) rec.get('Name');
                        Object stObj   = rec.get('SymbolTable');
                        if (stObj == null || clsName == null) continue;
                        Map<String, Object> st      = (Map<String, Object>) stObj;
                        List<Object>        methods = (List<Object>) st.get('methods');
                        if (methods == null) continue;
                        for (Object mObj : methods) {
                            Map<String, Object> m    = (Map<String, Object>) mObj;
                            List<Object>        anns = (List<Object>) m.get('annotations');
                            if (anns == null) continue;
                            for (Object aObj : anns) {
                                Map<String, Object> ann  = (Map<String, Object>) aObj;
                                String              aName = (String) ann.get('name');
                                if ('InvocableMethod'.equalsIgnoreCase(aName)) invocableClasses.add(clsName);
                                if ('AuraEnabled'.equalsIgnoreCase(aName))     auraEnabledClasses.add(clsName);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'annotation scan failed — continue: ' + ex.getMessage()); }

        for (String clsName : allClassMap.keySet()) {
            ApexClassInfo info   = allClassMap.get(clsName);
            Boolean isManaged    = String.isNotBlank(info.namespacePrefix);
            Boolean isTest       = clsName.endsWith('Test') || clsName.endsWith('Tests');
            Boolean isInvocable  = invocableClasses.contains(clsName);
            Boolean isAura       = auraEnabledClasses.contains(clsName);
            Boolean isUsed       = referencedNames.contains(clsName);

            info.isManagedPackage = isManaged;
            info.isTestClass      = isTest;
            info.isInvocable      = isInvocable;
            info.isAuraEnabled    = isAura;

            if (isManaged) {
                info.safetyStatus = 'MANAGED';
            } else if (isTest) {
                info.safetyStatus = 'TEST_CLASS';
            } else if (isInvocable) {
                info.safetyStatus = 'IN_USE';
            } else if (isAura) {
                info.safetyStatus = 'IN_USE';
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
        // One HTTP callout with LIMIT 200 — avoids CPU timeout.
        // MetadataComponentDependency already filters to only direct references
        // so 200 is more than enough for any real-world class.
        // Pagination was removed because multiple callouts in a loop
        // caused Apex CPU time limit exceeded errors.
        Set<String> seenKeys = new Set<String>();
        try {
            String depSoql =
                'SELECT MetadataComponentName, MetadataComponentType ' +
                'FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentName = \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                'AND MetadataComponentName != \'' + String.escapeSingleQuotes(componentName) + '\' ' +
                'ORDER BY MetadataComponentType, MetadataComponentName ' +
                'LIMIT 200';

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
            res.formattedReport = buildFormattedReport(componentName, res.references, null);
        }

        return res;
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
            item.relationship = 'calls / extends / implements';

        } else if (t == 'apextrigger') {
            item.groupLabel   = 'Triggers';
            item.relationship = 'instantiates class in trigger body';

        } else if (t == 'apextestsuite') {
            item.groupLabel   = 'Test Suites';
            item.relationship = 'included in test suite';

        // ── AUTOMATION ───────────────────────────────────────────────
        } else if (t == 'flow' || t == 'flowdefinition') {
            item.groupLabel   = 'Flows';
            item.relationship = 'calls as Apex Action (@InvocableMethod)';

        } else if (t.contains('workflowrule') || t.contains('workflowalert')
                || t.contains('workflowtask') || t.contains('workflowoutbound')
                || t.contains('processbuilder') || t.contains('process')) {
            item.groupLabel   = 'Workflow / Process Builder';
            item.relationship = 'calls as Apex Action';

        // ── UI COMPONENTS ────────────────────────────────────────────
        } else if (t == 'lightningcomponentbundle') {
            item.groupLabel   = 'LWC Components';
            item.relationship = '@wire or @AuraEnabled call';

        } else if (t == 'auradefinitionbundle') {
            item.groupLabel   = 'Aura Components';
            item.relationship = 'controller / helper reference';

        } else if (t == 'apexpage') {
            item.groupLabel   = 'Visualforce Pages';
            item.relationship = 'page controller or extension';

        } else if (t == 'apexcomponent') {
            item.groupLabel   = 'Visualforce Components';
            item.relationship = 'component controller';

        } else if (t == 'flexipage') {
            item.groupLabel   = 'Lightning Pages';
            item.relationship = 'component placed on Lightning page';

        } else if (t == 'customtab') {
            item.groupLabel   = 'Tabs';
            item.relationship = 'Visualforce tab backed by this class';

        // ── ACTIONS / INVOCABLE ──────────────────────────────────────
        } else if (t == 'quickaction') {
            item.groupLabel   = 'Quick Actions';
            item.relationship = 'Apex action handler';

        } else if (t == 'actionlinkgrouptemplate') {
            item.groupLabel   = 'Action Links';
            item.relationship = 'action link handler';

        // ── CONFIGURATION / SCHEMA ───────────────────────────────────
        } else if (t == 'customobject') {
            item.groupLabel   = 'Custom Objects';
            item.relationship = 'trigger or class referenced on object';

        } else if (t == 'customfield') {
            item.groupLabel   = 'Custom Fields';
            item.relationship = 'default formula or lookup filter';

        } else if (t == 'validationrule') {
            item.groupLabel   = 'Validation Rules';
            item.relationship = 'class referenced in rule formula';

        } else if (t == 'fieldset') {
            item.groupLabel   = 'Field Sets';
            item.relationship = 'controller reads field set';

        } else if (t == 'custommetadata' || t == 'custommetadatatype') {
            item.groupLabel   = 'Custom Metadata';
            item.relationship = 'Apex class name stored in record';

        } else if (t == 'customsetting') {
            item.groupLabel   = 'Custom Settings';
            item.relationship = 'referenced in config or formula';

        } else if (t == 'custompermission') {
            item.groupLabel   = 'Custom Permissions';
            item.relationship = 'checked via FeatureManagement';

        } else if (t == 'globalvalueset' || t == 'standardvalueset') {
            item.groupLabel   = 'Value Sets / Picklists';
            item.relationship = 'class references picklist values';

        // ── SECURITY / ACCESS ────────────────────────────────────────
        } else if (t == 'permissionset') {
            item.groupLabel   = 'Permission Sets';
            item.relationship = 'Apex class access granted';

        } else if (t == 'profile') {
            item.groupLabel   = 'Profiles';
            item.relationship = 'Apex class access granted';

        } else if (t == 'muting permissionset' || t == 'mutingpermissionset') {
            item.groupLabel   = 'Muting Permission Sets';
            item.relationship = 'Apex class access muted';

        // ── INTEGRATION ──────────────────────────────────────────────
        } else if (t == 'externalservice') {
            item.groupLabel   = 'External Services';
            item.relationship = 'registered external service handler';

        } else if (t == 'namedcredential') {
            item.groupLabel   = 'Named Credentials';
            item.relationship = 'callout uses named credential';

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
    private static String buildFormattedReport(String className, List<ReferenceItem> items, List<String> genAiTypes) {
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
            'Flows', 'Workflow / Process Builder',
            // Code
            'Apex Classes', 'Triggers', 'Test Suites',
            // UI
            'LWC Components', 'Aura Components', 'Visualforce Pages', 'Visualforce Components',
            'Lightning Pages', 'Tabs',
            // Actions
            'Quick Actions', 'Action Links',
            // Schema / Config
            'Custom Objects', 'Custom Fields', 'Validation Rules', 'Field Sets',
            'Custom Metadata', 'Custom Settings', 'Custom Permissions', 'Value Sets / Picklists',
            // Security
            'Permission Sets', 'Profiles', 'Muting Permission Sets',
            // Integration
            'External Services', 'Named Credentials', 'Auth Providers',
            'Connected Apps', 'CSP Trusted Sites',
            // Events / Messaging
            'Platform Events', 'Change Data Capture', 'Custom Notifications',
            // Email
            'Email Services',
            // Batch / Scheduled
            'Scheduled Jobs',
            // Communities
            'Communities / Experience', 'Sites',
            // Reporting
            'Reports', 'Dashboards',
            // Packages
            'Installed Packages'
        };

        Integer total = items.size();
        if (genAiTypes != null) total += genAiTypes.size();

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
            }
            report += '\n';
        }

        // GenAI types from error (not queryable via Tooling API)
        if (genAiTypes != null && !genAiTypes.isEmpty()) {
            report += 'Agentforce - Agent Actions:\n';
            for (String t : genAiTypes) {
                report += '  - ' + t + '\n';
            }
            report += '  To fix: Setup > Agents > find Agent using "' + className + '" > Topics & Actions > remove this Action > retry delete\n\n';
        }

        report += 'Tip: Setup > Apex Classes > "' + className + '" > "Where is this used?" for the full list.';


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

    public static DeleteResult deleteApexClassByName(String className) {
        // ── Strip namespace prefix upfront (e.g. es_AccountAgentAction → AccountAgentAction) ──
        String strippedClassName = className;
        try {
            List<Organization> orgList = [SELECT NamespacePrefix FROM Organization LIMIT 1];
            if (!orgList.isEmpty() && String.isNotBlank(orgList[0].NamespacePrefix)) {
                String ns = orgList[0].NamespacePrefix + '_';
                if (strippedClassName.startsWith(ns)) {
                    strippedClassName = strippedClassName.substring(ns.length());
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'keep original name if query fails: ' + ex.getMessage()); }

        // ── Reference check FIRST — before production guard ──
        // If the class is referenced by other components, show WHAT is blocking
        // instead of a generic production guard message.
        // ── Pre-check: query all queryable references before attempting delete ──
        // If found, show the report immediately without attempting the HTTP DELETE.
        // Note: GenAI references are NOT queryable — they will only appear if the
        // delete attempt fails with DEPENDENCY_EXISTS (handled below).
        ReferenceResult refs = getReferencesFor(strippedClassName, 'ApexClass');
        if (refs.hasReferences) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;
            blocked.message = refs.formattedReport;
            return blocked;
        }

        // ── Production guard — only fires if no references block ──
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        String lookupSoql = 'SELECT Id, Name FROM ApexClass ' +
                            'WHERE Name = \'' + String.escapeSingleQuotes(strippedClassName) + '\' LIMIT 1';

        HttpRequest lookupReq = new HttpRequest();
        lookupReq.setEndpoint(BASE_URL + 'tooling/query?q=' +
            EncodingUtil.urlEncode(lookupSoql, 'UTF-8'));
        lookupReq.setMethod('GET');
        lookupReq.setHeader('Content-Type', 'application/json');

        HttpResponse lookupRes = http.send(lookupReq);

        if (lookupRes.getStatusCode() < 200 || lookupRes.getStatusCode() >= 300) {
            result.success = false;
            result.message = 'Failed to look up Apex class "' + className + '". HTTP ' + lookupRes.getStatusCode();
            return result;
        }

        Map<String, Object> lookupResponse =
            (Map<String, Object>) JSON.deserializeUntyped(lookupRes.getBody());
        List<Object> lookupRecords = (List<Object>) lookupResponse.get('records');

        if (lookupRecords == null || lookupRecords.isEmpty()) {
            result.success = false;
            result.message = 'No Apex class found with name: ' + className;
            return result;
        }

        String classId = (String)((Map<String, Object>) lookupRecords[0]).get('Id');

        ApexSummary apexCheck = getApexClasses(null);
        for (ApexClassInfo ci : apexCheck.unusedClasses) {
            if (className.equalsIgnoreCase(ci.name)) {
                DeleteResult blocked = checkSafetyBeforeDelete(ci.safetyStatus, className);
                if (blocked != null) return blocked;
                break;
            }
        }

        HttpRequest deleteReq = new HttpRequest();
        deleteReq.setEndpoint(BASE_URL + 'tooling/sobjects/ApexClass/' + classId);
        deleteReq.setMethod('DELETE');
        deleteReq.setHeader('Content-Type', 'application/json');

        HttpResponse deleteRes = http.send(deleteReq);

        if (deleteRes.getStatusCode() == 204 || deleteRes.getStatusCode() == 200) {
            // ── Success ──
            result.success = true;
            result.message = '✅ Apex class "' + className + '" successfully deleted.';

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

            // Query all queryable references
            ReferenceResult refsAfterFail = getReferencesFor(strippedClassName, 'ApexClass');

            result.success = false;

            if (refsAfterFail.hasReferences || !genAiTypes.isEmpty()) {
                // Build combined report: queryable refs + GenAI types from error
                result.message = buildFormattedReport(
                    strippedClassName,
                    refsAfterFail.references,
                    genAiTypes.isEmpty() ? null : genAiTypes
                );
            } else {
                // getReferencesFor returned nothing AND no GenAI types parsed
                // Show everything Salesforce told us + fallback guidance
                String allTypes = '';
                for (String dt : depTypes) {
                    allTypes += '  🔗 ' + dt + '\n';
                }
                if (String.isBlank(allTypes)) allTypes = '  🔗 One or more metadata components\n';

                result.message =
                    'Cannot delete "' + strippedClassName + '". It is referenced elsewhere.\n\n' +
                    'Blocking references:\n' +
                    allTypes + '\n' +
                    'To fix:\n' +
                    '  1. Setup > Apex Classes > "' + strippedClassName + '" > Where is this used?\n' +
                    '  2. Setup > Agents > find Agent using this class > Topics & Actions > remove it\n' +
                    '  3. Then retry the delete.';
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
    public static MassDeleteResult massDeleteApexClasses(List<String> classNames) {
        MassDeleteResult mass = new MassDeleteResult();
        mass.totalRequested = classNames.size();
        mass.successCount   = 0;
        mass.failureCount   = 0;
        mass.succeeded      = new List<String>();
        mass.failed         = new List<String>();

        for (String className : classNames) {
            if (String.isBlank(className)) continue;
            DeleteResult r = deleteApexClassByName(className.trim());
            if (r.success) {
                mass.successCount++;
                mass.succeeded.add(className.trim());
            } else {
                mass.failureCount++;
                mass.failed.add(className.trim() + ' (' + r.message + ')');
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
                        usedTriggerNames.add(info.name + ' → ' + referencedClass);
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

    // ===============================
    // DELETE TRIGGER BY NAME
    // ===============================
    public static DeleteResult deleteTriggerByName(String triggerName) {
        // ── Reference check FIRST — before production guard ──
        ReferenceResult triggerRefs = getReferencesFor(triggerName, 'ApexTrigger');
        if (triggerRefs.hasReferences) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;
            String msg = '\U0001f6ab Cannot delete "' + triggerName + '" \u2014 it is referenced by ' + triggerRefs.referenceCount + ' component(s).\n\n';
            msg += '\U0001f4cb REFERENCES BLOCKING DELETE (' + triggerRefs.referenceCount + ' found):\n';
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            Integer triggerIdx = 1;
            for (ReferenceItem ref : triggerRefs.references) {
                msg += triggerIdx++ + '. ' + ref.name + '\n';
                msg += '   Type         : ' + ref.type + '\n';
                msg += '   Relationship : ' + ref.relationship + '\n\n';
            }
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            msg += '\U0001f4a1 Remove "' + triggerName + '" from the above component(s) first, then retry.';
            blocked.message = msg;
            return blocked;
        }

        // ── Production guard \u2014 only fires if no references block ──
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();


        String lookupSoql = 'SELECT Id, Name, TableEnumOrId, Status FROM ApexTrigger ' +
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

        TriggerSummary trigCheck = getTriggers(null);
        List<TriggerInfo> allTrigs = new List<TriggerInfo>();
        if (trigCheck.activeTriggers   != null) allTrigs.addAll(trigCheck.activeTriggers);
        if (trigCheck.inactiveTriggers != null) allTrigs.addAll(trigCheck.inactiveTriggers);
        for (TriggerInfo ti : allTrigs) {
            if (triggerName.equalsIgnoreCase(ti.name)) {
                DeleteResult blocked = checkSafetyBeforeDelete(ti.safetyStatus, triggerName);
                if (blocked != null) return blocked;
                break;
            }
        }

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
            result.success = false;
            result.message = 'Failed to delete Trigger "' + triggerName + '". HTTP ' +
                              deleteRes.getStatusCode() + ': ' + deleteRes.getBody();
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
            DeleteResult r = deleteTriggerByName(name.trim());
            if (r.success) { mass.successCount++; mass.succeeded.add(name.trim()); }
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
            DeleteResult r = deleteLwcByName(name.trim());
            if (r.success) { mass.successCount++; mass.succeeded.add(name.trim()); }
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
            DeleteResult r = deleteAuraByName(name.trim());
            if (r.success) { mass.successCount++; mass.succeeded.add(name.trim()); }
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

        Set<String> objDepNames = new Set<String>();
        try {
            String objDepSoql = 'SELECT RefMetadataComponentName FROM MetadataComponentDependency ' +
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
                        Map<String, Object> row     = (Map<String, Object>) r;
                        String              refName = (String) row.get('RefMetadataComponentName');
                        if (String.isNotBlank(refName)) objDepNames.add(refName.toLowerCase());
                    }
                }
            }
        } catch (Exception ex) { System.debug(LoggingLevel.WARN, 'dep check failed — continue: ' + ex.getMessage()); }

        for (CustomObjectInfo info : allObjects) {
            Boolean isManaged  = String.isNotBlank(info.namespacePrefix);
            Boolean isInDep    = objDepNames.contains((info.name + '__c').toLowerCase()) ||
                                 objDepNames.contains((info.name).toLowerCase());
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
            String msg = '\U0001f6ab Cannot delete "' + objectName + '" \u2014 it is referenced by ' + objectRefs.referenceCount + ' component(s).\n\n';
            msg += '\U0001f4cb REFERENCES BLOCKING DELETE (' + objectRefs.referenceCount + ' found):\n';
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            Integer objectIdx = 1;
            for (ReferenceItem ref : objectRefs.references) {
                msg += objectIdx++ + '. ' + ref.name + '\n';
                msg += '   Type         : ' + ref.type + '\n';
                msg += '   Relationship : ' + ref.relationship + '\n\n';
            }
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            msg += '\U0001f4a1 Remove "' + objectName + '" from the above component(s) first, then retry.';
            blocked.message = msg;
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
    public static DeleteResult deleteLwcByName(String componentName) {
        // ── Reference check FIRST — before production guard ──
        ReferenceResult compRefs = getReferencesFor(componentName, 'LightningComponentBundle');
        if (compRefs.hasReferences) {
            DeleteResult blocked = new DeleteResult();
            blocked.success = false;
            String msg = '\U0001f6ab Cannot delete "' + componentName + '" \u2014 it is referenced by ' + compRefs.referenceCount + ' component(s).\n\n';
            msg += '\U0001f4cb REFERENCES BLOCKING DELETE (' + compRefs.referenceCount + ' found):\n';
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            Integer compIdx = 1;
            for (ReferenceItem ref : compRefs.references) {
                msg += compIdx++ + '. ' + ref.name + '\n';
                msg += '   Type         : ' + ref.type + '\n';
                msg += '   Relationship : ' + ref.relationship + '\n\n';
            }
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            msg += '\U0001f4a1 Remove "' + componentName + '" from the above component(s) first, then retry.';
            blocked.message = msg;
            return blocked;
        }

        // ── Production guard \u2014 only fires if no references block ──
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

        LwcSummary lwcCheck = getLwcComponents(null);
        for (LwcComponentInfo li : lwcCheck.allComponents) {
            if (componentName.equalsIgnoreCase(li.name)) {
                DeleteResult blocked = checkSafetyBeforeDelete(li.safetyStatus, componentName);
                if (blocked != null) return blocked;
                break;
            }
        }

        HttpRequest del = new HttpRequest();
        del.setEndpoint(BASE_URL + 'tooling/sobjects/LightningComponentBundle/' + cId);
        del.setMethod('DELETE');
        del.setHeader('Content-Type', 'application/json');

        HttpResponse dr = http.send(del);

        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true;
            result.message = 'LWC "' + componentName + '" (Id: ' + cId + ') deleted successfully.';
        } else {
            result.success = false;
            result.message = 'Failed to delete LWC "' + componentName + '". HTTP ' +
                              dr.getStatusCode() + ': ' + dr.getBody();
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
            String msg = '\U0001f6ab Cannot delete "' + componentName + '" \u2014 it is referenced by ' + auraRefs.referenceCount + ' component(s).\n\n';
            msg += '\U0001f4cb REFERENCES BLOCKING DELETE (' + auraRefs.referenceCount + ' found):\n';
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            Integer auraIdx = 1;
            for (ReferenceItem ref : auraRefs.references) {
                msg += auraIdx++ + '. ' + ref.name + '\n';
                msg += '   Type         : ' + ref.type + '\n';
                msg += '   Relationship : ' + ref.relationship + '\n\n';
            }
            msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
            msg += '\U0001f4a1 Remove "' + componentName + '" from the above component(s) first, then retry.';
            blocked.message = msg;
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
            result.message = 'Failed to delete Aura "' + componentName + '". HTTP ' +
                              dr.getStatusCode() + ': ' + dr.getBody();
        }

        return result;
    }

    // ===============================
    // DELETE CUSTOM FIELD BY OBJECT + FIELD NAME
    // ===============================
    public static DeleteResult deleteCustomFieldByName(String objectName, String fieldName) {
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

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
            result.message = 'Failed to delete VR "' + objectName + '.' + ruleName + '". HTTP ' +
                              dr.getStatusCode() + ': ' + dr.getBody();
        }

        return result;
    }

    // ===============================
    // DELETE PERMISSION SET BY NAME
    // ===============================
    public static DeleteResult deletePermissionSetByName(String permSetName) {
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

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