/**
 * OrgCleanupAgentAction — v2
 *
 * Full natural-language agent for the LWC Org Cleanup dashboard.
 *
 * What's new vs v1:
 *  - detectTypes() returns ALL matched types (List<String>) — no more first-match-wins
 *  - Every type gets its own response section — combined into one clean reply
 *  - Smart intent keywords: unused/can be deleted/no references/safe to remove →
 *    shows the cleanup-relevant section for each type
 *  - Namespace detection: managed packages / not from packages / belonging to X
 *  - Delete from chat: "delete flow MyFlow" / "delete apex class MyClass" etc.
 *  - Works with Agentforce AND LWC equally
 */
@SuppressWarnings('PMD.NcssMethodCount,PMD.ExcessiveClassLength,PMD.CognitiveComplexity,PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces,PMD.ApexCRUDViolation,PMD.ForLoopsMustUseBraces,PMD.ExcessiveParameterList,PMD.NcssTypeCount,PMD.EmptyStatementBlock,PMD.AvoidDeeplyNestedIfStmts')
public without sharing class OrgCleanupAgentAction {

    // ── Type constants ────────────────────────────────────────
    private static final String TYPE_FLOW    = 'flow';
    private static final String TYPE_APEX    = 'apex';
    private static final String TYPE_TRIGGER = 'trigger';
    private static final String TYPE_LWC     = 'lwc';
    private static final String TYPE_AURA    = 'aura';
    private static final String TYPE_PROFILE = 'profile';
    private static final String TYPE_PERMSET = 'permset';
    private static final String TYPE_FIELD   = 'field';
    private static final String TYPE_OBJECT  = 'object';
    private static final String TYPE_VR      = 'vr';

    // ── Intent constants ──────────────────────────────────────
    private static final String INTENT_UNUSED    = 'unused';    // unused/inactive/can be deleted/no references/safe to remove/cleanup
    private static final String INTENT_USED      = 'used';      // used/active/assigned/referenced
    private static final String INTENT_MANAGED   = 'managed';   // managed packages/from packages/with namespace
    private static final String INTENT_UNMANAGED = 'unmanaged'; // not from packages/no namespace/custom only
    private static final String INTENT_ALL       = 'all';       // show all / list all / default

    // ── Delete action constants ───────────────────────────────
    private static final String ACTION_DELETE = 'delete';
    private static final String ACTION_QUERY  = 'query';

    // ── Query context wrapper — avoids long parameter lists ─
    @TestVisible
    private class QueryContext {
        String intent;
        String ns;
        String lower;
        QueryContext(String intent, String ns, String lower) {
            this.intent = intent;
            this.ns     = ns;
            this.lower  = lower;
        }
    }

    // =========================================================
    // LWC ENTRY POINT
    // =========================================================
    @AuraEnabled(cacheable=false)
    public static String handleAgentQuery(String userQuery) {
        if (String.isBlank(userQuery)) {
            return helpMessage();
        }
        try {
            String lower = userQuery.toLowerCase().trim();

            // ── Delete intent ──────────────────────────────────
            if (isDeleteIntent(lower)) {
                return handleDelete(lower, userQuery);
            }

            // ── Query intent ───────────────────────────────────
            List<String>  types  = detectTypes(lower);
            String        intent = detectIntent(lower);
            String        ns     = extractNamespace(userQuery, lower);
            QueryContext  ctx    = new QueryContext(intent, ns, lower);

            if (types.isEmpty()) {
                return helpMessage();
            }

            // Build response for each matched type and combine
            List<String> sections = new List<String>();
            for (String t : types) {
                sections.add(buildSection(t, ctx));
            }

            String combined = String.join(sections, '\n' + repeat('─', 50) + '\n\n');

            // Add header if multiple types were matched
            if (types.size() > 1) {
                combined = '📋 Showing results for: ' + String.join(types, ' + ').toUpperCase() + '\n\n' + combined;
            }

            return combined;

        } catch (Exception ex) {
            System.debug('OrgCleanupAgentAction error: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            return 'Sorry, I encountered an error: ' + ex.getMessage();
        }
    }

    // =========================================================
    // DELETE HANDLER
    // =========================================================
    private static Boolean isDeleteIntent(String lower) {
        return lower.startsWith('delete ') || lower.startsWith('remove ') ||
               lower.contains('delete the ') || lower.contains('remove the ');
    }

    private static String handleDelete(String lower, String originalQuery) {
        // ── Detect type — most specific first to avoid wrong matches ──
        String type = null;
        if      (lower.contains('validation rule') || lower.contains('val rule'))  type = TYPE_VR;
        else if (lower.contains('custom field')    || lower.contains('field'))     type = TYPE_FIELD;
        else if (lower.contains('custom object')   || lower.contains('object'))    type = TYPE_OBJECT;
        else if (lower.contains('permission sets') || lower.contains('permission set') || lower.contains('perm sets') || lower.contains('perm set') || lower.contains('permsets') || lower.contains('permset'))   type = TYPE_PERMSET;
        else if (lower.contains('apex class')      || lower.contains('apex'))      type = TYPE_APEX;
        else if (lower.contains('flow'))                                            type = TYPE_FLOW;
        else if (lower.contains('trigger'))                                         type = TYPE_TRIGGER;
        else if (lower.contains('lwc') || lower.contains('lightning web'))         type = TYPE_LWC;
        else if (lower.contains('aura'))                                            type = TYPE_AURA;
        else if (lower.contains('profile'))                                         type = TYPE_PROFILE;

        if (type == null) {
            return buildDeleteHelp();
        }

        // ── Profile: needs fallback profile ───────────────────
        if (type == TYPE_PROFILE) {
            return handleProfileDelete(originalQuery, lower);
        }

        // ── Field: needs ObjectName.FieldName format ──────────
        if (type == TYPE_FIELD) {
            return handleFieldDelete(originalQuery, lower);
        }

        // ── VR: needs ObjectName.RuleName format ──────────────
        if (type == TYPE_VR) {
            return handleVrDelete(originalQuery, lower);
        }

        // ── All other types: single name ──────────────────────
        String name = extractDeleteName(originalQuery, type);
        if (String.isBlank(name)) {
            return '⚠️ Please provide the API name to delete.\nExample: "delete ' + type + ' YourComponentName"';
        }
        return executeDelete(type, name);
    }

    private static String handleProfileDelete(String originalQuery, String lower) {
        // Parse: "deactivate profile ProfileName fallback FallbackProfile"
        // Split by spaces and find 'profile', 'fallback' keywords
        List<String> words = lower.split('\\s+');
        String profileName  = null;
        String fallbackName = null;

        for (Integer i = 0; i < words.size(); i++) {
            if (words[i] == 'profile' && i + 1 < words.size()) {
                profileName = originalQuery.split('(?i)\\s+')[i + 1];
            }
            if ((words[i] == 'fallback' || words[i] == 'to' || words[i] == 'use') && i + 1 < words.size()) {
                fallbackName = originalQuery.split('(?i)\\s+')[i + 1];
            }
        }

        if (String.isBlank(profileName)) {
            return '⚠️ Profile delete format:\n' +
                   'deactivate profile <ProfileName> fallback <FallbackProfile>\n' +
                   'Example: deactivate profile ReadOnly fallback StandardUser';
        }
        if (String.isBlank(fallbackName)) {
            return '⚠️ A fallback profile is required to reassign users.\n' +
                   'Example: deactivate profile ReadOnly fallback StandardUser';
        }
        try {
            MetadataEngine.DeleteResult result = MetadataEngine.deactivateProfileByName(profileName.trim(), fallbackName.trim());
            return result.success ? '✅ ' + result.message : '❌ ' + result.message;
        } catch (Exception ex) {
            return '❌ Error: ' + ex.getMessage();
        }
    }

    private static String handleFieldDelete(String originalQuery, String lower) {
        // Parse: "delete field Account.EM_Usha" or "delete field EM_Usha on Account"
        // Find the token after 'field' keyword
        List<String> words = originalQuery.trim().split('\\s+');
        String fieldToken  = null;
        String objectName  = null;
        String fieldName   = null;

        for (Integer i = 0; i < words.size(); i++) {
            if (words[i].toLowerCase() == 'field' && i + 1 < words.size()) {
                fieldToken = words[i + 1];
            }
            if (words[i].toLowerCase() == 'on' && i + 1 < words.size()) {
                objectName = words[i + 1];
            }
        }

        if (String.isNotBlank(fieldToken)) {
            if (fieldToken.contains('.')) {
                // dot notation: Account.EM_Usha
                List<String> parts = fieldToken.split('\\.');
                if (parts.size() == 2) {
                    objectName = parts[0].trim();
                    fieldName  = parts[1].trim().replace('__c', '').replace('__C', '');
                }
            } else if (String.isNotBlank(objectName)) {
                // "on" notation: EM_Usha on Account
                fieldName = fieldToken.trim().replace('__c', '').replace('__C', '');
            }
        }

        if (String.isBlank(objectName) || String.isBlank(fieldName)) {
            return '⚠️ To delete a custom field use one of these formats:\n' +
                   '  • delete field Account.EM_Usha\n' +
                   '  • delete field EM_Usha on Account';
        }

        try {
            MetadataEngine.DeleteResult result = MetadataEngine.deleteCustomFieldByName(objectName, fieldName);
            return result.success ? '✅ ' + result.message : '❌ ' + result.message;
        } catch (Exception ex) {
            return '❌ Error deleting field: ' + ex.getMessage();
        }
    }

    private static String handleVrDelete(String originalQuery, String lower) {
        // Parse: "delete validation rule Account.MyRule" or "delete validation rule MyRule on Account"
        // Find the token after 'rule' keyword
        List<String> words = originalQuery.trim().split('\\s+');
        String ruleToken  = null;
        String objectName = null;
        String ruleName   = null;

        for (Integer i = 0; i < words.size(); i++) {
            if (words[i].toLowerCase() == 'rule' && i + 1 < words.size()) {
                ruleToken = words[i + 1];
            }
            if (words[i].toLowerCase() == 'on' && i + 1 < words.size()) {
                objectName = words[i + 1];
            }
        }

        if (String.isNotBlank(ruleToken)) {
            if (ruleToken.contains('.')) {
                List<String> parts = ruleToken.split('\\.');
                if (parts.size() == 2) {
                    objectName = parts[0].trim();
                    ruleName   = parts[1].trim();
                }
            } else if (String.isNotBlank(objectName)) {
                ruleName = ruleToken.trim();
            }
        }

        if (String.isBlank(objectName) || String.isBlank(ruleName)) {
            return '⚠️ To delete a validation rule use one of these formats:\n' +
                   '  • delete validation rule Account.MyRule\n' +
                   '  • delete validation rule MyRule on Account';
        }

        try {
            MetadataEngine.DeleteResult result = MetadataEngine.deleteValidationRuleByName(objectName, ruleName);
            return result.success ? '✅ ' + result.message : '❌ ' + result.message;
        } catch (Exception ex) {
            return '❌ Error deleting validation rule: ' + ex.getMessage();
        }
    }

    private static String buildDeleteHelp() {
        return 'What would you like to delete? Here are the supported formats:\n\n' +
               '  • delete apex class MyClass\n' +
               '  • delete flow My_Flow_API_Name\n' +
               '  • delete trigger AccountTrigger\n' +
               '  • delete lwc myComponent\n' +
               '  • delete aura MyComponent\n' +
               '  • delete field Account.EM_Usha\n' +
               '  • delete field EM_Usha on Account\n' +
               '  • delete validation rule Account.MyRule\n' +
               '  • delete permission set MyPermSet\n' +
               '  • delete custom object MyObject\n' +
               '  • deactivate profile ReadOnly fallback "Standard User"';
    }

    private static String extractDeleteName(String query, String type) {
        // Patterns: "delete flow My_Flow", "delete apex class MyClass", "delete trigger AccountTrigger"
        String lower = query.toLowerCase();
        String stripped = query;

        // Remove leading verb
        stripped = stripped.replaceFirst('(?i)^(delete|remove)\\s+', '');

        // Remove type keywords
        stripped = stripped.replaceFirst('(?i)^(apex\\s+class|apex|flow|trigger|lwc|lightning\\s+web\\s+component|aura|validation\\s+rule|val\\s+rule|permission\\s+sets|permission\\s+set|perm\\s+sets|perm\\s+set|permsets|permset|custom\\s+field|field|custom\\s+object|object|profile|the)\\s+', '');

        String candidate = stripped.trim();

        // Must look like an API name (letters, numbers, underscores)
        if (candidate.length() > 0 && Pattern.matches('[A-Za-z][A-Za-z0-9_]*', candidate.split('\\s+')[0])) {
            return candidate.split('\\s+')[0];
        }
        return null;
    }

    private static String executeDelete(String type, String name) {
        MetadataEngine.DeleteResult result;
        try {
            if      (type == TYPE_APEX)    { result = MetadataEngine.deleteApexClassByName(name); }
            else if (type == TYPE_FLOW)    { result = MetadataEngine.deleteFlowByApiName(name); }
            else if (type == TYPE_TRIGGER) { result = MetadataEngine.deleteTriggerByName(name); }
            else if (type == TYPE_LWC)     { result = MetadataEngine.deleteLwcByName(name); }
            else if (type == TYPE_AURA)    { result = MetadataEngine.deleteAuraByName(name); }
            else if (type == TYPE_PERMSET) { result = MetadataEngine.deletePermissionSetByName(name); }
            else if (type == TYPE_OBJECT)  { result = MetadataEngine.deleteCustomObjectByName(name); }
            else {
                return '⚠️ Delete is not supported for ' + type + ' from the chat.';
            }
        } catch (Exception ex) {
            return '❌ Error during delete: ' + ex.getMessage();
        }
        if (result == null) {
            return '❌ Delete returned no result for: ' + name;
        }
        return result.success ? '✅ ' + result.message : '❌ ' + result.message;
    }

    // =========================================================
    // TYPE DETECTION — returns ALL matched types
    // =========================================================
    @TestVisible
    private static List<String> detectTypes(String lower) {
        List<String> types = new List<String>();

        if (lower.contains('flow'))                                                              types.add(TYPE_FLOW);
        if (lower.contains('apex') || lower.contains('apex class') || lower.contains('class'))  types.add(TYPE_APEX);
        if (lower.contains('trigger'))                                                           types.add(TYPE_TRIGGER);
        if (lower.contains('lwc') || lower.contains('lightning web') ||
            lower.contains('lightning component'))                                               types.add(TYPE_LWC);
        if (lower.contains('aura'))                                                              types.add(TYPE_AURA);
        if (lower.contains('profile'))                                                           types.add(TYPE_PROFILE);
        if (lower.contains('permission set') || lower.contains('perm set') ||
            lower.contains('permset') || lower.contains('permission'))                           types.add(TYPE_PERMSET);
        // check VR before field/object so 'rules' doesn't fall to wrong type
        if (lower.contains('validation') || lower.contains('val rule') ||
            lower.contains('validation rule'))                                                   types.add(TYPE_VR);
        if (lower.contains('field') && !lower.contains('validation'))                           types.add(TYPE_FIELD);
        if (lower.contains('object') || lower.contains('sobject') ||
            lower.contains('custom object'))                                                     types.add(TYPE_OBJECT);

        return types;
    }

    // =========================================================
    // INTENT DETECTION — what the user wants to see
    // =========================================================
    @TestVisible
    private static String detectIntent(String lower) {
        // Unused / cleanup / can be deleted / no references
        if (lower.contains('unused')         || lower.contains('inactive')        ||
            lower.contains('can be deleted') || lower.contains('safe to delete')  ||
            lower.contains('safe to remove') || lower.contains('no reference')    ||
            lower.contains('not referenced') || lower.contains('not used')        ||
            lower.contains('never used')     || lower.contains('cleanup')         ||
            lower.contains('clean up')       || lower.contains('which')           && lower.contains('delet') ||
            lower.contains('unassigned')     || lower.contains('no assignment')) {
            return INTENT_UNUSED;
        }

        // Used / active / assigned
        if (lower.contains('used')     || lower.contains('active')    ||
            lower.contains('assigned') || lower.contains('referenced') ||
            lower.contains('in use')) {
            return INTENT_USED;
        }

        // Managed packages / with namespace
        if (lower.contains('managed package') || lower.contains('from package') ||
            lower.contains('installed')        || lower.contains('with namespace') ||
            lower.contains('package')) {
            return INTENT_MANAGED;
        }

        // Not from packages / custom only / no namespace
        if (lower.contains('not from package') || lower.contains('no namespace') ||
            lower.contains('without namespace') || lower.contains('custom only')  ||
            lower.contains('unmanaged')) {
            return INTENT_UNMANAGED;
        }

        // Default — show all
        return INTENT_ALL;
    }

    // =========================================================
    // NAMESPACE EXTRACTOR
    // =========================================================
    private static String extractNamespace(String query, String lower) {
        // "not from packages" / "no namespace" → return special marker
        if (lower.contains('not from package') || lower.contains('no namespace') ||
            lower.contains('without namespace') || lower.contains('unmanaged')) {
            return null; // handled by INTENT_UNMANAGED
        }

        Set<String> stopWords = new Set<String>{
            'the','all','show','list','get','find','unused','inactive','active',
            'my','our','this','that','class','apex','flow','trigger','lwc','aura',
            'rules','rule','fields','field','objects','object','profiles','profile',
            'permission','sets','set','modified','last','days','old','recent',
            'managed','package','packages','installed','from','not','without','with',
            'namespace','custom','only','unmanaged','can','be','deleted','safe',
            'remove','which','never','used','assigned','referenced','in','use'
        };

        // Pattern 1: "from namespace X" / "in namespace X" / "belonging to X"
        // Parse namespace from "in X namespace" / "for X namespace" / "from X" / "X namespace"
        List<String> qWords = query.trim().split('\\s+');
        Set<String> triggerWords = new Set<String>{'in','for','from','namespace','belonging'};
        for (Integer i = 0; i < qWords.size(); i++) {
            String w = qWords[i].toLowerCase();
            if (triggerWords.contains(w) && i + 1 < qWords.size()) {
                String candidate = qWords[i + 1].replaceAll('[^A-Za-z0-9_]', '');
                if (!stopWords.contains(candidate.toLowerCase()) && candidate.length() > 1) {
                    return candidate;
                }
            }
            if ((w == 'namespace' || w == 'app' || w == 'application') && i > 0) {
                String candidate = qWords[i - 1].replaceAll('[^A-Za-z0-9_]', '');
                if (!stopWords.contains(candidate.toLowerCase()) && candidate.length() > 1) {
                    return candidate;
                }
            }
        }

        return null;
    }

    // =========================================================
    // SECTION BUILDER — routes each type to its response builder
    // =========================================================
    private static String buildSection(String type, QueryContext ctx) {
        if      (type == TYPE_FLOW)    { return buildFlowResponse(MetadataEngine.getFlows(ctx.ns), ctx); }
        else if (type == TYPE_APEX)    { return buildApexResponse(MetadataEngine.getApexClasses(ctx.ns), ctx); }
        else if (type == TYPE_TRIGGER) { return buildTriggerResponse(MetadataEngine.getTriggers(ctx.ns), ctx); }
        else if (type == TYPE_LWC)     { return buildLwcResponse(MetadataEngine.getLwcComponents(ctx.ns), ctx); }
        else if (type == TYPE_AURA)    { return buildAuraResponse(MetadataEngine.getAuraComponents(ctx.ns), ctx); }
        else if (type == TYPE_PROFILE) { return buildProfileResponse(MetadataEngine.getProfiles(), ctx); }
        else if (type == TYPE_PERMSET) { return buildPermSetResponse(MetadataEngine.getPermissionSets(), ctx); }
        else if (type == TYPE_FIELD)   { return buildFieldResponse(MetadataEngine.getCustomFields(ctx.ns), ctx); }
        else if (type == TYPE_OBJECT)  { return buildObjectResponse(MetadataEngine.getCustomObjects(ctx.ns), ctx); }
        else if (type == TYPE_VR)      { return buildVrResponse(MetadataEngine.getValidationRules(ctx.ns), ctx); }
        return '';
    }

    // =========================================================
    // RESPONSE BUILDERS
    // =========================================================

    // ── FLOWS ─────────────────────────────────────────────────
    private static String buildFlowResponse(MetadataEngine.FlowSummary s, QueryContext ctx) {
        String resp = '🔀 FLOWS\n'
                    + 'Total: ' + s.total + '  |  Active: ' + s.active + '  |  Inactive: ' + s.inactive + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + s.filteredTotal + ' matching)\n';
            resp += listItems(s.filteredActiveFlows,   '✅ Active',   '  * ');
            resp += listItems(s.filteredInactiveFlows, '⬜ Inactive', '  - ');
            if (s.filteredTotal == 0) resp += '  No flows found for namespace "' + ctx.ns + '".\n';
            return resp;
        }

        if (ctx.intent == INTENT_UNUSED) {
            resp += '🗑️ Inactive flows — safe to review/delete (' + s.inactive + '):\n\n';
            if (s.inactiveFlows != null && !s.inactiveFlows.isEmpty()) {
                Integer i = 1;
                for (String f : s.inactiveFlows) {
                    resp += formatItem(i++, f, f, 'Flow (Inactive)');
                }
            } else {
                resp += 'None found — all flows are active! ✅\n';
            }
            resp += '\nTo delete: type "delete flow <ApiName>"';
            return resp;
        }

        if (ctx.intent == INTENT_USED) {
            resp += '✅ Active flows (' + s.active + '):\n\n';
            if (s.activeFlows != null) {
                Integer i = 1;
                for (String f : s.activeFlows) {
                    if (i > 30) { resp += '  ... and ' + (s.active - 30) + ' more.\n'; break; }
                    resp += formatItem(i++, f, f, 'Flow (Active)');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_MANAGED) {
            List<String> managed = new List<String>();
            if (s.activeFlows != null)   { for (String f : s.activeFlows)   { if (f.contains('[ns:')) managed.add(f); } }
            if (s.inactiveFlows != null) { for (String f : s.inactiveFlows) { if (f.contains('[ns:')) managed.add(f); } }
            resp += '📦 Flows from managed packages (' + managed.size() + '):\n\n';
            Integer i = 1;
            for (String f : managed) { resp += formatItem(i++, f, f, 'Flow'); }
            if (managed.isEmpty()) resp += 'No managed package flows found.\n';
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            List<String> unmanaged = new List<String>();
            if (s.activeFlows != null)   { for (String f : s.activeFlows)   { if (!f.contains('[ns:')) unmanaged.add(f); } }
            if (s.inactiveFlows != null) { for (String f : s.inactiveFlows) { if (!f.contains('[ns:')) unmanaged.add(f); } }
            resp += '🔧 Custom flows (no namespace) (' + unmanaged.size() + '):\n\n';
            Integer i = 1;
            for (String f : unmanaged) { resp += formatItem(i++, f, f, 'Flow'); }
            if (unmanaged.isEmpty()) resp += 'None found.\n';
            return resp;
        }

        // Default — show all
        if (s.activeFlows != null && !s.activeFlows.isEmpty()) {
            resp += '--- ✅ ACTIVE (' + s.active + ') ---\n\n';
            Integer i = 1;
            for (String f : s.activeFlows) {
                if (i > 20) { resp += '  ... and ' + (s.active - 20) + ' more.\n'; break; }
                resp += formatItem(i++, f, f, 'Flow (Active)');
            }
            resp += '\n';
        }
        if (s.inactiveFlows != null && !s.inactiveFlows.isEmpty()) {
            resp += '--- ⬜ INACTIVE (' + s.inactive + ') ---\n\n';
            Integer i = 1;
            for (String f : s.inactiveFlows) { resp += formatItem(i++, f, f, 'Flow (Inactive)'); }
        }
        return resp;
    }

    // ── APEX CLASSES ──────────────────────────────────────────
    private static String buildApexResponse(MetadataEngine.ApexSummary s, QueryContext ctx) {
        String resp = '⚡ APEX CLASSES\n'
                    + 'Total: ' + s.total + '  |  Used: ' + s.used + '  |  Unused: ' + s.unused
                    + '  |  Test: ' + s.testCount + '  |  Standard/Package: ' + s.standard + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + s.filteredTotal + ' matching)\n';
            if (s.filteredClasses != null && !s.filteredClasses.isEmpty()) {
                for (MetadataEngine.ApexClassInfo c : s.filteredClasses) {
                    resp += '  * ' + c.name + (c.linesOfCode > 0 ? ' (' + c.linesOfCode + ' lines)' : '') + '\n';
                }
            } else {
                resp += '  No classes found for namespace "' + ctx.ns + '".\n';
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNUSED) {
            resp += '🗑️ Unused Apex classes — safe to delete (' + s.unused + '):\n\n';
            if (s.unusedClasses != null && !s.unusedClasses.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.ApexClassInfo c : s.unusedClasses) {
                    resp += formatItem(i++, c.name, c.name, 'Apex Class');
                }
            } else {
                resp += 'None found — all classes are in use! ✅\n';
            }
            resp += '\nTo delete: type "delete apex class <ClassName>"';
            return resp;
        }

        if (ctx.intent == INTENT_USED) {
            resp += '✅ Used Apex classes (' + s.used + '):\n\n';
            if (s.usedClassNames != null) {
                Integer i = 1;
                for (String n : s.usedClassNames) {
                    resp += formatItem(i++, n, n, 'Apex Class');
                }
            }
            return resp;
        }

        if (ctx.lower.contains('test')) {
            resp += '🧪 Test classes (' + s.testCount + '):\n\n';
            if (s.testClassNames != null) {
                Integer i = 1;
                for (String n : s.testClassNames) {
                    resp += formatItem(i++, n, n, 'Apex Class (Test)');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_MANAGED) {
            resp += '📦 Standard/package classes (' + s.standard + '):\n\n';
            if (s.standardClassNames != null) {
                Integer i = 1;
                for (String n : s.standardClassNames) {
                    resp += formatItem(i++, n, n, 'Apex Class');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            resp += '🔧 Custom Apex classes (no namespace):\n\n';
            if (s.usedClassNames != null) {
                Integer i = 1;
                for (String n : s.usedClassNames) {
                    if (i > 20) { resp += '  ... and ' + (s.used - 20) + ' more.\n'; break; }
                    resp += formatItem(i++, n, n, 'Apex Class');
                }
            }
            if (s.unusedClasses != null) {
                Integer i = 1;
                for (MetadataEngine.ApexClassInfo c : s.unusedClasses) {
                    resp += formatItem(i++, c.name, c.name, 'Apex Class (Unused)');
                }
            }
            return resp;
        }

        // Default — all sections
        if (s.unusedClasses != null && !s.unusedClasses.isEmpty()) {
            resp += '--- 🗑️ UNUSED (' + s.unused + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.ApexClassInfo c : s.unusedClasses) {
                resp += formatItem(i++, c.name, c.name, 'Apex Class');
            }
            resp += '\n';
        }
        if (s.usedClassNames != null && !s.usedClassNames.isEmpty()) {
            resp += '--- ✅ USED (' + s.used + ') ---\n\n';
            Integer i = 1;
            for (String n : s.usedClassNames) {
                if (i > 20) { resp += '  ... and ' + (s.used - 20) + ' more.\n'; break; }
                resp += formatItem(i++, n, n, 'Apex Class');
            }
            resp += '\n';
        }
        if (s.testClassNames != null && !s.testClassNames.isEmpty()) {
            resp += '--- 🧪 TEST (' + s.testCount + ') ---\n\n';
            Integer i = 1;
            for (String n : s.testClassNames) {
                resp += formatItem(i++, n, n, 'Apex Class (Test)');
            }
        }
        return resp;
    }

    // ── TRIGGERS ──────────────────────────────────────────────
    private static String buildTriggerResponse(MetadataEngine.TriggerSummary s, QueryContext ctx) {
        String resp = '⚡ TRIGGERS\n'
                    + 'Total: ' + s.total + '  |  Active: ' + s.active + '  |  Inactive: ' + s.inactive
                    + '  |  Used: ' + s.used + '  |  Unused: ' + s.unused + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + s.filteredTotal + ' matching)\n';
            if (s.filteredTriggers != null && !s.filteredTriggers.isEmpty()) {
                for (MetadataEngine.TriggerInfo t : s.filteredTriggers) {
                    resp += '  * ' + t.name + ' on ' + t.objectName + '\n';
                }
            } else {
                resp += '  No triggers found for namespace "' + ctx.ns + '".\n';
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNUSED) {
            resp += '🗑️ Unused/Inactive triggers — safe to delete (' + s.unusedTriggers.size() + '):\n\n';
            if (!s.unusedTriggers.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.TriggerInfo t : s.unusedTriggers) {
                    resp += formatItem(i++, t.name, t.name, t.objectName + ' Trigger');
                }
            } else {
                resp += 'None found — all triggers are active and used! ✅\n';
            }
            resp += '\nTo delete: type "delete trigger <TriggerName>"';
            return resp;
        }

        if (ctx.intent == INTENT_USED) {
            resp += '✅ Used triggers (' + s.used + '):\n\n';
            if (s.usedTriggerNames != null) {
                Integer i = 1;
                for (String n : s.usedTriggerNames) { resp += formatItem(i++, n, n, 'Trigger'); }
            }
            return resp;
        }

        // Default
        if (!s.unusedTriggers.isEmpty()) {
            resp += '--- 🗑️ UNUSED (' + s.unused + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.TriggerInfo t : s.unusedTriggers) {
                resp += formatItem(i++, t.name, t.name, t.objectName + ' Trigger');
            }
            resp += '\n';
        }
        if (!s.activeTriggers.isEmpty()) {
            resp += '--- ✅ ACTIVE (' + s.active + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.TriggerInfo t : s.activeTriggers) {
                resp += formatItem(i++, t.name, t.name, t.objectName + ' Trigger');
            }
            resp += '\n';
        }
        if (!s.inactiveTriggers.isEmpty()) {
            resp += '--- ⬜ INACTIVE (' + s.inactive + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.TriggerInfo t : s.inactiveTriggers) {
                resp += formatItem(i++, t.name, t.name, t.objectName + ' Trigger (Inactive)');
            }
        }
        return resp;
    }

    // ── LWC ───────────────────────────────────────────────────
    private static String buildLwcResponse(MetadataEngine.LwcSummary s, QueryContext ctx) {
        String resp = '🔷 LWC COMPONENTS\n'
                    + 'Total: ' + s.total + '  |  With namespace: ' + s.withNamespace
                    + '  |  No namespace: ' + s.withoutNamespace + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + (s.filteredComponents != null ? s.filteredComponents.size() : 0) + ' matching)\n';
            if (s.filteredComponents != null && !s.filteredComponents.isEmpty()) {
                for (MetadataEngine.LwcComponentInfo c : s.filteredComponents) {
                    resp += '  * ' + c.name + ' (v' + c.apiVersion + ')\n';
                }
            } else {
                resp += '  No LWC found for namespace "' + ctx.ns + '".\n';
            }
            return resp;
        }

        if (ctx.intent == INTENT_MANAGED) {
            resp += '📦 LWC from managed packages (' + s.withNamespace + '):\n\n';
            if (s.allComponents != null) {
                Integer i = 1;
                for (MetadataEngine.LwcComponentInfo c : s.allComponents) {
                    if (String.isNotBlank(c.namespacePrefix))
                        resp += formatItem(i++, c.name, c.namespacePrefix + '__' + c.name, 'LWC Component');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            resp += '🔧 Custom LWC (no namespace) (' + s.withoutNamespace + '):\n\n';
            if (s.allComponents != null) {
                Integer i = 1;
                for (MetadataEngine.LwcComponentInfo c : s.allComponents) {
                    if (String.isBlank(c.namespacePrefix)) resp += formatItem(i++, c.name, c.name, 'LWC Component');
                }
            }
            return resp;
        }

        resp += '--- ALL LWC COMPONENTS (' + s.total + ') ---\n\n';
        if (s.allComponents != null && !s.allComponents.isEmpty()) {
            Integer i = 1;
            for (MetadataEngine.LwcComponentInfo c : s.allComponents) {
                if (i > 30) { resp += '  ... and ' + (s.total - 30) + ' more.\n'; break; }
                String apiName = String.isNotBlank(c.namespacePrefix) ? c.namespacePrefix + '__' + c.name : c.name;
                resp += formatItem(i++, c.name, apiName, 'LWC Component');
            }
        } else {
            resp += 'None found.\n';
        }
        return resp;
    }

    // ── AURA ──────────────────────────────────────────────────
    private static String buildAuraResponse(MetadataEngine.AuraSummary s, QueryContext ctx) {
        String resp = '🔶 AURA COMPONENTS\n'
                    + 'Total: ' + s.total + '  |  With namespace: ' + s.withNamespace
                    + '  |  No namespace: ' + s.withoutNamespace + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + (s.filteredComponents != null ? s.filteredComponents.size() : 0) + ' matching)\n';
            if (s.filteredComponents != null && !s.filteredComponents.isEmpty()) {
                for (MetadataEngine.AuraComponentInfo c : s.filteredComponents) {
                    resp += '  * ' + c.name + ' (v' + c.apiVersion + ')\n';
                }
            } else {
                resp += '  No Aura components found for namespace "' + ctx.ns + '".\n';
            }
            return resp;
        }

        if (ctx.intent == INTENT_MANAGED) {
            resp += '📦 Aura from managed packages (' + s.withNamespace + '):\n\n';
            if (s.allComponents != null) {
                Integer i = 1;
                for (MetadataEngine.AuraComponentInfo c : s.allComponents) {
                    if (String.isNotBlank(c.namespacePrefix))
                        resp += formatItem(i++, c.name, c.namespacePrefix + '__' + c.name, 'Aura Component');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            resp += '🔧 Custom Aura (no namespace) (' + s.withoutNamespace + '):\n\n';
            if (s.allComponents != null) {
                Integer i = 1;
                for (MetadataEngine.AuraComponentInfo c : s.allComponents) {
                    if (String.isBlank(c.namespacePrefix)) resp += formatItem(i++, c.name, c.name, 'Aura Component');
                }
            }
            return resp;
        }

        resp += '--- ALL AURA COMPONENTS (' + s.total + ') ---\n\n';
        if (s.allComponents != null && !s.allComponents.isEmpty()) {
            Integer i = 1;
            for (MetadataEngine.AuraComponentInfo c : s.allComponents) {
                if (i > 30) { resp += '  ... and ' + (s.total - 30) + ' more.\n'; break; }
                String apiName = String.isNotBlank(c.namespacePrefix) ? c.namespacePrefix + '__' + c.name : c.name;
                resp += formatItem(i++, c.name, apiName, 'Aura Component');
            }
        } else {
            resp += 'None found.\n';
        }
        return resp;
    }

    // ── PROFILES ──────────────────────────────────────────────
    private static String buildProfileResponse(MetadataEngine.ProfileSummary s, QueryContext ctx) {
        String resp = '👤 PROFILES\n'
                    + 'Total: ' + s.total + '  |  Assigned: ' + s.used + '  |  Unassigned: ' + s.unused + '\n\n';

        if (ctx.intent == INTENT_UNUSED) {
            resp += '🗑️ Unassigned profiles — no active users (' + s.unused + '):\n\n';
            if (!s.unusedProfiles.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.ProfileInfo p : s.unusedProfiles) {
                    resp += formatItem(i++, p.name, p.name, 'Profile');
                }
            } else {
                resp += 'All profiles have active users assigned! ✅\n';
            }
            resp += '\nNote: To remove a profile, use "deactivate profile <ProfileName> fallback <FallbackProfile>"';
            return resp;
        }

        if (ctx.intent == INTENT_USED) {
            resp += '✅ Assigned profiles (' + s.used + '):\n\n';
            Integer i = 1;
            for (MetadataEngine.ProfileInfo p : s.usedProfiles) {
                resp += formatItem(i++, p.name, p.name, 'Profile');
            }
            return resp;
        }

        // Default — all
        if (!s.usedProfiles.isEmpty()) {
            resp += '--- ✅ ASSIGNED (' + s.used + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.ProfileInfo p : s.usedProfiles) {
                resp += formatItem(i++, p.name, p.name, 'Profile');
            }
            resp += '\n';
        }
        if (!s.unusedProfiles.isEmpty()) {
            resp += '--- 🗑️ UNASSIGNED (' + s.unused + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.ProfileInfo p : s.unusedProfiles) {
                resp += formatItem(i++, p.name, p.name, 'Profile');
            }
        }
        return resp;
    }

    // ── PERMISSION SETS ───────────────────────────────────────
    private static String buildPermSetResponse(MetadataEngine.PermissionSetSummary s, QueryContext ctx) {
        String resp = '🔑 PERMISSION SETS\n'
                    + 'Total: ' + s.total + '  |  Assigned: ' + s.used + '  |  Unassigned: ' + s.unused + '\n\n';

        if (ctx.intent == INTENT_UNUSED) {
            resp += '🗑️ Unassigned permission sets (' + s.unused + '):\n\n';
            if (!s.unusedPermSets.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.PermissionSetInfo p : s.unusedPermSets) {
                    resp += formatItem(i++, p.label, p.name, 'Permission Set');
                }
            } else {
                resp += 'All permission sets have assignments! ✅\n';
            }
            resp += '\nTo delete: type "delete permission set <Name>"';
            return resp;
        }

        if (ctx.intent == INTENT_USED) {
            resp += '✅ Assigned permission sets (' + s.used + '):\n\n';
            Integer i = 1;
            for (MetadataEngine.PermissionSetInfo p : s.usedPermSets) {
                resp += formatItem(i++, p.label, p.name, 'Permission Set');
            }
            return resp;
        }

        // Default
        if (!s.usedPermSets.isEmpty()) {
            resp += '--- ✅ ASSIGNED (' + s.used + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.PermissionSetInfo p : s.usedPermSets) {
                resp += formatItem(i++, p.label, p.name, 'Permission Set');
            }
            resp += '\n';
        }
        if (!s.unusedPermSets.isEmpty()) {
            resp += '--- 🗑️ UNASSIGNED (' + s.unused + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.PermissionSetInfo p : s.unusedPermSets) {
                resp += formatItem(i++, p.label, p.name, 'Permission Set');
            }
        }
        return resp;
    }

    // ── CUSTOM FIELDS ─────────────────────────────────────────
    private static String buildFieldResponse(MetadataEngine.CustomFieldSummary s, QueryContext ctx) {
        String resp = '🗂️ CUSTOM FIELDS\n'
                    + 'Total: ' + s.total + '  |  With namespace: ' + s.withNamespace
                    + '  |  No namespace: ' + s.withoutNamespace + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + (s.filteredFields != null ? s.filteredFields.size() : 0) + ' matching)\n';
            if (s.filteredFields != null && !s.filteredFields.isEmpty()) {
                for (MetadataEngine.CustomFieldInfo f : s.filteredFields) {
                    resp += '  * ' + f.objectName + '.' + f.name + '\n';
                }
            } else {
                resp += '  No fields found for namespace "' + ctx.ns + '".\n';
            }
            return resp;
        }

        if (ctx.intent == INTENT_MANAGED) {
            resp += '📦 Fields from managed packages (' + s.withNamespace + '):\n\n';
            if (s.allFields != null) {
                Integer i = 1;
                for (MetadataEngine.CustomFieldInfo f : s.allFields) {
                    if (String.isNotBlank(f.namespacePrefix))
                        resp += formatItem(i++, f.name, f.objectName + '.' + f.name, 'Custom Field');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            resp += '🔧 Custom fields (no namespace) (' + s.withoutNamespace + '):\n\n';
            if (s.allFields != null) {
                Integer i = 1;
                for (MetadataEngine.CustomFieldInfo f : s.allFields) {
                    if (String.isBlank(f.namespacePrefix)) {
                        if (i > 30) { resp += '  ... and more. Use namespace filter.\n'; break; }
                        resp += formatItem(i++, f.name, f.objectName + '.' + f.name, 'Custom Field');
                    }
                }
            }
            return resp;
        }

        // Default — show all capped
        resp += '--- ALL CUSTOM FIELDS (' + s.total + ') ---\n\n';
        if (s.allFields != null && !s.allFields.isEmpty()) {
            Integer i = 1;
            for (MetadataEngine.CustomFieldInfo f : s.allFields) {
                if (i > 30) { resp += '  ... and ' + (s.total - 30) + ' more. Use namespace filter.\n'; break; }
                resp += formatItem(i++, f.name, f.objectName + '.' + f.name, 'Custom Field');
            }
        } else {
            resp += 'None found.\n';
        }
        return resp;
    }

    // ── CUSTOM OBJECTS ────────────────────────────────────────
    private static String buildObjectResponse(MetadataEngine.CustomObjectSummary s, QueryContext ctx) {
        String resp = '🗄️ CUSTOM OBJECTS\n'
                    + 'Total: ' + s.total + '  |  With namespace: ' + s.withNamespace
                    + '  |  No namespace: ' + s.withoutNamespace + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + (s.filteredObjects != null ? s.filteredObjects.size() : 0) + ' matching)\n';
            if (s.filteredObjects != null && !s.filteredObjects.isEmpty()) {
                for (MetadataEngine.CustomObjectInfo o : s.filteredObjects) {
                    resp += '  * ' + o.name + '__c' + (String.isNotBlank(o.namespacePrefix) ? ' [' + o.namespacePrefix + ']' : '') + '\n';
                }
            } else {
                resp += '  No objects found for namespace "' + ctx.ns + '".\n';
            }
            return resp;
        }

        if (ctx.intent == INTENT_MANAGED) {
            resp += '📦 Objects from managed packages (' + s.withNamespace + '):\n\n';
            if (s.allObjects != null) {
                Integer i = 1;
                for (MetadataEngine.CustomObjectInfo o : s.allObjects) {
                    if (String.isNotBlank(o.namespacePrefix))
                        resp += formatItem(i++, o.label, o.name + '__c', 'Custom Object');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            resp += '🔧 Custom objects (no namespace) (' + s.withoutNamespace + '):\n\n';
            if (s.allObjects != null) {
                Integer i = 1;
                for (MetadataEngine.CustomObjectInfo o : s.allObjects) {
                    if (String.isBlank(o.namespacePrefix))
                        resp += formatItem(i++, o.label, o.name + '__c', 'Custom Object');
                }
            }
            return resp;
        }

        // Default
        resp += '--- ALL CUSTOM OBJECTS (' + s.total + ') ---\n\n';
        if (s.allObjects != null && !s.allObjects.isEmpty()) {
            Integer i = 1;
            for (MetadataEngine.CustomObjectInfo o : s.allObjects) {
                resp += formatItem(i++, o.label, o.name + '__c', 'Custom Object');
            }
        } else {
            resp += 'None found.\n';
        }
        return resp;
    }

    // ── VALIDATION RULES ──────────────────────────────────────
    private static String buildVrResponse(MetadataEngine.ValidationRuleSummary s, QueryContext ctx) {
        String resp = '✔️ VALIDATION RULES\n'
                    + 'Total: ' + s.total + '  |  Active: ' + s.active + '  |  Inactive: ' + s.inactive + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + (s.filteredRules != null ? s.filteredRules.size() : 0) + ' matching)\n';
            if (s.filteredRules != null && !s.filteredRules.isEmpty()) {
                for (MetadataEngine.ValidationRuleInfo v : s.filteredRules) {
                    resp += '  ' + (v.isActive ? '*' : '-') + ' ' + v.objectName + '.' + v.name
                          + ' (' + (v.isActive ? 'active' : 'inactive') + ')\n';
                }
            } else {
                resp += '  No rules found for namespace "' + ctx.ns + '".\n';
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNUSED) {
            resp += '🗑️ Inactive validation rules — safe to review (' + s.inactive + '):\n\n';
            if (s.inactiveRules != null && !s.inactiveRules.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.ValidationRuleInfo v : s.inactiveRules) {
                    resp += formatItem(i++, v.name, v.objectName + '.' + v.name, 'Validation Rule');
                }
            } else {
                resp += 'None found — all rules are active! ✅\n';
            }
            resp += '\nTo delete: type "delete validation rule ObjectName.RuleName"';
            return resp;
        }

        if (ctx.intent == INTENT_USED) {
            resp += '✅ Active validation rules (' + s.active + '):\n\n';
            if (s.activeRules != null) {
                Integer i = 1;
                for (MetadataEngine.ValidationRuleInfo v : s.activeRules) {
                    if (i > 20) { resp += '  ... and ' + (s.active - 20) + ' more.\n'; break; }
                    resp += formatItem(i++, v.name, v.objectName + '.' + v.name, 'Validation Rule');
                }
            }
            return resp;
        }

        // Default
        if (s.activeRules != null && !s.activeRules.isEmpty()) {
            resp += '--- ✅ ACTIVE (' + s.active + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.ValidationRuleInfo v : s.activeRules) {
                if (i > 20) { resp += '  ... and ' + (s.active - 20) + ' more.\n'; break; }
                resp += formatItem(i++, v.name, v.objectName + '.' + v.name, 'Validation Rule');
            }
            resp += '\n';
        }
        if (s.inactiveRules != null && !s.inactiveRules.isEmpty()) {
            resp += '--- 🗑️ INACTIVE (' + s.inactive + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.ValidationRuleInfo v : s.inactiveRules) {
                resp += formatItem(i++, v.name, v.objectName + '.' + v.name, 'Validation Rule');
            }
        }
        return resp;
    }

    // =========================================================
    // UTILITIES
    // =========================================================

    // ── Format a single item as Label / API Name / Type ──────
    private static String formatItem(Integer idx, String label, String apiName, String type) {
        return idx + '.\n' +
               '   Label    : ' + label + '\n' +
               '   API Name : ' + apiName + '\n' +
               '   Type     : ' + type + '\n';
    }

    private static String listItems(List<String> items, String header, String prefix) {
        if (items == null || items.isEmpty()) return '';
        String result = (String.isNotBlank(header) ? header + '\n' : '');
        for (String item : items) {
            result += prefix + item + '\n';
        }
        return result + '\n';
    }

    private static String listItemsCapped(List<String> items, String prefix, Integer cap) {
        if (items == null || items.isEmpty()) return '';
        String result = '';
        Integer shown = 0;
        for (String item : items) {
            if (shown >= cap) { result += '  ... and ' + (items.size() - cap) + ' more.\n'; break; }
            result += prefix + item + '\n'; shown++;
        }
        return result;
    }

    private static String formatDate(String isoDate) {
        if (String.isBlank(isoDate)) return 'unknown';
        return isoDate.length() >= 10 ? isoDate.substring(0, 10) : isoDate;
    }

    private static String repeat(String ch, Integer times) {
        String result = '';
        for (Integer i = 0; i < times; i++) {
            result += ch;
        }
        return result;
    }

    private static String helpMessage() {
        return '👋 Hi! I can help you audit and clean your Salesforce org.\n\n'
             + 'Try asking:\n'
             + '  • "show unused flows"\n'
             + '  • "which apex classes can be deleted?"\n'
             + '  • "show apex + triggers"\n'
             + '  • "show flows from managed packages"\n'
             + '  • "list custom objects with no namespace"\n'
             + '  • "show unassigned permission sets"\n'
             + '  • "show inactive validation rules"\n'
             + '  • "show lwc and aura components"\n\n'
             + 'To delete:\n'
             + '  • "delete apex class MyClass"\n'
             + '  • "delete flow My_Flow_API_Name"\n'
             + '  • "delete trigger AccountTrigger"\n'
             + '  • "delete validation rule Account.MyRule"\n'
             + '  • "delete permission set MyPermSet"';
    }
}