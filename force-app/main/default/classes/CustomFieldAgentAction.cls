public without sharing class CustomFieldAgentAction {

    public class FieldRequest {
        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter Custom Fields (e.g. ITSms, FinanceApp). Leave blank for all.')
        public String namespaceFilter;
    }

    public class FieldOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full Custom Field summary')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of custom fields in org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='With Namespace Count' description='Number of fields with a namespace prefix')
        public String withNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Without Namespace Count' description='Number of fields without a namespace prefix')
        public String withoutNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of fields matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='All Fields' description='Numbered list of ALL custom fields')
        public String allFields;

        @AuraEnabled @InvocableVariable(label='Filtered Fields' description='Numbered list of namespace-filtered custom fields')
        public String filteredFields;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Custom Field Metadata' description='Returns Custom Field Summary with optional namespace filtering for Agentforce')
    public static List<FieldOutput> run(List<FieldRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<FieldOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static FieldOutput getCustomFieldSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static FieldOutput buildOutput(String namespaceFilter) {
        MetadataEngine.CustomFieldSummary summary = MetadataEngine.getCustomFields(namespaceFilter);

        String allList = '';
        if (summary.allFields == null || summary.allFields.isEmpty()) {
            allList = 'None';
        } else {
            for (Integer i = 0; i < summary.allFields.size(); i++) {
                MetadataEngine.CustomFieldInfo info = summary.allFields[i];
                allList += (i + 1) + '. ' + info.objectName + '.' + info.name +
                           (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                           ' | Type: ' + (String.isNotBlank(info.dataType) ? info.dataType : 'N/A') + '\n';
            }
        }

        String filteredList = '';
        if (summary.filteredFields == null || summary.filteredFields.isEmpty()) {
            filteredList = String.isNotBlank(namespaceFilter)
                ? 'No custom fields found with namespace: ' + namespaceFilter
                : 'None';
        } else {
            for (Integer i = 0; i < summary.filteredFields.size(); i++) {
                MetadataEngine.CustomFieldInfo info = summary.filteredFields[i];
                filteredList += (i + 1) + '. ' + info.objectName + '.' + info.name +
                                (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                                ' | Type: ' + (String.isNotBlank(info.dataType) ? info.dataType : 'N/A') + '\n';
            }
        }

        String nsDisplay = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';

        FieldOutput output            = new FieldOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.withNamespaceCount     = String.valueOf(summary.withNamespace);
        output.withoutNamespaceCount  = String.valueOf(summary.withoutNamespace);
        output.filteredCount          = String.valueOf(
            summary.filteredFields != null ? summary.filteredFields.size() : 0);
        output.namespaceFilterApplied = nsDisplay;
        output.allFields              = allList;
        output.filteredFields         = filteredList;
        output.summary =
            'This org has ' + summary.total + ' custom fields in total. ' +
            summary.withNamespace + ' have a namespace prefix, ' +
            summary.withoutNamespace + ' do not.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n' +
            'Matching Fields: ' + output.filteredCount + '\n\n' +
            '--- ALL CUSTOM FIELDS (' + summary.total + ') ---\n' + allList + '\n' +
            (String.isNotBlank(namespaceFilter)
                ? '--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + output.filteredCount + ') ---\n' + filteredList
                : '');

        System.debug('CUSTOM FIELD SUMMARY: ' + output.summary);
        return output;
    }
}
