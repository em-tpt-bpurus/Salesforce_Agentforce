public without sharing class PermissionSetAgentAction {

    public class PermSetRequest {
        @InvocableVariable(label='Input' description='User question about Permission Sets')
        public String input;

        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter Permission Sets. Leave blank for all.')
        public String namespaceFilter;
    }

    public class PermSetOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full Permission Set summary with unused detection')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of custom Permission Sets in org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='Used Count' description='Number of Permission Sets assigned to at least one user')
        public String usedCount;

        @AuraEnabled @InvocableVariable(label='Unused Count' description='Number of Permission Sets with no user assignments')
        public String unusedCount;

        @AuraEnabled @InvocableVariable(label='With Namespace Count' description='Number of Permission Sets with a namespace prefix')
        public String withNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Without Namespace Count' description='Number of Permission Sets without a namespace prefix')
        public String withoutNamespaceCount;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of Permission Sets matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='Used Permission Sets' description='Numbered list of Permission Sets that have active assignments')
        public String usedPermSets;

        @AuraEnabled @InvocableVariable(label='Unused Permission Sets' description='Numbered list of Permission Sets with zero assignments — candidates for cleanup')
        public String unusedPermSets;

        @AuraEnabled @InvocableVariable(label='Filtered Permission Sets' description='Numbered list of namespace-filtered Permission Sets')
        public String filteredPermSets;

        @AuraEnabled
        public List<MetadataEngine.PermissionSetInfo> usedPermSetObjects;
        @AuraEnabled
        public List<MetadataEngine.PermissionSetInfo> unusedPermSetObjects;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Permission Set Metadata' description='Returns Permission Set Summary with unused detection for Agentforce')
    public static List<PermSetOutput> run(List<PermSetRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter : null;
        return new List<PermSetOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static PermSetOutput getPermissionSetSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static String buildUsedPermSetList(MetadataEngine.PermissionSetSummary summary) {
        if (summary.usedPermSets == null || summary.usedPermSets.isEmpty()) {
            return 'None';
        }
        String result = '';
        for (Integer i = 0; i < summary.usedPermSets.size(); i++) {
            MetadataEngine.PermissionSetInfo info = summary.usedPermSets[i];
            result += (i + 1) + '. ' + info.label +
                        ' (' + info.name + ')' +
                        (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                        ' | Assignments: ' + info.assignmentCount + '\n';
        }
        return result;
    }

    private static String buildUnusedPermSetList(MetadataEngine.PermissionSetSummary summary) {
        if (summary.unusedPermSets == null || summary.unusedPermSets.isEmpty()) {
            return 'None';
        }
        String result = '';
        for (Integer i = 0; i < summary.unusedPermSets.size(); i++) {
            MetadataEngine.PermissionSetInfo info = summary.unusedPermSets[i];
            result += (i + 1) + '. ' + info.label +
                          ' (' + info.name + ')' +
                          (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                          ' | Assignments: 0\n';
        }
        return result;
    }

    private static String buildFilteredPermSetList(List<MetadataEngine.PermissionSetInfo> permSets) {
       if (permSets == null || permSets.isEmpty()) { return 'None'; }
        String result = '';
        for (Integer i = 0; i < permSets.size(); i++) {
            MetadataEngine.PermissionSetInfo info = permSets[i];
            result += (i + 1) + '. ' + info.label +
                      ' (' + info.name + ')' +
                      (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                      ' | Assignments: ' + info.assignmentCount + '\n';
        }
        return result;
    }

    private static PermSetOutput buildOutput(String namespaceFilter) {
        MetadataEngine.PermissionSetSummary summary = MetadataEngine.getPermissionSets(namespaceFilter);

        String usedList      = buildUsedPermSetList(summary);
        String unusedList    = buildUnusedPermSetList(summary);
        String filteredList  = buildFilteredPermSetList(summary.filteredPermSets);
        String nsDisplay     = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';
        Integer withNs       = summary.withNamespace    != null ? summary.withNamespace    : 0;
        Integer withoutNs    = summary.withoutNamespace != null ? summary.withoutNamespace : 0;
        Integer filteredCnt  = summary.filteredTotal    != null ? summary.filteredTotal    : 0;

        PermSetOutput output          = new PermSetOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.usedCount              = String.valueOf(summary.used);
        output.unusedCount            = String.valueOf(summary.unused);
        output.withNamespaceCount     = String.valueOf(withNs);
        output.withoutNamespaceCount  = String.valueOf(withoutNs);
        output.filteredCount          = String.valueOf(filteredCnt);
        output.namespaceFilterApplied = nsDisplay;
        output.usedPermSets           = usedList;
        output.unusedPermSets         = unusedList;
        output.filteredPermSets       = filteredList;
        output.summary =
            'This org has ' + summary.total + ' custom Permission Sets in total. ' +
            summary.used + ' have active user assignments and ' +
            summary.unused + ' have no assignments.\n' +
            withNs + ' have a namespace prefix, ' + withoutNs + ' do not.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n\n' +
            '--- USED PERMISSION SETS (' + summary.used + ') — Have active assignments ---\n' + usedList + '\n' +
            '--- UNUSED PERMISSION SETS (' + summary.unused + ') — No assignments — Safe to review ---\n' + unusedList +
            (String.isNotBlank(namespaceFilter)
                ? '\n\n--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + filteredCnt + ') ---\n' + filteredList
                : '');

        output.usedPermSetObjects   = summary.usedPermSets;
        output.unusedPermSetObjects = summary.unusedPermSets;
        System.debug('PERM SET SUMMARY: ' + output.summary);
        return output;
    }
}