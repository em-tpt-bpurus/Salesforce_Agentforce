@SuppressWarnings('PMD.CognitiveComplexity,PMD.NcssMethodCount,PMD.ApexCRUDViolation,PMD.AvoidDeeplyNestedIfStmts,PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces,PMD.ApexDoc')
public without sharing class DeletePermissionSetAction {
    public class DeletePSRequest {
        @InvocableVariable(label='Permission Set Name' description='API Name of the Permission Set to delete')
        public String permSetName;
    }
    public class DeletePSOutput {
        @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled public String  message;
    }
    @InvocableMethod(label='Delete Permission Set' description='Removes all assignments then deletes a custom Permission Set')
    public static List<DeletePSOutput> deletePS(List<DeletePSRequest> requests) {
        List<DeletePSOutput> outputs = new List<DeletePSOutput>();
        for (DeletePSRequest req : requests) {
            DeletePSOutput out = new DeletePSOutput();
            if (String.isBlank(req.permSetName)) {
                out.success = false; out.message = 'Permission Set name was not provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deletePermissionSetByName(req.permSetName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }

    @AuraEnabled(cacheable=false)
    public static DeletePSOutput deletePermSetFromLWC(String permSetName) {
        DeletePSOutput out = new DeletePSOutput();
        if (String.isBlank(permSetName)) {
            out.success = false; out.message = 'Permission Set name was not provided.';
            return out;
        }
        MetadataEngine.DeleteResult r = MetadataEngine.deletePermissionSetByName(permSetName.trim());
        out.success = r.success; out.message = r.message;
        return out;
    }

    @AuraEnabled(cacheable=false)
    public static MetadataEngine.MassDeleteResult massDeletePermSetsDirect(List<String> permSetNames) {
        if (permSetNames == null || permSetNames.isEmpty()) {
            MetadataEngine.MassDeleteResult r = new MetadataEngine.MassDeleteResult();
            r.totalRequested = 0; r.successCount = 0; r.failureCount = 0;
            r.succeeded = new List<String>(); r.failed = new List<String>();
            r.summary = 'No Permission Set names provided.';
            return r;
        }
        return MetadataEngine.massDeletePermissionSets(permSetNames);
    }

    public class PermSetReferencesOutput {
        @AuraEnabled public Boolean hasReferences;
        @AuraEnabled public Integer totalReferenceCount;
        @AuraEnabled public String  report;
        @AuraEnabled public String  flows;
        @AuraEnabled public String  apexClasses;
        @AuraEnabled public String  lwcComponents;
        @AuraEnabled public String  auraComponents;
        @AuraEnabled public String  connectedApps;
        @AuraEnabled public String  permissionSetGroups;
        @AuraEnabled public String  mutingPermissionSets;
        @AuraEnabled public String  assignedUsers;
        @AuraEnabled public String  otherReferences;
        @AuraEnabled public List<String> warningNotes;
    }

    @AuraEnabled(cacheable=false)
    public static PermSetReferencesOutput findReferencesForPermissionSet(String permSetName) {
        PermSetReferencesOutput out = new PermSetReferencesOutput();
        out.hasReferences       = false;
        out.totalReferenceCount = 0;
        out.report              = '';
        out.warningNotes        = new List<String>();

        if (String.isBlank(permSetName)) {
            out.report = 'Permission Set name must be provided.';
            return out;
        }

        String      safeName = permSetName.trim();
        Set<String> seenKeys = new Set<String>();

        // ── Resolve PermissionSet Id + namespace once ──────────────
        String psId = null;
        String psNs = null;
        try {
            List<PermissionSet> psLookup = [
                SELECT Id, Label, NamespacePrefix
                FROM PermissionSet
                WHERE (Name = :safeName OR Label = :safeName) AND IsOwnedByProfile = false
                LIMIT 1
            ];
            if (!psLookup.isEmpty()) {
                psId = psLookup[0].Id;
                psNs = psLookup[0].NamespacePrefix;
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Permission Set Id lookup failed: ' + ex.getMessage());
        }

        // ── CHECK 1: MetadataComponentDependency (MCD) ─────────────
        MetadataEngine.ReferenceResult mcdResult =
            MetadataEngine.getReferencesFor(safeName, 'PermissionSet');
        if (mcdResult.warningNotes != null) {
            out.warningNotes.addAll(mcdResult.warningNotes);
        }

        // ── CHECK 2: Active user assignments ───────────────────────
        Integer assignedCount = 0;
        try {
            assignedCount = [
                SELECT COUNT() FROM PermissionSetAssignment
                WHERE PermissionSet.Name = :safeName
                AND AssigneeId != null
            ];
            if (assignedCount > 0) {
                out.assignedUsers = assignedCount + ' user(s) currently assigned to this Permission Set — remove all assignments before deleting.';
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ User assignment check failed: ' + ex.getMessage());
        }

        // ── CHECK 3: PermissionSetGroup membership ─────────────────
        try {
            if (psId != null) {
                List<PermissionSetGroupComponent> psgComps = [
                    SELECT PermissionSetGroup.DeveloperName, PermissionSetGroup.MasterLabel
                    FROM PermissionSetGroupComponent
                    WHERE PermissionSetId = :psId
                    LIMIT 50
                ];
                for (PermissionSetGroupComponent comp : psgComps) {
                    if (comp.PermissionSetGroup == null) { continue; }
                    String grpName = comp.PermissionSetGroup.DeveloperName;
                    String key     = ('psg|' + grpName).toLowerCase();
                    if (!seenKeys.contains(key)) {
                        seenKeys.add(key);
                        out.permissionSetGroups = (out.permissionSetGroups != null ? out.permissionSetGroups : '') +
                            grpName + ' (' + comp.PermissionSetGroup.MasterLabel + ')\n';
                    }
                }
                if (String.isNotBlank(out.permissionSetGroups)) {
                    out.warningNotes.add('🔒 BLOCKER — This Permission Set is a component in PermissionSetGroup(s): ' +
                        out.permissionSetGroups.trim() + '. Remove it from the group(s) first via Setup > Permission Set Groups.');
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ PermissionSetGroup check failed: ' + ex.getMessage());
        }

        // ── CHECK 4: MutingPermissionSet membership (Tooling API) ──
        // MutingPermissionSet is NOT queryable via standard SOQL — it has no
        // ParentId field accessible in Apex SOQL. It is only available via the
        // Tooling API. We query PermissionSetGroupComponent for PSGs that
        // contain this PS, then use the Tooling API to find any
        // MutingPermissionSet records inside those PSGs.
        try {
            if (psId != null) {
                // Step 1: find PSG Ids that include this PS as a component
                List<PermissionSetGroupComponent> psgLinks = [
                    SELECT PermissionSetGroupId
                    FROM PermissionSetGroupComponent
                    WHERE PermissionSetId = :psId
                    LIMIT 50
                ];
                if (!psgLinks.isEmpty()) {
                    Set<String> psgIdSet = new Set<String>();
                    for (PermissionSetGroupComponent link : psgLinks) {
                        if (link.PermissionSetGroupId != null) {
                            psgIdSet.add('\'' + link.PermissionSetGroupId + '\'');
                        }
                    }
                    if (!psgIdSet.isEmpty()) {
                        // Step 2: Tooling API query for MutingPermissionSet in those PSGs
                        String      muteSoql = 'SELECT Id, DeveloperName, PermissionSetGroupId ' +
                                               'FROM MutingPermissionSet ' +
                                               'WHERE PermissionSetGroupId IN (' + String.join(new List<String>(psgIdSet), ',') + ') ' +
                                               'LIMIT 20';
                        HttpRequest muteReq  = new HttpRequest();
                        muteReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
                                            EncodingUtil.urlEncode(muteSoql, 'UTF-8'));
                        muteReq.setMethod('GET');
                        muteReq.setHeader('Content-Type', 'application/json');
                        muteReq.setTimeout(30000);
                        HttpResponse muteRes = new Http().send(muteReq);
                        if (muteRes.getStatusCode() >= 200 && muteRes.getStatusCode() < 300) {
                            Map<String, Object> muteBody = (Map<String, Object>) JSON.deserializeUntyped(muteRes.getBody());
                            List<Object>        muteRecs = (List<Object>) muteBody.get('records');
                            if (muteRecs != null) {
                                for (Object r : muteRecs) {
                                    Map<String, Object> row     = (Map<String, Object>) r;
                                    String              muteName = (String) row.get('DeveloperName');
                                    String              psgId2   = (String) row.get('PermissionSetGroupId');
                                    if (String.isBlank(muteName)) { continue; }
                                    String key = ('mute|' + muteName).toLowerCase();
                                    if (!seenKeys.contains(key)) {
                                        seenKeys.add(key);
                                        out.mutingPermissionSets = (out.mutingPermissionSets != null ? out.mutingPermissionSets : '') +
                                            muteName + ' (PSG Id: ' + (psgId2 != null ? psgId2 : 'unknown') + ')\n';
                                    }
                                }
                            }
                        }
                    }
                }
                if (String.isNotBlank(out.mutingPermissionSets)) {
                    out.warningNotes.add('⚠️ PSG(s) containing this PS also have a MutingPermissionSet: ' +
                        out.mutingPermissionSets.trim() + '. Remove from the group before deleting.');
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ MutingPermissionSet check failed: ' + ex.getMessage());
        }

        // ── CHECK 5: SetupEntityAccess — Apex/VF/Custom Setting access ─
        try {
            if (psId != null) {
                Id      psIdTyped = psId;
                Integer seaCount  = [SELECT COUNT() FROM SetupEntityAccess WHERE ParentId = :psIdTyped];
                if (seaCount > 0) {
                    out.warningNotes.add('ℹ️  ' + seaCount + ' Apex class / VF page / Custom Setting access entries are granted by this Permission Set. These will be removed on delete — not a blocker.');
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ SetupEntityAccess count skipped: ' + ex.getMessage());
        }

        // ── CHECK 6: Connected App OAuth policies (Tooling API) ────
        try {
            if (psId != null) {
                String      capSoql  = 'SELECT ConnectedApplicationId FROM ConnectedAppPermSet ' +
                                       'WHERE PermissionSetId = \'' + String.escapeSingleQuotes(psId) + '\' LIMIT 50';
                HttpRequest capReq   = new HttpRequest();
                capReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
                                   EncodingUtil.urlEncode(capSoql, 'UTF-8'));
                capReq.setMethod('GET');
                capReq.setHeader('Content-Type', 'application/json');
                capReq.setTimeout(30000);
                HttpResponse capRes    = new Http().send(capReq);
                Integer      cappCount = 0;
                if (capRes.getStatusCode() >= 200 && capRes.getStatusCode() < 300) {
                    Map<String, Object> capBody = (Map<String, Object>) JSON.deserializeUntyped(capRes.getBody());
                    List<Object>        capRecs = (List<Object>) capBody.get('records');
                    if (capRecs != null) {
                        for (Object r : capRecs) {
                            Map<String, Object> row   = (Map<String, Object>) r;
                            String              appId = (String) row.get('ConnectedApplicationId');
                            if (String.isBlank(appId)) { continue; }
                            String key = ('connectedapp|' + appId).toLowerCase();
                            if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                cappCount++;
                                out.connectedApps = (out.connectedApps != null ? out.connectedApps : '') + appId + '\n';
                            }
                        }
                    }
                }
                if (String.isNotBlank(out.connectedApps)) {
                    out.warningNotes.add('ℹ️  ' + cappCount + ' Connected App(s) reference this Permission Set in their OAuth policies. Remove the PS from their policies before deleting.');
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Connected App check failed: ' + ex.getMessage());
        }

        // ── CHECK 7: MCD — group by category for LWC display ────────
        if (mcdResult.references != null && !mcdResult.references.isEmpty()) {
            Map<String, List<String>> groupMap = new Map<String, List<String>>();
            for (MetadataEngine.ReferenceItem item : mcdResult.references) {
                String grp = item.groupLabel != null ? item.groupLabel : 'Other';
                if (!groupMap.containsKey(grp)) {
                    groupMap.put(grp, new List<String>());
                }
                groupMap.get(grp).add(item.name);
            }
            out.flows          = formatGroup(groupMap.get('Flows'));
            out.apexClasses    = formatGroup(groupMap.get('Apex Classes'));
            out.lwcComponents  = formatGroup(groupMap.get('LWC Components'));
            out.auraComponents = formatGroup(groupMap.get('Aura Components'));

            Set<String>  knownGroups = new Set<String>{
                'Flows', 'Apex Classes', 'LWC Components', 'Aura Components'
            };
            List<String> otherLines = new List<String>();
            for (String grp : groupMap.keySet()) {
                if (!knownGroups.contains(grp)) {
                    otherLines.addAll(groupMap.get(grp));
                }
            }
            out.otherReferences = otherLines.isEmpty() ? null : formatGroup(otherLines);
        }

        // ── Aggregate hasReferences + totalCount ────────────────────
        Integer mcdCount  = mcdResult.referenceCount != null ? mcdResult.referenceCount : 0;
        Integer psgCount  = String.isNotBlank(out.permissionSetGroups)  ? out.permissionSetGroups.countMatches('\n')  : 0;
        Integer muteCount = String.isNotBlank(out.mutingPermissionSets) ? out.mutingPermissionSets.countMatches('\n') : 0;
        Integer cappCount = String.isNotBlank(out.connectedApps)        ? out.connectedApps.countMatches('\n')        : 0;

        out.totalReferenceCount = mcdCount + assignedCount + psgCount + muteCount + cappCount;
        out.hasReferences       = out.totalReferenceCount > 0;

        // ── Build report ─────────────────────────────────────────────
        if (!out.hasReferences && out.warningNotes.isEmpty()) {
            out.report = '✅ No references found for Permission Set "' + safeName + '". Safe to delete.';
        } else if (String.isNotBlank(mcdResult.formattedReport)) {
            out.report = mcdResult.formattedReport;
        } else {
            out.report = buildPermSetReport(safeName, out, assignedCount);
        }

        return out;
    }

    private static String formatGroup(List<String> names) {
        if (names == null || names.isEmpty()) { return null; }
        String result = '';
        for (Integer i = 0; i < names.size(); i++) {
            result += (i + 1) + '. ' + names[i] + '\n';
        }
        return result;
    }

    public static String buildPermSetReportPublic(String psName, PermSetReferencesOutput out) {
        Integer assigned = out.assignedUsers != null ? Integer.valueOf(out.assignedUsers.split(' ')[0]) : 0;
        return buildPermSetReport(psName, out, assigned);
    }

    private static String buildPermSetReport(String psName, PermSetReferencesOutput out, Integer assigned) {
        String r = '🔍 References found for Permission Set "' + psName + '":\n\n';
        if (assigned > 0)                                { r += '🔒 BLOCKER — ' + assigned + ' user(s) assigned. Remove all assignments first.\n'; }
        if (String.isNotBlank(out.permissionSetGroups))  { r += '🔒 BLOCKER — PermissionSetGroup(s):\n'     + out.permissionSetGroups + '\n'; }
        if (String.isNotBlank(out.mutingPermissionSets)) { r += '⚠️  Muting Permission Set in PSG(s):\n'    + out.mutingPermissionSets + '\n'; }
        if (String.isNotBlank(out.flows))                { r += '📋 Flows:\n'                               + out.flows + '\n'; }
        if (String.isNotBlank(out.apexClasses))          { r += '⚙️  Apex Classes:\n'                       + out.apexClasses + '\n'; }
        if (String.isNotBlank(out.lwcComponents))        { r += '⚡ LWC Components:\n'                      + out.lwcComponents + '\n'; }
        if (String.isNotBlank(out.auraComponents))       { r += '🌩️  Aura Components:\n'                    + out.auraComponents + '\n'; }
        if (String.isNotBlank(out.connectedApps))        { r += '🔗 Connected Apps:\n'                      + out.connectedApps + '\n'; }
        if (String.isNotBlank(out.otherReferences))      { r += '📌 Other:\n'                               + out.otherReferences + '\n'; }
        return r;
    }
}