@SuppressWarnings('PMD.CognitiveComplexity')
public without sharing class ProfileAgentAction {

    public class ProfileRequest {
        @InvocableVariable(label='Input' description='User question about Profiles')
        public String input;

        @InvocableVariable(label='Namespace Filter' description='Optional prefix to filter Profiles by name (e.g. EM, HR, ITSms). Leave blank for all.')
        public String namespaceFilter;
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

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of Profiles matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='Filtered Profiles' description='Numbered list of Profiles matching the namespace filter')
        public String filteredProfiles;

        @AuraEnabled
        public List<MetadataEngine.ProfileInfo> usedProfileObjects;
        @AuraEnabled
        public List<MetadataEngine.ProfileInfo> unusedProfileObjects;
        @AuraEnabled
        public List<MetadataEngine.ProfileInfo> allProfileObjects;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Profile Metadata' description='Returns Profile Summary with unused profile detection for Agentforce')
    public static List<ProfileOutput> run(List<ProfileRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<ProfileOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static ProfileOutput getProfileSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Shared logic ──────────────────────────────────────────
    private static String buildFilteredProfileList(List<MetadataEngine.ProfileInfo> profiles, String namespaceFilter) {
        if (profiles == null || profiles.isEmpty()) {
            return String.isNotBlank(namespaceFilter)
                ? 'No Profiles found with namespace: ' + namespaceFilter
                : MetadataConstants.NONE;
        }
        String result = '';
        for (Integer i = 0; i < profiles.size(); i++) {
            MetadataEngine.ProfileInfo info = profiles[i];
            result += (i + 1) + '. ' + info.name +
                      MetadataConstants.COL_LICENSE + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : MetadataConstants.NA) +
                      MetadataConstants.COL_USERS + info.assignedUserCount + '\n';
        }
        return result;
    }
    private static String buildUsedProfileList(MetadataEngine.ProfileSummary summary) {
        if (summary.usedProfiles == null || summary.usedProfiles.isEmpty()) {
            return MetadataConstants.NONE;
        }
        String result = '';
        for (Integer i = 0; i < summary.usedProfiles.size(); i++) {
            MetadataEngine.ProfileInfo info = summary.usedProfiles[i];
            result += (i + 1) + '. ' + info.name +
                        MetadataConstants.COL_LICENSE + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : MetadataConstants.NA) +
                        MetadataConstants.COL_USERS + info.assignedUserCount + '\n';
        }
        return result;
    }

    private static String buildUnusedProfileList(MetadataEngine.ProfileSummary summary) {
        if (summary.unusedProfiles == null || summary.unusedProfiles.isEmpty()) {
            return MetadataConstants.NONE;
        }
        String result = '';
        for (Integer i = 0; i < summary.unusedProfiles.size(); i++) {
            MetadataEngine.ProfileInfo info = summary.unusedProfiles[i];
            result += (i + 1) + '. ' + info.name +
                          MetadataConstants.COL_LICENSE + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : MetadataConstants.NA) +
                          ' | Users: 0\n';
        }
        return result;
    }

    private static String buildProfileList(List<MetadataEngine.ProfileInfo> profiles) {
        if (profiles == null || profiles.isEmpty()) { return MetadataConstants.NONE; }
        String result = '';
        for (Integer i = 0; i < profiles.size(); i++) {
            MetadataEngine.ProfileInfo info = profiles[i];
            result += (i + 1) + '. ' + info.name +
                      MetadataConstants.COL_LICENSE + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : MetadataConstants.NA) +
                      MetadataConstants.COL_USERS + info.assignedUserCount + '\n';
        }
        return result;
    }

    private static ProfileOutput buildOutput(String namespaceFilter) {
        MetadataEngine.ProfileSummary summary = MetadataEngine.getProfiles(namespaceFilter);

        String usedList      = buildUsedProfileList(summary);
        String unusedList    = buildUnusedProfileList(summary);
        String customList    = buildProfileList(summary.customProfiles);
        String standardList  = buildProfileList(summary.standardProfiles);
        String filteredList  = buildFilteredProfileList(summary.filteredProfiles, namespaceFilter);

        Integer customCnt    = summary.customCount   != null ? summary.customCount   : 0;
        Integer standardCnt  = summary.standardCount != null ? summary.standardCount : 0;
        Integer filteredCnt  = summary.filteredTotal != null ? summary.filteredTotal  : 0;
        String  nsDisplay    = String.isNotBlank(namespaceFilter) ? namespaceFilter : MetadataConstants.NS_ALL;

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
        output.filteredCount    = String.valueOf(filteredCnt);
        output.namespaceFilterApplied = nsDisplay;
        output.filteredProfiles = filteredList;
        // Build combined ALL profiles list (assigned first, then unassigned)
        String allProfilesList = '';
        Integer allPIdx = 1;
        if (summary.usedProfiles != null) {
            for (MetadataEngine.ProfileInfo info : summary.usedProfiles) {
                allProfilesList += allPIdx++ + '. ' + info.name +
                    MetadataConstants.COL_LICENSE + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : MetadataConstants.NA) +
                    MetadataConstants.COL_USERS + info.assignedUserCount + ' [ASSIGNED]\n';
            }
        }
        if (summary.unusedProfiles != null) {
            for (MetadataEngine.ProfileInfo info : summary.unusedProfiles) {
                allProfilesList += allPIdx++ + '. ' + info.name +
                    MetadataConstants.COL_LICENSE + (String.isNotBlank(info.userLicenseName) ? info.userLicenseName : MetadataConstants.NA) +
                    ' | Users: 0 [UNASSIGNED]\n';
            }
        }
        if (String.isBlank(allProfilesList)) {
            allProfilesList = MetadataConstants.NONE;
        }

        output.summary =
            'This org has ' + summary.total + ' Profiles in total. ' +
            summary.used + ' are assigned to active users and ' +
            summary.unused + ' are not assigned to any active users.\n' +
            customCnt + ' are custom org profiles and ' + standardCnt + ' are standard system profiles.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n\n' +
            '--- ALL PROFILES (' + summary.total + ') ---\n' + allProfilesList + '\n' +
            MetadataConstants.SEC_USED_PROFILES + ' (' + summary.used + MetadataConstants.SEC_HINT_ACTIVE_USERS + usedList + '\n' +
            MetadataConstants.SEC_UNUSED_PROFILES + ' (' + summary.unused + MetadataConstants.SEC_HINT_NO_USERS + unusedList + '\n' +
            MetadataConstants.SEC_CUSTOM_PROFILES + ' (' + customCnt + ') ---\n' + customList + '\n' +
            MetadataConstants.SEC_STANDARD_PROFILES + ' (' + standardCnt + ') ---\n' + standardList +
            (String.isNotBlank(namespaceFilter)
                ? '\n\n--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + filteredCnt + ') ---\n' + filteredList
                : '');

        output.usedProfileObjects   = summary.usedProfiles;
        output.unusedProfileObjects = summary.unusedProfiles;
        output.allProfileObjects    = new List<MetadataEngine.ProfileInfo>();
        if (summary.usedProfiles != null) {
            output.allProfileObjects.addAll(summary.usedProfiles);
        }
        if (summary.unusedProfiles != null) {
            output.allProfileObjects.addAll(summary.unusedProfiles);
        }
        System.debug('PROFILE SUMMARY: ' + output.summary);
        return output;
    }
}