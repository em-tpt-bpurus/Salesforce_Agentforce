@SuppressWarnings('PMD.CognitiveComplexity')
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

    // ── Shared logic ──────────────────────────────────────────
    private static ApexOutput buildOutput(String namespaceFilter) {
        MetadataEngine.ApexSummary summary = MetadataEngine.getApexClasses(namespaceFilter);

        String standardList = '';
        if (summary.standardClassNames == null || summary.standardClassNames.isEmpty()) {
            standardList = 'None';
        } else {
            for (Integer i = 0; i < summary.standardClassNames.size(); i++) {
                standardList += (i + 1) + '. ' + summary.standardClassNames[i] + '\n';
            }
        }

        String usedList = '';
        if (summary.usedClassNames.isEmpty()) {
            usedList = 'None';
        } else {
            for (Integer i = 0; i < summary.usedClassNames.size(); i++) {
                usedList += (i + 1) + '. ' + summary.usedClassNames[i] + '\n';
            }
        }

        String unusedList = '';
        if (summary.unusedClasses.isEmpty()) {
            unusedList = 'None';
        } else {
            for (Integer i = 0; i < summary.unusedClasses.size(); i++) {
                MetadataEngine.ApexClassInfo info = summary.unusedClasses[i];
                unusedList += (i + 1) + '. ' + info.name +
                              ' | Lines: ' + info.linesOfCode +
                              ' | Last Modified: ' + info.lastModifiedDate + '\n';
            }
        }

        String testList = '';
        if (summary.testClassNames == null || summary.testClassNames.isEmpty()) {
            testList = 'None';
        } else {
            for (Integer i = 0; i < summary.testClassNames.size(); i++) {
                testList += (i + 1) + '. ' + summary.testClassNames[i] + '\n';
            }
        }

        // Namespace-filtered list
        String filteredList = '';
        Integer filteredTotal = summary.filteredTotal != null ? summary.filteredTotal : 0;
        if (summary.filteredClasses == null || summary.filteredClasses.isEmpty()) {
            filteredList = String.isNotBlank(namespaceFilter)
                ? 'No Apex classes found with namespace: ' + namespaceFilter
                : 'None';
        } else {
            for (Integer i = 0; i < summary.filteredClasses.size(); i++) {
                MetadataEngine.ApexClassInfo info = summary.filteredClasses[i];
                filteredList += (i + 1) + '. ' + info.name +
                                (info.linesOfCode != null && info.linesOfCode > 0
                                    ? ' | Lines: ' + info.linesOfCode : '') +
                                (String.isNotBlank(info.lastModifiedDate)
                                    ? ' | Last Modified: ' + info.lastModifiedDate : '') + '\n';
            }
        }

        String nsDisplay = String.isNotBlank(namespaceFilter) ? namespaceFilter : 'None (showing all)';
        Integer stdCount = summary.standardClassNames != null ? summary.standardClassNames.size() : 0;
        Integer tstCount = summary.testClassNames     != null ? summary.testClassNames.size()     : 0;

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
            '--- STANDARD / PACKAGE CLASSES (' + stdCount + ') — Do NOT delete ---\n' + standardList + '\n' +
            '--- CUSTOM USED CLASSES (' + summary.used + ') — Actively in use ---\n' + usedList + '\n' +
            '--- CUSTOM UNUSED CLASSES (' + summary.unused + ') — Safe to delete ---\n' + unusedList + '\n' +
            '--- TEST CLASSES (' + tstCount + ') — Do NOT delete ---\n' + testList +
            (String.isNotBlank(namespaceFilter)
                ? '\n\n--- FILTERED BY NAMESPACE: ' + namespaceFilter + ' (' + filteredTotal + ') ---\n' + filteredList
                : '');

        output.allApexObjects    = summary.filteredClasses;
        output.unusedApexObjects = summary.unusedClasses;
        System.debug('APEX SUMMARY : ' + output.summary);
        return output;
    }
}