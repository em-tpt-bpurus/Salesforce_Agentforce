public without sharing class CustomObjectAgentAction {

    public class ObjectRequest {
        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter Custom Objects (e.g. ITSms, FinanceApp). Leave blank for all.')
        public String namespaceFilter;
    }

    public class ObjectOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full Custom Object summary')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of custom objects in org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='With Namespace Count' description='Number of objects with a namespace prefix')
        public String withNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Without Namespace Count' description='Number of objects without a namespace prefix')
        public String withoutNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of objects matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='All Objects' description='Numbered list of ALL custom objects')
        public String allObjects;

        @AuraEnabled @InvocableVariable(label='Filtered Objects' description='Numbered list of namespace-filtered custom objects')
        public String filteredObjects;

        @AuraEnabled
        public List<MetadataEngine.CustomObjectInfo> allObjectObjects;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Custom Object Metadata' description='Returns Custom Object Summary with optional namespace filtering for Agentforce')
    public static List<ObjectOutput> run(List<ObjectRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<ObjectOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static ObjectOutput getCustomObjectSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static String buildObjectLine(Integer idx, MetadataEngine.CustomObjectInfo info) {
        return (idx + 1) + '. ' + info.name +
               (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
               ' | Label: ' + (String.isNotBlank(info.label) ? info.label : 'N/A') + '\n';
    }

    private static String buildObjectList(List<MetadataEngine.CustomObjectInfo> objects, String namespaceFilter, Boolean isFiltered) {
        if (objects == null || objects.isEmpty()) {
            if (isFiltered && String.isNotBlank(namespaceFilter)) {
                return 'No custom objects found with namespace: ' + namespaceFilter;
            }
            return 'None';
        }
        String result = '';
        for (Integer i = 0; i < objects.size(); i++) {
            result += buildObjectLine(i, objects[i]);
        }
        return result;
    }

    private static ObjectOutput buildOutput(String namespaceFilter) {
        MetadataEngine.CustomObjectSummary summary = MetadataEngine.getCustomObjects(namespaceFilter);

        String allList      = buildObjectList(summary.allObjects,      namespaceFilter, false);
        String filteredList = buildObjectList(summary.filteredObjects,  namespaceFilter, true);

        String nsDisplay = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';

        ObjectOutput output           = new ObjectOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.withNamespaceCount     = String.valueOf(summary.withNamespace);
        output.withoutNamespaceCount  = String.valueOf(summary.withoutNamespace);
        output.filteredCount          = String.valueOf(
            summary.filteredObjects != null ? summary.filteredObjects.size() : 0);
        output.namespaceFilterApplied = nsDisplay;
        output.allObjects             = allList;
        output.filteredObjects        = filteredList;
        output.summary =
            'This org has ' + summary.total + ' custom objects in total. ' +
            summary.withNamespace + ' have a namespace prefix, ' +
            summary.withoutNamespace + ' do not.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n' +
            'Matching Objects: ' + output.filteredCount + '\n\n' +
            '--- ALL CUSTOM OBJECTS (' + summary.total + ') ---\n' + allList + '\n' +
            (String.isNotBlank(namespaceFilter)
                ? '--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + output.filteredCount + ') ---\n' + filteredList
                : '');

        output.allObjectObjects = summary.allObjects;
        System.debug('CUSTOM OBJECT SUMMARY: ' + output.summary);
        return output;
    }
}