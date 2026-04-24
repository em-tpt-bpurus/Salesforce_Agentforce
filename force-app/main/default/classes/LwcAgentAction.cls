@SuppressWarnings('PMD.CognitiveComplexity')
public without sharing class LwcAgentAction {

    public class LwcRequest {
        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter LWC components (e.g. FinanceApp, ITSms). Leave blank for all.')
        public String namespaceFilter;
    }

    public class LwcOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full LWC component summary')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of LWC components in org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='With Namespace Count' description='Number of LWC components with a namespace prefix')
        public String withNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Without Namespace Count' description='Number of LWC components without a namespace prefix')
        public String withoutNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of LWC components matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='All Components' description='Numbered list of ALL LWC components')
        public String allComponents;

        @AuraEnabled @InvocableVariable(label='Filtered Components' description='Numbered list of namespace-filtered LWC components')
        public String filteredComponents;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='LWC Components Metadata' description='Returns LWC Component Summary with optional namespace filtering for Agentforce')
    public static List<LwcOutput> run(List<LwcRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<LwcOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static LwcOutput getLwcSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static LwcOutput buildOutput(String namespaceFilter) {
        MetadataEngine.LwcSummary summary = MetadataEngine.getLwcComponents(namespaceFilter);

        String allList = '';
        if (summary.allComponents == null || summary.allComponents.isEmpty()) {
            allList = 'None';
        } else {
            for (Integer i = 0; i < summary.allComponents.size(); i++) {
                MetadataEngine.LwcComponentInfo info = summary.allComponents[i];
                allList += (i + 1) + '. ' + info.name +
                           (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                           ' | API: ' + (String.isNotBlank(info.apiVersion) ? info.apiVersion : 'N/A') +
                           ' | Modified: ' + (String.isNotBlank(info.lastModifiedDate) ? info.lastModifiedDate : 'N/A') + '\n';
            }
        }

        String filteredList = '';
        if (summary.filteredComponents == null || summary.filteredComponents.isEmpty()) {
            filteredList = String.isNotBlank(namespaceFilter)
                ? 'No LWC components found with namespace: ' + namespaceFilter
                : 'None';
        } else {
            for (Integer i = 0; i < summary.filteredComponents.size(); i++) {
                MetadataEngine.LwcComponentInfo info = summary.filteredComponents[i];
                filteredList += (i + 1) + '. ' + info.name +
                                (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                                ' | API: ' + (String.isNotBlank(info.apiVersion) ? info.apiVersion : 'N/A') +
                                ' | Modified: ' + (String.isNotBlank(info.lastModifiedDate) ? info.lastModifiedDate : 'N/A') + '\n';
            }
        }

        String nsDisplay = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';

        LwcOutput output              = new LwcOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.withNamespaceCount     = String.valueOf(summary.withNamespace);
        output.withoutNamespaceCount  = String.valueOf(summary.withoutNamespace);
        output.filteredCount          = String.valueOf(
            summary.filteredComponents != null ? summary.filteredComponents.size() : 0);
        output.namespaceFilterApplied = nsDisplay;
        output.allComponents          = allList;
        output.filteredComponents     = filteredList;
        output.summary =
            'This org has ' + summary.total + ' LWC components in total. ' +
            summary.withNamespace + ' have a namespace prefix, ' +
            summary.withoutNamespace + ' do not.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n' +
            'Matching Components: ' + output.filteredCount + '\n\n' +
            '--- ALL LWC COMPONENTS (' + summary.total + ') ---\n' + allList + '\n' +
            (String.isNotBlank(namespaceFilter)
                ? '--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + output.filteredCount + ') ---\n' + filteredList
                : '');

        System.debug('LWC SUMMARY: ' + output.summary);
        return output;
    }
}
