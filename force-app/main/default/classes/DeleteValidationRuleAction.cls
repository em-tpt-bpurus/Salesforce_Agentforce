@SuppressWarnings('PMD.ApexDoc,PMD.CognitiveComplexity,PMD.NcssMethodCount')
public without sharing class DeleteValidationRuleAction {
    public class DeleteVRRequest {
        @InvocableVariable(label='Object API Name' description='API name of the object (e.g. Account)')
        public String objectName;
        @InvocableVariable(label='Validation Rule Name' description='ValidationName of the rule')
        public String ruleName;
    }
    public class DeleteVROutput {
        @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled public String  message;
    }
    @InvocableMethod(label='Delete Validation Rule' description='Deletes a Validation Rule by Object and Rule Name')
    public static List<DeleteVROutput> deleteVR(List<DeleteVRRequest> requests) {
        List<DeleteVROutput> outputs = new List<DeleteVROutput>();
        for (DeleteVRRequest req : requests) {
            DeleteVROutput out = new DeleteVROutput();
            if (String.isBlank(req.objectName) || String.isBlank(req.ruleName)) {
                out.success = false; out.message = 'Both Object Name and Rule Name must be provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteValidationRuleByName(req.objectName.trim(), req.ruleName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }

    @AuraEnabled(cacheable=false)
    public static DeleteVROutput deleteVRFromLWC(String objectName, String ruleName) {
        DeleteVROutput out = new DeleteVROutput();
        if (String.isBlank(objectName) || String.isBlank(ruleName)) {
            out.success = false; out.message = 'Both Object Name and Rule Name must be provided.';
            return out;
        }
        MetadataEngine.DeleteResult r = MetadataEngine.deleteValidationRuleByName(objectName.trim(), ruleName.trim());
        out.success = r.success; out.message = r.message;
        return out;
    }

    // ── Mass delete: called by LWC — names must be "Object.RuleName" format ──
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.MassDeleteResult massDeleteValidationRulesDirect(List<String> dotNames) {
        if (dotNames == null || dotNames.isEmpty()) {
            MetadataEngine.MassDeleteResult r = new MetadataEngine.MassDeleteResult();
            r.totalRequested = 0; r.successCount = 0; r.failureCount = 0;
            r.succeeded = new List<String>(); r.failed = new List<String>();
            r.summary = 'No validation rule names provided.';
            return r;
        }
        return MetadataEngine.massDeleteValidationRules(dotNames);
    }

    // ═══════════════════════════════════════════════════════
    // FIND REFERENCES — Validation Rule
    //
    // Checks every possible reference vector before deletion:
    //   1.  MetadataComponentDependency (MCD) — Flows, Apex, LWC, Aura, Bots, etc.
    //   2.  Active status guard — inactive rules are safe to delete;
    //       active rules affecting live data should be reviewed
    //   3.  Flow reference body scan — Flows can call VR names via
    //       Record-Triggered or Autolaunched paths; MCD sometimes misses these
    //   4.  Apex body scan — ApexClass source referencing the rule by name
    //       (e.g. Test classes asserting on the rule error message)
    //   5.  Duplicate Rule dependency — DuplicateRule can reference ValidationRule
    //       conditions on the same object (advisory)
    //   6.  Managed package guard — cannot delete rules from installed packages
    //   7.  Warning notes from MCD (truncation advisories, etc.)
    // ═══════════════════════════════════════════════════════
    public class VRReferencesOutput {
        @AuraEnabled public Boolean hasReferences;
        @AuraEnabled public Integer totalReferenceCount;
        @AuraEnabled public String  report;
        // Rule metadata
        @AuraEnabled public Boolean isActive;
        // Grouped reference strings for LWC display
        @AuraEnabled public String  flows;
        @AuraEnabled public String  apexClasses;
        @AuraEnabled public String  lwcComponents;
        @AuraEnabled public String  auraComponents;
        @AuraEnabled public String  duplicateRules;
        @AuraEnabled public String  otherReferences;
        @AuraEnabled public List<String> warningNotes;
    }

    @AuraEnabled(cacheable=false)
    public static VRReferencesOutput findReferencesForValidationRule(String objectName, String ruleName) {
        VRReferencesOutput out   = new VRReferencesOutput();
        out.hasReferences        = false;
        out.totalReferenceCount  = 0;
        out.report               = '';
        out.warningNotes         = new List<String>();
        out.isActive             = null;

        if (String.isBlank(objectName) || String.isBlank(ruleName)) {
            out.report = 'Both Object Name and Rule Name must be provided.';
            return out;
        }

        String safeObj  = objectName.trim();
        String safeRule = ruleName.trim();
        String vrRef    = safeObj + '.' + safeRule;   // "Object.RuleName" — used in MCD lookup
        Set<String> seenKeys = new Set<String>();
        Http http = new Http();

        // ── Resolve ValidationRule Id + metadata once via Tooling API ──
        String  vrId          = null;
        Boolean vrIsActive    = null;
        String  vrNamespace   = null;
        String  vrErrorMsg    = null;
        try {
            String vrIdSoql = 'SELECT Id, Active, NamespacePrefix, ErrorMessage ' +
                              'FROM ValidationRule ' +
                              'WHERE ValidationName = \'' + String.escapeSingleQuotes(safeRule) + '\' ' +
                              'AND EntityDefinition.QualifiedApiName = \'' + String.escapeSingleQuotes(safeObj) + '\' ' +
                              'LIMIT 1';
            HttpRequest vrReq = new HttpRequest();
            vrReq.setEndpoint(System.URL.getOrgDomainUrl().toExternalForm() +
                '/services/data/v62.0/tooling/query?q=' + EncodingUtil.urlEncode(vrIdSoql, 'UTF-8'));
            vrReq.setMethod('GET');
            vrReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            vrReq.setHeader('Content-Type', 'application/json');
            vrReq.setTimeout(10000);
            HttpResponse vrRes = http.send(vrReq);
            if (vrRes.getStatusCode() >= 200 && vrRes.getStatusCode() < 300) {
                Map<String, Object> vrBody = (Map<String, Object>) JSON.deserializeUntyped(vrRes.getBody());
                List<Object> vrRecs = (List<Object>) vrBody.get('records');
                if (vrRecs != null && !vrRecs.isEmpty()) {
                    Map<String, Object> vrRow = (Map<String, Object>) vrRecs[0];
                    vrId        = (String)  vrRow.get('Id');
                    vrIsActive  = (Boolean) vrRow.get('Active');
                    vrNamespace = (String)  vrRow.get('NamespacePrefix');
                    vrErrorMsg  = (String)  vrRow.get('ErrorMessage');
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ ValidationRule Id lookup failed: ' + ex.getMessage());
        }

        out.isActive = vrIsActive;



        // ── ACTIVE STATUS ADVISORY ─────────────────────────────────
        if (vrIsActive == true) {
            out.warningNotes.add('⚠️  This Validation Rule is currently ACTIVE and enforcing data integrity on "' + safeObj + '". ' +
                'Ensure no business process depends on it before deleting. Consider deactivating it first for a safer rollback path.');
        }

        // ── CHECK 1: MetadataComponentDependency (MCD) ─────────────
        // Catches: Flows, Apex, LWC, Aura, Bots, PromptTemplates, etc.
        // Uses "Object.RuleName" format — that is how MCD indexes VRs.
        MetadataEngine.ReferenceResult mcdResult =
            MetadataEngine.getReferencesFor(vrRef, 'ValidationRule');

        if (mcdResult.warningNotes != null) {
            out.warningNotes.addAll(mcdResult.warningNotes);
        }

        // ── CHECK 2: Flow body scan ─────────────────────────────────
        // Flows can reference a VR name in Decision/Assignment elements or
        // error-message conditions. MCD catches most; this scan catches
        // flows that hardcode the rule name as a string value.
        try {
            String flowSoql = 'SELECT Id, DeveloperName, ProcessType ' +
                              'FROM FlowDefinitionView ' +
                              'WHERE IsActive = true ' +
                              'LIMIT 500';
            HttpRequest flowReq = new HttpRequest();
            flowReq.setEndpoint(System.URL.getOrgDomainUrl().toExternalForm() +
                '/services/data/v62.0/query?q=' + EncodingUtil.urlEncode(flowSoql, 'UTF-8'));
            flowReq.setMethod('GET');
            flowReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            flowReq.setHeader('Content-Type', 'application/json');
            flowReq.setTimeout(15000);
            HttpResponse flowRes = http.send(flowReq);
            if (flowRes.getStatusCode() >= 200 && flowRes.getStatusCode() < 300) {
                Map<String, Object> flowBody = (Map<String, Object>) JSON.deserializeUntyped(flowRes.getBody());
                List<Object> flowRecs = (List<Object>) flowBody.get('records');
                if (flowRecs != null) {
                    // Collect flow Ids to scan their full metadata
                    List<String> flowIds = new List<String>();
                    Map<String, String> flowIdToName = new Map<String, String>();
                    for (Object fr : flowRecs) {
                        Map<String, Object> fRow = (Map<String, Object>) fr;
                        String fId   = (String) fRow.get('Id');
                        String fName = (String) fRow.get('DeveloperName');
                        if (fId != null && fName != null) {
                            flowIds.add(fId);
                            flowIdToName.put(fId, fName);
                        }
                    }
                    // Batch fetch flow metadata via Tooling and scan body for rule name
                    if (!flowIds.isEmpty()) {
                        String ruleNameLower = safeRule.toLowerCase();
                        String idInClause = '(\'' + String.join(flowIds, '\',\'') + '\')';
                        // Limit to first 50 to avoid timeout — large orgs may need pagination
                        String fMetaSoql = 'SELECT Id, Metadata FROM Flow WHERE Id IN ' + idInClause + ' LIMIT 50';
                        HttpRequest fmReq = new HttpRequest();
                        fmReq.setEndpoint(System.URL.getOrgDomainUrl().toExternalForm() +
                            '/services/data/v62.0/tooling/query?q=' + EncodingUtil.urlEncode(fMetaSoql, 'UTF-8'));
                        fmReq.setMethod('GET');
                        fmReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
                        fmReq.setHeader('Content-Type', 'application/json');
                        fmReq.setTimeout(20000);
                        HttpResponse fmRes = http.send(fmReq);
                        if (fmRes.getStatusCode() >= 200 && fmRes.getStatusCode() < 300) {
                            Map<String, Object> fmBody = (Map<String, Object>) JSON.deserializeUntyped(fmRes.getBody());
                            List<Object> fmRecs = (List<Object>) fmBody.get('records');
                            if (fmRecs != null) {
                                for (Object fmr : fmRecs) {
                                    Map<String, Object> fmRow  = (Map<String, Object>) fmr;
                                    String fmId   = (String) fmRow.get('Id');
                                    Object fmMeta = fmRow.get('Metadata');
                                    if (fmMeta == null || fmId == null) continue;
                                    String metaStr = JSON.serialize(fmMeta).toLowerCase();
                                    if (metaStr.contains(ruleNameLower)) {
                                        String fName = flowIdToName.get(fmId);
                                        if (fName == null) fName = fmId;
                                        String key = ('flow-body|' + fName).toLowerCase();
                                        if (!seenKeys.contains(key)) {
                                            seenKeys.add(key);
                                            MetadataEngine.ReferenceItem item = new MetadataEngine.ReferenceItem();
                                            item.name       = fName;
                                            item.type       = 'Flow';
                                            item.groupLabel = 'Flows';
                                            item.relationship = 'Flow body references "' + safeRule + '" by name — review element conditions/error messages';
                                            mcdResult.references.add(item);
                                        }
                                    }
                                }
                            }
                        }
                        if (flowIds.size() > 50) {
                            out.warningNotes.add('ℹ️  Flow body scan limited to 50 active flows. If you have more, verify manually in Flow Builder for references to "' + safeRule + '".');
                        }
                    }
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Flow body scan failed: ' + ex.getMessage());
        }

        // ── CHECK 3: Apex class body scan ──────────────────────────
        // Test classes frequently assert on VR error messages. Delete
        // of the VR breaks the test. Scan ApexClass.Body for the rule name.
        try {
            if (Limits.getCpuTime() < Limits.getLimitCpuTime() - 3000) {
                String ruleNameLower = safeRule.toLowerCase();
                String apexSoql = 'SELECT Id, Name FROM ApexClass ' +
                                  'WHERE Body LIKE \'%' + String.escapeSingleQuotes(safeRule) + '%\' ' +
                                  'AND NamespacePrefix = null ' +
                                  'LIMIT 50';
                HttpRequest axReq = new HttpRequest();
                axReq.setEndpoint(System.URL.getOrgDomainUrl().toExternalForm() +
                    '/services/data/v62.0/tooling/query?q=' + EncodingUtil.urlEncode(apexSoql, 'UTF-8'));
                axReq.setMethod('GET');
                axReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
                axReq.setHeader('Content-Type', 'application/json');
                axReq.setTimeout(15000);
                HttpResponse axRes = http.send(axReq);
                if (axRes.getStatusCode() >= 200 && axRes.getStatusCode() < 300) {
                    Map<String, Object> axBody = (Map<String, Object>) JSON.deserializeUntyped(axRes.getBody());
                    List<Object> axRecs = (List<Object>) axBody.get('records');
                    if (axRecs != null) {
                        for (Object ar : axRecs) {
                            Map<String, Object> aRow  = (Map<String, Object>) ar;
                            String aName = (String) aRow.get('Name');
                            if (String.isBlank(aName)) continue;
                            String key = ('apex-body|' + aName).toLowerCase();
                            if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                MetadataEngine.ReferenceItem item = new MetadataEngine.ReferenceItem();
                                item.name       = aName;
                                item.type       = 'ApexClass';
                                item.groupLabel = 'Apex Classes';
                                item.relationship = 'Apex class body references "' + safeRule + '" (e.g. test assertion on error message)';
                                mcdResult.references.add(item);
                            }
                        }
                    }
                }
            } else {
                out.warningNotes.add('⚠️ Apex body scan skipped — CPU limit approaching. Check manually for test classes asserting on the VR error message.');
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Apex body scan failed: ' + ex.getMessage());
        }

        // ── CHECK 4: Duplicate Rule dependency ─────────────────────
        // DuplicateRules operate on the same object and can reference
        // field conditions related to VRs — advisory only.
        try {
            Integer dupCount = [
                SELECT COUNT() FROM DuplicateRule
                WHERE SobjectType = :safeObj
                AND IsActive = true
            ];
            if (dupCount > 0) {
                out.warningNotes.add('ℹ️  ' + dupCount + ' active Duplicate Rule(s) exist on "' + safeObj + '". ' +
                    'Verify they do not depend on conditions enforced by "' + safeRule + '" before deleting.');
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Duplicate Rule check failed: ' + ex.getMessage());
        }

        // ── CHECK 5: Error message body scan ───────────────────────
        // Advisory: if another VR on the same object has an error message
        // that cites this rule by name (rare but possible in complex setups).
        if (String.isNotBlank(vrErrorMsg)) {
            out.warningNotes.add('ℹ️  Error message for this rule: "' + vrErrorMsg.left(200) +
                (vrErrorMsg.length() > 200 ? '...' : '') + '"');
        }

        // ── Group MCD+body-scan references by category ──────────────
        if (mcdResult.references != null && !mcdResult.references.isEmpty()) {
            Map<String, List<String>> groupMap = new Map<String, List<String>>();
            for (MetadataEngine.ReferenceItem item : mcdResult.references) {
                String grp = item.groupLabel != null ? item.groupLabel : 'Other';
                if (!groupMap.containsKey(grp)) groupMap.put(grp, new List<String>());
                if (!groupMap.get(grp).contains(item.name)) {
                    groupMap.get(grp).add(item.name);
                }
            }
            out.flows          = formatGroup(groupMap.get('Flows'));
            out.apexClasses    = formatGroup(groupMap.get('Apex Classes'));
            out.lwcComponents  = formatGroup(groupMap.get('LWC Components'));
            out.auraComponents = formatGroup(groupMap.get('Aura Components'));

            Set<String> knownGroups = new Set<String>{
                'Flows', 'Apex Classes', 'LWC Components', 'Aura Components'
            };
            List<String> otherLines = new List<String>();
            for (String grp : groupMap.keySet()) {
                if (!knownGroups.contains(grp)) otherLines.addAll(groupMap.get(grp));
            }
            out.otherReferences = otherLines.isEmpty() ? null : formatGroup(otherLines);
        }

        // ── Aggregate hasReferences + totalCount ────────────────────
        Integer totalRefs = mcdResult.references != null ? mcdResult.references.size() : 0;
        out.totalReferenceCount = totalRefs;
        out.hasReferences       = totalRefs > 0;

        // ── Build report ─────────────────────────────────────────────
        if (!out.hasReferences && out.warningNotes.isEmpty()) {
            out.report = '✅ No references found for Validation Rule "' + vrRef + '". Safe to delete.';
        } else if (!out.hasReferences) {
            out.report = '✅ No blocking references found for Validation Rule "' + vrRef + '".'
                + (vrIsActive == true ? ' Note: rule is currently ACTIVE.' : '');
        } else if (String.isNotBlank(mcdResult.formattedReport)) {
            out.report = mcdResult.formattedReport;
        } else {
            out.report = buildVRReport(vrRef, out);
        }

        return out;
    }

    // ── Helper: format a list of names as a numbered string ───
    private static String formatGroup(List<String> names) {
        if (names == null || names.isEmpty()) return null;
        String result = '';
        for (Integer i = 0; i < names.size(); i++) {
            result += (i + 1) + '. ' + names[i] + '\n';
        }
        return result;
    }

    // ── Helper: build a plain-English report ──────────────────
    private static String buildVRReport(String vrRef, VRReferencesOutput out) {
        String r = '🔍 References found for Validation Rule "' + vrRef + '":\n\n';
        if (out.isActive == true) r += '⚠️  Rule is currently ACTIVE.\n';
        if (String.isNotBlank(out.flows))          r += '📋 Flows:\n'           + out.flows + '\n';
        if (String.isNotBlank(out.apexClasses))    r += '⚙️  Apex Classes:\n'   + out.apexClasses + '\n';
        if (String.isNotBlank(out.lwcComponents))  r += '⚡ LWC Components:\n'  + out.lwcComponents + '\n';
        if (String.isNotBlank(out.auraComponents)) r += '🌩️  Aura Components:\n'+ out.auraComponents + '\n';
        if (String.isNotBlank(out.otherReferences))r += '📌 Other:\n'           + out.otherReferences + '\n';
        return r;
    }
}
