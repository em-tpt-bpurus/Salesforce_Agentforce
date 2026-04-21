public without sharing class AuraAgentAction {

    public class AuraRequest {
        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter Aura components (e.g. FinanceApp, ITSms). Leave blank for all.')
        public String namespaceFilter;
    }

    public class AuraOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full Aura component summary')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of Aura components in org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='With Namespace Count' description='Number of Aura components with a namespace prefix')
        public String withNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Without Namespace Count' description='Number of Aura components without a namespace prefix')
        public String withoutNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of Aura components matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='All Components' description='Numbered list of ALL Aura components')
        public String allComponents;

        @AuraEnabled @InvocableVariable(label='Filtered Components' description='Numbered list of namespace-filtered Aura components')
        public String filteredComponents;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Aura Components Metadata' description='Returns Aura Component Summary with optional namespace filtering for Agentforce')
    public static List<AuraOutput> run(List<AuraRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<AuraOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static AuraOutput getAuraSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static AuraOutput buildOutput(String namespaceFilter) {
        MetadataEngine.AuraSummary summary = MetadataEngine.getAuraComponents(namespaceFilter);

        String allList = '';
        if (summary.allComponents == null || summary.allComponents.isEmpty()) {
            allList = 'None';
        } else {
            for (Integer i = 0; i < summary.allComponents.size(); i++) {
                MetadataEngine.AuraComponentInfo info = summary.allComponents[i];
                allList += (i + 1) + '. ' + info.name +
                           (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                           ' | API: ' + (String.isNotBlank(info.apiVersion) ? info.apiVersion : 'N/A') +
                           ' | Modified: ' + (String.isNotBlank(info.lastModifiedDate) ? info.lastModifiedDate : 'N/A') + '\n';
            }
        }

        String filteredList = '';
        if (summary.filteredComponents == null || summary.filteredComponents.isEmpty()) {
            filteredList = String.isNotBlank(namespaceFilter)
                ? 'No Aura components found with namespace: ' + namespaceFilter
                : 'None';
        } else {
            for (Integer i = 0; i < summary.filteredComponents.size(); i++) {
                MetadataEngine.AuraComponentInfo info = summary.filteredComponents[i];
                filteredList += (i + 1) + '. ' + info.name +
                                (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                                ' | API: ' + (String.isNotBlank(info.apiVersion) ? info.apiVersion : 'N/A') +
                                ' | Modified: ' + (String.isNotBlank(info.lastModifiedDate) ? info.lastModifiedDate : 'N/A') + '\n';
            }
        }

        String nsDisplay = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';

        AuraOutput output             = new AuraOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.withNamespaceCount     = String.valueOf(summary.withNamespace);
        output.withoutNamespaceCount  = String.valueOf(summary.withoutNamespace);
        output.filteredCount          = String.valueOf(
            summary.filteredComponents != null ? summary.filteredComponents.size() : 0);
        output.namespaceFilterApplied = nsDisplay;
        output.allComponents          = allList;
        output.filteredComponents     = filteredList;
        output.summary =
            'This org has ' + summary.total + ' Aura components in total. ' +
            summary.withNamespace + ' have a namespace prefix, ' +
            summary.withoutNamespace + ' do not.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n' +
            'Matching Components: ' + output.filteredCount + '\n\n' +
            '--- ALL AURA COMPONENTS (' + summary.total + ') ---\n' + allList + '\n' +
            (String.isNotBlank(namespaceFilter)
                ? '--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + output.filteredCount + ') ---\n' + filteredList
                : '');

        System.debug('AURA SUMMARY: ' + output.summary);
        return output;
    }
}
