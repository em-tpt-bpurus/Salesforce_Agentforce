public without sharing class ValidationRuleAgentAction {

    public class VRRequest {
        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter Validation Rules (e.g. ITSms, FinanceApp). Leave blank for all.')
        public String namespaceFilter;
    }

    public class VROutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full Validation Rule summary')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of Validation Rules in org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='Active Count' description='Number of active Validation Rules')
        public String activeCount;

        @AuraEnabled @InvocableVariable(label='Inactive Count' description='Number of inactive Validation Rules — candidates for cleanup')
        public String inactiveCount;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of Validation Rules matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='Active Rules' description='Numbered list of all active Validation Rules')
        public String activeRules;

        @AuraEnabled @InvocableVariable(label='Inactive Rules' description='Numbered list of all inactive Validation Rules — safe to review/delete')
        public String inactiveRules;

        @AuraEnabled @InvocableVariable(label='Filtered Rules' description='Numbered list of Validation Rules matching the namespace filter')
        public String filteredRules;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Validation Rule Metadata' description='Returns Validation Rule Summary with namespace filtering and active/inactive detection for Agentforce')
    public static List<VROutput> run(List<VRRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<VROutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static VROutput getValidationRuleSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static VROutput buildOutput(String namespaceFilter) {
        MetadataEngine.ValidationRuleSummary summary = MetadataEngine.getValidationRules(namespaceFilter);

        String activeList = '';
        if (summary.activeRules == null || summary.activeRules.isEmpty()) {
            activeList = 'None';
        } else {
            for (Integer i = 0; i < summary.activeRules.size(); i++) {
                MetadataEngine.ValidationRuleInfo info = summary.activeRules[i];
                activeList += (i + 1) + '. ' + info.objectName + '.' + info.name +
                              (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                              ' | Active: true\n';
            }
        }

        String inactiveList = '';
        if (summary.inactiveRules == null || summary.inactiveRules.isEmpty()) {
            inactiveList = 'None';
        } else {
            for (Integer i = 0; i < summary.inactiveRules.size(); i++) {
                MetadataEngine.ValidationRuleInfo info = summary.inactiveRules[i];
                inactiveList += (i + 1) + '. ' + info.objectName + '.' + info.name +
                                (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                                ' | Active: false\n';
            }
        }

        String filteredList = '';
        if (summary.filteredRules == null || summary.filteredRules.isEmpty()) {
            filteredList = String.isNotBlank(namespaceFilter)
                ? 'No Validation Rules found with namespace: ' + namespaceFilter
                : 'None';
        } else {
            for (Integer i = 0; i < summary.filteredRules.size(); i++) {
                MetadataEngine.ValidationRuleInfo info = summary.filteredRules[i];
                filteredList += (i + 1) + '. ' + info.objectName + '.' + info.name +
                                (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                                ' | Active: ' + info.isActive + '\n';
            }
        }

        String nsDisplay = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';

        VROutput output               = new VROutput();
        output.totalCount             = String.valueOf(summary.total);
        output.activeCount            = String.valueOf(summary.active);
        output.inactiveCount          = String.valueOf(summary.inactive);
        output.filteredCount          = String.valueOf(
            summary.filteredRules != null ? summary.filteredRules.size() : 0);
        output.namespaceFilterApplied = nsDisplay;
        output.activeRules            = activeList;
        output.inactiveRules          = inactiveList;
        output.filteredRules          = filteredList;
        output.summary =
            'This org has ' + summary.total + ' Validation Rules in total. ' +
            summary.active + ' are active and ' +
            summary.inactive + ' are inactive.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n' +
            'Matching Rules: ' + output.filteredCount + '\n\n' +
            '--- ACTIVE VALIDATION RULES (' + summary.active + ') ---\n' + activeList + '\n' +
            '--- INACTIVE VALIDATION RULES (' + summary.inactive + ') — Safe to review ---\n' + inactiveList + '\n' +
            (String.isNotBlank(namespaceFilter)
                ? '--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + output.filteredCount + ') ---\n' + filteredList
                : '');

        System.debug('VALIDATION RULE SUMMARY: ' + output.summary);
        return output;
    }
}
