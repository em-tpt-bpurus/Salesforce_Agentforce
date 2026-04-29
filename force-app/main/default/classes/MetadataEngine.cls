@SuppressWarnings('PMD.ExcessiveClassLength,PMD.NcssMethodCount,PMD.AvoidDeeplyNestedIfStmts,PMD.CognitiveComplexity,PMD.NcssTypeCount,PMD.EmptyStatementBlock,PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces,PMD.ApexCRUDViolation')
public without sharing class MetadataEngine {

    // ===============================
    // WRAPPERS — FLOWS
    // ===============================
    public class FlowInfo {
        public String  apiName;
        public String  label;
        public String  processType;
        public Boolean isActive;
        public String  namespacePrefix;
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

    // ===============================
    // WRAPPERS — LWC COMPONENTS
    // ===============================
    public class LwcComponentInfo {
        public String id;
        public String name;
        public String namespacePrefix;
        public String lastModifiedDate;
        public String apiVersion;
    }

    public class LwcSummary {
        public Integer                total;
        public Integer                withNamespace;
        public Integer                withoutNamespace;
        public List<LwcComponentInfo> allComponents;
        public List<LwcComponentInfo> filteredComponents;
        public String                 namespaceFilter;
    }

    // ===============================
    // WRAPPERS — AURA COMPONENTS
    // ===============================
    public class AuraComponentInfo {
        public String id;
        public String name;
        public String namespacePrefix;
        public String lastModifiedDate;
        public String apiVersion;
    }

    public class AuraSummary {
        public Integer                 total;
        public Integer                 withNamespace;
        public Integer                 withoutNamespace;
        public List<AuraComponentInfo> allComponents;
        public List<AuraComponentInfo> filteredComponents;
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
    }

    public class PermissionSetSummary {
        public Integer                 total;
        public Integer                 unused;
        public Integer                 used;
        public Integer                 withNamespace;
        public Integer                 withoutNamespace;
        public Integer                 filteredTotal;
        public String                  namespaceFilterApplied;
        public List<PermissionSetInfo> unusedPermSets;
        public List<PermissionSetInfo> usedPermSets;
        public List<PermissionSetInfo> filteredPermSets;
    }

    // ===============================
    // WRAPPERS — CUSTOM FIELDS
    // ===============================
    public class CustomFieldInfo {
        public String id;
        public String name;
        public String objectName;
        public String dataType;
        public String namespacePrefix;
        public String lastModifiedDate;
    }

    public class CustomFieldSummary {
        public Integer               total;
        public Integer               withNamespace;
        public Integer               withoutNamespace;
        public List<CustomFieldInfo> allFields;
        public List<CustomFieldInfo> filteredFields;
        public String                namespaceFilter;
    }

    // ===============================
    // WRAPPERS — CUSTOM OBJECTS
    // ===============================
    public class CustomObjectInfo {
        public String id;
        public String name;
        public String label;
        public String namespacePrefix;
        public String lastModifiedDate;
    }

    public class CustomObjectSummary {
        public Integer                total;
        public Integer                withNamespace;
        public Integer                withoutNamespace;
        public List<CustomObjectInfo> allObjects;
        public List<CustomObjectInfo> filteredObjects;
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
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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

                    // Populate rich FlowInfo object for export
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

                    Boolean matchesFilter = String.isBlank(namespaceFilter) ||
                        namespaceFilter.equalsIgnoreCase(nsPrefix == null ? '' : nsPrefix);

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
    // DELETE FLOW BY API NAME
    // ===============================
    public static DeleteResult deleteFlowByApiName(String apiName) {

        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        String lookupSoql = 'SELECT Id, DurableId, Label, ApiName, IsActive ' +
                            'FROM FlowDefinitionView ' +
                            'WHERE ApiName = \'' + String.escapeSingleQuotes(apiName) + '\' ' +
                            'LIMIT 1';

        HttpRequest lookupReq = new HttpRequest();
        lookupReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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

        if (isActive) {
            HttpRequest deactivateReq = new HttpRequest();
            deactivateReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/FlowDefinition/' + durableId);
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
        versionReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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
            deleteReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/Flow/' + versionId);
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

    // ===============================
    // GET APEX CLASSES + DETECT UNUSED
    // ===============================
    public static ApexSummary getApexClasses(String namespaceFilter) {

        Http http = new Http();

        String      countSoql = 'SELECT Id FROM ApexClass';
        HttpRequest countReq  = new HttpRequest();
        countReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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
        stdReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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
        classReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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
        depReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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
            // Match standard/package classes whose NamespacePrefix equals the filter
            for (String stdName : standardClassNames) {
                ApexClassInfo stdInfo = standardClassMap.get(stdName);
                String        stdNs   = stdInfo != null && stdInfo.namespacePrefix != null
                                          ? stdInfo.namespacePrefix.toLowerCase() : '';
                if (stdNs.equals(nsLower)) {
                    filteredClasses.add(stdInfo);
                }
            }
            // Match custom classes whose name starts with the namespace.
            // Handles all conventions:
            //   NS_ClassName   (underscore separator)
            //   NSClassName    (camelCase, no separator)
            // A match requires the class name to start with the filter AND the very next
            // character (if any) is either '_' or an uppercase letter — this prevents
            // "EM" matching "EMployee" only when the developer actually used "EM" as a prefix.
            for (String className : allClassMap.keySet()) {
                String classLower = className.toLowerCase();
                if (classLower.startsWith(nsLower)) {
                    Integer nextIdx = nsLower.length();
                    if (nextIdx >= className.length()) {
                        // Exact name match — include it
                        filteredClasses.add(allClassMap.get(className));
                    } else {
                        String nextChar = className.substring(nextIdx, nextIdx + 1);
                        // Include if followed by underscore (NS_Class) or uppercase (NSClass)
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

    // ===============================
    // DELETE APEX CLASS BY NAME
    // ===============================
    public static DeleteResult deleteApexClassByName(String className) {

        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        String lookupSoql = 'SELECT Id, Name FROM ApexClass ' +
                            'WHERE Name = \'' + String.escapeSingleQuotes(className) + '\' ' +
                            'AND NamespacePrefix = null LIMIT 1';

        HttpRequest lookupReq = new HttpRequest();
        lookupReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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

        HttpRequest deleteReq = new HttpRequest();
        deleteReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/ApexClass/' + classId);
        deleteReq.setMethod('DELETE');
        deleteReq.setHeader('Content-Type', 'application/json');

        HttpResponse deleteRes = http.send(deleteReq);

        if (deleteRes.getStatusCode() == 204 || deleteRes.getStatusCode() == 200) {
            result.success = true;
            result.message = 'Apex class "' + className + '" (Id: ' + classId + ') successfully deleted.';
        } else {
            result.success = false;
            result.message = 'Failed to delete Apex class "' + className + '". HTTP ' +
                              deleteRes.getStatusCode() + ': ' + deleteRes.getBody();
        }

        return result;
    }

    // ===============================
    // GET TRIGGERS + DETECT UNUSED
    // ===============================
    public static TriggerSummary getTriggers(String namespaceFilter) {

        Http http = new Http();

        String      classSoql = 'SELECT Name FROM ApexClass WHERE NamespacePrefix = null';
        HttpRequest classReq  = new HttpRequest();
        classReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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
        trigReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        trigReq.setMethod('GET');
        trigReq.setHeader('Content-Type', 'application/json');

        HttpResponse      trigRes         = http.send(trigReq);
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

        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        String lookupSoql = 'SELECT Id, Name, TableEnumOrId, Status FROM ApexTrigger ' +
                            'WHERE Name = \'' + String.escapeSingleQuotes(triggerName) + '\' ' +
                            'AND NamespacePrefix = null LIMIT 1';

        HttpRequest lookupReq = new HttpRequest();
        lookupReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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

        HttpRequest deleteReq = new HttpRequest();
        deleteReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/ApexTrigger/' + triggerId);
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

    // ===============================
    // GET LWC COMPONENTS
    // ===============================
    public static LwcSummary getLwcComponents(String namespaceFilter) {

        Http   http = new Http();
        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate, ApiVersion ' +
                      'FROM LightningComponentBundle ORDER BY DeveloperName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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

        return summary;
    }

    // ===============================
    // GET AURA COMPONENTS
    // ===============================
    public static AuraSummary getAuraComponents(String namespaceFilter) {

        Http   http = new Http();
        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate, ApiVersion ' +
                      'FROM AuraDefinitionBundle ORDER BY DeveloperName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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

        return summary;
    }

    // ===============================
    // GET PROFILES + DETECT UNUSED
    // ===============================
    public static ProfileSummary getProfiles() {

        Http http = new Http();

        String      profileSoql = 'SELECT Id, Name, UserLicenseId, UserLicense.Name, UserType FROM Profile ORDER BY Name ASC';
        HttpRequest profileReq  = new HttpRequest();
        profileReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
            EncodingUtil.urlEncode(profileSoql, 'UTF-8'));
        profileReq.setMethod('GET');
        profileReq.setHeader('Content-Type', 'application/json');

        HttpResponse             profileRes = http.send(profileReq);
        Map<String, ProfileInfo> profileMap = new Map<String, ProfileInfo>();

        if (profileRes.getStatusCode() >= 200 && profileRes.getStatusCode() < 300) {
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
        }

        String      userSoql = 'SELECT ProfileId, COUNT(Id) userCount FROM User WHERE IsActive = true GROUP BY ProfileId';
        HttpRequest userReq  = new HttpRequest();
        userReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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

        List<ProfileInfo> unusedProfiles   = new List<ProfileInfo>();
        List<ProfileInfo> usedProfiles     = new List<ProfileInfo>();
        List<ProfileInfo> customProfiles   = new List<ProfileInfo>();
        List<ProfileInfo> standardProfiles = new List<ProfileInfo>();

        for (ProfileInfo info : profileMap.values()) {
            if (info.assignedUserCount == 0) {
                unusedProfiles.add(info);
            } else {
                usedProfiles.add(info);
            }
            if (info.isCustom == true) {
                customProfiles.add(info);
            } else {
                standardProfiles.add(info);
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

        return summary;
    }

    // ===============================
    // GET PERMISSION SETS + DETECT UNUSED
    // ===============================
    public static PermissionSetSummary getPermissionSets() {
        return getPermissionSets(null);
    }

    public static PermissionSetSummary getPermissionSets(String namespaceFilter) {

        Http http = new Http();

        String      permSetSoql = 'SELECT Id, Name, Label, IsCustom, NamespacePrefix FROM PermissionSet ' +
                                  'WHERE IsOwnedByProfile = false ORDER BY Label ASC';
        HttpRequest permSetReq  = new HttpRequest();
        permSetReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
            EncodingUtil.urlEncode(permSetSoql, 'UTF-8'));
        permSetReq.setMethod('GET');
        permSetReq.setHeader('Content-Type', 'application/json');

        HttpResponse                   permSetRes = http.send(permSetReq);
        Map<String, PermissionSetInfo> permSetMap = new Map<String, PermissionSetInfo>();

        if (permSetRes.getStatusCode() >= 200 && permSetRes.getStatusCode() < 300) {
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
        }

        String      assignSoql = 'SELECT PermissionSetId, COUNT(Id) assignCount FROM PermissionSetAssignment GROUP BY PermissionSetId';
        HttpRequest assignReq  = new HttpRequest();
        assignReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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
            if (info.assignmentCount == 0) {
                unusedPermSets.add(info);
            } else {
                usedPermSets.add(info);
            }
            if (nsLower != null && String.isNotBlank(info.namespacePrefix) &&
                info.namespacePrefix.toLowerCase().contains(nsLower)) {
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
        summary.unusedPermSets          = unusedPermSets;
        summary.usedPermSets            = usedPermSets;
        summary.filteredPermSets        = filteredPermSets;

        return summary;
    }

    
       // ===============================
        // GET CUSTOM OBJECTS
        // ===============================
        public static CustomObjectSummary getCustomObjects(String namespaceFilter) {

            Http http = new Http();

            // ── Step 1: Fetch all CustomObjects from Tooling API ───────
            String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate ' +
                        'FROM CustomObject ' +
                        'ORDER BY DeveloperName ASC';

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
                EncodingUtil.urlEncode(soql, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);

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

                        // ── Step 2: Check each object exists individually ──
                        Boolean exists = false;
                        try {
                            Schema.describeSObjects(new List<String>{ devName + '__c' });
                            exists = true;
                        } catch (Exception ex) {
                            exists = false;
                        }

                        // Skip deleted/ghost objects
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

            return summary;
        }

    // ===============================
    // GET CUSTOM FIELDS
    // ===============================
    public static CustomFieldSummary getCustomFields(String namespaceFilter) {

        Http http = new Http();

        // Known Salesforce sample/demo fields to exclude
        Set<String> sampleFields = new Set<String>{
            'active', 'customerpriority', 'numberoflocations', 'sla',
            'slaexpirationdate', 'slaserialnumber', 'upsellOpportunity',
            'engineeringreqnumber', 'potentialliability', 'product',
            'slaviolation', 'languages', 'level', 'currentgenerators',
            'primary', 'productinterest', 'siccode', 'origgoalid',
            'origmetricid', 'deliveryinstallationstatus', 'maincompetitors',
            'ordernumber', 'trackingnumber', 'naicsdesc', 'sicdesc'
        };

        // Known valid standard object names
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

        // System/platform object ID prefixes to skip
        Set<String> systemPrefixes = new Set<String>{
            '9sdg',  // Individual / GDPR Data Privacy object
            '0Hf',   // Territory Management
            '0Mo',   // Einstein AI
            '0Ho',   // Other system objects
            '0Db',   // Data.com
            '0Dt',   // Data stream
            '0XO'    // Omnichannel
        };

        // ── Step 1: Get valid custom object IDs ───────────────────
        Map<String, String> validObjectIds = new Map<String, String>();

        HttpRequest objReq = new HttpRequest();
        objReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(
                'SELECT Id, DeveloperName FROM CustomObject ORDER BY DeveloperName ASC',
                'UTF-8'
            ));
        objReq.setMethod('GET');
        objReq.setHeader('Content-Type', 'application/json');
        objReq.setTimeout(120000);

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

        // ── Step 2: Get all unmanaged custom fields ────────────────
        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate, TableEnumOrId ' +
                    'FROM CustomField ' +
                    'WHERE ManageableState = \'unmanaged\' ' +
                    'ORDER BY TableEnumOrId, DeveloperName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

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
                        if (field.endsWith('_del')) continue; // ← skip soft-deleted fields

                        // ── Check system prefix — skip entirely ───────
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
                            // ✅ Valid custom object — always include
                            objectName = validObjectIds.get(tableId);

                        } else if (knownStandardObjects.contains(tableId)) {
                            // ✅ Known standard object — exclude sample fields
                            if (sampleFields.contains(field.toLowerCase())) continue;
                            objectName = tableId;

                        } else {
                            // ❌ Unknown ID — skip
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

        return summary;
    }


    // ===============================
    // GET VALIDATION RULES
    // ===============================
    public static ValidationRuleSummary getValidationRules(String namespaceFilter) {

        Http   http = new Http();
        String soql = 'SELECT Id, ValidationName, EntityDefinition.QualifiedApiName, Active, ErrorMessage, NamespacePrefix, LastModifiedDate ' +
                      'FROM ValidationRule ORDER BY ValidationName ASC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        String cleanName = objectName.trim().endsWith('__c')
            ? objectName.trim().substring(0, objectName.trim().length() - 3)
            : objectName.trim();
        cleanName = cleanName.replace(' ', '_');

        String fullApiName = cleanName + '__c';

        // ── Step 1: Verify object exists via Tooling API ──────────
        String soql = 'SELECT Id, DeveloperName, NamespacePrefix FROM CustomObject ' +
                    'WHERE DeveloperName = \'' + String.escapeSingleQuotes(cleanName) + '\' LIMIT 1';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

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

        System.debug('Object found   : ' + fullApiName);
        System.debug('NamespacePrefix: ' + nsPrefix);
        System.debug('Is Managed     : ' + isManaged);

        // ── Step 2: If managed — find and uninstall the package ───
        if (isManaged) {
            HttpRequest pkgReq = new HttpRequest();
            pkgReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
                EncodingUtil.urlEncode(
                    'SELECT Id, SubscriberPackageId, SubscriberPackage.Name, SubscriberPackage.NamespacePrefix ' +
                    'FROM InstalledSubscriberPackage ' +
                    'WHERE SubscriberPackage.NamespacePrefix = \'' + String.escapeSingleQuotes(nsPrefix) + '\'',
                    'UTF-8'
                ));
            pkgReq.setMethod('GET');
            pkgReq.setHeader('Content-Type', 'application/json');
            pkgReq.setTimeout(30000);

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
                    uninstallReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/InstalledSubscriberPackage/' + pkgId);
                    uninstallReq.setMethod('DELETE');
                    uninstallReq.setHeader('Content-Type', 'application/json');
                    uninstallReq.setTimeout(120000);

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

        // ── Step 3: Get Session ID via JWT Bearer OAuth ────────────
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

            Long   expTime = DateTime.now().addMinutes(5).getTime() / 1000;
            String payload = EncodingUtil.base64Encode(Blob.valueOf(
                '{"iss":"' + cred.ConsumerKey__c + '",' +
                '"sub":"' + cred.Username__c + '",' +
                '"aud":"https://login.salesforce.com",' +
                '"exp":' + expTime + '}'
            )).replace('+', '-').replace('/', '_').replace('=', '');

            String signingInput   = header + '.' + payload;
            Blob   privateKeyBlob = EncodingUtil.base64Decode(cred.Certificate__c);
            Blob   signature      = Crypto.sign('RSA-SHA256', Blob.valueOf(signingInput), privateKeyBlob);

            String jwt = signingInput + '.' + EncodingUtil.base64Encode(signature)
                .replace('+', '-').replace('/', '_').replace('=', '');

            HttpRequest jwtReq = new HttpRequest();
            jwtReq.setEndpoint('https://login.salesforce.com/services/oauth2/token');
            jwtReq.setMethod('POST');
            jwtReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            jwtReq.setTimeout(30000);
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

        // ── Step 4: Fallback — UserInfo.getSessionId() ────────────
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

        // ── Step 5: Delete via Metadata SOAP deleteMetadata ───────
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
        del.setTimeout(120000);
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
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        String      soql = 'SELECT Id FROM LightningComponentBundle WHERE DeveloperName = \'' +
                           String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
        HttpRequest req  = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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

        String      cId = (String)((Map<String, Object>) records[0]).get('Id');
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/LightningComponentBundle/' + cId);
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
        Http         http   = new Http();
        DeleteResult result = new DeleteResult();

        String      soql = 'SELECT Id FROM AuraDefinitionBundle WHERE DeveloperName = \'' +
                           String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
        HttpRequest req  = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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

        String      cId = (String)((Map<String, Object>) records[0]).get('Id');
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/AuraDefinitionBundle/' + cId);
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

        // ── Step 1: Normalize names ───────────────────────────────
        String cleanObject = objectName.trim().endsWith('__c')
            ? objectName.trim().substring(0, objectName.trim().length() - 3)
            : objectName.trim();
        cleanObject = cleanObject.replace(' ', '_');

        String cleanField = fieldName.trim().endsWith('__c')
            ? fieldName.trim().substring(0, fieldName.trim().length() - 3)
            : fieldName.trim();
        cleanField = cleanField.replace(' ', '_');

        // Determine if object is custom or standard
        Boolean isCustomObject = objectName.trim().endsWith('__c') || objectName.trim().contains('__');

        String fullObjectName = isCustomObject ? cleanObject + '__c' : cleanObject;
        String fullFieldName  = cleanField + '__c';
        String fullApiName    = fullObjectName + '.' + cleanField + '__c';

        System.debug('Object API Name : ' + fullObjectName);
        System.debug('Field API Name  : ' + fullFieldName);
        System.debug('Metadata Full   : ' + fullApiName);

        // ── Step 2: Verify field exists via Tooling API ───────────
        String soql = 'SELECT Id, DeveloperName FROM CustomField ' +
              'WHERE DeveloperName = \'' + String.escapeSingleQuotes(cleanField) + '\' ' +
              'AND EntityDefinition.QualifiedApiName = \'' + String.escapeSingleQuotes(fullObjectName) + '\' ' +
              'LIMIT 1';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

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

        // ── Step 3: Get Session ID via JWT Bearer OAuth ────────────
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

            Long   expTime = DateTime.now().addMinutes(5).getTime() / 1000;
            String payload = EncodingUtil.base64Encode(Blob.valueOf(
                '{"iss":"' + cred.ConsumerKey__c + '",' +
                '"sub":"' + cred.Username__c + '",' +
                '"aud":"https://login.salesforce.com",' +
                '"exp":' + expTime + '}'
            )).replace('+', '-').replace('/', '_').replace('=', '');

            String signingInput   = header + '.' + payload;
            Blob   privateKeyBlob = EncodingUtil.base64Decode(cred.Certificate__c);
            Blob   signature      = Crypto.sign('RSA-SHA256', Blob.valueOf(signingInput), privateKeyBlob);

            String jwt = signingInput + '.' + EncodingUtil.base64Encode(signature)
                .replace('+', '-').replace('/', '_').replace('=', '');

            HttpRequest jwtReq = new HttpRequest();
            jwtReq.setEndpoint('https://login.salesforce.com/services/oauth2/token');
            jwtReq.setMethod('POST');
            jwtReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            jwtReq.setTimeout(30000);
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

        // ── Step 4: Fallback — UserInfo.getSessionId() ────────────
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

        // ── Step 5: Delete via Metadata SOAP deleteMetadata ───────
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
        del.setTimeout(120000);
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
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
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

        String      rId = (String)((Map<String, Object>) records[0]).get('Id');
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/ValidationRule/' + rId);
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
        lReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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

        String      aSoql = 'SELECT Id FROM PermissionSetAssignment WHERE PermissionSetId = \'' + psId + '\'';
        HttpRequest aReq  = new HttpRequest();
        aReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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
                    dAReq.setEndpoint('callout:Metadata_API/services/data/v60.0/sobjects/PermissionSetAssignment/' + aId);
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
        delReq.setEndpoint('callout:Metadata_API/services/data/v60.0/sobjects/PermissionSet/' + psId);
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

        // ── Step 1: Look up profile by Name ──────────────────────
        String      pSoql = 'SELECT Id FROM Profile WHERE Name = \'' +
                            String.escapeSingleQuotes(profileName) + '\' LIMIT 1';
        HttpRequest pReq  = new HttpRequest();
        pReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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

        // ── Step 2: Check for assigned users ─────────────────────
        String profileId = (String)((Map<String, Object>) pRecs[0]).get('Id');

        String      uSoql = 'SELECT Id FROM User WHERE ProfileId = \'' + profileId + '\' AND IsActive = true LIMIT 1';
        HttpRequest uReq  = new HttpRequest();
        uReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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
                fReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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
                allUReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
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
                            patchReq.setEndpoint('callout:Metadata_API/services/data/v60.0/sobjects/User/' + uid);
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

        // ── Step 3: Get Session ID via JWT Bearer OAuth ───────────
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

            Long   expTime = DateTime.now().addMinutes(5).getTime() / 1000;
            String payload = EncodingUtil.base64Encode(Blob.valueOf(
                '{"iss":"' + cred.ConsumerKey__c + '",' +
                '"sub":"' + cred.Username__c + '",' +
                '"aud":"https://login.salesforce.com",' +
                '"exp":' + expTime + '}'
            )).replace('+', '-').replace('/', '_').replace('=', '');

            String signingInput   = header + '.' + payload;
            Blob   privateKeyBlob = EncodingUtil.base64Decode(cred.Certificate__c);
            Blob   signature      = Crypto.sign('RSA-SHA256', Blob.valueOf(signingInput), privateKeyBlob);

            String jwt = signingInput + '.' + EncodingUtil.base64Encode(signature)
                .replace('+', '-').replace('/', '_').replace('=', '');

            HttpRequest jwtReq = new HttpRequest();
            jwtReq.setEndpoint('https://login.salesforce.com/services/oauth2/token');
            jwtReq.setMethod('POST');
            jwtReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            jwtReq.setTimeout(30000);
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

        // ── Step 4: Fallback to UserInfo session ──────────────────
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

        // ── Step 5: Delete via Metadata SOAP deleteMetadata ───────
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
        delReq.setTimeout(120000);
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