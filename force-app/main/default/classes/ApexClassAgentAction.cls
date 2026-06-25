@SuppressWarnings('PMD.CognitiveComplexity,PMD.NcssMethodCount,PMD.ApexDoc')
public without sharing class ApexClassAgentAction {

    public class ApexRequest {
        @InvocableVariable(label='Input' description='User question about Apex classes')
        public String input;

        @InvocableVariable(label='Namespace Filter' description='Optional namespace to filter Apex classes (e.g. ITSms, FinanceApp). Leave blank for all.')
        public String namespaceFilter;
    }

    public class ApexOutput {
        @AuraEnabled @InvocableVariable(label='Summary' description='Full Apex class summary with all 5 categories')
        public String summary;

        @AuraEnabled @InvocableVariable(label='Total Count' description='Total number of ALL Apex classes in org')
        public String totalCount;

        @AuraEnabled @InvocableVariable(label='Standard Count' description='Number of standard/package Apex classes')
        public String standardCount;

        @AuraEnabled @InvocableVariable(label='Used Count' description='Number of custom used Apex classes')
        public String usedCount;

        @AuraEnabled @InvocableVariable(label='Unused Count' description='Number of custom unused Apex classes')
        public String unusedCount;

        @AuraEnabled @InvocableVariable(label='Test Count' description='Number of test classes')
        public String testCount;

        @AuraEnabled @InvocableVariable(label='Standard Classes' description='Numbered list of all standard/package classes — do not delete')
        public String standardClasses;

        @AuraEnabled @InvocableVariable(label='Used Classes' description='Numbered list of all custom used Apex classes')
        public String usedClasses;

        @AuraEnabled @InvocableVariable(label='Unused Classes' description='Numbered list of all custom unused Apex classes with lines and last modified date')
        public String unusedClasses;

        @AuraEnabled @InvocableVariable(label='Test Classes' description='Numbered list of test classes — do not delete')
        public String testClasses;

        @AuraEnabled @InvocableVariable(label='Filtered Count' description='Number of Apex classes matching the namespace filter')
        public String filteredCount;

        @AuraEnabled @InvocableVariable(label='Namespace Filter Applied' description='The namespace filter that was applied')
        public String namespaceFilterApplied;

        @AuraEnabled @InvocableVariable(label='Filtered Classes' description='Numbered list of Apex classes matching the namespace filter')
        public String filteredClasses;

        @AuraEnabled
        public List<MetadataEngine.ApexClassInfo> allApexObjects;
        @AuraEnabled
        public List<MetadataEngine.ApexClassInfo> unusedApexObjects;
    }


    public class ApexReferencesRequest {
        @InvocableVariable(label='Class Name' description='The Apex class name to look up references for')
        public String className;
    }

    public class ApexReferencesOutput {
        @AuraEnabled @InvocableVariable(label='Report' description='Full formatted reference report')
        public String report;

        @AuraEnabled @InvocableVariable(label='Has References' description='True if the class has any references')
        public Boolean hasReferences;

        @AuraEnabled @InvocableVariable(label='Total Reference Count' description='Total number of references found')
        public Integer totalReferenceCount;

        @AuraEnabled @InvocableVariable(label='Flows' description='Flows that reference this class')
        public String flows;

        @AuraEnabled @InvocableVariable(label='Triggers' description='Triggers that reference this class')
        public String triggers;

        @AuraEnabled @InvocableVariable(label='Test Classes' description='Test classes for this class')
        public String testClasses;

        @AuraEnabled @InvocableVariable(label='Apex Classes' description='Other Apex classes that reference this class')
        public String apexClasses;

        @AuraEnabled @InvocableVariable(label='LWC Components' description='LWC components that reference this class')
        public String lwcComponents;

        @AuraEnabled @InvocableVariable(label='Aura Components' description='Aura components that reference this class')
        public String auraComponents;

        @AuraEnabled @InvocableVariable(label='Agent Actions' description='Generative AI / Agent Actions using this class')
        public String agentActions;

        @AuraEnabled @InvocableVariable(label='Agent Topics' description='Generative AI / Agent Topics using this class')
        public String agentTopics;

        @AuraEnabled @InvocableVariable(label='Other References' description='Any other reference types')
        public String otherReferences;
    }

    @AuraEnabled(cacheable=false)
    public static List<ApexReferencesOutput> getReferences(List<ApexReferencesRequest> requests) {
        String className = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].className : null;
        return new List<ApexReferencesOutput>{ buildReferencesOutput(className) };
    }

    @AuraEnabled(cacheable=false)
    public static ApexReferencesOutput getApexClassReferences(String className) {
        return buildReferencesOutput(className);
    }

    private static ApexReferencesOutput buildReferencesOutput(String className) {
        // Run ALL 16 reference checks so the chatbot sees every blocking reference:
        //   1.  MetadataComponentDependency  — Flows, LWC, Aura, VF, FlexiPages, Triggers...
        //   2.  SymbolTable (Apex-to-Apex)   — classes calling/extending/implementing this class
        //   3.  Live Scheduled Jobs          — CronTrigger + AsyncApexJob (ScheduledApex)
        //   4.  Active Batch/Queueable jobs  — AsyncApexJob (Queued/Processing)
        //   5.  Approval Processes
        //   6.  Assignment Rules
        //   7.  Escalation Rules
        //   8.  Auto-Response Rules
        //   9.  Email Services               — EmailServicesFunction handler
        //  10.  Test Classes + Test Suite Membership
        //  11.  Sharing Rules
        //  12.  Experience Cloud / Sites
        //  13.  Custom Metadata Records
        //  14.  Reports & Dashboards
        //  15.  LWC Static Resource advisory
        //  16.  Permission Sets & Profiles   — SetupEntityAccess
        MetadataEngine.ApexReferenceCheckResult allRefs = MetadataEngine.checkAllApexReferences(className);

        ApexReferencesOutput out = new ApexReferencesOutput();
        out.report              = allRefs.formattedReport;
        out.hasReferences       = allRefs.hasBlockingReferences;
        out.totalReferenceCount = allRefs.referenceCount;

        // Build per-group string fields from the full references list
        Map<String, String> groupMap = new Map<String, String>();
        Integer idx = 1;
        for (MetadataEngine.ReferenceItem item : allRefs.references) {
            String key  = item.groupLabel != null ? item.groupLabel : 'Other';
            String line = idx++ + '. ' + item.name + '\n';
            groupMap.put(key, (groupMap.containsKey(key) ? groupMap.get(key) : '') + line);
        }

        out.flows          = groupMap.get('Flows');
        out.triggers       = groupMap.get('Triggers');
        out.testClasses    = groupMap.get('Test Classes');
        out.apexClasses    = groupMap.get('Apex Classes');
        out.lwcComponents  = groupMap.get('LWC Components');
        out.auraComponents = groupMap.get('Aura Components');
        out.agentActions   = groupMap.get('Agentforce - Agent Actions');
        out.agentTopics    = groupMap.get('Agentforce - Topics');

        // Collect everything else (Permission Sets, Profiles, Email Services, etc.) into otherReferences
        Set<String> knownGroups = new Set<String>{
            'Flows', 'Triggers', 'Test Classes', 'Apex Classes', 'LWC Components',
            'Aura Components', 'Agentforce - Agent Actions', 'Agentforce - Topics'
        };
        String others = '';
        for (String grp : groupMap.keySet()) {
            if (!knownGroups.contains(grp)) {
                others += grp + ':\n' + groupMap.get(grp) + '\n';
            }
        }
        if (String.isNotBlank(others)) {
            out.otherReferences = others;
        }

        return out;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Apex Class Metadata' description='Returns full Apex Class Summary with namespace filtering for Agentforce')
    public static List<ApexOutput> run(List<ApexRequest> requests) {
        String namespaceFilter = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0].namespaceFilter
            : null;
        return new List<ApexOutput>{ buildOutput(namespaceFilter) };
    }

    // ── Called by LWC via @AuraEnabled ────────────────────────
    @AuraEnabled(cacheable=false)
    public static ApexOutput getApexSummary(String namespaceFilter) {
        return buildOutput(namespaceFilter);
    }

    // ── Build individual category lists ───────────────────────
    private static String buildStandardList(MetadataEngine.ApexSummary summary) {
        if (summary.standardClassNames == null || summary.standardClassNames.isEmpty()) {
            return MetadataConstants.NONE;
        }
        String result = '';
        for (Integer i = 0; i < summary.standardClassNames.size(); i++) {
            result += (i + 1) + '. ' + summary.standardClassNames[i] + '\n';
        }
        return result;
    }

    private static String buildUsedList(MetadataEngine.ApexSummary summary) {
        if (summary.usedClassNames == null || summary.usedClassNames.isEmpty()) {
            return MetadataConstants.NONE;
        }
        String result = '';
        for (Integer i = 0; i < summary.usedClassNames.size(); i++) {
            result += (i + 1) + '. ' + summary.usedClassNames[i] + '\n';
        }
        return result;
    }

    private static String buildUnusedList(MetadataEngine.ApexSummary summary) {
        if (summary.unusedClasses == null || summary.unusedClasses.isEmpty()) {
            return MetadataConstants.NONE;
        }
        String result = '';
        for (Integer i = 0; i < summary.unusedClasses.size(); i++) {
            MetadataEngine.ApexClassInfo info = summary.unusedClasses[i];
            // Append [PS] tag if the class is granted in a Permission Set or Profile.
            // This signals the LWC to show a ⚠️ badge — class is UNUSED by code
            // but actively referenced in org security setup; verify before deleting.
            String psTag = (info.hasPermSetAccess == true) ? ' | PS_ACCESS' : '';
            result += (i + 1) + '. ' + info.name +
                      MetadataConstants.COL_LINES + info.linesOfCode +
                      ' | Last Modified: ' + info.lastModifiedDate + psTag + '\n';
        }
        return result;
    }

    private static String buildTestList(MetadataEngine.ApexSummary summary) {
        if (summary.testClassNames == null || summary.testClassNames.isEmpty()) {
            return MetadataConstants.NONE;
        }
        String result = '';
        for (Integer i = 0; i < summary.testClassNames.size(); i++) {
            result += (i + 1) + '. ' + summary.testClassNames[i] + '\n';
        }
        return result;
    }

    private static String buildFilteredList(MetadataEngine.ApexSummary summary, String namespaceFilter) {
        if (summary.filteredClasses == null || summary.filteredClasses.isEmpty()) {
            return String.isNotBlank(namespaceFilter)
                ? 'No Apex classes found with namespace: ' + namespaceFilter
                : MetadataConstants.NONE;
        }
        String result = '';
        for (Integer i = 0; i < summary.filteredClasses.size(); i++) {
            MetadataEngine.ApexClassInfo info = summary.filteredClasses[i];
            result += (i + 1) + '. ' + info.name +
                      (info.linesOfCode != null && info.linesOfCode > 0
                          ? MetadataConstants.COL_LINES + info.linesOfCode : '') +
                      (String.isNotBlank(info.lastModifiedDate)
                          ? ' | Last Modified: ' + info.lastModifiedDate : '') + '\n';
        }
        return result;
    }

    private static String buildAllApexList(MetadataEngine.ApexSummary summary) {
        String result = '';
        Integer idx = 1;
        if (summary.usedClassNames != null) {
            for (String n : summary.usedClassNames) {
                result += idx++ + '. ' + n + ' [USED]\n';
            }
        }
        if (summary.unusedClasses != null) {
            for (MetadataEngine.ApexClassInfo info : summary.unusedClasses) {
                result += idx++ + '. ' + info.name +
                    MetadataConstants.COL_LINES + info.linesOfCode +
                    ' | Last Modified: ' + info.lastModifiedDate + ' [UNUSED]\n';
            }
        }
        if (summary.testClassNames != null) {
            for (String n : summary.testClassNames) {
                result += idx++ + '. ' + n + ' [TEST]\n';
            }
        }
        if (summary.standardClassNames != null) {
            for (String n : summary.standardClassNames) {
                result += idx++ + '. ' + n + ' [STANDARD/PACKAGE]\n';
            }
        }
        return String.isBlank(result) ? MetadataConstants.NONE : result;
    }

    // ── Shared logic ──────────────────────────────────────────
    private static ApexOutput buildOutput(String namespaceFilter) {
        MetadataEngine.ApexSummary summary = MetadataEngine.getApexClasses(namespaceFilter);

        String  standardList  = buildStandardList(summary);
        String  usedList      = buildUsedList(summary);
        String  unusedList    = buildUnusedList(summary);
        String  testList      = buildTestList(summary);
        String  filteredList  = buildFilteredList(summary, namespaceFilter);
        String  allApexList   = buildAllApexList(summary);
        String  nsDisplay     = String.isNotBlank(namespaceFilter) ? namespaceFilter : MetadataConstants.NS_ALL;
        Integer stdCount      = summary.standardClassNames != null ? summary.standardClassNames.size() : 0;
        Integer tstCount      = summary.testClassNames     != null ? summary.testClassNames.size()     : 0;
        Integer filteredTotal = summary.filteredTotal      != null ? summary.filteredTotal              : 0;

        ApexOutput output             = new ApexOutput();
        output.totalCount             = String.valueOf(summary.total);
        output.standardCount          = String.valueOf(stdCount);
        output.usedCount              = String.valueOf(summary.used);
        output.unusedCount            = String.valueOf(summary.unused);
        output.testCount              = String.valueOf(tstCount);
        output.standardClasses        = standardList;
        output.usedClasses            = usedList;
        output.unusedClasses          = unusedList;
        output.testClasses            = testList;
        output.filteredCount          = String.valueOf(filteredTotal);
        output.namespaceFilterApplied = nsDisplay;
        output.filteredClasses        = filteredList;
        output.summary =
            'This org has ' + summary.total + ' Apex classes in total.\n\n' +
            'Namespace Filter: ' + nsDisplay + '\n\n' +
            '--- ALL APEX CLASSES (' + summary.total + ') ---\n' + allApexList + '\n' +
            MetadataConstants.SEC_USED_CLASSES + ' (' + summary.used + MetadataConstants.SEC_HINT_IN_USE + usedList + '\n' +
            MetadataConstants.SEC_UNUSED_CLASSES + ' (' + summary.unused + MetadataConstants.SEC_HINT_SAFE_DELETE + unusedList + '\n' +
            MetadataConstants.SEC_TEST_CLASSES + ' (' + tstCount + MetadataConstants.SEC_HINT_NO_DELETE + testList + '\n' +
            MetadataConstants.SEC_STANDARD_CLASSES + ' (' + stdCount + MetadataConstants.SEC_HINT_NO_DELETE + standardList +
            (String.isNotBlank(namespaceFilter)
                ? '\n\n--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + filteredTotal + ') ---\n' + filteredList
                : '');

        output.allApexObjects = new List<MetadataEngine.ApexClassInfo>();
        if (summary.unusedClasses != null) {
            output.allApexObjects.addAll(summary.unusedClasses);
        }
        output.unusedApexObjects = summary.unusedClasses;
        System.debug('APEX SUMMARY : ' + output.summary);
        return output;
    }
}