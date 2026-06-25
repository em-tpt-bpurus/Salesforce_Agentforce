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

        @AuraEnabled @InvocableVariable(label='Unreferenced Count' description='Number of LWC components not referenced in any page or component')
        public String unreferencedCount;

        @AuraEnabled @InvocableVariable(label='Unreferenced Components' description='Numbered list of LWC components with no page/component references — safe to review')
        public String unreferencedComponents;

        @AuraEnabled
        public List<MetadataEngine.LwcComponentInfo> allLwcObjects;
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
        String unreferencedList = '';
        Integer unknownCount = 0;
        if (summary.allComponents == null || summary.allComponents.isEmpty()) {
            allList = MetadataConstants.NONE;
        } else {
            for (Integer i = 0; i < summary.allComponents.size(); i++) {
                MetadataEngine.LwcComponentInfo info = summary.allComponents[i];
                String refInfo;
                if (info.isReferenced == true) {
                    refInfo = MetadataConstants.COL_REF_BY + (String.isNotBlank(info.referencedBy) ? info.referencedBy : 'Yes');
                } else if (info.isReferenced == false) {
                    refInfo = ' | Unreferenced';
                } else {
                    // isReferenced == null → UNKNOWN: scan was incomplete
                    refInfo = ' | Unknown (scan incomplete — FlexiPage API unavailable in this org)';
                    unknownCount++;
                }
                allList += (i + 1) + '. ' + info.name +
                           '' +
                           MetadataConstants.COL_API + (String.isNotBlank(info.apiVersion) ? info.apiVersion : MetadataConstants.NA) +
                           refInfo + '\n';
            }
        }
        if (summary.unreferencedComponents != null && !summary.unreferencedComponents.isEmpty()) {
            for (Integer i = 0; i < summary.unreferencedComponents.size(); i++) {
                MetadataEngine.LwcComponentInfo info = summary.unreferencedComponents[i];
                unreferencedList += (i + 1) + '. ' + info.name +
                    '' +
                    MetadataConstants.COL_API + (String.isNotBlank(info.apiVersion) ? info.apiVersion : MetadataConstants.NA) + '\n';
            }
        } else {
            unreferencedList = MetadataConstants.NONE;
        }

        String filteredList = '';
        if (summary.filteredComponents == null || summary.filteredComponents.isEmpty()) {
            filteredList = String.isNotBlank(namespaceFilter)
                ? 'No LWC components found with namespace: ' + namespaceFilter
                : MetadataConstants.NONE;
        } else {
            for (Integer i = 0; i < summary.filteredComponents.size(); i++) {
                MetadataEngine.LwcComponentInfo info = summary.filteredComponents[i];
                filteredList += (i + 1) + '. ' + info.name +
                                '' +
                                MetadataConstants.COL_API + (String.isNotBlank(info.apiVersion) ? info.apiVersion : MetadataConstants.NA) +
                                MetadataConstants.COL_MODIFIED + (String.isNotBlank(info.lastModifiedDate) ? info.lastModifiedDate : MetadataConstants.NA) + '\n';
            }
        }

        String nsDisplay = String.isNotBlank(namespaceFilter) ? namespaceFilter : MetadataConstants.NS_ALL;

        LwcOutput output              = new LwcOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.withNamespaceCount     = String.valueOf(summary.withNamespace);
        output.withoutNamespaceCount  = String.valueOf(summary.withoutNamespace);
        output.filteredCount          = String.valueOf(
            summary.filteredComponents != null ? summary.filteredComponents.size() : 0);
        output.namespaceFilterApplied = nsDisplay;
        output.allComponents          = allList;
        output.filteredComponents     = filteredList;
        output.unreferencedCount      = String.valueOf(summary.unreferencedCount != null ? summary.unreferencedCount : 0);
        output.unreferencedComponents = unreferencedList;
        output.summary =
            'This org has ' + summary.total + ' LWC components. ' +
            summary.withNamespace + ' have a namespace prefix, ' +
            summary.withoutNamespace + ' do not. ' +
            output.unreferencedCount + ' are confirmed unreferenced.' +
            (unknownCount > 0
                ? ' ' + unknownCount + ' show as Unknown because the FlexiPage Metadata API is not available in this org — they may be referenced. Do not delete Unknown components without manual verification in Setup → Lightning App Builder.'
                : '') + '\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n' +
            'Matching Components: ' + output.filteredCount + '\n\n' +
            MetadataConstants.SEC_ALL_COMPONENTS + ' LWC COMPONENTS (' + summary.total + ') ---\n' + allList + '\n' +
            MetadataConstants.SEC_UNREFERENCED_LWC + ' (' + output.unreferencedCount + ') ---\n' + unreferencedList + '\n' +
            (String.isNotBlank(namespaceFilter)
                ? MetadataConstants.SEC_FILTERED_NS + namespaceFilter + ' (' + output.filteredCount + ') ---\n' + filteredList
                : '');

        output.allLwcObjects = summary.allComponents;
        System.debug('LWC SUMMARY: ' + output.summary);
        return output;
    }
}