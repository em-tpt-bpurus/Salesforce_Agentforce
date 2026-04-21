public without sharing class MetadataAgentAction {

    public class FlowRequest {
        @InvocableVariable(label='Input' description='User question about flows')
        public String input;

        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter flows (e.g. ITSms, FinanceApp). Leave blank for all.')
        public String namespaceFilter;
    }

    public class FlowOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full summary including active and inactive flow lists')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of flows')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='Active Count' description='Number of active flows')
        public String activeCount;

        @AuraEnabled @InvocableVariable(label='Inactive Count' description='Number of inactive flows')
        public String inactiveCount;

        @AuraEnabled @InvocableVariable(label='Active Flows' description='Numbered list of ALL active flows')
        public String activeFlows;

        @AuraEnabled @InvocableVariable(label='Inactive Flows' description='Numbered list of ALL inactive flows')
        public String inactiveFlows;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of flows matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='Filtered Active Flows' description='Numbered list of namespace-filtered active flows')
        public String filteredActiveFlows;

        @AuraEnabled @InvocableVariable(label='Filtered Inactive Flows' description='Numbered list of namespace-filtered inactive flows')
        public String filteredInactiveFlows;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Flows Metadata' description='Returns Flow Summary with optional namespace filtering for Agentforce')
    public static List<FlowOutput> run(List<FlowRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<FlowOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static FlowOutput getFlowSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static FlowOutput buildOutput(String namespaceFilter) {
        MetadataEngine.FlowSummary summary = MetadataEngine.getFlows(namespaceFilter);

        String activeList           = buildNumberedList(summary.activeFlows);
        String inactiveList         = buildNumberedList(summary.inactiveFlows);
        String filteredActiveList   = buildNumberedList(summary.filteredActiveFlows);
        String filteredInactiveList = buildNumberedList(summary.filteredInactiveFlows);

        String  nsDisplay     = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';
        Integer filteredTotal = summary.filteredTotal != null ? summary.filteredTotal : 0;

        FlowOutput output             = new FlowOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.activeCount            = String.valueOf(summary.active);
        output.inactiveCount          = String.valueOf(summary.inactive);
        output.activeFlows            = activeList;
        output.inactiveFlows          = inactiveList;
        output.filteredCount          = String.valueOf(filteredTotal);
        output.namespaceFilterApplied = nsDisplay;
        output.filteredActiveFlows    = filteredActiveList;
        output.filteredInactiveFlows  = filteredInactiveList;
        output.summary =
            'This org has ' + summary.total + ' flows in total. ' +
            summary.active + ' are active and ' + summary.inactive + ' are inactive.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n\n' +
            '--- ACTIVE FLOWS (' + summary.active + ') ---\n' + activeList + '\n' +
            '--- INACTIVE FLOWS (' + summary.inactive + ') ---\n' + inactiveList +
            (String.isNotBlank(namespaceFilter)
                ? '\n\n--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + filteredTotal + ') ---\n' +
                  'Active:\n' + filteredActiveList + '\nInactive:\n' + filteredInactiveList
                : '');

        System.debug('FLOW SUMMARY: ' + output.summary);
        return output;
    }

    private static String buildNumberedList(List<String> items) {
        if (items == null || items.isEmpty()) return 'None';
        String result = '';
        for (Integer i = 0; i < items.size(); i++) {
            result += (i + 1) + '. ' + items[i] + '\n';
        }
        return result;
    }
}
