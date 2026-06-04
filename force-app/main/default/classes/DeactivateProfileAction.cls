@SuppressWarnings('PMD.CognitiveComplexity,PMD.NcssMethodCount,PMD.ApexCRUDViolation,PMD.AvoidDeeplyNestedIfStmts,PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces,PMD.ApexDoc')
public without sharing class DeactivateProfileAction {
    public class DeactivateProfileRequest {
        @InvocableVariable(label='Profile Name' description='Name of the Profile to empty and deactivate')
        public String profileName;
        @InvocableVariable(label='Fallback Profile Name' description='Profile to reassign existing users to (e.g. Standard User)')
        public String fallbackProfileName;
    }
    public class DeactivateProfileOutput {
        @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled public String  message;
    }
    @InvocableMethod(label='Deactivate Profile' description='Reassigns all users from a Profile to a fallback Profile so it can be deleted in Setup')
    public static List<DeactivateProfileOutput> deactivateProfile(List<DeactivateProfileRequest> requests) {
        List<DeactivateProfileOutput> outputs = new List<DeactivateProfileOutput>();
        for (DeactivateProfileRequest req : requests) {
            DeactivateProfileOutput out = new DeactivateProfileOutput();
            if (String.isBlank(req.profileName) || String.isBlank(req.fallbackProfileName)) {
                out.success = false; out.message = 'Both Profile Name and Fallback Profile Name must be provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deactivateProfileByName(req.profileName.trim(), req.fallbackProfileName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }

    @AuraEnabled(cacheable=false)
    public static DeactivateProfileOutput deactivateProfileFromLWC(String profileName, String fallbackProfileName) {
        DeactivateProfileOutput out = new DeactivateProfileOutput();
        if (String.isBlank(profileName)) {
            out.success = false;
            out.message = 'Profile name must be provided.';
            return out;
        }
        String fallback = String.isBlank(fallbackProfileName) ? MetadataConstants.DEFAULT_PROFILE : fallbackProfileName;
        MetadataEngine.DeleteResult r = MetadataEngine.deactivateProfileByName(profileName.trim(), fallback.trim());
        out.success = r.success;
        out.message  = r.message;
        return out;
    }

    @AuraEnabled(cacheable=false)
    public static MetadataEngine.MassDeleteResult massDeactivateProfilesDirect(List<String> profileNames) {
        if (profileNames == null || profileNames.isEmpty()) {
            MetadataEngine.MassDeleteResult r = new MetadataEngine.MassDeleteResult();
            r.totalRequested = 0; r.successCount = 0; r.failureCount = 0;
            r.succeeded = new List<String>(); r.failed = new List<String>();
            r.summary = 'No profile names provided.';
            return r;
        }
        return MetadataEngine.massDeactivateProfiles(profileNames);
    }

    // ═══════════════════════════════════════════════════════
    // FIND REFERENCES — Profile
    //
    //   1.  MetadataComponentDependency (MCD) — Flows, LWC, Aura, VF, etc.
    //   2.  Active user assignments (User.ProfileId)
    //   3.  Inactive user count (advisory)
    //   4.  PermissionSetGroup membership (Profile backing PermSet)
    //   5.  Login Flows (Tooling API — LoginFlow not queryable via SOQL)
    //   6.  Connected Apps (Tooling API — ConnectedAppProfile not queryable via SOQL)
    //   7.  SetupEntityAccess — Apex/VF/Custom Setting access (advisory)
    //   8.  Profile-based Sharing Rules (advisory)
    // ═══════════════════════════════════════════════════════
    public class ProfileReferencesOutput {
        @AuraEnabled public Boolean hasReferences;
        @AuraEnabled public Integer totalReferenceCount;
        @AuraEnabled public String  report;
        @AuraEnabled public String  flows;
        @AuraEnabled public String  apexClasses;
        @AuraEnabled public String  lwcComponents;
        @AuraEnabled public String  auraComponents;
        @AuraEnabled public String  connectedApps;
        @AuraEnabled public String  loginFlows;
        @AuraEnabled public String  permissionSetGroups;
        @AuraEnabled public String  assignedUsers;
        @AuraEnabled public String  inactiveUsers;
        @AuraEnabled public String  otherReferences;
        @AuraEnabled public List<String> warningNotes;
    }

    @AuraEnabled(cacheable=false)
    public static ProfileReferencesOutput findReferencesForProfile(String profileName) {
        ProfileReferencesOutput out = new ProfileReferencesOutput();
        out.hasReferences       = false;
        out.totalReferenceCount = 0;
        out.report              = '';
        out.warningNotes        = new List<String>();

        if (String.isBlank(profileName)) {
            out.report = 'Profile name must be provided.';
            return out;
        }

        String      safeName = profileName.trim();
        Set<String> seenKeys = new Set<String>();

        // ── Resolve Profile Id once ────────────────────────────────
        String profileId = null;
        try {
            List<Profile> profList = [
                SELECT Id, UserType FROM Profile WHERE Name = :safeName LIMIT 1
            ];
            if (!profList.isEmpty()) {
                profileId = profList[0].Id;
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Profile Id lookup failed: ' + ex.getMessage());
        }

        // ── CHECK 1: MetadataComponentDependency (MCD) ─────────────
        MetadataEngine.ReferenceResult mcdResult =
            MetadataEngine.getReferencesFor(safeName, 'Profile');
        if (mcdResult.warningNotes != null) {
            out.warningNotes.addAll(mcdResult.warningNotes);
        }

        // ── CHECK 2: Active user assignments ───────────────────────
        Integer activeUserCount = 0;
        try {
            if (profileId != null) {
                activeUserCount = [
                    SELECT COUNT() FROM User
                    WHERE ProfileId = :profileId AND IsActive = true
                ];
            } else {
                activeUserCount = [
                    SELECT COUNT() FROM User
                    WHERE ProfileId IN (SELECT Id FROM Profile WHERE Name = :safeName)
                    AND IsActive = true
                ];
            }
            if (activeUserCount > 0) {
                out.assignedUsers = activeUserCount + ' active user(s) currently assigned to this Profile — must be reassigned first.';
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Active user check failed: ' + ex.getMessage());
        }

        // ── CHECK 3: Inactive user count (advisory) ─────────────────
        try {
            if (profileId != null) {
                Integer inactiveCount = [
                    SELECT COUNT() FROM User WHERE ProfileId = :profileId AND IsActive = false
                ];
                if (inactiveCount > 0) {
                    out.inactiveUsers = inactiveCount + ' inactive user(s) still reference this Profile (advisory — reassign before deleting from Setup).';
                    out.warningNotes.add('ℹ️  ' + inactiveCount + ' inactive user(s) still reference "' + safeName + '". Reassign them before deleting the profile from Setup.');
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Inactive user check failed: ' + ex.getMessage());
        }

        // ── CHECK 4: PermissionSetGroup membership ──────────────────
        try {
            if (profileId != null) {
                List<PermissionSet> backingPS = [
                    SELECT Id FROM PermissionSet
                    WHERE ProfileId = :profileId AND IsOwnedByProfile = true
                    LIMIT 1
                ];
                if (!backingPS.isEmpty()) {
                    String bpsId = backingPS[0].Id;
                    List<PermissionSetGroupComponent> psgComps = [
                        SELECT PermissionSetGroup.DeveloperName
                        FROM PermissionSetGroupComponent
                        WHERE PermissionSetId = :bpsId
                        LIMIT 50
                    ];
                    for (PermissionSetGroupComponent comp : psgComps) {
                        if (comp.PermissionSetGroup == null) { continue; }
                        String grpName = comp.PermissionSetGroup.DeveloperName;
                        String key     = ('permsetgroup|' + grpName).toLowerCase();
                        if (!seenKeys.contains(key)) {
                            seenKeys.add(key);
                            out.permissionSetGroups = (out.permissionSetGroups != null ? out.permissionSetGroups : '') +
                                grpName + '\n';
                        }
                    }
                    if (String.isNotBlank(out.permissionSetGroups)) {
                        out.warningNotes.add('⚠️  This profile\'s backing Permission Set is included in PermissionSetGroup(s): ' +
                            out.permissionSetGroups.trim() + '. Remove it from the group before deleting.');
                    }
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ PermissionSetGroup check failed: ' + ex.getMessage());
        }

        // ── CHECK 5: Login Flows (Tooling API) ─────────────────────
        // LoginFlow is not a queryable SObject in standard SOQL.
        try {
            if (profileId != null) {
                String      lfSoql = 'SELECT DeveloperName, FlowDefinitionId FROM LoginFlow ' +
                                     'WHERE ProfileId = \'' + String.escapeSingleQuotes(profileId) + '\' LIMIT 20';
                HttpRequest lfReq  = new HttpRequest();
                lfReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
                                  EncodingUtil.urlEncode(lfSoql, 'UTF-8'));
                lfReq.setMethod('GET');
                lfReq.setHeader('Content-Type', 'application/json');
                lfReq.setTimeout(30000);
                HttpResponse lfRes = new Http().send(lfReq);
                if (lfRes.getStatusCode() >= 200 && lfRes.getStatusCode() < 300) {
                    Map<String, Object> lfBody = (Map<String, Object>) JSON.deserializeUntyped(lfRes.getBody());
                    List<Object>        lfRecs = (List<Object>) lfBody.get('records');
                    if (lfRecs != null) {
                        for (Object r : lfRecs) {
                            Map<String, Object> row    = (Map<String, Object>) r;
                            String              lfName = (String) row.get('DeveloperName');
                            if (String.isBlank(lfName)) { continue; }
                            String key = ('loginflow|' + lfName).toLowerCase();
                            if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                out.loginFlows = (out.loginFlows != null ? out.loginFlows : '') + lfName + '\n';
                            }
                        }
                    }
                }
                if (String.isNotBlank(out.loginFlows)) {
                    out.warningNotes.add('ℹ️  Login Flow(s) are assigned to this Profile. Remove them via Setup > Login Flows before deactivating.');
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Login Flow check failed: ' + ex.getMessage());
        }

        // ── CHECK 6: Connected App access policies (Tooling API) ────
        // ConnectedAppProfile is not a standard queryable SObject.
        try {
            if (profileId != null) {
                String      capSoql  = 'SELECT ConnectedApplicationId FROM ConnectedAppProfile ' +
                                       'WHERE ProfileId = \'' + String.escapeSingleQuotes(profileId) + '\' LIMIT 50';
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
                    out.warningNotes.add('ℹ️  ' + cappCount + ' Connected App(s) restrict access to this Profile. Remove the profile from their OAuth policies before deleting.');
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Connected App check failed: ' + ex.getMessage());
        }

        // ── CHECK 7: SetupEntityAccess — Apex, VF, Custom Settings ──
        try {
            if (profileId != null) {
                List<PermissionSet> backingPS2 = [
                    SELECT Id FROM PermissionSet
                    WHERE ProfileId = :profileId AND IsOwnedByProfile = true
                    LIMIT 1
                ];
                if (!backingPS2.isEmpty()) {
                    Id      bpsId2   = backingPS2[0].Id;
                    Integer seaCount = [SELECT COUNT() FROM SetupEntityAccess WHERE ParentId = :bpsId2];
                    if (seaCount > 0) {
                        out.warningNotes.add('ℹ️  ' + seaCount + ' Apex class / VF page / Custom Setting access entries exist for this Profile. Cleaned up automatically by Salesforce on delete — not a blocker.');
                    }
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ SetupEntityAccess count skipped: ' + ex.getMessage());
        }

        // ── CHECK 8: Sharing Rules (advisory) ──────────────────────
        out.warningNotes.add('ℹ️  Sharing Rules referencing this Profile cannot be detected via SOQL. ' +
            'Check Setup > Sharing Settings for any rules using "Members of this Profile" for "' + safeName + '".');

        // ── CHECK 9: MCD — group by category for LWC display ────────
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
        Integer psgCount  = String.isNotBlank(out.permissionSetGroups) ? out.permissionSetGroups.countMatches('\n') : 0;
        Integer lfCount   = String.isNotBlank(out.loginFlows)          ? out.loginFlows.countMatches('\n')          : 0;
        Integer cappCount = String.isNotBlank(out.connectedApps)       ? out.connectedApps.countMatches('\n')       : 0;

        out.totalReferenceCount = mcdCount + activeUserCount + psgCount + lfCount + cappCount;
        out.hasReferences = (out.totalReferenceCount > 0) || String.isNotBlank(out.inactiveUsers);

        // ── Build report ─────────────────────────────────────────────
        if (!out.hasReferences && out.warningNotes.isEmpty()) {
            out.report = '✅ No blocking references found for Profile "' + safeName + '". Safe to deactivate.';
        } else if (String.isNotBlank(mcdResult.formattedReport)) {
            out.report = mcdResult.formattedReport;
        } else {
            out.report = buildProfileReport(safeName, out, activeUserCount);
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

    private static String buildProfileReport(String profileName, ProfileReferencesOutput out, Integer activeUsers) {
        String r = '🔍 References found for Profile "' + profileName + '":\n\n';
        if (activeUsers > 0)                           { r += '🔒 BLOCKER — ' + activeUsers + ' active user(s) assigned. Reassign before deactivating.\n'; }
        if (String.isNotBlank(out.flows))              { r += '📋 Flows:\n'                 + out.flows + '\n'; }
        if (String.isNotBlank(out.apexClasses))        { r += '⚙️  Apex Classes:\n'         + out.apexClasses + '\n'; }
        if (String.isNotBlank(out.lwcComponents))      { r += '⚡ LWC Components:\n'        + out.lwcComponents + '\n'; }
        if (String.isNotBlank(out.auraComponents))     { r += '🌩️  Aura Components:\n'      + out.auraComponents + '\n'; }
        if (String.isNotBlank(out.loginFlows))         { r += '🔑 Login Flows:\n'           + out.loginFlows + '\n'; }
        if (String.isNotBlank(out.connectedApps))      { r += '🔗 Connected Apps:\n'        + out.connectedApps + '\n'; }
        if (String.isNotBlank(out.permissionSetGroups)){ r += '👥 Permission Set Groups:\n' + out.permissionSetGroups + '\n'; }
        if (String.isNotBlank(out.inactiveUsers))      { r += 'ℹ️  ' + out.inactiveUsers + '\n'; }
        if (String.isNotBlank(out.otherReferences))    { r += '📌 Other:\n'                 + out.otherReferences + '\n'; }
        return r;
    }
}