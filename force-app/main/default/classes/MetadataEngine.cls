@SuppressWarnings('PMD.ExcessiveClassLength,PMD.NcssMethodCount,PMD.AvoidDeeplyNestedIfStmts,PMD.CognitiveComplexity')
public without sharing class MetadataEngine {

    // ===============================
    // WRAPPERS — FLOWS
    // ===============================
    public class FlowSummary {
        public Integer      total;
        public Integer      active;
        public Integer      inactive;
        public List<String> activeFlows;
        public List<String> inactiveFlows;
        // Namespace filter support
        public Integer      filteredTotal;
        public List<String> filteredActiveFlows;
        public List<String> filteredInactiveFlows;
        public String       namespaceFilter;
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
        // Namespace filter support
        public Integer             filteredTotal;
        public List<ApexClassInfo> filteredClasses;
        public String              namespaceFilter;
    }

    // ===============================
    // SHARED WRAPPER
    // ===============================
    public class DeleteResult {
        public Boolean success;
        public String  message;
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
        public Integer               total;
        public Integer               withNamespace;
        public Integer               withoutNamespace;
        public List<LwcComponentInfo> allComponents;
        public List<LwcComponentInfo> filteredComponents;
        public String                namespaceFilter;
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
        public Integer                total;
        public Integer                withNamespace;
        public Integer                withoutNamespace;
        public List<AuraComponentInfo> allComponents;
        public List<AuraComponentInfo> filteredComponents;
        public String                 namespaceFilter;
    }

    // ===============================
    // WRAPPERS — PROFILES
    // ===============================
    public class ProfileInfo {
        public String  id;
        public String  name;
        public String  userLicenseName;
        public Integer assignedUserCount;
    }

    public class ProfileSummary {
        public Integer           total;
        public Integer           unused;
        public Integer           used;
        public List<ProfileInfo> unusedProfiles;
        public List<ProfileInfo> usedProfiles;
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
        public Integer                total;
        public Integer                unused;
        public Integer                used;
        public List<PermissionSetInfo> unusedPermSets;
        public List<PermissionSetInfo> usedPermSets;
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
        public Integer                 total;
        public Integer                 active;
        public Integer                 inactive;
        public List<ValidationRuleInfo> activeRules;
        public List<ValidationRuleInfo> inactiveRules;
        public List<ValidationRuleInfo> filteredRules;
        public String                  namespaceFilter;
    }

    // ===============================
    // GET FLOWS
    // ===============================
    public static FlowSummary getFlows(String namespaceFilter) {

        Http http = new Http();

        List<String> activeFlows   = new List<String>();
        List<String> inactiveFlows = new List<String>();
        List<String> filteredActiveFlows   = new List<String>();
        List<String> filteredInactiveFlows = new List<String>();

        // FlowDefinitionView exposes NamespacePrefix for managed/packaged flows
        String soql = 'SELECT Label, ApiName, IsActive, ProcessType, NamespacePrefix ' +
                      'FROM FlowDefinitionView ' +
                      'WHERE ProcessType != \'StandardInvocableAction\'';

        System.debug('🔍 FLOW SOQL: ' + soql);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        System.debug('📡 FLOW STATUS CODE  : ' + res.getStatusCode());
        System.debug('📡 FLOW RESPONSE BODY: ' + res.getBody());

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {

            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> records = (List<Object>) response.get('records');

            System.debug('📊 TOTAL FLOW RECORDS: ' + (records != null ? records.size() : 0));

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    Boolean isActive  = (Boolean) rec.get('IsActive');
                    String  label     = (String)  rec.get('Label');
                    String  apiName   = (String)  rec.get('ApiName');
                    String  procType  = (String)  rec.get('ProcessType');
                    String  nsPrefix  = (String)  rec.get('NamespacePrefix');

                    String flowLabel = label + ' [' + procType + '] (' + apiName + ')' +
                                       (String.isNotBlank(nsPrefix) ? ' [ns:' + nsPrefix + ']' : '');

                    if (isActive) {
                        activeFlows.add(flowLabel);
                    } else {
                        inactiveFlows.add(flowLabel);
                    }

                    // Apply namespace filter
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

        } else {
            System.debug('❌ FLOW STATUS CODE : ' + res.getStatusCode());
            System.debug('❌ FLOW ERROR BODY  : ' + res.getBody());
        }

        System.debug('Total Flows   : ' + (activeFlows.size() + inactiveFlows.size()));
        System.debug('Active Flows  : ' + activeFlows.size());
        System.debug('Inactive Flows: ' + inactiveFlows.size());
        System.debug('Filtered      : ' + (filteredActiveFlows.size() + filteredInactiveFlows.size()));

        FlowSummary summary              = new FlowSummary();
        summary.active                   = activeFlows.size();
        summary.inactive                 = inactiveFlows.size();
        summary.total                    = summary.active + summary.inactive;
        summary.activeFlows              = activeFlows;
        summary.inactiveFlows            = inactiveFlows;
        summary.filteredActiveFlows      = filteredActiveFlows;
        summary.filteredInactiveFlows    = filteredInactiveFlows;
        summary.filteredTotal            = filteredActiveFlows.size() + filteredInactiveFlows.size();
        summary.namespaceFilter          = namespaceFilter;

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

        Map<String, Object> flowDef = (Map<String, Object>) lookupRecords[0];
        String durableId            = (String)  flowDef.get('DurableId');
        Boolean isActive            = (Boolean) flowDef.get('IsActive');
        String flowLabel            = (String)  flowDef.get('Label');

        if (isActive) {
            String deactivateBody = '{"Metadata": {"activeVersionNumber": 0}}';

            HttpRequest deactivateReq = new HttpRequest();
            deactivateReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/FlowDefinition/' + durableId);
            deactivateReq.setMethod('PATCH');
            deactivateReq.setHeader('Content-Type', 'application/json');
            deactivateReq.setBody(deactivateBody);

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
            Map<String, Object> vRec = (Map<String, Object>) vObj;
            String versionId         = (String) vRec.get('Id');

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
            result.message = 'Flow "' + flowLabel + '" (' + apiName + ') and all its ' +
                             versionRecords.size() + ' version(s) were successfully deleted.';
        }

        return result;
    }

    // ===============================
    // GET APEX CLASSES + DETECT UNUSED
    // ===============================
    public static ApexSummary getApexClasses(String namespaceFilter) {

        Http http = new Http();

        String countSoql = 'SELECT Id FROM ApexClass';
        HttpRequest countReq = new HttpRequest();
        countReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(countSoql, 'UTF-8'));
        countReq.setMethod('GET');
        countReq.setHeader('Content-Type', 'application/json');
        HttpResponse countRes = http.send(countReq);
        Integer trueTotal = 0;
        if (countRes.getStatusCode() >= 200 && countRes.getStatusCode() < 300) {
            Map<String, Object> countResponse =
                (Map<String, Object>) JSON.deserializeUntyped(countRes.getBody());
            Object totalSize = countResponse.get('totalSize');
            if (totalSize != null) {
                trueTotal = Integer.valueOf(String.valueOf(totalSize));
            }
        }

        String stdSoql = 'SELECT Id, Name, Status, LengthWithoutComments, LastModifiedDate ' +
                         'FROM ApexClass ' +
                         'WHERE NamespacePrefix != null ' +
                         'ORDER BY Name ASC';

        HttpRequest stdReq = new HttpRequest();
        stdReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(stdSoql, 'UTF-8'));
        stdReq.setMethod('GET');
        stdReq.setHeader('Content-Type', 'application/json');

        HttpResponse stdRes = http.send(stdReq);

        List<String> standardClassNames = new List<String>();
        if (stdRes.getStatusCode() >= 200 && stdRes.getStatusCode() < 300) {
            Map<String, Object> stdResponse =
                (Map<String, Object>) JSON.deserializeUntyped(stdRes.getBody());
            List<Object> stdRecords = (List<Object>) stdResponse.get('records');
            if (stdRecords != null) {
                for (Object obj : stdRecords) {
                    Map<String, Object> rec = (Map<String, Object>) obj;
                    String stdName = (String) rec.get('Name');
                    if (String.isNotBlank(stdName)) {
                        standardClassNames.add(stdName);
                    }
                }
            }
        }

        String soql = 'SELECT Id, Name, Status, LengthWithoutComments, LastModifiedDate, SymbolTable ' +
                      'FROM ApexClass ' +
                      'WHERE NamespacePrefix = null ' +
                      'ORDER BY Name ASC';

        HttpRequest classReq = new HttpRequest();
        classReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        classReq.setMethod('GET');
        classReq.setHeader('Content-Type', 'application/json');

        HttpResponse classRes = http.send(classReq);

        Map<String, ApexClassInfo> allClassMap    = new Map<String, ApexClassInfo>();
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
                                Map<String, Object> method = (Map<String, Object>) mObj;
                                List<Object> annotations = (List<Object>) method.get('annotations');
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
                                Map<String, Object> ic = (Map<String, Object>) icObj;
                                List<Object> icMethods = (List<Object>) ic.get('methods');
                                if (icMethods != null) {
                                    for (Object mObj : icMethods) {
                                        Map<String, Object> method = (Map<String, Object>) mObj;
                                        List<Object> annotations = (List<Object>) method.get('annotations');
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

        String depSoql = 'SELECT RefMetadataComponentName, RefMetadataComponentType ' +
                         'FROM MetadataComponentDependency ' +
                         'WHERE RefMetadataComponentType = \'ApexClass\'';

        HttpRequest depReq = new HttpRequest();
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
                    Map<String, Object> rec = (Map<String, Object>) obj;
                    String refName = (String) rec.get('RefMetadataComponentName');
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

        List<ApexClassInfo> unusedClasses  = new List<ApexClassInfo>();
        List<String>        usedClassNames = new List<String>();
        List<String>        testClassNames = new List<String>();
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

        // Namespace filter — applied across ALL custom classes (used + unused)
        // NamespacePrefix is fetched in stdSoql (non-null) and custom classes have null prefix.
        // For namespace filter on custom classes, we cross-reference standardClassNames list:
        // classes in standardClassNames came from NamespacePrefix != null query, so we match by name.
        // For allClassMap entries (custom, NamespacePrefix = null), filter only matches blank/empty namespace.
        if (String.isNotBlank(namespaceFilter)) {
            // Standard/package classes that match the namespace
            for (String stdName : allClassMap.keySet() == null ? new List<String>() : new List<String>()) {}
            // Pull from standardClassNames list for namespace match
            for (String stdName : standardClassNames) {
                ApexClassInfo info = new ApexClassInfo();
                info.name   = stdName;
                info.status = 'Active';
                info.linesOfCode = 0;
                filteredClasses.add(info);
            }
        } else {
            // No filter — filteredClasses = all custom classes
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

        String lookupSoql = 'SELECT Id, Name ' +
                            'FROM ApexClass ' +
                            'WHERE Name = \'' + String.escapeSingleQuotes(className) + '\' ' +
                            'AND NamespacePrefix = null ' +
                            'LIMIT 1';

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

        Map<String, Object> classDef = (Map<String, Object>) lookupRecords[0];
        String classId               = (String) classDef.get('Id');

        HttpRequest deleteReq = new HttpRequest();
        deleteReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/ApexClass/' + classId);
        deleteReq.setMethod('DELETE');
        deleteReq.setHeader('Content-Type', 'application/json');

        HttpResponse deleteRes = http.send(deleteReq);

        if (deleteRes.getStatusCode() == 204 || deleteRes.getStatusCode() == 200) {
            result.success = true;
            result.message = 'Apex class "' + className + '" (Id: ' + classId + ') was successfully deleted.';
        } else {
            result.success = false;
            result.message = 'Failed to delete Apex class "' + className + '". HTTP ' +
                              deleteRes.getStatusCode() + ': ' + deleteRes.getBody();
        }

        return result;
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
        // Namespace filter support
        public Integer           filteredTotal;
        public List<TriggerInfo> filteredTriggers;
        public String            namespaceFilter;
    }

    // ===============================
    // GET TRIGGERS + DETECT UNUSED
    // ===============================
    public static TriggerSummary getTriggers(String namespaceFilter) {

        Http http = new Http();

        String classSoql = 'SELECT Name FROM ApexClass WHERE NamespacePrefix = null';

        HttpRequest classReq = new HttpRequest();
        classReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(classSoql, 'UTF-8'));
        classReq.setMethod('GET');
        classReq.setHeader('Content-Type', 'application/json');

        HttpResponse classRes = http.send(classReq);

        Set<String> existingClassNames = new Set<String>();

        if (classRes.getStatusCode() >= 200 && classRes.getStatusCode() < 300) {
            Map<String, Object> classResponse =
                (Map<String, Object>) JSON.deserializeUntyped(classRes.getBody());
            List<Object> classRecords = (List<Object>) classResponse.get('records');
            if (classRecords != null) {
                for (Object obj : classRecords) {
                    Map<String, Object> rec = (Map<String, Object>) obj;
                    String cName = (String) rec.get('Name');
                    if (String.isNotBlank(cName)) {
                        existingClassNames.add(cName.toLowerCase());
                    }
                }
            }
        }

        String soql = 'SELECT Id, Name, TableEnumOrId, Status, Body, LengthWithoutComments, LastModifiedDate, NamespacePrefix ' +
                      'FROM ApexTrigger ' +
                      'WHERE NamespacePrefix = null ' +
                      'ORDER BY Name ASC';

        HttpRequest trigReq = new HttpRequest();
        trigReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        trigReq.setMethod('GET');
        trigReq.setHeader('Content-Type', 'application/json');

        HttpResponse trigRes = http.send(trigReq);

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
                            String cleanBody = body.replaceAll('[^a-zA-Z0-9_]', ' ');
                            List<String> tokens = cleanBody.split('\\s+');

                            for (String token : tokens) {
                                if (String.isNotBlank(token) && token.length() > 2) {
                                    if (existingClassNames.contains(token.toLowerCase())) {
                                        referencesClass = true;
                                        referencedClass = token;
                                        break;
                                    }
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

        // Build filtered list — all triggers matching namespace (active + inactive)
        List<TriggerInfo> allTriggers = new List<TriggerInfo>();
        allTriggers.addAll(activeTriggers);
        for (TriggerInfo t : inactiveTriggers) {
            // inactiveTriggers are already in activeTriggers only if isActive, so add only truly inactive
            if (!t.isActive) allTriggers.add(t);
        }
        for (TriggerInfo t : allTriggers) {
            Boolean matchesFilter = String.isBlank(namespaceFilter) ||
                namespaceFilter.equalsIgnoreCase(t.namespacePrefix == null ? '' : t.namespacePrefix);
            if (matchesFilter) {
                filteredTriggers.add(t);
            }
        }

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

        String lookupSoql = 'SELECT Id, Name, TableEnumOrId, Status ' +
                            'FROM ApexTrigger ' +
                            'WHERE Name = \'' + String.escapeSingleQuotes(triggerName) + '\' ' +
                            'AND NamespacePrefix = null ' +
                            'LIMIT 1';

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

        Map<String, Object> trigDef  = (Map<String, Object>) lookupRecords[0];
        String triggerId             = (String) trigDef.get('Id');
        String objectName            = (String) trigDef.get('TableEnumOrId');

        HttpRequest deleteReq = new HttpRequest();
        deleteReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/ApexTrigger/' + triggerId);
        deleteReq.setMethod('DELETE');
        deleteReq.setHeader('Content-Type', 'application/json');

        HttpResponse deleteRes = http.send(deleteReq);

        if (deleteRes.getStatusCode() == 204 || deleteRes.getStatusCode() == 200) {
            result.success = true;
            result.message = 'Trigger "' + triggerName + '" on ' + objectName +
                             ' (Id: ' + triggerId + ') was successfully deleted.';
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
    // Fetches all Lightning Web Components from the org.
    // Supports optional namespace filtering (e.g., 'ITSms', 'FinanceApp').
    // Pass null or empty string to get ALL components.
    // ===============================
    public static LwcSummary getLwcComponents(String namespaceFilter) {

        Http http = new Http();

        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate, ApiVersion ' +
                      'FROM LightningComponentBundle ' +
                      'ORDER BY DeveloperName ASC';

        System.debug('🔍 LWC SOQL: ' + soql);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        System.debug('📡 LWC STATUS CODE: ' + res.getStatusCode());

        List<LwcComponentInfo> allComponents      = new List<LwcComponentInfo>();
        List<LwcComponentInfo> filteredComponents = new List<LwcComponentInfo>();
        Integer withNamespace    = 0;
        Integer withoutNamespace = 0;

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {

            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> records = (List<Object>) response.get('records');

            System.debug('📊 TOTAL LWC RECORDS: ' + (records != null ? records.size() : 0));

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    LwcComponentInfo info = new LwcComponentInfo();
                    info.id              = (String) rec.get('Id');
                    info.name            = (String) rec.get('DeveloperName');
                    info.namespacePrefix = (String) rec.get('NamespacePrefix');
                    info.lastModifiedDate= (String) rec.get('LastModifiedDate');
                    info.apiVersion      = rec.get('ApiVersion') != null
                                            ? String.valueOf(rec.get('ApiVersion'))
                                            : '';

                    allComponents.add(info);

                    if (String.isNotBlank(info.namespacePrefix)) {
                        withNamespace++;
                    } else {
                        withoutNamespace++;
                    }

                    // Apply namespace filter if provided
                    Boolean matchesFilter = String.isBlank(namespaceFilter) ||
                        namespaceFilter.equalsIgnoreCase(info.namespacePrefix == null ? '' : info.namespacePrefix);

                    if (matchesFilter) {
                        filteredComponents.add(info);
                    }
                }
            }

        } else {
            System.debug('❌ LWC STATUS CODE : ' + res.getStatusCode());
            System.debug('❌ LWC ERROR BODY  : ' + res.getBody());
        }

        LwcSummary summary         = new LwcSummary();
        summary.total              = allComponents.size();
        summary.withNamespace      = withNamespace;
        summary.withoutNamespace   = withoutNamespace;
        summary.allComponents      = allComponents;
        summary.filteredComponents = filteredComponents;
        summary.namespaceFilter    = namespaceFilter;

        System.debug('Total LWC       : ' + summary.total);
        System.debug('With Namespace  : ' + summary.withNamespace);
        System.debug('Filtered        : ' + summary.filteredComponents.size());

        return summary;
    }

    // ===============================
    // GET AURA COMPONENTS
    // ===============================
    // Fetches all Aura (Lightning) Components from the org.
    // Supports optional namespace filtering (e.g., 'ITSms', 'FinanceApp').
    // Pass null or empty string to get ALL components.
    // ===============================
    public static AuraSummary getAuraComponents(String namespaceFilter) {

        Http http = new Http();

        String soql = 'SELECT Id, DeveloperName, NamespacePrefix, LastModifiedDate, ApiVersion ' +
                      'FROM AuraDefinitionBundle ' +
                      'ORDER BY DeveloperName ASC';

        System.debug('🔍 AURA SOQL: ' + soql);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        System.debug('📡 AURA STATUS CODE: ' + res.getStatusCode());

        List<AuraComponentInfo> allComponents      = new List<AuraComponentInfo>();
        List<AuraComponentInfo> filteredComponents = new List<AuraComponentInfo>();
        Integer withNamespace    = 0;
        Integer withoutNamespace = 0;

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {

            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> records = (List<Object>) response.get('records');

            System.debug('📊 TOTAL AURA RECORDS: ' + (records != null ? records.size() : 0));

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    AuraComponentInfo info = new AuraComponentInfo();
                    info.id               = (String) rec.get('Id');
                    info.name             = (String) rec.get('DeveloperName');
                    info.namespacePrefix  = (String) rec.get('NamespacePrefix');
                    info.lastModifiedDate = (String) rec.get('LastModifiedDate');
                    info.apiVersion       = rec.get('ApiVersion') != null
                                             ? String.valueOf(rec.get('ApiVersion'))
                                             : '';

                    allComponents.add(info);

                    if (String.isNotBlank(info.namespacePrefix)) {
                        withNamespace++;
                    } else {
                        withoutNamespace++;
                    }

                    Boolean matchesFilter = String.isBlank(namespaceFilter) ||
                        namespaceFilter.equalsIgnoreCase(info.namespacePrefix == null ? '' : info.namespacePrefix);

                    if (matchesFilter) {
                        filteredComponents.add(info);
                    }
                }
            }

        } else {
            System.debug('❌ AURA STATUS CODE : ' + res.getStatusCode());
            System.debug('❌ AURA ERROR BODY  : ' + res.getBody());
        }

        AuraSummary summary         = new AuraSummary();
        summary.total               = allComponents.size();
        summary.withNamespace       = withNamespace;
        summary.withoutNamespace    = withoutNamespace;
        summary.allComponents       = allComponents;
        summary.filteredComponents  = filteredComponents;
        summary.namespaceFilter     = namespaceFilter;

        System.debug('Total Aura       : ' + summary.total);
        System.debug('With Namespace   : ' + summary.withNamespace);
        System.debug('Filtered         : ' + summary.filteredComponents.size());

        return summary;
    }

    // ===============================
    // GET PROFILES + DETECT UNUSED
    // ===============================
    // Strategy:
    //   1. Query all Profiles
    //   2. Query User records grouped by ProfileId to get assignment counts
    //   3. Any Profile with 0 assigned users = Unused
    // ===============================
    public static ProfileSummary getProfiles() {

        Http http = new Http();

        // ---------------------------------------------------
        // STEP 1 — Fetch all Profiles
        // ---------------------------------------------------
        String profileSoql = 'SELECT Id, Name, UserLicenseId, UserLicense.Name ' +
                             'FROM Profile ' +
                             'ORDER BY Name ASC';

        HttpRequest profileReq = new HttpRequest();
        profileReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
            EncodingUtil.urlEncode(profileSoql, 'UTF-8'));
        profileReq.setMethod('GET');
        profileReq.setHeader('Content-Type', 'application/json');

        HttpResponse profileRes = http.send(profileReq);

        System.debug('📡 PROFILE STATUS CODE: ' + profileRes.getStatusCode());

        Map<String, ProfileInfo> profileMap = new Map<String, ProfileInfo>();

        if (profileRes.getStatusCode() >= 200 && profileRes.getStatusCode() < 300) {
            Map<String, Object> profileResponse =
                (Map<String, Object>) JSON.deserializeUntyped(profileRes.getBody());
            List<Object> profileRecords = (List<Object>) profileResponse.get('records');

            if (profileRecords != null) {
                for (Object obj : profileRecords) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    ProfileInfo info = new ProfileInfo();
                    info.id               = (String) rec.get('Id');
                    info.name             = (String) rec.get('Name');
                    info.assignedUserCount = 0;

                    // Retrieve nested UserLicense.Name
                    Map<String, Object> licMap = (Map<String, Object>) rec.get('UserLicense');
                    info.userLicenseName = licMap != null ? (String) licMap.get('Name') : 'Unknown';

                    profileMap.put(info.id, info);
                }
            }
        }

        System.debug('📊 TOTAL PROFILES: ' + profileMap.size());

        // ---------------------------------------------------
        // STEP 2 — Count users per Profile
        // ---------------------------------------------------
        String userSoql = 'SELECT ProfileId, COUNT(Id) userCount ' +
                          'FROM User ' +
                          'WHERE IsActive = true ' +
                          'GROUP BY ProfileId';

        HttpRequest userReq = new HttpRequest();
        userReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
            EncodingUtil.urlEncode(userSoql, 'UTF-8'));
        userReq.setMethod('GET');
        userReq.setHeader('Content-Type', 'application/json');

        HttpResponse userRes = http.send(userReq);

        System.debug('📡 USER COUNT STATUS CODE: ' + userRes.getStatusCode());

        if (userRes.getStatusCode() >= 200 && userRes.getStatusCode() < 300) {
            Map<String, Object> userResponse =
                (Map<String, Object>) JSON.deserializeUntyped(userRes.getBody());
            List<Object> userRecords = (List<Object>) userResponse.get('records');

            if (userRecords != null) {
                for (Object obj : userRecords) {
                    Map<String, Object> rec = (Map<String, Object>) obj;
                    String profileId = (String) rec.get('ProfileId');
                    Integer cnt      = Integer.valueOf(String.valueOf(rec.get('userCount')));

                    if (profileMap.containsKey(profileId)) {
                        profileMap.get(profileId).assignedUserCount = cnt;
                    }
                }
            }
        }

        // ---------------------------------------------------
        // STEP 3 — Classify used vs unused
        // ---------------------------------------------------
        List<ProfileInfo> unusedProfiles = new List<ProfileInfo>();
        List<ProfileInfo> usedProfiles   = new List<ProfileInfo>();

        for (ProfileInfo info : profileMap.values()) {
            if (info.assignedUserCount == 0) {
                unusedProfiles.add(info);
            } else {
                usedProfiles.add(info);
            }
        }

        ProfileSummary summary   = new ProfileSummary();
        summary.total            = profileMap.size();
        summary.unused           = unusedProfiles.size();
        summary.used             = usedProfiles.size();
        summary.unusedProfiles   = unusedProfiles;
        summary.usedProfiles     = usedProfiles;

        System.debug('Total Profiles  : ' + summary.total);
        System.debug('Used Profiles   : ' + summary.used);
        System.debug('Unused Profiles : ' + summary.unused);

        return summary;
    }

    // ===============================
    // GET PERMISSION SETS + DETECT UNUSED
    // ===============================
    // Strategy:
    //   1. Query all custom PermissionSets (IsOwnedByProfile = false)
    //   2. Query PermissionSetAssignment to get count per PermSet
    //   3. Any PermSet with 0 assignments = Unused
    // ===============================
    public static PermissionSetSummary getPermissionSets() {

        Http http = new Http();

        // ---------------------------------------------------
        // STEP 1 — Fetch all custom Permission Sets
        // ---------------------------------------------------
        String permSetSoql = 'SELECT Id, Name, Label, IsCustom, NamespacePrefix ' +
                             'FROM PermissionSet ' +
                             'WHERE IsOwnedByProfile = false ' +
                             'ORDER BY Label ASC';

        HttpRequest permSetReq = new HttpRequest();
        permSetReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
            EncodingUtil.urlEncode(permSetSoql, 'UTF-8'));
        permSetReq.setMethod('GET');
        permSetReq.setHeader('Content-Type', 'application/json');

        HttpResponse permSetRes = http.send(permSetReq);

        System.debug('📡 PERM SET STATUS CODE: ' + permSetRes.getStatusCode());

        Map<String, PermissionSetInfo> permSetMap = new Map<String, PermissionSetInfo>();

        if (permSetRes.getStatusCode() >= 200 && permSetRes.getStatusCode() < 300) {
            Map<String, Object> permSetResponse =
                (Map<String, Object>) JSON.deserializeUntyped(permSetRes.getBody());
            List<Object> permSetRecords = (List<Object>) permSetResponse.get('records');

            if (permSetRecords != null) {
                for (Object obj : permSetRecords) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    PermissionSetInfo info  = new PermissionSetInfo();
                    info.id                 = (String)  rec.get('Id');
                    info.name               = (String)  rec.get('Name');
                    info.label              = (String)  rec.get('Label');
                    info.isCustom           = (Boolean) rec.get('IsCustom');
                    info.namespacePrefix    = (String)  rec.get('NamespacePrefix');
                    info.assignmentCount    = 0;

                    permSetMap.put(info.id, info);
                }
            }
        }

        System.debug('📊 TOTAL PERM SETS: ' + permSetMap.size());

        // ---------------------------------------------------
        // STEP 2 — Count assignments per Permission Set
        // ---------------------------------------------------
        String assignSoql = 'SELECT PermissionSetId, COUNT(Id) assignCount ' +
                            'FROM PermissionSetAssignment ' +
                            'GROUP BY PermissionSetId';

        HttpRequest assignReq = new HttpRequest();
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
                    Map<String, Object> rec = (Map<String, Object>) obj;
                    String psId  = (String) rec.get('PermissionSetId');
                    Integer cnt  = Integer.valueOf(String.valueOf(rec.get('assignCount')));

                    if (permSetMap.containsKey(psId)) {
                        permSetMap.get(psId).assignmentCount = cnt;
                    }
                }
            }
        }

        // ---------------------------------------------------
        // STEP 3 — Classify used vs unused
        // ---------------------------------------------------
        List<PermissionSetInfo> unusedPermSets = new List<PermissionSetInfo>();
        List<PermissionSetInfo> usedPermSets   = new List<PermissionSetInfo>();

        for (PermissionSetInfo info : permSetMap.values()) {
            if (info.assignmentCount == 0) {
                unusedPermSets.add(info);
            } else {
                usedPermSets.add(info);
            }
        }

        PermissionSetSummary summary = new PermissionSetSummary();
        summary.total                = permSetMap.size();
        summary.unused               = unusedPermSets.size();
        summary.used                 = usedPermSets.size();
        summary.unusedPermSets       = unusedPermSets;
        summary.usedPermSets         = usedPermSets;

        System.debug('Total Perm Sets  : ' + summary.total);
        System.debug('Used Perm Sets   : ' + summary.used);
        System.debug('Unused Perm Sets : ' + summary.unused);

        return summary;
    }

    // ===============================
    // GET CUSTOM FIELDS
    // ===============================
    // Fetches all custom fields from the org via Tooling API.
    // Supports optional namespace filtering (e.g., 'ITSms').
    // Pass null or empty string to get ALL fields.
    // ===============================
    public static CustomFieldSummary getCustomFields(String namespaceFilter) {

        Http http = new Http();

        String soql = 'SELECT Id, DeveloperName, EntityDefinitionId, DataType, NamespacePrefix, LastModifiedDate ' +
                      'FROM CustomField ' +
                      'ORDER BY EntityDefinitionId, DeveloperName ASC';

        System.debug('🔍 CUSTOM FIELD SOQL: ' + soql);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        System.debug('📡 CUSTOM FIELD STATUS CODE: ' + res.getStatusCode());

        List<CustomFieldInfo> allFields      = new List<CustomFieldInfo>();
        List<CustomFieldInfo> filteredFields = new List<CustomFieldInfo>();
        Integer withNamespace    = 0;
        Integer withoutNamespace = 0;

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {

            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> records = (List<Object>) response.get('records');

            System.debug('📊 TOTAL CUSTOM FIELD RECORDS: ' + (records != null ? records.size() : 0));

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    CustomFieldInfo info  = new CustomFieldInfo();
                    info.id              = (String) rec.get('Id');
                    info.name            = (String) rec.get('DeveloperName');
                    info.objectName      = (String) rec.get('EntityDefinitionId');
                    info.dataType        = (String) rec.get('DataType');
                    info.namespacePrefix = (String) rec.get('NamespacePrefix');
                    info.lastModifiedDate= (String) rec.get('LastModifiedDate');

                    allFields.add(info);

                    if (String.isNotBlank(info.namespacePrefix)) {
                        withNamespace++;
                    } else {
                        withoutNamespace++;
                    }

                    Boolean matchesFilter = String.isBlank(namespaceFilter) ||
                        namespaceFilter.equalsIgnoreCase(info.namespacePrefix == null ? '' : info.namespacePrefix);

                    if (matchesFilter) {
                        filteredFields.add(info);
                    }
                }
            }

        } else {
            System.debug('❌ CUSTOM FIELD STATUS CODE : ' + res.getStatusCode());
            System.debug('❌ CUSTOM FIELD ERROR BODY  : ' + res.getBody());
        }

        CustomFieldSummary summary   = new CustomFieldSummary();
        summary.total                = allFields.size();
        summary.withNamespace        = withNamespace;
        summary.withoutNamespace     = withoutNamespace;
        summary.allFields            = allFields;
        summary.filteredFields       = filteredFields;
        summary.namespaceFilter      = namespaceFilter;

        System.debug('Total Fields    : ' + summary.total);
        System.debug('With Namespace  : ' + summary.withNamespace);
        System.debug('Filtered        : ' + summary.filteredFields.size());

        return summary;
    }

    // ===============================
    // GET CUSTOM OBJECTS
    // ===============================
    // Fetches all custom objects from the org via Tooling API.
    // Supports optional namespace filtering (e.g., 'ITSms').
    // Pass null or empty string to get ALL objects.
    // ===============================
    public static CustomObjectSummary getCustomObjects(String namespaceFilter) {

        Http http = new Http();

        String soql = 'SELECT Id, DeveloperName, Label, NamespacePrefix, LastModifiedDate ' +
                      'FROM CustomObject ' +
                      'ORDER BY DeveloperName ASC';

        System.debug('🔍 CUSTOM OBJECT SOQL: ' + soql);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        System.debug('📡 CUSTOM OBJECT STATUS CODE: ' + res.getStatusCode());

        List<CustomObjectInfo> allObjects      = new List<CustomObjectInfo>();
        List<CustomObjectInfo> filteredObjects = new List<CustomObjectInfo>();
        Integer withNamespace    = 0;
        Integer withoutNamespace = 0;

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {

            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> records = (List<Object>) response.get('records');

            System.debug('📊 TOTAL CUSTOM OBJECT RECORDS: ' + (records != null ? records.size() : 0));

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    CustomObjectInfo info = new CustomObjectInfo();
                    info.id               = (String) rec.get('Id');
                    info.name             = (String) rec.get('DeveloperName');
                    info.label            = (String) rec.get('Label');
                    info.namespacePrefix  = (String) rec.get('NamespacePrefix');
                    info.lastModifiedDate = (String) rec.get('LastModifiedDate');

                    allObjects.add(info);

                    if (String.isNotBlank(info.namespacePrefix)) {
                        withNamespace++;
                    } else {
                        withoutNamespace++;
                    }

                    Boolean matchesFilter = String.isBlank(namespaceFilter) ||
                        namespaceFilter.equalsIgnoreCase(info.namespacePrefix == null ? '' : info.namespacePrefix);

                    if (matchesFilter) {
                        filteredObjects.add(info);
                    }
                }
            }

        } else {
            System.debug('❌ CUSTOM OBJECT STATUS CODE : ' + res.getStatusCode());
            System.debug('❌ CUSTOM OBJECT ERROR BODY  : ' + res.getBody());
        }

        CustomObjectSummary summary  = new CustomObjectSummary();
        summary.total                = allObjects.size();
        summary.withNamespace        = withNamespace;
        summary.withoutNamespace     = withoutNamespace;
        summary.allObjects           = allObjects;
        summary.filteredObjects      = filteredObjects;
        summary.namespaceFilter      = namespaceFilter;

        System.debug('Total Objects   : ' + summary.total);
        System.debug('With Namespace  : ' + summary.withNamespace);
        System.debug('Filtered        : ' + summary.filteredObjects.size());

        return summary;
    }

    // ===============================
    // GET VALIDATION RULES
    // ===============================
    // Fetches all Validation Rules from the org via Tooling API.
    // Supports optional namespace filtering (e.g., 'ITSms').
    // Pass null or empty string to get ALL validation rules.
    // ===============================
    public static ValidationRuleSummary getValidationRules(String namespaceFilter) {

        Http http = new Http();

        String soql = 'SELECT Id, ValidationName, EntityDefinitionId, Active, ErrorMessage, NamespacePrefix, LastModifiedDate ' +
                      'FROM ValidationRule ' +
                      'ORDER BY EntityDefinitionId, ValidationName ASC';

        System.debug('🔍 VALIDATION RULE SOQL: ' + soql);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);

        System.debug('📡 VALIDATION RULE STATUS CODE: ' + res.getStatusCode());

        List<ValidationRuleInfo> activeRules   = new List<ValidationRuleInfo>();
        List<ValidationRuleInfo> inactiveRules = new List<ValidationRuleInfo>();
        List<ValidationRuleInfo> filteredRules = new List<ValidationRuleInfo>();

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {

            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> records = (List<Object>) response.get('records');

            System.debug('📊 TOTAL VALIDATION RULE RECORDS: ' + (records != null ? records.size() : 0));

            if (records != null) {
                for (Object obj : records) {
                    Map<String, Object> rec = (Map<String, Object>) obj;

                    ValidationRuleInfo info = new ValidationRuleInfo();
                    info.id               = (String)  rec.get('Id');
                    info.name             = (String)  rec.get('ValidationName');
                    info.objectName       = (String)  rec.get('EntityDefinitionId');
                    info.isActive         = (Boolean) rec.get('Active');
                    info.errorMessage     = (String)  rec.get('ErrorMessage');
                    info.namespacePrefix  = (String)  rec.get('NamespacePrefix');
                    info.lastModifiedDate = (String)  rec.get('LastModifiedDate');

                    if (info.isActive) {
                        activeRules.add(info);
                    } else {
                        inactiveRules.add(info);
                    }

                    Boolean matchesFilter = String.isBlank(namespaceFilter) ||
                        namespaceFilter.equalsIgnoreCase(info.namespacePrefix == null ? '' : info.namespacePrefix);

                    if (matchesFilter) {
                        filteredRules.add(info);
                    }
                }
            }

        } else {
            System.debug('❌ VALIDATION RULE STATUS CODE : ' + res.getStatusCode());
            System.debug('❌ VALIDATION RULE ERROR BODY  : ' + res.getBody());
        }

        Integer total = activeRules.size() + inactiveRules.size();

        ValidationRuleSummary summary = new ValidationRuleSummary();
        summary.total                 = total;
        summary.active                = activeRules.size();
        summary.inactive              = inactiveRules.size();
        summary.activeRules           = activeRules;
        summary.inactiveRules         = inactiveRules;
        summary.filteredRules         = filteredRules;
        summary.namespaceFilter       = namespaceFilter;

        System.debug('Total Validation Rules  : ' + summary.total);
        System.debug('Active Rules            : ' + summary.active);
        System.debug('Inactive Rules          : ' + summary.inactive);
        System.debug('Filtered (namespace)    : ' + summary.filteredRules.size());

        return summary;
    }

    // ===============================
    // DELETE LWC COMPONENT BY NAME
    // ===============================
    public static DeleteResult deleteLwcByName(String componentName) {
        Http http = new Http();
        DeleteResult result = new DeleteResult();
        String soql = 'SELECT Id FROM LightningComponentBundle WHERE DeveloperName = \''+
            String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false; result.message = 'Lookup failed for LWC "' + componentName + '". HTTP ' + res.getStatusCode(); return result;
        }
        List<Object> records = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(res.getBody())).get('records');
        if (records == null || records.isEmpty()) {
            result.success = false; result.message = 'No LWC found: ' + componentName; return result;
        }
        String cId = (String)((Map<String,Object>)records[0]).get('Id');
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/LightningComponentBundle/' + cId);
        del.setMethod('DELETE'); del.setHeader('Content-Type', 'application/json');
        HttpResponse dr = http.send(del);
        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true; result.message = 'LWC "' + componentName + '" (Id: ' + cId + ') deleted successfully.';
        } else {
            result.success = false; result.message = 'Failed to delete LWC "' + componentName + '". HTTP ' + dr.getStatusCode() + ': ' + dr.getBody();
        }
        return result;
    }

    // ===============================
    // DELETE AURA COMPONENT BY NAME
    // ===============================
    public static DeleteResult deleteAuraByName(String componentName) {
        Http http = new Http();
        DeleteResult result = new DeleteResult();
        String soql = 'SELECT Id FROM AuraDefinitionBundle WHERE DeveloperName = \''+
            String.escapeSingleQuotes(componentName) + '\' LIMIT 1';
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false; result.message = 'Lookup failed for Aura "' + componentName + '". HTTP ' + res.getStatusCode(); return result;
        }
        List<Object> records = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(res.getBody())).get('records');
        if (records == null || records.isEmpty()) {
            result.success = false; result.message = 'No Aura component found: ' + componentName; return result;
        }
        String cId = (String)((Map<String,Object>)records[0]).get('Id');
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/AuraDefinitionBundle/' + cId);
        del.setMethod('DELETE'); del.setHeader('Content-Type', 'application/json');
        HttpResponse dr = http.send(del);
        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true; result.message = 'Aura component "' + componentName + '" (Id: ' + cId + ') deleted successfully.';
        } else {
            result.success = false; result.message = 'Failed to delete Aura "' + componentName + '". HTTP ' + dr.getStatusCode() + ': ' + dr.getBody();
        }
        return result;
    }

    // ===============================
    // DELETE CUSTOM FIELD BY OBJECT.FIELD
    // ===============================
    public static DeleteResult deleteCustomFieldByName(String objectName, String fieldName) {
        Http http = new Http();
        DeleteResult result = new DeleteResult();
        String soql = 'SELECT Id FROM CustomField WHERE DeveloperName = \''+
            String.escapeSingleQuotes(fieldName) + '\' AND EntityDefinitionId = \''+
            String.escapeSingleQuotes(objectName) + '\' LIMIT 1';
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false; result.message = 'Lookup failed for Field "'+objectName+'.'+fieldName+'". HTTP '+res.getStatusCode(); return result;
        }
        List<Object> records = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(res.getBody())).get('records');
        if (records == null || records.isEmpty()) {
            result.success = false; result.message = 'No Custom Field found: '+objectName+'.'+fieldName; return result;
        }
        String fId = (String)((Map<String,Object>)records[0]).get('Id');
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/CustomField/' + fId);
        del.setMethod('DELETE'); del.setHeader('Content-Type', 'application/json');
        HttpResponse dr = http.send(del);
        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true; result.message = 'Custom field "'+objectName+'.'+fieldName+'" deleted.';
        } else {
            result.success = false; result.message = 'Failed to delete field "'+objectName+'.'+fieldName+'". HTTP '+dr.getStatusCode()+': '+dr.getBody();
        }
        return result;
    }

    // ===============================
    // DELETE CUSTOM OBJECT BY NAME
    // ===============================
    public static DeleteResult deleteCustomObjectByName(String objectName) {
        Http http = new Http();
        DeleteResult result = new DeleteResult();
        String soql = 'SELECT Id FROM CustomObject WHERE DeveloperName = \''+
            String.escapeSingleQuotes(objectName) + '\' LIMIT 1';
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false; result.message = 'Lookup failed for Object "' + objectName + '". HTTP ' + res.getStatusCode(); return result;
        }
        List<Object> records = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(res.getBody())).get('records');
        if (records == null || records.isEmpty()) {
            result.success = false; result.message = 'No Custom Object found: ' + objectName; return result;
        }
        String oId = (String)((Map<String,Object>)records[0]).get('Id');
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/CustomObject/' + oId);
        del.setMethod('DELETE'); del.setHeader('Content-Type', 'application/json');
        HttpResponse dr = http.send(del);
        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true; result.message = 'Custom Object "' + objectName + '" deleted. All records permanently removed.';
        } else {
            result.success = false; result.message = 'Failed to delete Object "' + objectName + '". HTTP ' + dr.getStatusCode() + ': ' + dr.getBody();
        }
        return result;
    }

    // ===============================
    // DELETE VALIDATION RULE BY OBJECT + RULE NAME
    // ===============================
    public static DeleteResult deleteValidationRuleByName(String objectName, String ruleName) {
        Http http = new Http();
        DeleteResult result = new DeleteResult();
        String soql = 'SELECT Id FROM ValidationRule WHERE ValidationName = \''+
            String.escapeSingleQuotes(ruleName) + '\' AND EntityDefinitionId = \''+
            String.escapeSingleQuotes(objectName) + '\' LIMIT 1';
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            result.success = false; result.message = 'Lookup failed for VR "'+objectName+'.'+ruleName+'". HTTP '+res.getStatusCode(); return result;
        }
        List<Object> records = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(res.getBody())).get('records');
        if (records == null || records.isEmpty()) {
            result.success = false; result.message = 'No Validation Rule found: '+objectName+'.'+ruleName; return result;
        }
        String rId = (String)((Map<String,Object>)records[0]).get('Id');
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/sobjects/ValidationRule/' + rId);
        del.setMethod('DELETE'); del.setHeader('Content-Type', 'application/json');
        HttpResponse dr = http.send(del);
        if (dr.getStatusCode() == 204 || dr.getStatusCode() == 200) {
            result.success = true; result.message = 'Validation Rule "'+objectName+'.'+ruleName+'" deleted.';
        } else {
            result.success = false; result.message = 'Failed to delete VR "'+objectName+'.'+ruleName+'". HTTP '+dr.getStatusCode()+': '+dr.getBody();
        }
        return result;
    }

    // ===============================
    // DELETE PERMISSION SET BY NAME
    // ===============================
    // Removes all assignments then deletes the PermissionSet record
    // ===============================
    public static DeleteResult deletePermissionSetByName(String permSetName) {
        Http http = new Http();
        DeleteResult result = new DeleteResult();
        String lookSoql = 'SELECT Id, Label FROM PermissionSet WHERE Name = \''+
            String.escapeSingleQuotes(permSetName) + '\' AND IsOwnedByProfile = false LIMIT 1';
        HttpRequest lReq = new HttpRequest();
        lReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' +
            EncodingUtil.urlEncode(lookSoql, 'UTF-8'));
        lReq.setMethod('GET'); lReq.setHeader('Content-Type', 'application/json');
        HttpResponse lRes = http.send(lReq);
        if (lRes.getStatusCode() < 200 || lRes.getStatusCode() >= 300) {
            result.success = false; result.message = 'Lookup failed for PermSet "' + permSetName + '". HTTP ' + lRes.getStatusCode(); return result;
        }
        List<Object> records = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(lRes.getBody())).get('records');
        if (records == null || records.isEmpty()) {
            result.success = false; result.message = 'No custom PermissionSet found: ' + permSetName; return result;
        }
        String psId    = (String)((Map<String,Object>)records[0]).get('Id');
        String psLabel = (String)((Map<String,Object>)records[0]).get('Label');
        // Remove assignments
        String aSoql = 'SELECT Id FROM PermissionSetAssignment WHERE PermissionSetId = \'' + psId + '\'';
        HttpRequest aReq = new HttpRequest();
        aReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' + EncodingUtil.urlEncode(aSoql, 'UTF-8'));
        aReq.setMethod('GET'); aReq.setHeader('Content-Type', 'application/json');
        HttpResponse aRes = http.send(aReq);
        Integer removed = 0;
        if (aRes.getStatusCode() >= 200 && aRes.getStatusCode() < 300) {
            List<Object> aRecs = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(aRes.getBody())).get('records');
            if (aRecs != null) {
                for (Object o : aRecs) {
                    String aId = (String)((Map<String,Object>)o).get('Id');
                    HttpRequest dAReq = new HttpRequest();
                    dAReq.setEndpoint('callout:Metadata_API/services/data/v60.0/sobjects/PermissionSetAssignment/' + aId);
                    dAReq.setMethod('DELETE'); dAReq.setHeader('Content-Type', 'application/json');
                    HttpResponse dARes = http.send(dAReq);
                    if (dARes.getStatusCode() == 204 || dARes.getStatusCode() == 200) removed++;
                }
            }
        }
        HttpRequest delReq = new HttpRequest();
        delReq.setEndpoint('callout:Metadata_API/services/data/v60.0/sobjects/PermissionSet/' + psId);
        delReq.setMethod('DELETE'); delReq.setHeader('Content-Type', 'application/json');
        HttpResponse delRes = http.send(delReq);
        if (delRes.getStatusCode() == 204 || delRes.getStatusCode() == 200) {
            result.success = true; result.message = 'Permission Set "' + psLabel + '" deleted. ' + removed + ' assignment(s) removed.';
        } else {
            result.success = false; result.message = 'Failed to delete PermSet "' + permSetName + '". HTTP ' + delRes.getStatusCode() + ': ' + delRes.getBody();
        }
        return result;
    }

    // ===============================
    // DEACTIVATE PROFILE — reassign users to fallback
    // ===============================
    // Salesforce does not allow API-based profile deletion.
    // This method empties the profile by reassigning all active users
    // to a fallback profile so it can be manually deleted in Setup.
    // ===============================
    public static DeleteResult deactivateProfileByName(String profileName, String fallbackProfileName) {
        Http http = new Http();
        DeleteResult result = new DeleteResult();
        // Look up target profile
        String pSoql = 'SELECT Id FROM Profile WHERE Name = \'' + String.escapeSingleQuotes(profileName) + '\' LIMIT 1';
        HttpRequest pReq = new HttpRequest();
        pReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' + EncodingUtil.urlEncode(pSoql, 'UTF-8'));
        pReq.setMethod('GET'); pReq.setHeader('Content-Type', 'application/json');
        HttpResponse pRes = http.send(pReq);
        if (pRes.getStatusCode() < 200 || pRes.getStatusCode() >= 300) {
            result.success = false; result.message = 'Lookup failed for Profile "' + profileName + '". HTTP ' + pRes.getStatusCode(); return result;
        }
        List<Object> pRecs = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(pRes.getBody())).get('records');
        if (pRecs == null || pRecs.isEmpty()) { result.success = false; result.message = 'Profile not found: ' + profileName; return result; }
        String profileId = (String)((Map<String,Object>)pRecs[0]).get('Id');
        // Look up fallback profile
        String fSoql = 'SELECT Id FROM Profile WHERE Name = \'' + String.escapeSingleQuotes(fallbackProfileName) + '\' LIMIT 1';
        HttpRequest fReq = new HttpRequest();
        fReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' + EncodingUtil.urlEncode(fSoql, 'UTF-8'));
        fReq.setMethod('GET'); fReq.setHeader('Content-Type', 'application/json');
        HttpResponse fRes = http.send(fReq);
        List<Object> fRecs = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(fRes.getBody())).get('records');
        if (fRecs == null || fRecs.isEmpty()) { result.success = false; result.message = 'Fallback Profile not found: ' + fallbackProfileName; return result; }
        String fallbackId = (String)((Map<String,Object>)fRecs[0]).get('Id');
        // Reassign users
        String uSoql = 'SELECT Id FROM User WHERE ProfileId = \'' + profileId + '\' AND IsActive = true';
        HttpRequest uReq = new HttpRequest();
        uReq.setEndpoint('callout:Metadata_API/services/data/v60.0/query?q=' + EncodingUtil.urlEncode(uSoql, 'UTF-8'));
        uReq.setMethod('GET'); uReq.setHeader('Content-Type', 'application/json');
        HttpResponse uRes = http.send(uReq);
        Integer moved = 0;
        if (uRes.getStatusCode() >= 200 && uRes.getStatusCode() < 300) {
            List<Object> uRecs = (List<Object>)((Map<String,Object>)JSON.deserializeUntyped(uRes.getBody())).get('records');
            if (uRecs != null) {
                for (Object o : uRecs) {
                    String uid = (String)((Map<String,Object>)o).get('Id');
                    HttpRequest patchReq = new HttpRequest();
                    patchReq.setEndpoint('callout:Metadata_API/services/data/v60.0/sobjects/User/' + uid);
                    patchReq.setMethod('PATCH'); patchReq.setHeader('Content-Type', 'application/json');
                    patchReq.setBody('{"ProfileId":"' + fallbackId + '"}');
                    HttpResponse patchRes = http.send(patchReq);
                    if (patchRes.getStatusCode() == 204 || patchRes.getStatusCode() == 200) moved++;
                }
            }
        }
        result.success = true;
        result.message = 'Profile "' + profileName + '" is now empty. ' + moved +
            ' user(s) moved to "' + fallbackProfileName +
            '". Manually delete the profile in Setup → Profiles.';
        return result;
    }
}
