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

        @AuraEnabled @InvocableVariable(label='Custom Count' description='Number of custom org profiles')
        public String customCount;

        @AuraEnabled @InvocableVariable(label='Standard Count' description='Number of standard system profiles')
        public String standardCount;

        @AuraEnabled @InvocableVariable(label='Used Profiles' description='Numbered list of Profiles that are assigned to active users')
        public String usedProfiles;

        @AuraEnabled @InvocableVariable(label='Unused Profiles' description='Numbered list of Profiles with zero active user assignments — candidates for cleanup')
        public String unusedProfiles;

        @AuraEnabled @InvocableVariable(label='Custom Profiles' description='Numbered list of custom org profiles')
        public String customProfiles;

        @AuraEnabled @InvocableVariable(label='Standard Profiles' description='Numbered list of standard system profiles')
        public String standardProfiles;

        @AuraEnabled
        public List<MetadataEngine.ProfileInfo> usedProfileObjects;
        @AuraEnabled
        public List<MetadataEngine.ProfileInfo> unusedProfileObjects;
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
    private static String buildUsedProfileList(MetadataEngine.ProfileSummary summary) {
        if (summary.usedProfiles == null || summary.usedProfiles.isEmpty()) {
            return 'None';
        }
        String result = '';
        for (Integer i = 0; i < summary.usedProfiles.size(); i++) {
            MetadataEngine.ProfileInfo info = summary.usedProfiles[i];
            result += (i + 1) + '. ' + info.name +
                        ' | License: ' + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : 'N/A') +
                        ' | Users: ' + info.assignedUserCount + '\n';
        }
        return result;
    }

    private static String buildUnusedProfileList(MetadataEngine.ProfileSummary summary) {
        if (summary.unusedProfiles == null || summary.unusedProfiles.isEmpty()) {
            return 'None';
        }
        String result = '';
        for (Integer i = 0; i < summary.unusedProfiles.size(); i++) {
            MetadataEngine.ProfileInfo info = summary.unusedProfiles[i];
            result += (i + 1) + '. ' + info.name +
                          ' | License: ' + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : 'N/A') +
                          ' | Users: 0\n';
        }
        return result;
    }

    private static String buildProfileList(List<MetadataEngine.ProfileInfo> profiles) {
        if (profiles == null || profiles.isEmpty()) { return 'None'; }
        String result = '';
        for (Integer i = 0; i < profiles.size(); i++) {
            MetadataEngine.ProfileInfo info = profiles[i];
            result += (i + 1) + '. ' + info.name +
                      ' | License: ' + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : 'N/A') +
                      ' | Users: ' + info.assignedUserCount + '\n';
        }
        return result;
    }

    private static ProfileOutput buildOutput() {
        MetadataEngine.ProfileSummary summary = MetadataEngine.getProfiles();

        String usedList      = buildUsedProfileList(summary);
        String unusedList    = buildUnusedProfileList(summary);
        String customList    = buildProfileList(summary.customProfiles);
        String standardList  = buildProfileList(summary.standardProfiles);

        Integer customCnt   = summary.customCount   != null ? summary.customCount   : 0;
        Integer standardCnt = summary.standardCount != null ? summary.standardCount : 0;

        ProfileOutput output    = new ProfileOutput();
        output.totalCount       = String.valueOf(summary.total);
        output.usedCount        = String.valueOf(summary.used);
        output.unusedCount      = String.valueOf(summary.unused);
        output.customCount      = String.valueOf(customCnt);
        output.standardCount    = String.valueOf(standardCnt);
        output.usedProfiles     = usedList;
        output.unusedProfiles   = unusedList;
        output.customProfiles   = customList;
        output.standardProfiles = standardList;
        output.summary =
            'This org has ' + summary.total + ' Profiles in total. ' +
            summary.used + ' are assigned to active users and ' +
            summary.unused + ' are not assigned to any active users.\n' +
            customCnt + ' are custom org profiles and ' + standardCnt + ' are standard system profiles.\n\n' +
            '--- CUSTOM PROFILES (' + customCnt + ') ---\n' + customList + '\n' +
            '--- STANDARD PROFILES (' + standardCnt + ') ---\n' + standardList + '\n' +
            '--- USED PROFILES (' + summary.used + ') — Assigned to active users ---\n' + usedList + '\n' +
            '--- UNUSED PROFILES (' + summary.unused + ') — No active user assignments ---\n' + unusedList;

        output.usedProfileObjects   = summary.usedProfiles;
        output.unusedProfileObjects = summary.unusedProfiles;
        System.debug('PROFILE SUMMARY: ' + output.summary);
        return output;
    }
}