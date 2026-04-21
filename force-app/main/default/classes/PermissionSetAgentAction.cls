public without sharing class PermissionSetAgentAction {

    public class PermSetRequest {
        @InvocableVariable(label='Input' description='User question about Permission Sets')
        public String input;
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

        @AuraEnabled @InvocableVariable(label='Used Permission Sets' description='Numbered list of Permission Sets that have active assignments')
        public String usedPermSets;

        @AuraEnabled @InvocableVariable(label='Unused Permission Sets' description='Numbered list of Permission Sets with zero assignments — candidates for cleanup')
        public String unusedPermSets;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Permission Set Metadata' description='Returns Permission Set Summary with unused detection for Agentforce')
    public static List<PermSetOutput> run(List<PermSetRequest> requests) {
        return new List<PermSetOutput>{ buildOutput() };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static PermSetOutput getPermissionSetSummary() {
        return buildOutput();
    }

    // ── Shared logic ──────────────────────────────────────────
    private static PermSetOutput buildOutput() {
        MetadataEngine.PermissionSetSummary summary = MetadataEngine.getPermissionSets();

        String usedList = '';
        if (summary.usedPermSets == null || summary.usedPermSets.isEmpty()) {
            usedList = 'None';
        } else {
            for (Integer i = 0; i < summary.usedPermSets.size(); i++) {
                MetadataEngine.PermissionSetInfo info = summary.usedPermSets[i];
                usedList += (i + 1) + '. ' + info.label +
                            ' (' + info.name + ')' +
                            (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                            ' | Assignments: ' + info.assignmentCount + '\n';
            }
        }

        String unusedList = '';
        if (summary.unusedPermSets == null || summary.unusedPermSets.isEmpty()) {
            unusedList = 'None';
        } else {
            for (Integer i = 0; i < summary.unusedPermSets.size(); i++) {
                MetadataEngine.PermissionSetInfo info = summary.unusedPermSets[i];
                unusedList += (i + 1) + '. ' + info.label +
                              ' (' + info.name + ')' +
                              (String.isNotBlank(info.namespacePrefix) ? ' [' + info.namespacePrefix + ']' : '') +
                              ' | Assignments: 0\n';
            }
        }

        PermSetOutput output   = new PermSetOutput();
        output.totalCount      = String.valueOf(summary.total);
        output.usedCount       = String.valueOf(summary.used);
        output.unusedCount     = String.valueOf(summary.unused);
        output.usedPermSets    = usedList;
        output.unusedPermSets  = unusedList;
        output.summary =
            'This org has ' + summary.total + ' custom Permission Sets in total. ' +
            summary.used + ' have active user assignments and ' +
            summary.unused + ' have no assignments.\n\n' +
            '--- USED PERMISSION SETS (' + summary.used + ') — Have active assignments ---\n' + usedList + '\n' +
            '--- UNUSED PERMISSION SETS (' + summary.unused + ') — No assignments — Safe to review ---\n' + unusedList;

        System.debug('PERM SET SUMMARY: ' + output.summary);
        return output;
    }
}
