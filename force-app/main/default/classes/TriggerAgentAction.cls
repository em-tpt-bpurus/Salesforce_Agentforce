@SuppressWarnings('PMD.CognitiveComplexity')
public without sharing class TriggerAgentAction {

    public class TriggerRequest {
        @InvocableVariable(label='Input' description='User question about Apex Triggers')
        public String input;

        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter Triggers (e.g. ITSms, FinanceApp). Leave blank for all.')
        public String namespaceFilter;
    }

    public class TriggerOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full trigger summary with all categories')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of Apex Triggers in the org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='Active Count' description='Number of active triggers')
        public String activeCount;

        @AuraEnabled @InvocableVariable(label='Inactive Count' description='Number of inactive triggers')
        public String inactiveCount;

        @AuraEnabled @InvocableVariable(label='Used Count' description='Number of triggers actively referenced')
        public String usedCount;

        @AuraEnabled @InvocableVariable(label='Unused Count' description='Number of triggers that are inactive or unreferenced')
        public String unusedCount;

        @AuraEnabled @InvocableVariable(label='Active Triggers' description='Numbered list of all active triggers')
        public String activeTriggers;

        @AuraEnabled @InvocableVariable(label='Inactive Triggers' description='Numbered list of all inactive triggers — safe to delete')
        public String inactiveTriggers;

        @AuraEnabled @InvocableVariable(label='Unused Triggers' description='Numbered list of all unused triggers')
        public String unusedTriggers;

        @AuraEnabled @InvocableVariable(label='Used Triggers' description='Numbered list of all used and referenced triggers')
        public String usedTriggers;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of triggers matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='Filtered Triggers' description='Numbered list of triggers matching the namespace filter')
        public String filteredTriggers;

        @AuraEnabled
        public List<MetadataEngine.TriggerInfo> allTriggerObjects;
        @AuraEnabled
        public List<MetadataEngine.TriggerInfo> unusedTriggerObjects;
        @AuraEnabled
        public List<MetadataEngine.TriggerInfo> activeTriggerObjects;
        @AuraEnabled
        public List<MetadataEngine.TriggerInfo> inactiveTriggerObjects;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Trigger Metadata' description='Returns full Trigger Summary with namespace filtering for Agentforce')
    public static List<TriggerOutput> run(List<TriggerRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<TriggerOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static TriggerOutput getTriggerSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static TriggerOutput buildOutput(String namespaceFilter) {
        MetadataEngine.TriggerSummary summary = MetadataEngine.getTriggers(namespaceFilter);

        String activeList = '';
        if (summary.activeTriggers == null || summary.activeTriggers.isEmpty()) {
            activeList = 'None';
        } else {
            for (Integer i = 0; i < summary.activeTriggers.size(); i++) {
                MetadataEngine.TriggerInfo info = summary.activeTriggers[i];
                activeList += (i + 1) + '. ' + info.name +
                              ' | Object: '   + info.objectName +
                              ' | Lines: '    + info.linesOfCode +
                              ' | Modified: ' + info.lastModifiedDate + '\n';
            }
        }

        String inactiveList = '';
        if (summary.inactiveTriggers == null || summary.inactiveTriggers.isEmpty()) {
            inactiveList = 'None';
        } else {
            for (Integer i = 0; i < summary.inactiveTriggers.size(); i++) {
                MetadataEngine.TriggerInfo info = summary.inactiveTriggers[i];
                inactiveList += (i + 1) + '. ' + info.name +
                                ' | Object: '   + info.objectName +
                                ' | Lines: '    + info.linesOfCode +
                                ' | Modified: ' + info.lastModifiedDate + '\n';
            }
        }

        String unusedList = '';
        if (summary.unusedTriggers == null || summary.unusedTriggers.isEmpty()) {
            unusedList = 'None';
        } else {
            for (Integer i = 0; i < summary.unusedTriggers.size(); i++) {
                MetadataEngine.TriggerInfo info = summary.unusedTriggers[i];
                unusedList += (i + 1) + '. ' + info.name +
                              ' | Object: '  + info.objectName +
                              ' | Active: '  + info.isActive +
                              ' | Lines: '   + info.linesOfCode +
                              ' | Modified: '+ info.lastModifiedDate + '\n';
            }
        }

        String usedList = '';
        if (summary.usedTriggerNames == null || summary.usedTriggerNames.isEmpty()) {
            usedList = 'None';
        } else {
            for (Integer i = 0; i < summary.usedTriggerNames.size(); i++) {
                usedList += (i + 1) + '. ' + summary.usedTriggerNames[i] + '\n';
            }
        }

        // Namespace-filtered list
        String filteredList = '';
        Integer filteredTotal = summary.filteredTotal != null ? summary.filteredTotal : 0;
        if (summary.filteredTriggers == null || summary.filteredTriggers.isEmpty()) {
            filteredList = String.isNotBlank(namespaceFilter)
                ? 'No triggers found with namespace: ' + namespaceFilter
                : 'None';
        } else {
            for (Integer i = 0; i < summary.filteredTriggers.size(); i++) {
                MetadataEngine.TriggerInfo info = summary.filteredTriggers[i];
                filteredList += (i + 1) + '. ' + info.name +
                                ' | Object: '  + info.objectName +
                                ' | Active: '  + info.isActive +
                                ' | Lines: '   + info.linesOfCode +
                                (String.isNotBlank(info.namespacePrefix)
                                    ? ' | NS: ' + info.namespacePrefix : '') + '\n';
            }
        }

        String nsDisplay = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';

        TriggerOutput output          = new TriggerOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.activeCount            = String.valueOf(summary.active);
        output.inactiveCount          = String.valueOf(summary.inactive);
        output.usedCount              = String.valueOf(summary.used);
        output.unusedCount            = String.valueOf(summary.unused);
        output.activeTriggers         = activeList;
        output.inactiveTriggers       = inactiveList;
        output.unusedTriggers         = unusedList;
        output.usedTriggers           = usedList;
        output.filteredCount          = String.valueOf(filteredTotal);
        output.namespaceFilterApplied = nsDisplay;
        output.filteredTriggers       = filteredList;
        output.summary =
            'This org has ' + summary.total + ' Apex Triggers in total.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n\n' +
            '--- USED TRIGGERS ('    + summary.used    + ') — Actively referenced ---\n' + usedList    + '\n' +
            '--- UNUSED TRIGGERS ('  + summary.unused  + ') — Safe to delete ---\n'      + unusedList  + '\n' +
            '--- ACTIVE TRIGGERS ('  + summary.active  + ') ---\n'                       + activeList  + '\n' +
            '--- INACTIVE TRIGGERS (' + summary.inactive + ') — Safe to delete ---\n'   + inactiveList +
            (String.isNotBlank(namespaceFilter)
                ? '\n\n--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + filteredTotal + ') ---\n' + filteredList
                : '');

        output.allTriggerObjects      = summary.activeTriggers;
        output.unusedTriggerObjects    = summary.unusedTriggers;
        output.activeTriggerObjects    = summary.activeTriggers;
        output.inactiveTriggerObjects  = summary.inactiveTriggers;
        return output;
    }
}