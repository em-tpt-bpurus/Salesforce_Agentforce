@SuppressWarnings('PMD.ApexDoc,PMD.CognitiveComplexity,PMD.NcssMethodCount')
public without sharing class DeleteVfPageAction {

    // ── Invocable request / output ────────────────────────────
    public class DeleteVfRequest {
        @InvocableVariable(label='VF Page Name' description='API Name (Name field) of the Visualforce page to delete')
        public String pageName;
    }
    public class DeleteVfOutput {
        @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled public String  message;
    }

    // ── Invocable — called from Agentforce / Flow ─────────────
    @InvocableMethod(label='Delete Visualforce Page' description='Checks references then deletes a Visualforce Page by API Name')
    public static List<DeleteVfOutput> deleteVf(List<DeleteVfRequest> requests) {
        List<DeleteVfOutput> outputs = new List<DeleteVfOutput>();
        for (DeleteVfRequest req : requests) {
            DeleteVfOutput out = new DeleteVfOutput();
            if (String.isBlank(req.pageName)) {
                out.success = false; out.message = 'Page name must be provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteVfByName(req.pageName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }

    // ── Single delete — called by LWC ─────────────────────────
    @AuraEnabled(cacheable=false)
    public static DeleteVfOutput deleteVfFromLWC(String pageName) {
        DeleteVfOutput out = new DeleteVfOutput();
        if (String.isBlank(pageName)) {
            out.success = false; out.message = 'Page name must be provided.';
            return out;
        }
        MetadataEngine.DeleteResult r = MetadataEngine.deleteVfByName(pageName.trim());
        out.success = r.success; out.message = r.message;
        return out;
    }

    // ── Mass delete — called by LWC for bulk operations ───────
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.MassDeleteResult massDeleteVfPagesDirect(List<String> pageNames) {
        if (pageNames == null || pageNames.isEmpty()) {
            MetadataEngine.MassDeleteResult r = new MetadataEngine.MassDeleteResult();
            r.totalRequested = 0; r.successCount = 0; r.failureCount = 0;
            r.succeeded = new List<String>(); r.failed = new List<String>();
            r.summary = 'No Visualforce page names provided.';
            return r;
        }
        return MetadataEngine.massDeleteVfPages(pageNames);
    }

    // ── Single delete VF Component — called by LWC ───────────
    @AuraEnabled(cacheable=false)
    public static DeleteVfOutput deleteVfComponentFromLWC(String componentName) {
        DeleteVfOutput out = new DeleteVfOutput();
        if (String.isBlank(componentName)) {
            out.success = false; out.message = 'Component name must be provided.';
            return out;
        }
        MetadataEngine.DeleteResult r = MetadataEngine.deleteVfComponentByName(componentName.trim());
        out.success = r.success; out.message = r.message;
        return out;
    }

    // ── Mass delete VF Components — called by LWC ─────────────
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.MassDeleteResult massDeleteVfComponentsDirect(List<String> componentNames) {
        if (componentNames == null || componentNames.isEmpty()) {
            MetadataEngine.MassDeleteResult r = new MetadataEngine.MassDeleteResult();
            r.totalRequested = 0; r.successCount = 0; r.failureCount = 0;
            r.succeeded = new List<String>(); r.failed = new List<String>();
            r.summary = 'No VF Component names provided.';
            return r;
        }
        return MetadataEngine.massDeleteVfComponents(componentNames);
    }

    // ═══════════════════════════════════════════════════════════
    // FIND REFERENCES — Visualforce Page
    //
    // Every possible reference vector checked before delete:
    //   1.  MetadataComponentDependency (MCD)    — Apex, Flows, CustomTabs, FlexiPages, etc.
    //   2.  Apex body scan                       — PageReference(Page.xxx) / Page.xxx usages
    //   3.  Custom Tab reference                 — Tab pointing directly at this VF page
    //   4.  FlexiPage / App Builder scan         — Lightning pages embedding a VF page via Visualforce component
    //   5.  Flow body scan                       — Flows referencing the page name as a string
    //   6.  Custom Button / Link scan            — ContentSource='URL' using /apex/PageName
    //   7.  Managed package guard                — ManageableState = installed / installedEditable
    // ═══════════════════════════════════════════════════════════
    public class VfReferencesOutput {
        @AuraEnabled public Boolean      hasReferences;
        @AuraEnabled public Integer      totalReferenceCount;
        @AuraEnabled public String       report;
        // Grouped reference strings for LWC display
        @AuraEnabled public String       apexClasses;
        @AuraEnabled public String       flows;
        @AuraEnabled public String       customTabs;
        @AuraEnabled public String       flexiPages;
        @AuraEnabled public String       customButtons;
        @AuraEnabled public String       otherReferences;
        @AuraEnabled public List<String> warningNotes;
    }

    @AuraEnabled(cacheable=false)
    public static VfReferencesOutput findReferencesForVfPage(String pageName) {
        VfReferencesOutput out  = new VfReferencesOutput();
        out.hasReferences       = false;
        out.totalReferenceCount = 0;
        out.report              = '';
        out.warningNotes        = new List<String>();

        if (String.isBlank(pageName)) {
            out.report = 'Page name must be provided.';
            return out;
        }

        String      safeName = pageName.trim();
        Set<String> seenKeys = new Set<String>();
        Http        http     = new Http();
        String      BASE_URL = 'callout:Metadata_API/services/data/v60.0/';

        // ── Resolve ApexPage Id + managed state ───────────────
        String  pageId   = null;
        Boolean isManaged = false;
        try {
            String soql = 'SELECT Id, ManageableState FROM ApexPage WHERE Name = \'' +
                          String.escapeSingleQuotes(safeName) + '\' LIMIT 1';
            HttpRequest idReq = new HttpRequest();
            idReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
            idReq.setMethod('GET');
            idReq.setHeader('Content-Type', 'application/json');
            idReq.setTimeout(30000);
            HttpResponse idRes = http.send(idReq);
            if (idRes.getStatusCode() >= 200 && idRes.getStatusCode() < 300) {
                Map<String, Object> idBody = (Map<String, Object>) JSON.deserializeUntyped(idRes.getBody());
                List<Object>        idRecs = (List<Object>) idBody.get('records');
                if (idRecs != null && !idRecs.isEmpty()) {
                    Map<String, Object> row = (Map<String, Object>) idRecs[0];
                    pageId    = (String) row.get('Id');
                    String mg = (String) row.get('ManageableState');
                    isManaged = 'installed'.equalsIgnoreCase(mg) || 'installedEditable'.equalsIgnoreCase(mg);
                }
            }
            if (pageId == null) {
                out.report = '⚠️ Visualforce Page "' + safeName + '" not found in this org.';
                return out;
            }
            if (isManaged) {
                out.warningNotes.add('🚫 "' + safeName + '" belongs to a managed package and cannot be deleted.');
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Page lookup failed: ' + ex.getMessage());
        }

        // Seed a shared ReferenceResult to accumulate all items across checks
        MetadataEngine.ReferenceResult allRefs = MetadataEngine.getReferencesFor(safeName, 'ApexPage');
        if (allRefs.warningNotes != null) out.warningNotes.addAll(allRefs.warningNotes);
        // Populate seenKeys from MCD results to avoid duplicates
        if (allRefs.references != null) {
            for (MetadataEngine.ReferenceItem item : allRefs.references) {
                seenKeys.add((item.type + '|' + item.name).toLowerCase());
            }
        } else {
            allRefs.references = new List<MetadataEngine.ReferenceItem>();
        }

        // ── CHECK 2: Apex body scan ────────────────────────────
        // PageReference(Page.PageName) and Page.PageName are the two
        // Apex patterns that reference a VF page. MCD covers declared
        // dependencies; body scan catches dynamic / runtime references.
        try {
            String axSoql = 'SELECT Id, Name, Body FROM ApexClass ' +
                            'WHERE NamespacePrefix = null LIMIT 300';
            HttpRequest axReq = new HttpRequest();
            axReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(axSoql, 'UTF-8'));
            axReq.setMethod('GET');
            axReq.setHeader('Content-Type', 'application/json');
            axReq.setTimeout(120000);
            HttpResponse axRes = http.send(axReq);
            if (axRes.getStatusCode() >= 200 && axRes.getStatusCode() < 300) {
                Map<String, Object> axBody = (Map<String, Object>) JSON.deserializeUntyped(axRes.getBody());
                List<Object>        axRecs = (List<Object>) axBody.get('records');
                if (axRecs != null) {
                    String nameLower = safeName.toLowerCase();
                    for (Object r : axRecs) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              aName = (String) row.get('Name');
                        String              body  = (String) row.get('Body');
                        if (String.isBlank(body) || String.isBlank(aName)) continue;
                        String bodyLow = body.toLowerCase();
                        if (bodyLow.contains('page.' + nameLower) ||
                            bodyLow.contains('pagereference(\'' + nameLower + '\'') ||
                            bodyLow.contains('"' + nameLower + '"')) {
                            String key = ('apexclass|' + aName).toLowerCase();
                            if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                MetadataEngine.ReferenceItem item = new MetadataEngine.ReferenceItem();
                                item.name         = aName;
                                item.type         = 'ApexClass';
                                item.groupLabel   = 'Apex Classes';
                                item.relationship = 'References Page.' + safeName + ' or PageReference in Apex body';
                                allRefs.references.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Apex body scan failed: ' + ex.getMessage());
        }

        // ── CHECK 3: Custom Tab reference ──────────────────────
        // TabDefinition WHERE SobjectName = pageName catches any
        // custom tab that opens this VF page directly.
        try {
            List<TabDefinition> tabs = [
                SELECT Name, Label FROM TabDefinition
                WHERE SobjectName = :safeName
                LIMIT 10
            ];
            for (TabDefinition t : tabs) {
                String key = ('customtab|' + t.Name).toLowerCase();
                if (!seenKeys.contains(key)) {
                    seenKeys.add(key);
                    MetadataEngine.ReferenceItem item = new MetadataEngine.ReferenceItem();
                    item.name         = t.Label != null ? t.Label : t.Name;
                    item.type         = 'CustomTab';
                    item.groupLabel   = 'Custom Tabs';
                    item.relationship = 'Custom Tab opens this VF Page — delete or reassign the tab first (Setup > Tabs)';
                    allRefs.references.add(item);
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Custom Tab check failed: ' + ex.getMessage());
        }

        // ── CHECK 4: FlexiPage scan ────────────────────────────
        // Lightning App Builder pages can embed a VF page via the
        // Visualforce Page component. Scan FlexiPage.Metadata JSON.
        try {
            String fpSoql = 'SELECT DeveloperName, MasterLabel, Type, Metadata ' +
                            'FROM FlexiPage LIMIT 300';
            HttpRequest fpReq = new HttpRequest();
            fpReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(fpSoql, 'UTF-8'));
            fpReq.setMethod('GET');
            fpReq.setHeader('Content-Type', 'application/json');
            fpReq.setTimeout(120000);
            HttpResponse fpRes = http.send(fpReq);
            if (fpRes.getStatusCode() >= 200 && fpRes.getStatusCode() < 300) {
                Map<String, Object> fpBody = (Map<String, Object>) JSON.deserializeUntyped(fpRes.getBody());
                List<Object>        fpRecs = (List<Object>) fpBody.get('records');
                if (fpRecs != null) {
                    String nameLower = safeName.toLowerCase();
                    for (Object r : fpRecs) {
                        Map<String, Object> row    = (Map<String, Object>) r;
                        String              fpName = (String) row.get('DeveloperName');
                        String              fpLabel= (String) row.get('MasterLabel');
                        String              fpType = (String) row.get('Type');
                        Object              meta   = row.get('Metadata');
                        if (meta == null || String.isBlank(fpName)) continue;
                        if (JSON.serialize(meta).toLowerCase().contains(nameLower)) {
                            String key = ('flexipage|' + fpName).toLowerCase();
                            if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                String typeLabel = 'Lightning Page';
                                if ('RecordPage'.equalsIgnoreCase(fpType))    typeLabel = 'Lightning Record Page';
                                else if ('AppPage'.equalsIgnoreCase(fpType))  typeLabel = 'Lightning App Page';
                                else if ('HomePage'.equalsIgnoreCase(fpType)) typeLabel = 'Lightning Home Page';
                                MetadataEngine.ReferenceItem item = new MetadataEngine.ReferenceItem();
                                item.name         = fpLabel != null ? fpLabel : fpName;
                                item.type         = 'FlexiPage';
                                item.groupLabel   = 'Lightning Pages (FlexiPage)';
                                item.relationship = typeLabel + ' embeds this VF Page via Visualforce component — open in App Builder and remove it';
                                allRefs.references.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ FlexiPage scan failed: ' + ex.getMessage());
        }

        // ── CHECK 5: Flow body scan ────────────────────────────
        // Screen Flows can open a VF page via URL action or
        // reference the name in a formula. Scan active flow metadata.
        try {
            String flowSoql = 'SELECT DeveloperName, Metadata FROM FlowDefinition ' +
                              'WHERE ActiveVersionId != null LIMIT 200';
            HttpRequest flowReq = new HttpRequest();
            flowReq.setEndpoint(BASE_URL + 'tooling/query?q=' + EncodingUtil.urlEncode(flowSoql, 'UTF-8'));
            flowReq.setMethod('GET');
            flowReq.setHeader('Content-Type', 'application/json');
            flowReq.setTimeout(120000);
            HttpResponse flowRes = http.send(flowReq);
            if (flowRes.getStatusCode() >= 200 && flowRes.getStatusCode() < 300) {
                Map<String, Object> flowBody = (Map<String, Object>) JSON.deserializeUntyped(flowRes.getBody());
                List<Object>        flowRecs = (List<Object>) flowBody.get('records');
                if (flowRecs != null) {
                    String nameLower = safeName.toLowerCase();
                    for (Object r : flowRecs) {
                        Map<String, Object> row   = (Map<String, Object>) r;
                        String              fName = (String) row.get('DeveloperName');
                        Object              fMeta = row.get('Metadata');
                        if (fMeta == null || String.isBlank(fName)) continue;
                        if (JSON.serialize(fMeta).toLowerCase().contains(nameLower)) {
                            String key = ('flow|' + fName).toLowerCase();
                            if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                MetadataEngine.ReferenceItem item = new MetadataEngine.ReferenceItem();
                                item.name         = fName;
                                item.type         = 'Flow';
                                item.groupLabel   = 'Flows';
                                item.relationship = 'Active Flow references this VF Page by name — review in Flow Builder';
                                allRefs.references.add(item);
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Flow scan failed: ' + ex.getMessage());
        }

        // ── CHECK 6: Custom Button / Link scan ─────────────────
        // WebLink (Custom Button/Link) records can use /apex/PageName
        // as their URL. Url field is not filterable in SOQL — fetch all
        // URL-type links and filter in Apex.
        try {
            List<WebLink> links = [
                SELECT Name, PageOrSobjectType, Url, LinkType
                FROM WebLink
                WHERE LinkType = 'url'
                LIMIT 200
            ];
            String apexPath = '/apex/' + safeName.toLowerCase();
            for (WebLink lnk : links) {
                if (String.isBlank(lnk.Url) || !lnk.Url.toLowerCase().contains(apexPath)) continue;
                String key = ('weblink|' + lnk.Name).toLowerCase();
                if (!seenKeys.contains(key)) {
                    seenKeys.add(key);
                    MetadataEngine.ReferenceItem item = new MetadataEngine.ReferenceItem();
                    item.name         = lnk.Name + ' (' + lnk.PageOrSobjectType + ')';
                    item.type         = 'WebLink';
                    item.groupLabel   = 'Custom Buttons & Links';
                    item.relationship = 'Custom Button/Link URL points to /apex/' + safeName + ' — update or remove it first';
                    allRefs.references.add(item);
                }
            }
        } catch (Exception ex) {
            out.warningNotes.add('⚠️ Custom Button/Link scan failed: ' + ex.getMessage());
        }

        // ── Group all references by category ───────────────────
        if (allRefs.references != null && !allRefs.references.isEmpty()) {
            Map<String, List<String>> groupMap = new Map<String, List<String>>();
            for (MetadataEngine.ReferenceItem item : allRefs.references) {
                String grp = item.groupLabel != null ? item.groupLabel : 'Other';
                if (!groupMap.containsKey(grp)) groupMap.put(grp, new List<String>());
                if (!groupMap.get(grp).contains(item.name)) groupMap.get(grp).add(item.name);
            }
            out.apexClasses   = formatGroup(groupMap.get('Apex Classes'));
            out.flows         = formatGroup(groupMap.get('Flows'));
            out.customTabs    = formatGroup(groupMap.get('Custom Tabs'));
            out.flexiPages    = formatGroup(groupMap.get('Lightning Pages (FlexiPage)'));
            out.customButtons = formatGroup(groupMap.get('Custom Buttons & Links'));

            Set<String> knownGroups = new Set<String>{
                'Apex Classes', 'Flows', 'Custom Tabs',
                'Lightning Pages (FlexiPage)', 'Custom Buttons & Links'
            };
            List<String> otherLines = new List<String>();
            for (String grp : groupMap.keySet()) {
                if (!knownGroups.contains(grp)) otherLines.addAll(groupMap.get(grp));
            }
            out.otherReferences = otherLines.isEmpty() ? null : formatGroup(otherLines);
        }

        // ── Aggregate totals ────────────────────────────────────
        out.totalReferenceCount = allRefs.references != null ? allRefs.references.size() : 0;
        out.hasReferences       = out.totalReferenceCount > 0;

        // ── Build report ────────────────────────────────────────
        if (!out.hasReferences && out.warningNotes.isEmpty()) {
            out.report = '✅ No references found for VF Page "' + safeName + '". Safe to delete.';
        } else if (!out.hasReferences) {
            out.report = '✅ No blocking references found for VF Page "' + safeName + '".';
        } else if (String.isNotBlank(allRefs.formattedReport)) {
            out.report = allRefs.formattedReport;
        } else {
            out.report = buildVfReport(safeName, out);
        }

        return out;
    }

    // ── Helpers ───────────────────────────────────────────────
    private static String formatGroup(List<String> names) {
        if (names == null || names.isEmpty()) { return null; }
        String result = '';
        for (Integer i = 0; i < names.size(); i++) {
            result += (i + 1) + '. ' + names[i] + '\n';
        }
        return result;
    }

    private static String buildVfReport(String name, VfReferencesOutput out) {
        String r = '🔍 References found for VF Page "' + name + '":\n\n';
        if (String.isNotBlank(out.apexClasses))    { r += '⚙️  Apex Classes:\n'          + out.apexClasses      + '\n'; }
        if (String.isNotBlank(out.flows))          { r += '📋 Flows:\n'                  + out.flows            + '\n'; }
        if (String.isNotBlank(out.customTabs))     { r += '📑 Custom Tabs:\n'            + out.customTabs       + '\n'; }
        if (String.isNotBlank(out.flexiPages))     { r += '📄 Lightning Pages:\n'        + out.flexiPages       + '\n'; }
        if (String.isNotBlank(out.customButtons))  { r += '🔗 Custom Buttons & Links:\n' + out.customButtons    + '\n'; }
        if (String.isNotBlank(out.otherReferences)){ r += '📌 Other:\n'                  + out.otherReferences  + '\n'; }
        return r;
    }
}