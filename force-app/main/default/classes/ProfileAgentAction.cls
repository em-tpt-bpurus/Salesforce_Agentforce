public without sharing class ProfileAgentAction {

    public class ProfileRequest {
        @InvocableVariable(label='Input' description='User question about Profiles')
        public String input;
    }

    public class ProfileOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full Profile summary with used and unused detection')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of Profiles in org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='Used Count' description='Number of Profiles assigned to at least one active user')
        public String usedCount;

        @AuraEnabled @InvocableVariable(label='Unused Count' description='Number of Profiles not assigned to any active users')
        public String unusedCount;

        @AuraEnabled @InvocableVariable(label='Used Profiles' description='Numbered list of Profiles that are assigned to active users')
        public String usedProfiles;

        @AuraEnabled @InvocableVariable(label='Unused Profiles' description='Numbered list of Profiles with zero active user assignments — candidates for cleanup')
        public String unusedProfiles;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Profile Metadata' description='Returns Profile Summary with unused profile detection for Agentforce')
    public static List<ProfileOutput> run(List<ProfileRequest> requests) {
        return new List<ProfileOutput>{ buildOutput() };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static ProfileOutput getProfileSummary() {
        return buildOutput();
    }

    // ── Shared logic ──────────────────────────────────────────
    private static ProfileOutput buildOutput() {
        MetadataEngine.ProfileSummary summary = MetadataEngine.getProfiles();

        String usedList = '';
        if (summary.usedProfiles == null || summary.usedProfiles.isEmpty()) {
            usedList = 'None';
        } else {
            for (Integer i = 0; i < summary.usedProfiles.size(); i++) {
                MetadataEngine.ProfileInfo info = summary.usedProfiles[i];
                usedList += (i + 1) + '. ' + info.name +
                            ' | License: ' + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : 'N/A') +
                            ' | Users: ' + info.assignedUserCount + '\n';
            }
        }

        String unusedList = '';
        if (summary.unusedProfiles == null || summary.unusedProfiles.isEmpty()) {
            unusedList = 'None';
        } else {
            for (Integer i = 0; i < summary.unusedProfiles.size(); i++) {
                MetadataEngine.ProfileInfo info = summary.unusedProfiles[i];
                unusedList += (i + 1) + '. ' + info.name +
                              ' | License: ' + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : 'N/A') +
                              ' | Users: 0\n';
            }
        }

        ProfileOutput output  = new ProfileOutput();
        output.totalCount     = String.valueOf(summary.total);
        output.usedCount      = String.valueOf(summary.used);
        output.unusedCount    = String.valueOf(summary.unused);
        output.usedProfiles   = usedList;
        output.unusedProfiles = unusedList;
        output.summary =
            'This org has ' + summary.total + ' Profiles in total. ' +
            summary.used + ' are assigned to active users and ' +
            summary.unused + ' are not assigned to any active users.\n\n' +
            '--- USED PROFILES (' + summary.used + ') — Assigned to active users ---\n' + usedList + '\n' +
            '--- UNUSED PROFILES (' + summary.unused + ') — No active user assignments ---\n' + unusedList;

        System.debug('PROFILE SUMMARY: ' + output.summary);
        return output;
    }
}
