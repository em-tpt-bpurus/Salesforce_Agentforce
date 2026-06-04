@SuppressWarnings('PMD.ApexDoc,PMD.CognitiveComplexity,PMD.NcssMethodCount')
public without sharing class DeleteAuraAction {
    public class DeleteAuraRequest {
        @InvocableVariable(label='Aura Component Name' description='DeveloperName of the Aura component to delete')
        public String componentName;
    }
    public class DeleteAuraOutput {
        @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled public String  message;
    }
    @InvocableMethod(label='Delete Aura Component' description='Deletes an Aura (Lightning) component by its DeveloperName')
    public static List<DeleteAuraOutput> deleteAura(List<DeleteAuraRequest> requests) {
        List<DeleteAuraOutput> outputs = new List<DeleteAuraOutput>();
        for (DeleteAuraRequest req : requests) {
            DeleteAuraOutput out = new DeleteAuraOutput();
            if (String.isBlank(req.componentName)) {
                out.success = false; out.message = 'Aura component name was not provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteAuraByName(req.componentName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }

    @AuraEnabled(cacheable=false)
    public static DeleteAuraOutput deleteAuraFromLWC(String componentName) {
        DeleteAuraOutput out = new DeleteAuraOutput();
        if (String.isBlank(componentName)) {
            out.success = false; out.message = 'Aura component name was not provided.';
            return out;
        }
        MetadataEngine.DeleteResult r = MetadataEngine.deleteAuraByName(componentName.trim());
        out.success = r.success; out.message = r.message;
        return out;
    }

    // ── Mass delete: called by LWC for bulk operations ────────
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.MassDeleteResult massDeleteAuraDirect(List<String> componentNames) {
        if (componentNames == null || componentNames.isEmpty()) {
            MetadataEngine.MassDeleteResult r = new MetadataEngine.MassDeleteResult();
            r.totalRequested = 0; r.successCount = 0; r.failureCount = 0;
            r.succeeded = new List<String>(); r.failed = new List<String>();
            r.summary = 'No Aura component names provided.';
            return r;
        }
        return MetadataEngine.massDeleteAuraComponents(componentNames);
    }

    // ═══════════════════════════════════════════════════════════════
    // FIND REFERENCES — Aura Component (AuraDefinitionBundle)
    //
    // Every possible reference vector checked before delete:
    //   1.  MetadataComponentDependency (MCD)        — catches Flows, LWC, Apex, FlexiPages, etc.
    //   2.  Aura markup scan (<c:componentName>)     — other Aura bundles embedding this one
    //   3.  Aura application (.app) dependency scan  — aura:dependency tags in .app files
    //   4.  FlexiPage body scan                      — Lightning Record/App/Home pages via App Builder
    //   5.  Flow Screen component scan               — Flows with Screen elements using this component
    //   6.  Custom Tab reference                     — CustomTab pointing to this Aura app/component
    //   7.  NavMenuItem / AppMenuItem scan           — Navigation menus referencing this component
    //   8.  QuickAction scan                         — Quick Actions backed by this Aura component
    //   9.  Experience Cloud (ExperienceBundle) scan — Community pages embedding this component
    //  10.  Apex body scan                           — Apex classes referencing the DeveloperName as a string
    // ═══════════════════════════════════════════════════════════════

    public class AuraReferencesOutput {
        @AuraEnabled public Boolean      hasReferences;
        @AuraEnabled public Integer      totalReferenceCount;
        @AuraEnabled public String       report;
        // Grouped reference strings for LWC display
        @AuraEnabled public String       auraComponents;       // Other Aura bundles embedding this one
        @AuraEnabled public String       lwcComponents;        // LWC components referencing this
        @AuraEnabled public String       flows;                // Flows using this in a Screen
        @AuraEnabled public String       flexiPages;           // Lightning pages (Record/App/Home)
        @AuraEnabled public String       experienceCloud;      // Experience Cloud / Community pages
        @AuraEnabled public String       customTabs;           // Custom tabs backed by this component
        @AuraEnabled public String       navMenuItems;         // Navigation menu items
        @AuraEnabled public String       quickActions;         // Quick actions
        @AuraEnabled public String       apexClasses;          // Apex classes referencing by name
        @AuraEnabled public String       otherReferences;      // Anything else from MCD
        @AuraEnabled public List<String> warningNotes;
    }

    @AuraEnabled(cacheable=false)
    public static AuraReferencesOutput findReferencesForAura(String componentName) {
        AuraReferencesOutput out = new AuraReferencesOutput();
        out.hasReferences        = false;
        out.totalReferenceCount  = 0;
        out.report               = '';
        out.warningNotes         = new List<String>();

        if (String.isBlank(componentName)) {
            out.report = 'Aura component name must be provided.';
            return out;
        }

        String safeName = componentName.trim();

        // ── Delegate to checkAllAuraReferences in MetadataEngine ──────
        // Covers: MCD by Id + MCD by Name + FlexiPage scan +
        //         Aura markup scan + Flow Screen scan + CustomTab scan
        MetadataEngine.ReferenceResult res = MetadataEngine.checkAllAuraReferences(safeName);

        if (res.warningNotes != null) out.warningNotes.addAll(res.warningNotes);

        // ── Check if this is a top-level .app ─────────────────────────
        // Advisory only — not a blocker if no real references exist.
        try {
            Http http = new Http();
            String bundleId = null;
            String idSoql = 'SELECT Id FROM AuraDefinitionBundle WHERE DeveloperName = \'' +
                            String.escapeSingleQuotes(safeName) + '\' LIMIT 1';
            HttpRequest idReq = new HttpRequest();
            idReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
                              EncodingUtil.urlEncode(idSoql, 'UTF-8'));
            idReq.setMethod('GET');
            idReq.setHeader('Content-Type', 'application/json');
            idReq.setTimeout(30000);
            HttpResponse idRes = http.send(idReq);
            if (idRes.getStatusCode() >= 200 && idRes.getStatusCode() < 300) {
                Map<String, Object> idBody = (Map<String, Object>) JSON.deserializeUntyped(idRes.getBody());
                List<Object> idRecs = (List<Object>) idBody.get('records');
                if (idRecs != null && !idRecs.isEmpty()) {
                    bundleId = (String) ((Map<String, Object>) idRecs[0]).get('Id');
                }
            }
            if (bundleId != null) {
                String appSoql = 'SELECT Id FROM AuraDefinition WHERE AuraDefinitionBundleId = \'' +
                                 bundleId + '\' AND DefType = \'APPLICATION\' LIMIT 1';
                HttpRequest appReq = new HttpRequest();
                appReq.setEndpoint('callout:Metadata_API/services/data/v60.0/tooling/query?q=' +
                                   EncodingUtil.urlEncode(appSoql, 'UTF-8'));
                appReq.setMethod('GET');
                appReq.setHeader('Content-Type', 'application/json');
                appReq.setTimeout(30000);
                HttpResponse appRes = http.send(appReq);
                if (appRes.getStatusCode() >= 200 && appRes.getStatusCode() < 300) {
                    Map<String, Object> appBody = (Map<String, Object>) JSON.deserializeUntyped(appRes.getBody());
                    List<Object> appRecs = (List<Object>) appBody.get('records');
                    if (appRecs != null && !appRecs.isEmpty()) {
                        out.warningNotes.add('ℹ️  "' + safeName + '" is a top-level Aura App (.app file). ' +
                            'It is accessible via URL directly. Verify it is not actively used before deleting.');
                    }
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Top-level .app check failed: ' + ex.getMessage());
        }

        // ── Group references by category for LWC display ──────────────
        if (res.references != null && !res.references.isEmpty()) {
            Map<String, List<String>> groupMap = new Map<String, List<String>>();
            for (MetadataEngine.ReferenceItem item : res.references) {
                String grp = item.groupLabel != null ? item.groupLabel : 'Other';
                if (!groupMap.containsKey(grp)) groupMap.put(grp, new List<String>());
                if (!groupMap.get(grp).contains(item.name)) groupMap.get(grp).add(item.name);
            }
            out.auraComponents  = formatGroup(groupMap.get('Aura Components'));
            out.lwcComponents   = formatGroup(groupMap.get('LWC Components'));
            out.flows           = formatGroup(groupMap.get('Flows (Screen Component)'));
            out.flexiPages      = formatGroup(groupMap.get('Lightning Record Pages'));
            if (out.flexiPages  == null) out.flexiPages  = formatGroup(groupMap.get('Lightning App Pages'));
            if (out.flexiPages  == null) out.flexiPages  = formatGroup(groupMap.get('Lightning Pages'));
            out.customTabs      = formatGroup(groupMap.get('Custom Tabs'));
            out.apexClasses     = formatGroup(groupMap.get('Apex Classes'));
            out.experienceCloud = formatGroup(groupMap.get('Experience Cloud / Sites'));

            Set<String> knownGroups = new Set<String>{
                'Aura Components', 'LWC Components', 'Flows (Screen Component)',
                'Lightning Record Pages', 'Lightning App Pages', 'Lightning Home Pages',
                'Lightning Pages', 'Custom Tabs', 'Apex Classes', 'Experience Cloud / Sites'
            };
            List<String> otherLines = new List<String>();
            for (String grp : groupMap.keySet()) {
                if (!knownGroups.contains(grp)) otherLines.addAll(groupMap.get(grp));
            }
            out.otherReferences = otherLines.isEmpty() ? null : formatGroup(otherLines);
        }

        // ── Aggregate totals ───────────────────────────────────────────
        out.totalReferenceCount = res.references != null ? res.references.size() : 0;
        out.hasReferences       = out.totalReferenceCount > 0;

        // ── Build report ───────────────────────────────────────────────
        if (!out.hasReferences && out.warningNotes.isEmpty()) {
            out.report = '✅ No references found for Aura component "' + safeName + '". Safe to delete.';
        } else if (!out.hasReferences) {
            out.report = '✅ No blocking references found for Aura component "' + safeName + '".';
        } else if (String.isNotBlank(res.formattedReport)) {
            out.report = res.formattedReport;
        } else {
            out.report = buildAuraReport(safeName, out);
        }

        return out;
    }

    private static String formatGroup(List<String> names) {
        if (names == null || names.isEmpty()) return null;
        String result = '';
        for (Integer i = 0; i < names.size(); i++) result += (i + 1) + '. ' + names[i] + '\n';
        return result;
    }

    private static String buildAuraReport(String name, AuraReferencesOutput out) {
        String r = '🔍 References found for Aura Component "' + name + '":\n\n';
        if (String.isNotBlank(out.auraComponents))  r += '🌩️  Aura Components:\n'        + out.auraComponents  + '\n';
        if (String.isNotBlank(out.lwcComponents))   r += '⚡ LWC Components:\n'           + out.lwcComponents   + '\n';
        if (String.isNotBlank(out.flows))           r += '📋 Flows:\n'                    + out.flows           + '\n';
        if (String.isNotBlank(out.flexiPages))      r += '📄 Lightning Pages:\n'          + out.flexiPages      + '\n';
        if (String.isNotBlank(out.experienceCloud)) r += '🌐 Experience Cloud:\n'         + out.experienceCloud + '\n';
        if (String.isNotBlank(out.customTabs))      r += '📑 Custom Tabs:\n'              + out.customTabs      + '\n';
        if (String.isNotBlank(out.navMenuItems))    r += '🧭 Navigation Menu Items:\n'    + out.navMenuItems    + '\n';
        if (String.isNotBlank(out.quickActions))    r += '⚡ Quick Actions:\n'            + out.quickActions    + '\n';
        if (String.isNotBlank(out.apexClasses))     r += '⚙️  Apex Classes:\n'            + out.apexClasses     + '\n';
        if (String.isNotBlank(out.otherReferences)) r += '📌 Other:\n'                    + out.otherReferences + '\n';
        return r;
    }
}