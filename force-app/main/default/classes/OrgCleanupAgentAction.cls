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
@SuppressWarnings('PMD.NcssMethodCount,PMD.ExcessiveClassLength,PMD.CognitiveComplexity,PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces,PMD.ApexCRUDViolation,PMD.ForLoopsMustUseBraces,PMD.ExcessiveParameterList,PMD.NcssTypeCount,PMD.EmptyStatementBlock,PMD.AvoidDeeplyNestedIfStmts,PMD.EmptyCatchBlock')
public without sharing class OrgCleanupAgentAction {

    // ── Transaction-level cache ───────────────────────────────
    // getApexClasses() is expensive (fetches SymbolTable for every class).
    // Cache the result so multiple methods in the same transaction share it.
    private static MetadataEngine.ApexSummary cachedApexSummary = null;
    private static MetadataEngine.ApexSummary getApexCached(String ns) {
        if (cachedApexSummary == null) {
            cachedApexSummary = MetadataEngine.getApexClasses(ns);
        }
        return cachedApexSummary;
    }

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

    // ── Custom field/object suffix ────────────────────────────
    private static final String  CUSTOM_SUFFIX    = '__c';

    // ── Section separator width ───────────────────────────────
    private static final Integer SEPARATOR_WIDTH  = 50;

    // ── Help / hint message templates ────────────────────────
    private static final String HELP_MESSAGE =
        '👋 Hi! I can help you audit and clean your Salesforce org.\n\n'
      + 'Try asking:\n'
      + '  • "show unused flows"\n'
      + '  • "which apex classes can be deleted?"\n'
      + '  • "show apex + triggers"\n'
      + '  • "show flows from managed packages"\n'
      + '  • "list custom objects with no namespace"\n'
      + '  • "show unassigned permission sets"\n'
      + '  • "show inactive validation rules"\n'
      + '  • "show lwc and aura components"\n'
      + '  • "how many flows" — count only, no list\n'
      + '  • "org summary" or "show everything"\n\n'
      + 'Object & Field queries:\n'
      + '  • "fields on Account"\n'
      + '  • "what fields does MyObject__c have?"\n'
      + '  • "describe Account" — label, field count, field list\n\n'
      + 'Cross-type search:\n'
      + '  • "find anything named LeadScoring"\n\n'
      + 'Object-scoped queries:\n'
      + '  • "flows on Account"\n'
      + '  • "triggers on Account"\n'
      + '  • "validation rules on Account"\n\n'
      + 'Status & detail checks:\n'
      + '  • "is MyFlow active?"\n'
      + '  • "when was MyClass last modified"\n'
      + '  • "how many lines in MyClass"\n\n'
      + 'Org health:\n'
      + '  • "org health check"\n'
      + '  • "what should I clean up?"\n\n'
      + '  • "delete apex class MyClass"\n'
      + '  • "delete flow My_Flow_API_Name"\n'
      + '  • "delete trigger AccountTrigger"\n'
      + '  • "delete validation rule Account.MyRule"\n'
      + '  • "delete permission set MyPermSet"\n'
      + '  • "deactivate profile ReadOnly fallback Standard User"';

    private static final String DELETE_HELP =
        'What would you like to delete? Here are the supported formats:\n\n'
      + '  • delete apex class MyClass\n'
      + '  • delete flow My_Flow_API_Name\n'
      + '  • delete trigger AccountTrigger\n'
      + '  • delete lwc myComponent\n'
      + '  • delete aura MyComponent\n'
      + '  • delete field Account.EM_Usha\n'
      + '  • delete field EM_Usha on Account\n'
      + '  • delete validation rule Account.MyRule\n'
      + '  • delete permission set MyPermSet\n'
      + '  • delete custom object MyObject\n'
      + '  • deactivate profile ReadOnly fallback "Standard User"';

    // ── Section header labels ─────────────────────────────────
    private static final String HDR_FLOWS         = '🔀 FLOWS';
    private static final String HDR_APEX          = '⚡ APEX CLASSES';
    private static final String HDR_TRIGGERS      = '⚡ TRIGGERS';
    private static final String HDR_LWC           = '🔷 LWC COMPONENTS';
    private static final String HDR_AURA          = '🔶 AURA COMPONENTS';
    private static final String HDR_PROFILES      = '👤 PROFILES';
    private static final String HDR_PERMSETS      = '🔑 PERMISSION SETS';
    private static final String HDR_FIELDS        = '🗂️ CUSTOM FIELDS';
    private static final String HDR_OBJECTS       = '🗄️ CUSTOM OBJECTS';
    private static final String HDR_VR            = '✔️ VALIDATION RULES';

    // ── Query context wrapper — avoids long parameter lists ─
    @TestVisible
    private class QueryContext {
        String  intent;
        String  ns;
        String  lower;
        QueryContext(String intent, String ns, String lower) {
            this.intent = intent;
            this.ns     = ns;
            this.lower  = lower;
        }

    }

    // =========================================================
    // LWC ENTRY POINT
    // =========================================================
    // ── Reference check — called by LWC before showing delete confirmation ──────
    // Returns null if safe to delete, or a formatted report string if references exist.
    @AuraEnabled(cacheable=false)
    public static String checkReferences(String componentName, String componentType) {
        if (String.isBlank(componentName) || String.isBlank(componentType)) return null;
        try {
            MetadataEngine.ReferenceResult refs;

            // Use deep scan for LWC — covers MCD + JS imports + HTML child tags
            if ('LightningComponentBundle'.equalsIgnoreCase(componentType)) {
                refs = MetadataEngine.checkAllLwcReferences(componentName.trim());
            } else {
                refs = MetadataEngine.getReferencesFor(componentName.trim(), componentType.trim());
            }

            if (refs == null || !refs.hasReferences) return null;
            return String.isNotBlank(refs.formattedReport)
                ? refs.formattedReport
                : MetadataEngine.buildFormattedReportPublic(componentName.trim(), refs.references, componentType.trim());
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'checkReferences error: ' + ex.getMessage());
            return null; // fail open
        }
    }

    @AuraEnabled(cacheable=false)
    public static String handleAgentQuery(String userQuery) {
        if (String.isBlank(userQuery)) {
            return helpMessage();
        }
        try {
            String lower = userQuery.toLowerCase().trim();

            // ── Confirm delete intent ──────────────────────────
            if (isConfirmDeleteIntent(lower)) {
                return handleConfirmDelete(lower, userQuery);
            }

            // ── Delete intent ──────────────────────────────────
            if (isDeleteIntent(lower)) {
                return handleDelete(lower, userQuery);
            }

            // ── Greeting / thank-you intent ────────────────────
            if (isGreetingIntent(lower)) {
                return handleGreeting(lower);
            }

            // ── "Fields on Object" intent ──────────────────────
            if (isFieldsOnObjectIntent(lower)) {
                return handleFieldsOnObject(userQuery, lower);
            }

            // ── "Describe object" intent ───────────────────────
            if (isDescribeObjectIntent(lower)) {
                return handleDescribeObject(userQuery, lower);
            }

            // ── "Find anything named X" intent ────────────────
            if (isFindByNameIntent(lower)) {
                return handleFindByName(userQuery, lower);
            }

            // ── "How many X" count-only intent ────────────────
            if (isCountOnlyIntent(lower)) {
                return handleCountOnly(userQuery, lower);
            }

            // ── "X on Account" / type+object filter intent ────
            if (isTypeOnObjectIntent(lower)) {
                return handleTypeOnObject(userQuery, lower);
            }

            // ── Status check: "is X active" ───────────────────
            if (isStatusCheckIntent(lower)) {
                return handleStatusCheck(userQuery, lower);
            }

            // ── Component details: last modified / line count ──
            if (isComponentDetailIntent(lower)) {
                return handleComponentDetail(userQuery, lower);
            }

            // ── Org health / cleanup report ────────────────────
            if (isOrgHealthIntent(lower)) {
                return handleOrgHealth();
            }

            // ── Query intent ───────────────────────────────────
            List<String>  types   = detectTypes(lower);
            String        intent  = detectIntent(lower);
            String        ns      = extractNamespace(userQuery, lower);
            QueryContext  ctx    = new QueryContext(intent, ns, lower);

            if (types.isEmpty()) {
                return helpMessage();
            }

            // Build response for each matched type and combine
            List<String> sections = new List<String>();
            for (String t : types) {
                sections.add(buildSection(t, ctx));
            }

            String combined = String.join(sections, '\n' + repeat('─', SEPARATOR_WIDTH) + '\n\n');

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
        return lower.startsWith('delete ')     || lower.startsWith('remove ')     ||
               lower.startsWith('deactivate ') || lower.contains('delete the ')  ||
               lower.contains('remove the ');
    }

    // ── Confirm intent: "confirm delete apex class MyClass" ───
    private static Boolean isConfirmDeleteIntent(String lower) {
        return lower.startsWith('confirm delete ')      ||
               lower.startsWith('confirm remove ')      ||
               lower.startsWith('confirm mass delete ')  ||
               lower.startsWith('yes delete ')          ||
               lower.startsWith('yes, delete ')         ||
               lower.startsWith('confirm deactivate ');
    }

    // ── Strip "confirm" prefix and execute the actual deletion ──
    private static String handleConfirmDelete(String lower, String originalQuery) {

        // ── Mass delete path: "confirm mass delete <type> name1, name2, ..." ──
        if (lower.startsWith('confirm mass delete ')) {
            String body      = originalQuery.replaceFirst('(?i)^confirm\\s+mass\\s+delete\\s+', '').trim();
            String bodyLower = body.toLowerCase();

            String massType = null;
            if      (bodyLower.startsWith('apex class'))  { massType = TYPE_APEX;    body = body.replaceFirst('(?i)^apex\\s+classes?\\s*', ''); }
            else if (bodyLower.startsWith('apex'))        { massType = TYPE_APEX;    body = body.replaceFirst('(?i)^apex\\s*', ''); }
            else if (bodyLower.startsWith('flow'))        { massType = TYPE_FLOW;    body = body.replaceFirst('(?i)^flows?\\s*', ''); }
            else if (bodyLower.startsWith('trigger'))     { massType = TYPE_TRIGGER; body = body.replaceFirst('(?i)^triggers?\\s*', ''); }
            else if (bodyLower.startsWith('lwc'))         { massType = TYPE_LWC;     body = body.replaceFirst('(?i)^lwcs?\\s*', ''); }
            else if (bodyLower.startsWith('aura'))        { massType = TYPE_AURA;    body = body.replaceFirst('(?i)^aura\\s*(components?)?\\s*', ''); }
            else if (bodyLower.startsWith('permset') || bodyLower.startsWith('perm set') || bodyLower.startsWith('permission set')) {
                massType = TYPE_PERMSET; body = body.replaceFirst('(?i)^(permission\\s+sets?|perm\\s+sets?|permsets?)\\s*', '');
            }
            else if (bodyLower.startsWith('profile'))     { massType = TYPE_PROFILE; body = body.replaceFirst('(?i)^profiles?\\s*', ''); }
            else if (bodyLower.startsWith('object'))      { massType = TYPE_OBJECT;  body = body.replaceFirst('(?i)^objects?\\s*', ''); }

            if (massType == null) {
                return '⚠️ Could not detect type. Example: confirm mass delete flow BSR_Test01, BSR_Test 2';
            }

            List<String> names = splitNames(body);
            if (names.isEmpty()) {
                return '⚠️ No names found. Example: confirm mass delete flow BSR_Test01, BSR_Test 2';
            }

            MetadataEngine.MassDeleteResult result;
            try {
                if      (massType == TYPE_FLOW)    result = MetadataEngine.massDeleteFlows(names);
                else if (massType == TYPE_APEX)    result = MetadataEngine.massDeleteApexClasses(names);
                else if (massType == TYPE_TRIGGER) result = MetadataEngine.massDeleteTriggers(names);
                else if (massType == TYPE_LWC)     result = MetadataEngine.massDeleteLwcComponents(names);
                else if (massType == TYPE_AURA)    result = MetadataEngine.massDeleteAuraComponents(names);
                else if (massType == TYPE_PERMSET) result = MetadataEngine.massDeletePermissionSets(names);
                else if (massType == TYPE_PROFILE) result = MetadataEngine.massDeactivateProfiles(names);
                else if (massType == TYPE_OBJECT)  result = MetadataEngine.massDeleteCustomObjects(names);
                else return '❌ Mass delete not supported for type: ' + massType;
            } catch (Exception ex) {
                return '❌ Mass delete error: ' + ex.getMessage();
            }
            return formatMassResult(result);
        }

        String stripped      = originalQuery.replaceFirst('(?i)^(confirm|yes,?)\\s+', '').trim();
        String strippedLower = stripped.toLowerCase();

        // Detect type from the stripped query
        String type = null;
        if      (strippedLower.contains('validation rule') || strippedLower.contains('val rule'))  type = TYPE_VR;
        else if (strippedLower.contains('custom field')    || strippedLower.contains('field'))     type = TYPE_FIELD;
        else if (strippedLower.contains('custom object')   || strippedLower.contains('object'))    type = TYPE_OBJECT;
        else if (strippedLower.contains('permission sets') || strippedLower.contains('permission set') ||
                 strippedLower.contains('permsets')        || strippedLower.contains('permset'))   type = TYPE_PERMSET;
        else if (strippedLower.contains('apex class')      || strippedLower.contains('apex'))      type = TYPE_APEX;
        else if (strippedLower.contains('flow'))                                                    type = TYPE_FLOW;
        else if (strippedLower.contains('trigger'))                                                 type = TYPE_TRIGGER;
        else if (strippedLower.contains('lwc') || strippedLower.contains('lightning web'))         type = TYPE_LWC;
        else if (strippedLower.contains('aura'))                                                    type = TYPE_AURA;
        else if (strippedLower.contains('profile'))                                                 type = TYPE_PROFILE;

        if (type == null) {
            return '⚠️ Could not detect metadata type in confirmation. Please retry with full command.\nExample: confirm delete apex class MyClass';
        }

        // Route to special handlers for field, VR, profile (need extra parsing)
        if (type == TYPE_PROFILE) return handleProfileDelete(stripped, strippedLower);
        if (type == TYPE_FIELD)   return handleFieldDelete(stripped, strippedLower);
        if (type == TYPE_VR)      return handleVrDelete(stripped, strippedLower);

        // For all other types — extract name and execute confirmed deletion
        String name = extractDeleteName(stripped, type);
        if (String.isBlank(name)) {
            return '⚠️ Could not extract component name. Please retry.\nExample: confirm delete apex class MyClass';
        }
        return executeDeleteConfirmed(type, name);
    }

    // ── Look up safetyStatus for a component before confirming delete ──
    private static String getSafetyStatusForComponent(String type, String name) {
        try {
            if (type == TYPE_FLOW) {
                MetadataEngine.FlowSummary s = MetadataEngine.getFlows(null);
                for (MetadataEngine.FlowInfo f : s.allFlowObjects) {
                    if (name.equalsIgnoreCase(f.apiName)) return f.safetyStatus;
                }
            } else if (type == TYPE_APEX) {
                MetadataEngine.ApexSummary s = getApexCached(null);
                for (MetadataEngine.ApexClassInfo c : s.unusedClasses) {
                    if (name.equalsIgnoreCase(c.name)) return c.safetyStatus;
                }
                if (s.usedClassNames != null && s.usedClassNames.contains(name)) return 'IN_USE';
            } else if (type == TYPE_TRIGGER) {
                MetadataEngine.TriggerSummary s = MetadataEngine.getTriggers(null);
                List<MetadataEngine.TriggerInfo> all = new List<MetadataEngine.TriggerInfo>();
                if (s.activeTriggers   != null) all.addAll(s.activeTriggers);
                if (s.inactiveTriggers != null) all.addAll(s.inactiveTriggers);
                for (MetadataEngine.TriggerInfo t : all) {
                    if (name.equalsIgnoreCase(t.name)) return t.safetyStatus;
                }
            } else if (type == TYPE_LWC) {
                MetadataEngine.LwcSummary s = MetadataEngine.getLwcComponents(null);
                for (MetadataEngine.LwcComponentInfo c : s.allComponents) {
                    if (name.equalsIgnoreCase(c.name)) return c.safetyStatus;
                }
            } else if (type == TYPE_AURA) {
                MetadataEngine.AuraSummary s = MetadataEngine.getAuraComponents(null);
                for (MetadataEngine.AuraComponentInfo c : s.allComponents) {
                    if (name.equalsIgnoreCase(c.name)) return c.safetyStatus;
                }
            } else if (type == TYPE_PERMSET) {
                MetadataEngine.PermissionSetSummary s = MetadataEngine.getPermissionSets(null);
                for (MetadataEngine.PermissionSetInfo p : s.allPermSets) {
                    if (name.equalsIgnoreCase(p.name)) return p.safetyStatus;
                }
            } else if (type == TYPE_OBJECT) {
                MetadataEngine.CustomObjectSummary s = MetadataEngine.getCustomObjects(null);
                for (MetadataEngine.CustomObjectInfo o : s.allObjects) {
                    if (name.equalsIgnoreCase(o.name) || name.equalsIgnoreCase(o.name + '__c')) return o.safetyStatus;
                }
            }
        } catch (Exception ex) { /* lookup failed — return unknown */ }
        return 'UNKNOWN';
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

        // ── Auto-detect type if not specified ────────────────
        // User said e.g. "delete BSR_Test01, BSR_Test 2" without a type keyword.
        // Search FlowDefinitionView first (most common), then Apex, Trigger.
        if (type == null) {
            // Extract the raw name portion (everything after "delete ")
            String rawForDetect = originalQuery.replaceFirst('(?i)^(delete|remove)\\s+', '').trim();
            // Take first name (before any comma) to probe the type
            String probe = rawForDetect.contains(',')
                ? rawForDetect.split(',')[0].trim().replace(' ', '_')
                : rawForDetect.replace(' ', '_');

            if (String.isNotBlank(probe)) {
                // Try Flow first
                try {
                    MetadataEngine.FlowSummary fs = MetadataEngine.getFlows(null);
                    for (MetadataEngine.FlowInfo fi : fs.allFlowObjects) {
                        if (probe.equalsIgnoreCase(fi.apiName)) { type = TYPE_FLOW; break; }
                    }
                } catch (Exception ex) {}

                // Try Apex Class
                if (type == null) {
                    try {
                        MetadataEngine.ApexSummary apexSummary = getApexCached(null);
                        for (MetadataEngine.ApexClassInfo ci : apexSummary.unusedClasses) {
                            if (probe.equalsIgnoreCase(ci.name)) { type = TYPE_APEX; break; }
                        }
                        if (type == null && apexSummary.usedClassNames != null) {
                            for (String n : apexSummary.usedClassNames) {
                                if (probe.equalsIgnoreCase(n)) { type = TYPE_APEX; break; }
                            }
                        }
                    } catch (Exception ex) {}
                }

                // Try Trigger
                if (type == null) {
                    try {
                        MetadataEngine.TriggerSummary ts = MetadataEngine.getTriggers(null);
                        List<MetadataEngine.TriggerInfo> allT = new List<MetadataEngine.TriggerInfo>();
                        if (ts.activeTriggers   != null) allT.addAll(ts.activeTriggers);
                        if (ts.inactiveTriggers != null) allT.addAll(ts.inactiveTriggers);
                        for (MetadataEngine.TriggerInfo ti : allT) {
                            if (probe.equalsIgnoreCase(ti.name)) { type = TYPE_TRIGGER; break; }
                        }
                    } catch (Exception ex) {}
                }
            }

            if (type == null) {
                return '⚠️ Could not detect metadata type. Please include it in your command.\n' +
                       'Examples:\n' +
                       '  delete flow BSR_Test01, BSR_Test 2\n' +
                       '  delete apex class MyClass\n' +
                       '  delete trigger MyTrigger';
            }
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

        // ── Mass delete: comma-separated names ───────────────
        String rawName = extractDeleteName(originalQuery, type);
        if (String.isBlank(rawName)) {
            return '⚠️ Please provide the API name to delete.\nExample: "delete ' + type + ' YourComponentName"';
        }

        if (rawName.contains(',')) {
            List<String> names = splitNames(rawName);
            if (names.size() > 1) {
                // Build confirmation message listing names
                String nameList = '';
                for (Integer i = 0; i < names.size(); i++) {
                    nameList += '  ' + (i + 1) + '. ' + names[i] + '\n';
                }

                // ── For Apex: pre-scan profiles/permsets and warn user before confirming ──
                String apexProfileWarning = '';
                if (type == TYPE_APEX) {
                    apexProfileWarning = buildApexProfileStripWarning(names);
                }

                // Return a confirmation prompt (mirrors LWC behaviour)
                return '⚠️ Mass Delete Confirmation\n\n' +
                       'You are about to delete ' + names.size() + ' ' + type + '(s):\n' +
                       nameList +
                       apexProfileWarning +
                       '\nThis action cannot be undone.\n\n' +
                       'To confirm, reply:\n  confirm mass delete ' + type + ' ' + rawName;
            }
            rawName = names[0];
        }

        // ── Single name ────────────────────────────────────────
        return executeDelete(type, rawName);
    }

    // ── Pre-scan: find Profile/PermSet access for a list of Apex class names ──
    // Called at confirmation time so the user sees exactly what will be auto-stripped
    // before they confirm. The actual strip happens inside MetadataEngine.massDeleteApexClasses.
    private static String buildApexProfileStripWarning(List<String> classNames) {
        Map<String, List<String>> classToProfiles = new Map<String, List<String>>();
        Map<String, List<String>> classToPermSets = new Map<String, List<String>>();

        try {
            // Resolve class Ids in one bulk query
            Set<String> nameSet = new Set<String>();
            for (String n : classNames) {
                if (String.isNotBlank(n)) nameSet.add(n.trim().replace(' ', '_'));
            }

            List<ApexClass> classes = [
                SELECT Id, Name FROM ApexClass
                WHERE Name IN :nameSet
                AND NamespacePrefix = null
                LIMIT 200
            ];

            if (classes.isEmpty()) return '';

            // Build Id → Name map
            Map<Id, String> idToName = new Map<Id, String>();
            Set<Id> classIds = new Set<Id>();
            for (ApexClass ac : classes) {
                idToName.put(ac.Id, ac.Name);
                classIds.add(ac.Id);
            }

            // ── Query 1: Fetch SetupEntityAccess rows — Parent.Name + IsOwnedByProfile only ──
            // ParentId cannot be SELECT-ed. We use Parent.Name to resolve Profile/PermSet Ids
            // separately, then filter by UserType/IsCustom to show only user-assigned entries.
            List<SetupEntityAccess> allAccess = [
                SELECT SetupEntityId, Parent.Name, Parent.IsOwnedByProfile
                FROM SetupEntityAccess
                WHERE SetupEntityId IN :classIds
                LIMIT 1000
            ];

            if (allAccess.isEmpty()) return '';

            // ── Query 2: Split parent names by type ──
            Set<String> profileNames = new Set<String>();
            Set<String> permSetNames = new Set<String>();
            for (SetupEntityAccess sea : allAccess) {
                if (sea.Parent == null) continue;
                if (sea.Parent.IsOwnedByProfile) {
                    profileNames.add(sea.Parent.Name);
                } else {
                    permSetNames.add(sea.Parent.Name);
                }
            }

            // ── Query 3: Filter Profiles — only UserType = Standard ──
            // Excludes: Guest, Chatter Free, Partner Portal (system profiles)
            Set<String> userProfileNames = new Set<String>();
            if (!profileNames.isEmpty()) {
                for (Profile p : [
                    SELECT Id, Name FROM Profile
                    WHERE Name IN :profileNames
                    AND UserType = 'Standard'
                ]) {
                    userProfileNames.add(p.Name);
                }
            }

            // ── Query 4: Filter PermSets — only user-created custom ones ──
            // Excludes: profile-backed permsets, Salesforce standard permsets
            Set<String> userPermSetNames = new Set<String>();
            if (!permSetNames.isEmpty()) {
                for (PermissionSet ps : [
                    SELECT Id, Name FROM PermissionSet
                    WHERE Name IN :permSetNames
                    AND IsOwnedByProfile = false
                    AND IsCustom = true
                ]) {
                    userPermSetNames.add(ps.Name);
                }
            }

            if (userProfileNames.isEmpty() && userPermSetNames.isEmpty()) return '';

            // ── Build result maps — only user-assigned entries ──
            for (SetupEntityAccess sea : allAccess) {
                if (sea.Parent == null) continue;
                String parentName = sea.Parent.Name;
                Boolean isProfile = sea.Parent.IsOwnedByProfile;
                if (isProfile && !userProfileNames.contains(parentName)) continue;
                if (!isProfile && !userPermSetNames.contains(parentName)) continue;
                String clsName = idToName.get(sea.SetupEntityId);
                if (String.isBlank(clsName)) continue;
                if (isProfile) {
                    if (!classToProfiles.containsKey(clsName)) classToProfiles.put(clsName, new List<String>());
                    classToProfiles.get(clsName).add(parentName);
                } else {
                    if (!classToPermSets.containsKey(clsName)) classToPermSets.put(clsName, new List<String>());
                    classToPermSets.get(clsName).add(parentName);
                }
            }
        } catch (Exception ex) {
            return '\n⚠️ Could not pre-scan Profile/PermSet references: ' + ex.getMessage() + '\n';
        }

        if (classToProfiles.isEmpty() && classToPermSets.isEmpty()) return '';

        // Build warning block
        String warn = '\n🔐 Profile/PermSet Access Auto-Strip:\n';
        warn += '  The following access entries will be automatically removed before deletion:\n';
        for (String clsName : classToProfiles.keySet()) {
            List<String> profiles = classToProfiles.get(clsName);
            warn += '  • ' + clsName + ' → Profiles: ' + String.join(profiles, ', ') + '\n';
        }
        for (String clsName : classToPermSets.keySet()) {
            List<String> permSets = classToPermSets.get(clsName);
            // Only add if not already listed under profiles
            if (!classToProfiles.containsKey(clsName)) {
                warn += '  • ' + clsName + ' → Permission Sets: ' + String.join(permSets, ', ') + '\n';
            } else {
                warn += '    + Permission Sets: ' + String.join(permSets, ', ') + '\n';
            }
        }
        warn += '  ✅ This is done automatically — no manual Setup steps needed.\n';
        return warn;
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
                    fieldName  = parts[1].trim().replace(CUSTOM_SUFFIX, '').replace(CUSTOM_SUFFIX.toUpperCase(), '');
                }
            } else if (String.isNotBlank(objectName)) {
                // "on" notation: EM_Usha on Account
                fieldName = fieldToken.trim().replace(CUSTOM_SUFFIX, '').replace(CUSTOM_SUFFIX.toUpperCase(), '');
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
        return DELETE_HELP;
    }

    private static String extractDeleteName(String query, String type) {
        // Patterns: "delete flow My_Flow", "delete flows My_Flow", "delete apex class MyClass"
        String stripped = query;

        // Remove leading verb
        stripped = stripped.replaceFirst('(?i)^(delete|remove)\\s+', '');

        // Remove type keywords — plurals included (flows?, triggers?, etc.)
        stripped = stripped.replaceFirst('(?i)^(apex\\s+classes|apex\\s+class|apex|flows?|triggers?|lwcs?|lightning\\s+web\\s+components?|aura\\s+components?|aura|validation\\s+rules?|val\\s+rules?|permission\\s+sets?|perm\\s+sets?|permsets?|custom\\s+fields?|custom\\s+objects?|profiles?|objects?|fields?|the)\\s+', '');

        String candidate = stripped.trim();
        if (String.isNotBlank(candidate)) {
            return candidate;  // return full name — spaces allowed (e.g. "BSR Test 2")
        }
        return null;
    }

    // ── Split comma-separated names, trim each, remove blanks ─
    private static List<String> splitNames(String raw) {
        List<String> names = new List<String>();
        if (String.isBlank(raw)) return names;
        for (String n : raw.split(',')) {
            String t = n.trim();
            if (String.isNotBlank(t)) names.add(t);
        }
        return names;
    }

    // ── Format a MassDeleteResult into a readable chat message ─
    private static String formatMassResult(MetadataEngine.MassDeleteResult mass) {
        String emoji = mass.failureCount == 0 ? '✅' : (mass.successCount == 0 ? '❌' : '⚠️');
        String msg = emoji + ' Mass Delete Complete\n\n' + mass.summary;
        if (mass.succeeded != null && !mass.succeeded.isEmpty()) {
            msg += '\n\n✔ Deleted (' + mass.successCount + '):\n';
            for (String n : mass.succeeded) msg += '  • ' + n + '\n';
        }
        if (mass.failed != null && !mass.failed.isEmpty()) {
            msg += '\n\n✘ Failed (' + mass.failureCount + '):\n';
            for (String n : mass.failed) msg += '  • ' + n + '\n';
        }
        return msg;
    }

    private static String executeDelete(String type, String name) {
        // ── Pre-flight: show safetyStatus + ask for confirmation ──
        String status = getSafetyStatusForComponent(type, name);

        String statusLabel = '';
        String statusEmoji = '⚠️';
        if (status == 'SAFE_TO_REVIEW') { statusEmoji = '🟢'; statusLabel = 'Safe to Review — no active references detected.'; }
        else if (status == 'INACTIVE')  { statusEmoji = '🟢'; statusLabel = 'Inactive — currently disabled.'; }
        else if (status == 'EMPTY')     { statusEmoji = '🟡'; statusLabel = 'Empty — no logic found in body.'; }
        else if (status == 'HAS_DATA')  { statusEmoji = '🔴'; statusLabel = 'Has Data — records or field values exist. Deleting will permanently remove this data.'; }
        else if (status == 'TEST_CLASS'){ statusEmoji = '🟡'; statusLabel = 'Test Class — deleting may affect code coverage.'; }
        else if (status == 'SCHEDULED') { statusEmoji = '🟡'; statusLabel = 'Scheduled/Auto-launched — may have active schedule.'; }
        else if (status == 'IN_USE')    { statusEmoji = '🔴'; statusLabel = 'IN USE — referenced by other components. Delete blocked.'; }
        else if (status == 'MANAGED')   { statusEmoji = '🔴'; statusLabel = 'Managed Package — delete blocked.'; }
        else if (status == 'ENTRY_POINT'){ statusEmoji = '🔴'; statusLabel = 'Entry Point — delete blocked.'; }
        else if (status == 'SYSTEM')    { statusEmoji = '🔴'; statusLabel = 'System Profile — delete blocked.'; }
        else                            { statusLabel = status; }

        // Blocked statuses — the engine will also block, but give early feedback here
        if (status == 'IN_USE' || status == 'MANAGED' || status == 'ENTRY_POINT' || status == 'SYSTEM') {
            return '🚫 Cannot delete "' + name + '".\n' +
                   'Safety Status: ' + statusEmoji + ' ' + statusLabel + '\n\n' +
                   'Remove all references first, then retry.';
        }

        // Safe statuses — ask for confirmation before proceeding
        String typeLabel = type.toUpperCase();
        return '⚠️ CONFIRMATION REQUIRED\n\n' +
               'You are about to permanently delete:\n' +
               '  Component : ' + name + '\n' +
               '  Type      : ' + typeLabel + '\n' +
               '  Status    : ' + statusEmoji + ' ' + statusLabel + '\n\n' +
               '⚠️ This action CANNOT be undone.\n\n' +
               'To proceed, type exactly:\n' +
               '  confirm delete ' + type + ' ' + name + '\n\n' +
               'To cancel, type anything else.';
    }

    // ── Actual deletion — only reached via handleConfirmDelete ──
    private static String executeDeleteConfirmed(String type, String name) {
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

        // ── Catch-all queries: show all metadata types ─────────
        Boolean isAllQuery = lower.contains('everything')     || lower.contains('all metadata') ||
                             lower.contains('full summary')   || lower.contains('org summary')  ||
                             lower.contains('overview')       || lower.contains('full report');
        if (isAllQuery) {
            return new List<String>{ TYPE_FLOW, TYPE_APEX, TYPE_TRIGGER, TYPE_LWC,
                                     TYPE_AURA, TYPE_PROFILE, TYPE_PERMSET,
                                     TYPE_FIELD, TYPE_OBJECT, TYPE_VR };
        }

        if (lower.contains('flow'))                                                              types.add(TYPE_FLOW);
        // trigger keyword → triggers only
        if (lower.contains('trigger'))                                                           types.add(TYPE_TRIGGER);
        // 'apex class' or 'class' explicitly → classes only
        if ((lower.contains('apex') && lower.contains('class')) ||
            (lower.contains('class') && !lower.contains('trigger') && !lower.contains('object'))) types.add(TYPE_APEX);
        // 'apex' alone (no 'class', no 'trigger') → show BOTH apex classes + triggers
        if (lower.contains('apex') && !lower.contains('class') && !lower.contains('trigger')) {
            types.add(TYPE_APEX);
            types.add(TYPE_TRIGGER);
        }
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
            lower.contains('clean up')       || (lower.contains('which') && lower.contains('delet')) ||
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

        // Count / summary queries — show all with totals
        if (lower.contains('how many') || lower.contains('count')  ||
            lower.contains('total')    || lower.contains('summary') ||
            lower.contains('report')) {
            return INTENT_ALL;
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
            'remove','which','never','used','assigned','referenced','in','use',
            // additional stop words to prevent false namespace extraction
            'give','me','a','an','of','and','or','to','for','are','is','was',
            'validation','trigger','aura','components','component','classes',
            'flows','triggers','profiles','permsets','please','want','need',
            'count','how','many','total','summary','report','everything','overview'
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
        else if (type == TYPE_APEX)    { return buildApexResponse(getApexCached(ctx.ns), ctx); }
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
        String resp = HDR_FLOWS + '\n'
                    + 'Total: ' + s.total + '  |  Active: ' + s.active + '  |  Inactive: ' + s.inactive + '\n\n';

        List<MetadataEngine.FlowInfo> all = s.allFlowObjects != null ? s.allFlowObjects : new List<MetadataEngine.FlowInfo>();

        if (String.isNotBlank(ctx.ns)) {
            List<MetadataEngine.FlowInfo> filtered = new List<MetadataEngine.FlowInfo>();
            for (MetadataEngine.FlowInfo f : all) {
                if (ctx.ns.equalsIgnoreCase(f.namespacePrefix == null ? '' : f.namespacePrefix)) filtered.add(f);
            }
            resp += 'Namespace filter: ' + ctx.ns + ' (' + filtered.size() + ' matching)\n\n';
            if (filtered.isEmpty()) {
                resp += '  No flows found for namespace "' + ctx.ns + '".\n';
            } else {
                Integer i = 1;
                for (MetadataEngine.FlowInfo f : filtered) {
                    resp += formatItem(i++, f.label, f.apiName, f.processType != null ? f.processType : 'Flow');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNUSED) {
            resp += '🗑️ Inactive flows — safe to review/delete (' + s.inactive + '):\n\n';
            Boolean found = false;
            Integer i = 1;
            for (MetadataEngine.FlowInfo f : all) {
                if (!f.isActive) {
                    resp += formatItem(i++, f.label, f.apiName, f.processType != null ? f.processType : 'Flow');
                    found = true;
                }
            }
            if (!found) resp += 'None found — all flows are active! ✅\n';
            resp += '\nTo delete: type "delete flow <ApiName>"';
            return resp;
        }

        if (ctx.intent == INTENT_USED) {
            resp += '✅ Active flows (' + s.active + '):\n\n';
            Integer i = 1;
            for (MetadataEngine.FlowInfo f : all) {
                if (f.isActive) {
                    resp += formatItem(i++, f.label, f.apiName, f.processType != null ? f.processType : 'Flow');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_MANAGED) {
            List<MetadataEngine.FlowInfo> managed = new List<MetadataEngine.FlowInfo>();
            for (MetadataEngine.FlowInfo f : all) { if (String.isNotBlank(f.namespacePrefix)) managed.add(f); }
            resp += '📦 Flows from managed packages (' + managed.size() + '):\n\n';
            Integer i = 1;
            for (MetadataEngine.FlowInfo f : managed) { resp += formatItem(i++, f.label, f.apiName, f.processType != null ? f.processType : 'Flow'); }
            if (managed.isEmpty()) resp += 'No managed package flows found.\n';
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            List<MetadataEngine.FlowInfo> unmanaged = new List<MetadataEngine.FlowInfo>();
            for (MetadataEngine.FlowInfo f : all) { if (String.isBlank(f.namespacePrefix)) unmanaged.add(f); }
            resp += '🔧 Custom flows (no namespace) (' + unmanaged.size() + '):\n\n';
            Integer i = 1;
            for (MetadataEngine.FlowInfo f : unmanaged) { resp += formatItem(i++, f.label, f.apiName, f.processType != null ? f.processType : 'Flow'); }
            if (unmanaged.isEmpty()) resp += 'None found.\n';
            return resp;
        }

        // Default — show all
        List<MetadataEngine.FlowInfo> activeList   = new List<MetadataEngine.FlowInfo>();
        List<MetadataEngine.FlowInfo> inactiveList = new List<MetadataEngine.FlowInfo>();
        for (MetadataEngine.FlowInfo f : all) {
            if (f.isActive) activeList.add(f); else inactiveList.add(f);
        }
        if (!activeList.isEmpty()) {
            resp += '--- ✅ ACTIVE (' + activeList.size() + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.FlowInfo f : activeList) {
                resp += formatItem(i++, f.label, f.apiName, f.processType != null ? f.processType : 'Flow');
            }
            resp += '\n';
        }
        if (!inactiveList.isEmpty()) {
            resp += '--- ⬜ INACTIVE (' + inactiveList.size() + ') ---\n\n';
            Integer i = 1;
            for (MetadataEngine.FlowInfo f : inactiveList) {
                resp += formatItem(i++, f.label, f.apiName, f.processType != null ? f.processType : 'Flow');
            }
        }
        return resp;
    }

    // ── APEX CLASSES ──────────────────────────────────────────
    private static String buildApexResponse(MetadataEngine.ApexSummary s, QueryContext ctx) {
        String resp = HDR_APEX + '\n'
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
            resp += '\n';
        }
        if (s.standardClassNames != null && !s.standardClassNames.isEmpty()) {
            resp += '--- 📦 STANDARD/PACKAGE (' + s.standard + ') ---\n\n';
            Integer i = 1;
            for (String n : s.standardClassNames) {
                resp += formatItem(i++, n, n, 'Apex Class');
            }
        }
        return resp;
    }

    // ── TRIGGERS ──────────────────────────────────────────────
    private static String buildTriggerResponse(MetadataEngine.TriggerSummary s, QueryContext ctx) {
        String resp = HDR_TRIGGERS + '\n'
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
        String resp = HDR_LWC + '\n'
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

        if (ctx.intent == INTENT_UNUSED) {
            Integer unrefCount = s.unreferencedCount != null ? s.unreferencedCount : 0;
            resp += '🗑️ Unreferenced LWC components — not used in any page, flow, or tab (' + unrefCount + '):\n\n';
            if (s.unreferencedComponents != null && !s.unreferencedComponents.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.LwcComponentInfo c : s.unreferencedComponents) {
                    resp += formatItem(i++, c.name, c.name, 'LWC Component (' + (c.safetyStatus != null ? c.safetyStatus : 'SAFE_TO_REVIEW') + ')');
                }
            } else {
                resp += 'All LWC components are referenced! ✅\n';
            }
            resp += '\nTo delete: type "delete lwc <ComponentName>"';
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
        String resp = HDR_AURA + '\n'
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

        if (ctx.intent == INTENT_UNUSED) {
            Integer unrefCount = s.unreferencedCount != null ? s.unreferencedCount : 0;
            resp += '🗑️ Unreferenced Aura components — not used in any app or markup (' + unrefCount + '):\n\n';
            if (s.unreferencedComponents != null && !s.unreferencedComponents.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.AuraComponentInfo c : s.unreferencedComponents) {
                    resp += formatItem(i++, c.name, c.name, 'Aura Component (' + (c.safetyStatus != null ? c.safetyStatus : 'SAFE_TO_REVIEW') + ')');
                }
            } else {
                resp += 'All Aura components are referenced! ✅\n';
            }
            resp += '\nTo delete: type "delete aura <ComponentName>"';
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
        String resp = HDR_PROFILES + '\n'
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
        String resp = HDR_PERMSETS + '\n'
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

        // Default — all sections
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
        String resp = HDR_FIELDS + '\n'
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

        if (ctx.intent == INTENT_UNUSED) {
            Integer emptyCount = s.emptyCount != null ? s.emptyCount : 0;
            resp += '🗑️ Custom fields with no data (all values null) (' + emptyCount + '):\n\n';
            if (s.emptyFields != null && !s.emptyFields.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.CustomFieldInfo f : s.emptyFields) {
                    resp += formatItem(i++, f.name, f.objectName + '.' + f.name + '__c',
                        'Custom Field [' + (f.dataType != null ? f.dataType : 'unknown') + ']');
                }
            } else {
                resp += 'All custom fields have data! ✅\n';
            }
            resp += '\nTo delete: type "delete field Object.FieldName"';
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            resp += '🔧 Custom fields (no namespace) (' + s.withoutNamespace + '):\n\n';
            if (s.allFields != null) {
                Integer i = 1;
                for (MetadataEngine.CustomFieldInfo f : s.allFields) {
                    if (String.isBlank(f.namespacePrefix)) {
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
                resp += formatItem(i++, f.name, f.objectName + '.' + f.name, 'Custom Field');
            }
        } else {
            resp += 'None found.\n';
        }
        return resp;
    }

    // ── CUSTOM OBJECTS ────────────────────────────────────────
    private static String buildObjectResponse(MetadataEngine.CustomObjectSummary s, QueryContext ctx) {
        String resp = HDR_OBJECTS + '\n'
                    + 'Total: ' + s.total + '  |  With namespace: ' + s.withNamespace
                    + '  |  No namespace: ' + s.withoutNamespace + '\n\n';

        if (String.isNotBlank(ctx.ns)) {
            resp += 'Namespace filter: ' + ctx.ns + ' (' + (s.filteredObjects != null ? s.filteredObjects.size() : 0) + ' matching)\n';
            if (s.filteredObjects != null && !s.filteredObjects.isEmpty()) {
                for (MetadataEngine.CustomObjectInfo o : s.filteredObjects) {
                    resp += '  * ' + o.name + CUSTOM_SUFFIX + (String.isNotBlank(o.namespacePrefix) ? ' [' + o.namespacePrefix + ']' : '') + '\n';
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
                        resp += formatItem(i++, o.label, o.name + CUSTOM_SUFFIX, 'Custom Object');
                }
            }
            return resp;
        }

        if (ctx.intent == INTENT_UNUSED) {
            Integer emptyCount = s.emptyCount != null ? s.emptyCount : 0;
            resp += '🗑️ Custom objects with 0 records (' + emptyCount + '):\n\n';
            if (s.emptyObjects != null && !s.emptyObjects.isEmpty()) {
                Integer i = 1;
                for (MetadataEngine.CustomObjectInfo o : s.emptyObjects) {
                    resp += formatItem(i++, o.label != null ? o.label : o.name,
                        o.name + CUSTOM_SUFFIX, 'Custom Object [0 records]');
                }
            } else {
                resp += 'All custom objects have records! ✅\n';
            }
            resp += '\nTo delete: type "delete custom object <Name>"';
            return resp;
        }

        if (ctx.intent == INTENT_UNMANAGED) {
            resp += '🔧 Custom objects (no namespace) (' + s.withoutNamespace + '):\n\n';
            if (s.allObjects != null) {
                Integer i = 1;
                for (MetadataEngine.CustomObjectInfo o : s.allObjects) {
                    if (String.isBlank(o.namespacePrefix))
                        resp += formatItem(i++, o.label, o.name + CUSTOM_SUFFIX, 'Custom Object');
                }
            }
            return resp;
        }

        // Default
        resp += '--- ALL CUSTOM OBJECTS (' + s.total + ') ---\n\n';
        if (s.allObjects != null && !s.allObjects.isEmpty()) {
            Integer i = 1;
            for (MetadataEngine.CustomObjectInfo o : s.allObjects) {
                resp += formatItem(i++, o.label, o.name + CUSTOM_SUFFIX, 'Custom Object');
            }
        } else {
            resp += 'None found.\n';
        }
        return resp;
    }

    // ── VALIDATION RULES ──────────────────────────────────────
    private static String buildVrResponse(MetadataEngine.ValidationRuleSummary s, QueryContext ctx) {
        String resp = HDR_VR + '\n'
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

    private static String repeat(String ch, Integer times) {
        String result = '';
        for (Integer i = 0; i < times; i++) {
            result += ch;
        }
        return result;
    }

    private static String helpMessage() {
        return HELP_MESSAGE;
    }

    // =========================================================
    // ── NEW FEATURES ─────────────────────────────────────────
    // =========================================================

    // ── GREETING / THANK-YOU ──────────────────────────────────
    private static Boolean isGreetingIntent(String lower) {
        return lower.equals('hello') || lower.equals('hi') || lower.equals('hey') ||
               lower.startsWith('hello') || lower.startsWith('hi ') ||
               lower.contains('thank') || lower.contains('thanks') ||
               lower.equals('help') || lower.startsWith('help ') || lower.equals('what can you do') ||
               lower.contains('what can you do') || lower.contains('capabilities');
    }

    private static String handleGreeting(String lower) {
        if (lower.contains('thank')) {
            return '😊 You\'re welcome! Let me know if there\'s anything else you\'d like to audit or clean up in your org.';
        }
        if (lower.contains('help') || lower.contains('what can you do') || lower.contains('capabilities')) {
            return HELP_MESSAGE +
                '\n\nAdditional queries you can try:\n' +
                '  • \"fields on Account\" or \"what fields does MyObject__c have?\"\n' +
                '  • \"describe Account\" — label, field count, field list\n' +
                '  • \"find anything named LeadScoring\" — searches all metadata types\n' +
                '  • \"how many flows\" — count only, no full list\n' +
                '  • \"flows on Account\" — flows related to a specific object\n' +
                '  • \"triggers on Account\" — triggers for a specific object\n' +
                '  • \"is MyFlow active\" — quick status check\n' +
                '  • \"when was MyClass last modified\" — last modified date\n' +
                '  • \"how many lines in MyClass\" — line count\n' +
                '  • \"org health check\" or \"what should I clean up?\" — full health report';
        }
        return '👋 Hi there! I\'m your Salesforce Org Metadata Assistant.\n\n' +
               'I can help you audit flows, Apex classes, triggers, LWC, Aura components, profiles, permission sets, custom fields, objects, and validation rules.\n\n' +
               'Type \"help\" to see everything I can do, or just ask me something like:\n' +
               '  • \"show unused flows\"\n' +
               '  • \"fields on Account\"\n' +
               '  • \"org health check\"';
    }

    // ── FIELDS ON OBJECT ──────────────────────────────────────
    private static Boolean isFieldsOnObjectIntent(String lower) {
        return (lower.contains('field') && lower.contains(' on ')) ||
               lower.startsWith('fields on ') ||
               lower.contains('what fields') ||
               lower.contains('fields does') ||
               lower.contains('fields of ') ||
               lower.contains('fields for ');
    }

    private static String handleFieldsOnObject(String originalQuery, String lower) {
        String objectName = extractObjectNameFromQuery(originalQuery, lower);
        if (String.isBlank(objectName)) {
            return '⚠️ Please specify an object name.\nExamples:\n  • fields on Account\n  • what fields does MyObject__c have?';
        }

        String fullObjName = objectName.endsWith('__c') ? objectName : objectName;

        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(fullObjName);
            if (sot == null) {
                sot = Schema.getGlobalDescribe().get(fullObjName + '__c');
                if (sot != null) fullObjName = fullObjName + '__c';
            }
            if (sot == null) {
                return '❌ Object not found: \"' + objectName + '\". Check the API name and try again.';
            }

            Schema.DescribeSObjectResult describe = sot.getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = describe.fields.getMap();

            String resp = '🗂️ Fields on ' + describe.getLabel() + ' (' + fullObjName + ')\n';
            resp += 'Total fields: ' + fieldsMap.size() + '\n\n';

            List<String> customFields  = new List<String>();
            List<String> standardFields = new List<String>();

            for (String fieldKey : fieldsMap.keySet()) {
                Schema.DescribeFieldResult f = fieldsMap.get(fieldKey).getDescribe();
                String line = '  ' + f.getLabel() + ' (' + f.getName() + ') [' + f.getType() + ']';
                if (f.isCustom()) {
                    customFields.add(line);
                } else {
                    standardFields.add(line);
                }
            }

            if (!customFields.isEmpty()) {
                resp += '--- CUSTOM FIELDS (' + customFields.size() + ') ---\n';
                for (String f : customFields) resp += f + '\n';
                resp += '\n';
            }
            if (!standardFields.isEmpty()) {
                resp += '--- STANDARD FIELDS (' + standardFields.size() + ') ---\n';
                for (String f : standardFields) resp += f + '\n';
            }

            return resp;

        } catch (Exception ex) {
            return '❌ Error fetching fields for \"' + objectName + '\": ' + ex.getMessage();
        }
    }

    // ── DESCRIBE OBJECT ───────────────────────────────────────
    private static Boolean isDescribeObjectIntent(String lower) {
        return lower.startsWith('describe ') ||
               lower.contains('describe the object') ||
               lower.contains('tell me about ') && lower.contains('object');
    }

    private static String handleDescribeObject(String originalQuery, String lower) {
        // Extract object name after "describe"
        String objectName = null;
        List<String> words = originalQuery.trim().split('\\s+');
        for (Integer i = 0; i < words.size(); i++) {
            if (words[i].equalsIgnoreCase('describe') && i + 1 < words.size()) {
                objectName = words[i + 1].replaceAll('[^A-Za-z0-9_]', '');
                break;
            }
        }

        if (String.isBlank(objectName)) {
            return '⚠️ Please specify an object name.\nExample: describe Account';
        }

        try {
            String fullObjName = objectName;
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(fullObjName);
            if (sot == null) {
                sot = Schema.getGlobalDescribe().get(fullObjName + '__c');
                if (sot != null) fullObjName = fullObjName + '__c';
            }
            if (sot == null) {
                return '❌ Object not found: \"' + objectName + '\". Check the API name.';
            }

            Schema.DescribeSObjectResult d = sot.getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = d.fields.getMap();

            Integer customCount   = 0;
            Integer standardCount = 0;
            List<String> customFieldNames = new List<String>();

            for (String fKey : fieldsMap.keySet()) {
                Schema.DescribeFieldResult f = fieldsMap.get(fKey).getDescribe();
                if (f.isCustom()) {
                    customCount++;
                    customFieldNames.add(f.getLabel() + ' (' + f.getName() + ')');
                } else {
                    standardCount++;
                }
            }

            String resp = '🗄️ Object Description: ' + fullObjName + '\n\n';
            resp += '  Label         : ' + d.getLabel() + '\n';
            resp += '  API Name      : ' + d.getName() + '\n';
            resp += '  Label Plural  : ' + d.getLabelPlural() + '\n';
            resp += '  Key Prefix    : ' + d.getKeyPrefix() + '\n';
            resp += '  Total Fields  : ' + fieldsMap.size() + '\n';
            resp += '  Custom Fields : ' + customCount + '\n';
            resp += '  Standard Fields: ' + standardCount + '\n';
            resp += '  Createable    : ' + d.isCreateable() + '\n';
            resp += '  Queryable     : ' + d.isQueryable() + '\n\n';

            if (!customFieldNames.isEmpty()) {
                resp += '--- CUSTOM FIELDS (' + customCount + ') ---\n';
                for (String fn : customFieldNames) resp += '  • ' + fn + '\n';
            }

            return resp;

        } catch (Exception ex) {
            return '❌ Error describing \"' + objectName + '\": ' + ex.getMessage();
        }
    }

    // ── FIND BY NAME (cross-type search) ──────────────────────
    private static Boolean isFindByNameIntent(String lower) {
        return lower.startsWith('find ') || lower.startsWith('search ') ||
               lower.contains('find anything named') || lower.contains('search for ') ||
               lower.contains('look for ') || lower.contains('find anything with');
    }

    private static String handleFindByName(String originalQuery, String lower) {
        // Extract search term
        String searchTerm = null;
        String[] patterns = new String[]{ 'find anything named ', 'find anything with ', 'search for ', 'look for ', 'find ', 'search ' };
        for (String p : patterns) {
            if (lower.startsWith(p)) {
                searchTerm = originalQuery.substring(p.length()).trim();
                break;
            }
        }
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return '⚠️ Please provide a search term of at least 2 characters.\nExamples:\n  • find anything named LeadScoring\n  • search for Account';
        }

        String termLower = searchTerm.toLowerCase();
        List<String> results = new List<String>();

        // Search Flows
        MetadataEngine.FlowSummary flows = MetadataEngine.getFlows(null);
        if (flows.allFlowObjects != null) {
            for (MetadataEngine.FlowInfo f : flows.allFlowObjects) {
                if ((f.label != null && f.label.toLowerCase().contains(termLower)) ||
                    (f.apiName != null && f.apiName.toLowerCase().contains(termLower))) {
                    results.add('🔀 Flow: ' + f.label + ' (' + f.apiName + ') — ' + (f.isActive ? 'Active' : 'Inactive'));
                }
            }
        }

        // Search Apex Classes
        MetadataEngine.ApexSummary apex = getApexCached(null);
        Map<String, MetadataEngine.ApexClassInfo> allApex = new Map<String, MetadataEngine.ApexClassInfo>();
        if (apex.unusedClasses != null) for (MetadataEngine.ApexClassInfo c : apex.unusedClasses) allApex.put(c.name, c);
        if (apex.usedClassNames != null) for (String n : apex.usedClassNames) if (!allApex.containsKey(n)) allApex.put(n, null);
        for (String n : allApex.keySet()) {
            if (n.toLowerCase().contains(termLower)) {
                results.add('⚡ Apex Class: ' + n);
            }
        }

        // Search Triggers
        MetadataEngine.TriggerSummary trigs = MetadataEngine.getTriggers(null);
        List<MetadataEngine.TriggerInfo> allTrigs = new List<MetadataEngine.TriggerInfo>();
        if (trigs.activeTriggers != null) allTrigs.addAll(trigs.activeTriggers);
        if (trigs.inactiveTriggers != null) allTrigs.addAll(trigs.inactiveTriggers);
        for (MetadataEngine.TriggerInfo t : allTrigs) {
            if (t.name != null && t.name.toLowerCase().contains(termLower)) {
                results.add('⚡ Trigger: ' + t.name + ' on ' + t.objectName + ' — ' + (t.isActive ? 'Active' : 'Inactive'));
            }
        }

        // Search LWC
        MetadataEngine.LwcSummary lwc = MetadataEngine.getLwcComponents(null);
        if (lwc.allComponents != null) {
            for (MetadataEngine.LwcComponentInfo c : lwc.allComponents) {
                if (c.name != null && c.name.toLowerCase().contains(termLower)) {
                    results.add('🔷 LWC: ' + c.name);
                }
            }
        }

        // Search Aura
        MetadataEngine.AuraSummary aura = MetadataEngine.getAuraComponents(null);
        if (aura.allComponents != null) {
            for (MetadataEngine.AuraComponentInfo c : aura.allComponents) {
                if (c.name != null && c.name.toLowerCase().contains(termLower)) {
                    results.add('🔶 Aura: ' + c.name);
                }
            }
        }

        // Search Custom Objects
        MetadataEngine.CustomObjectSummary objs = MetadataEngine.getCustomObjects(null);
        if (objs.allObjects != null) {
            for (MetadataEngine.CustomObjectInfo o : objs.allObjects) {
                if ((o.name != null && o.name.toLowerCase().contains(termLower)) ||
                    (o.label != null && o.label.toLowerCase().contains(termLower))) {
                    results.add('🗄️ Custom Object: ' + o.name + '__c (' + o.label + ')');
                }
            }
        }

        // Search Custom Fields
        MetadataEngine.CustomFieldSummary fields = MetadataEngine.getCustomFields(null);
        if (fields.allFields != null) {
            for (MetadataEngine.CustomFieldInfo f : fields.allFields) {
                if (f.name != null && f.name.toLowerCase().contains(termLower)) {
                    results.add('🗂️ Custom Field: ' + f.objectName + '.' + f.name + '__c');
                }
            }
        }

        // Search Validation Rules
        MetadataEngine.ValidationRuleSummary vrs = MetadataEngine.getValidationRules(null);
        List<MetadataEngine.ValidationRuleInfo> allVrs = new List<MetadataEngine.ValidationRuleInfo>();
        if (vrs.activeRules != null) allVrs.addAll(vrs.activeRules);
        if (vrs.inactiveRules != null) allVrs.addAll(vrs.inactiveRules);
        for (MetadataEngine.ValidationRuleInfo v : allVrs) {
            if (v.name != null && v.name.toLowerCase().contains(termLower)) {
                results.add('✔️ Validation Rule: ' + v.objectName + '.' + v.name + ' — ' + (v.isActive ? 'Active' : 'Inactive'));
            }
        }

        // Search Profiles
        MetadataEngine.ProfileSummary profs = MetadataEngine.getProfiles();
        List<MetadataEngine.ProfileInfo> allProfs = new List<MetadataEngine.ProfileInfo>();
        if (profs.usedProfiles   != null) allProfs.addAll(profs.usedProfiles);
        if (profs.unusedProfiles != null) allProfs.addAll(profs.unusedProfiles);
        for (MetadataEngine.ProfileInfo p : allProfs) {
            if (p.name != null && p.name.toLowerCase().contains(termLower)) {
                String assigned = (p.safetyStatus != null && p.safetyStatus == 'SYSTEM') ? 'System' :
                                  (profs.usedProfiles != null && profs.usedProfiles.contains(p)) ? 'Assigned' : 'Unassigned';
                results.add('👤 Profile: ' + p.name + ' — ' + assigned);
            }
        }

        // Search Permission Sets
        MetadataEngine.PermissionSetSummary permSets = MetadataEngine.getPermissionSets();
        List<MetadataEngine.PermissionSetInfo> allPermSets = new List<MetadataEngine.PermissionSetInfo>();
        if (permSets.usedPermSets   != null) allPermSets.addAll(permSets.usedPermSets);
        if (permSets.unusedPermSets != null) allPermSets.addAll(permSets.unusedPermSets);
        for (MetadataEngine.PermissionSetInfo p : allPermSets) {
            if ((p.name  != null && p.name.toLowerCase().contains(termLower)) ||
                (p.label != null && p.label.toLowerCase().contains(termLower))) {
                String assigned = (permSets.usedPermSets != null && permSets.usedPermSets.contains(p)) ? 'Assigned' : 'Unassigned';
                results.add('🔑 Permission Set: ' + p.label + ' (' + p.name + ') — ' + assigned);
            }
        }

        if (results.isEmpty()) {
            return '🔍 No metadata found matching \"' + searchTerm + '\" across all types.';
        }

        String resp = '🔍 Search results for \"' + searchTerm + '\" (' + results.size() + ' found):\n\n';
        for (Integer i = 0; i < results.size(); i++) {
            resp += (i + 1) + '. ' + results[i] + '\n';
        }
        return resp;
    }

    // ── COUNT-ONLY INTENT ─────────────────────────────────────
    private static Boolean isCountOnlyIntent(String lower) {
        return (lower.startsWith('how many ') || lower.contains('how many ') && lower.length() < 40) &&
               !lower.contains(' on ');
    }

    private static String handleCountOnly(String originalQuery, String lower) {
        List<String> types = detectTypes(lower);
        if (types.isEmpty()) {
            return '⚠️ I couldn\'t detect a metadata type. Try: \"how many flows\" or \"how many apex classes\"';
        }

        String resp = '📊 Count Summary\n\n';
        for (String t : types) {
            if      (t == TYPE_FLOW)    { MetadataEngine.FlowSummary s = MetadataEngine.getFlows(null);
                                          resp += '🔀 Flows: ' + s.total + ' total  |  Active: ' + s.active + '  |  Inactive: ' + s.inactive + '\n'; }
            else if (t == TYPE_APEX)    { MetadataEngine.ApexSummary s = getApexCached(null);
                                          resp += '⚡ Apex Classes: ' + s.total + ' total  |  Used: ' + s.used + '  |  Unused: ' + s.unused + '  |  Test: ' + s.testCount + '\n'; }
            else if (t == TYPE_TRIGGER) { MetadataEngine.TriggerSummary s = MetadataEngine.getTriggers(null);
                                          resp += '⚡ Triggers: ' + s.total + ' total  |  Active: ' + s.active + '  |  Inactive: ' + s.inactive + '\n'; }
            else if (t == TYPE_LWC)     { MetadataEngine.LwcSummary s = MetadataEngine.getLwcComponents(null);
                                          resp += '🔷 LWC Components: ' + s.total + ' total  |  With NS: ' + s.withNamespace + '  |  No NS: ' + s.withoutNamespace + '\n'; }
            else if (t == TYPE_AURA)    { MetadataEngine.AuraSummary s = MetadataEngine.getAuraComponents(null);
                                          resp += '🔶 Aura Components: ' + s.total + ' total  |  With NS: ' + s.withNamespace + '  |  No NS: ' + s.withoutNamespace + '\n'; }
            else if (t == TYPE_PROFILE) { MetadataEngine.ProfileSummary s = MetadataEngine.getProfiles();
                                          resp += '👤 Profiles: ' + s.total + ' total  |  Assigned: ' + s.used + '  |  Unassigned: ' + s.unused + '\n'; }
            else if (t == TYPE_PERMSET) { MetadataEngine.PermissionSetSummary s = MetadataEngine.getPermissionSets();
                                          resp += '🔑 Permission Sets: ' + s.total + ' total  |  Assigned: ' + s.used + '  |  Unassigned: ' + s.unused + '\n'; }
            else if (t == TYPE_FIELD)   { MetadataEngine.CustomFieldSummary s = MetadataEngine.getCustomFields(null);
                                          resp += '🗂️ Custom Fields: ' + s.total + ' total\n'; }
            else if (t == TYPE_OBJECT)  { MetadataEngine.CustomObjectSummary s = MetadataEngine.getCustomObjects(null);
                                          resp += '🗄️ Custom Objects: ' + s.total + ' total\n'; }
            else if (t == TYPE_VR)      { MetadataEngine.ValidationRuleSummary s = MetadataEngine.getValidationRules(null);
                                          resp += '✔️ Validation Rules: ' + s.total + ' total  |  Active: ' + s.active + '  |  Inactive: ' + s.inactive + '\n'; }
        }
        return resp;
    }

    // ── TYPE ON OBJECT FILTER ─────────────────────────────────
    private static Boolean isTypeOnObjectIntent(String lower) {
        return lower.contains(' on ') && (
            lower.contains('flow') || lower.contains('trigger') || lower.contains('validation') ||
            lower.contains('field') || lower.contains('active flow') || lower.contains('active trigger')
        ) && !lower.contains('delete') && !lower.contains('remove');
    }

    private static String handleTypeOnObject(String originalQuery, String lower) {
        // Extract object name from "X on ObjectName"
        String objectName = null;
        List<String> words = originalQuery.trim().split('\\s+');
        for (Integer i = 0; i < words.size(); i++) {
            if (words[i].equalsIgnoreCase('on') && i + 1 < words.size()) {
                objectName = words[i + 1].replaceAll('[^A-Za-z0-9_]', '');
                break;
            }
        }

        if (String.isBlank(objectName)) {
            return '⚠️ Please specify an object. Example: \"triggers on Account\"';
        }

        String objLower = objectName.toLowerCase();
        List<String> results = new List<String>();
        String resp = '📋 Metadata on ' + objectName + '\n\n';

        // Triggers on Object
        if (lower.contains('trigger')) {
            MetadataEngine.TriggerSummary ts = MetadataEngine.getTriggers(null);
            List<MetadataEngine.TriggerInfo> all = new List<MetadataEngine.TriggerInfo>();
            if (ts.activeTriggers != null) all.addAll(ts.activeTriggers);
            if (ts.inactiveTriggers != null) all.addAll(ts.inactiveTriggers);
            resp += HDR_TRIGGERS + '\n';
            Integer count = 0;
            for (MetadataEngine.TriggerInfo t : all) {
                if (t.objectName != null && t.objectName.toLowerCase().equals(objLower)) {
                    resp += '  ' + (t.isActive ? '✅' : '⬜') + ' ' + t.name + ' (' + (t.isActive ? 'Active' : 'Inactive') + ')\n';
                    count++;
                }
            }
            if (count == 0) resp += '  None found on ' + objectName + '\n';
            resp += '\n';
        }

        // Flows on Object
        if (lower.contains('flow')) {
            MetadataEngine.FlowSummary fs = MetadataEngine.getFlows(null);
            resp += HDR_FLOWS + '\n';
            Integer count = 0;
            if (fs.allFlowObjects != null) {
                for (MetadataEngine.FlowInfo f : fs.allFlowObjects) {
                    if ((f.label != null && f.label.toLowerCase().contains(objLower)) ||
                        (f.apiName != null && f.apiName.toLowerCase().contains(objLower))) {
                        resp += '  ' + (f.isActive ? '✅' : '⬜') + ' ' + f.label + ' (' + f.apiName + ')\n';
                        count++;
                    }
                }
            }
            if (count == 0) resp += '  No flows found referencing ' + objectName + '\n';
            resp += '\n';
        }

        // Validation Rules on Object
        if (lower.contains('validation')) {
            MetadataEngine.ValidationRuleSummary vs = MetadataEngine.getValidationRules(null);
            resp += HDR_VR + '\n';
            Integer count = 0;
            List<MetadataEngine.ValidationRuleInfo> allVrs = new List<MetadataEngine.ValidationRuleInfo>();
            if (vs.activeRules != null) allVrs.addAll(vs.activeRules);
            if (vs.inactiveRules != null) allVrs.addAll(vs.inactiveRules);
            for (MetadataEngine.ValidationRuleInfo v : allVrs) {
                if (v.objectName != null && v.objectName.toLowerCase().equals(objLower)) {
                    resp += '  ' + (v.isActive ? '✅' : '⬜') + ' ' + v.name + ' (' + (v.isActive ? 'Active' : 'Inactive') + ')\n';
                    count++;
                }
            }
            if (count == 0) resp += '  None found on ' + objectName + '\n';
            resp += '\n';
        }

        // Fields on Object (if not just "triggers/flows/validation")
        if (lower.contains('field') && !lower.contains('trigger') && !lower.contains('flow')) {
            return handleFieldsOnObject(originalQuery, lower);
        }

        return resp;
    }

    // ── STATUS CHECK: "is X active" ───────────────────────────
    private static Boolean isStatusCheckIntent(String lower) {
        return (lower.startsWith('is ') && lower.contains('active')) ||
               lower.contains('is it active') || lower.contains('active?');
    }

    private static String handleStatusCheck(String originalQuery, String lower) {
        // Extract component name — "is MyFlow active"
        String name = null;
        List<String> words = originalQuery.trim().split('\\s+');
        if (words.size() >= 2) {
            // name is typically the word(s) between "is" and "active"
            List<String> nameParts = new List<String>();
            Boolean inName = false;
            for (String w : words) {
                if (w.equalsIgnoreCase('is')) { inName = true; continue; }
                if (w.equalsIgnoreCase('active') || w.equalsIgnoreCase('active?')) break;
                if (inName) nameParts.add(w);
            }
            if (!nameParts.isEmpty()) name = String.join(nameParts, ' ').trim();
        }

        if (String.isBlank(name)) {
            return '⚠️ Format: \"is <ComponentName> active?\"\nExample: \"is My_Flow active\"';
        }

        String nameLower = name.toLowerCase();
        List<String> found = new List<String>();

        // Check Flows
        MetadataEngine.FlowSummary fs = MetadataEngine.getFlows(null);
        if (fs.allFlowObjects != null) {
            for (MetadataEngine.FlowInfo f : fs.allFlowObjects) {
                if ((f.apiName != null && f.apiName.toLowerCase().equals(nameLower)) ||
                    (f.label != null && f.label.toLowerCase().equals(nameLower))) {
                    found.add('🔀 Flow \"' + f.label + '\": ' + (f.isActive ? '✅ ACTIVE' : '⬜ INACTIVE'));
                }
            }
        }

        // Check Triggers
        MetadataEngine.TriggerSummary ts = MetadataEngine.getTriggers(null);
        List<MetadataEngine.TriggerInfo> allT = new List<MetadataEngine.TriggerInfo>();
        if (ts.activeTriggers != null) allT.addAll(ts.activeTriggers);
        if (ts.inactiveTriggers != null) allT.addAll(ts.inactiveTriggers);
        for (MetadataEngine.TriggerInfo t : allT) {
            if (t.name != null && t.name.toLowerCase().equals(nameLower)) {
                found.add('⚡ Trigger \"' + t.name + '\": ' + (t.isActive ? '✅ ACTIVE' : '⬜ INACTIVE'));
            }
        }

        // Check Validation Rules
        MetadataEngine.ValidationRuleSummary vs = MetadataEngine.getValidationRules(null);
        List<MetadataEngine.ValidationRuleInfo> allV = new List<MetadataEngine.ValidationRuleInfo>();
        if (vs.activeRules != null) allV.addAll(vs.activeRules);
        if (vs.inactiveRules != null) allV.addAll(vs.inactiveRules);
        for (MetadataEngine.ValidationRuleInfo v : allV) {
            if (v.name != null && v.name.toLowerCase().equals(nameLower)) {
                found.add('✔️ Validation Rule \"' + v.name + '\": ' + (v.isActive ? '✅ ACTIVE' : '⬜ INACTIVE'));
            }
        }

        if (found.isEmpty()) {
            return '🔍 No flow, trigger, or validation rule found named \"' + name + '\".\nTry \"find anything named ' + name + '\" to search all types.';
        }
        return String.join(found, '\n');
    }

    // ── COMPONENT DETAILS: last modified / line count ─────────
    private static Boolean isComponentDetailIntent(String lower) {
        return lower.contains('last modified') || lower.contains('when was') ||
               lower.contains('how many lines') || lower.contains('line count') ||
               lower.contains('lines in ');
    }

    private static String handleComponentDetail(String originalQuery, String lower) {
        Boolean wantsLines    = lower.contains('how many lines') || lower.contains('line count') || lower.contains('lines in');
        Boolean wantsModified = lower.contains('last modified') || lower.contains('when was');

        // Extract component name — last word-token that looks like a name
        String name = null;
        String[] patterns = new String[]{ 'lines in ', 'when was ', 'last modified of ', 'modified date of ', 'line count of ', 'how many lines in ' };
        for (String p : patterns) {
            if (lower.contains(p)) {
                Integer idx = lower.indexOf(p) + p.length();
                String candidate = originalQuery.substring(idx).replaceFirst('(?i)\\s+(last modified|modified|active|inactive).*$', '').trim();
                if (String.isNotBlank(candidate)) { name = candidate; break; }
            }
        }

        if (String.isBlank(name)) {
            // Fallback: take last token
            List<String> words = originalQuery.trim().split('\\s+');
            name = words[words.size() - 1].replaceAll('[^A-Za-z0-9_]', '');
        }

        if (String.isBlank(name)) {
            return '⚠️ Please specify a component name.\nExamples:\n  • when was MyClass last modified\n  • how many lines in MyClass';
        }

        String nameLower = name.toLowerCase();
        List<String> results = new List<String>();

        // Search Apex Classes
        MetadataEngine.ApexSummary apex = getApexCached(null);
        List<MetadataEngine.ApexClassInfo> allApex = new List<MetadataEngine.ApexClassInfo>();
        if (apex.unusedClasses != null) allApex.addAll(apex.unusedClasses);
        for (MetadataEngine.ApexClassInfo c : allApex) {
            if (c.name != null && c.name.toLowerCase().equals(nameLower)) {
                String info = '⚡ Apex Class: ' + c.name;
                if (wantsLines) info += '\n   Lines of Code: ' + c.linesOfCode;
                if (wantsModified && c.lastModifiedDate != null) info += '\n   Last Modified: ' + c.lastModifiedDate;
                results.add(info);
            }
        }

        // Search Triggers
        MetadataEngine.TriggerSummary ts = MetadataEngine.getTriggers(null);
        List<MetadataEngine.TriggerInfo> allT = new List<MetadataEngine.TriggerInfo>();
        if (ts.activeTriggers != null) allT.addAll(ts.activeTriggers);
        if (ts.inactiveTriggers != null) allT.addAll(ts.inactiveTriggers);
        for (MetadataEngine.TriggerInfo t : allT) {
            if (t.name != null && t.name.toLowerCase().equals(nameLower)) {
                String info = '⚡ Trigger: ' + t.name + ' on ' + t.objectName;
                if (wantsLines) info += '\n   Lines of Code: ' + t.linesOfCode;
                if (wantsModified && t.lastModifiedDate != null) info += '\n   Last Modified: ' + t.lastModifiedDate;
                results.add(info);
            }
        }

        // Search LWC
        MetadataEngine.LwcSummary lwc = MetadataEngine.getLwcComponents(null);
        if (lwc.allComponents != null) {
            for (MetadataEngine.LwcComponentInfo c : lwc.allComponents) {
                if (c.name != null && c.name.toLowerCase().equals(nameLower)) {
                    String info = '🔷 LWC: ' + c.name;
                    if (wantsModified && c.lastModifiedDate != null) info += '\n   Last Modified: ' + c.lastModifiedDate;
                    results.add(info);
                }
            }
        }

        // Search Aura
        MetadataEngine.AuraSummary au = MetadataEngine.getAuraComponents(null);
        if (au.allComponents != null) {
            for (MetadataEngine.AuraComponentInfo c : au.allComponents) {
                if (c.name != null && c.name.toLowerCase().equals(nameLower)) {
                    String info = '🔶 Aura: ' + c.name;
                    if (wantsModified && c.lastModifiedDate != null) info += '\n   Last Modified: ' + c.lastModifiedDate;
                    results.add(info);
                }
            }
        }

        if (results.isEmpty()) {
            return '🔍 No component found named \"' + name + '\".\nTry \"find anything named ' + name + '\" for a broader search.';
        }
        return String.join(results, '\n\n');
    }

    // ── ORG HEALTH CHECK ──────────────────────────────────────
    private static Boolean isOrgHealthIntent(String lower) {
        return lower.contains('org health') || lower.contains('health check') ||
               lower.contains('what should i clean') || lower.contains('cleanup report') ||
               lower.contains('how big is my org') || lower.contains('org size') ||
               lower.contains('org cleanup report') || lower.contains('prioritized recommendations') ||
               lower.contains('what to clean');
    }

    private static String handleOrgHealth() {
        MetadataEngine.FlowSummary          flows  = MetadataEngine.getFlows(null);
        MetadataEngine.ApexSummary          apex   = getApexCached(null);
        MetadataEngine.TriggerSummary       trigs  = MetadataEngine.getTriggers(null);
        MetadataEngine.LwcSummary           lwc    = MetadataEngine.getLwcComponents(null);
        MetadataEngine.AuraSummary          aura   = MetadataEngine.getAuraComponents(null);
        MetadataEngine.ProfileSummary       profs  = MetadataEngine.getProfiles();
        MetadataEngine.PermissionSetSummary perms  = MetadataEngine.getPermissionSets();
        MetadataEngine.ValidationRuleSummary vrs   = MetadataEngine.getValidationRules(null);
        MetadataEngine.CustomFieldSummary   fields = MetadataEngine.getCustomFields(null);
        MetadataEngine.CustomObjectSummary  objs   = MetadataEngine.getCustomObjects(null);

        Integer lwcUnref    = lwc.unreferencedCount  != null ? lwc.unreferencedCount  : 0;
        Integer auraUnref   = aura.unreferencedCount != null ? aura.unreferencedCount : 0;
        Integer emptyFields = fields.emptyCount      != null ? fields.emptyCount      : 0;
        Integer emptyObjs   = objs.emptyCount        != null ? objs.emptyCount        : 0;

        Integer totalIssues = flows.inactive + apex.unused + trigs.inactive + profs.unused + perms.unused + vrs.inactive
                            + lwcUnref + auraUnref + emptyFields + emptyObjs;

        String score = totalIssues == 0 ? '\U0001f7e2 Excellent' : totalIssues <= 5 ? '\U0001f7e1 Good' : totalIssues <= 20 ? '\U0001f7e0 Needs Attention' : '\U0001f534 Cleanup Recommended';

        String resp = '\U0001fa7a ORG HEALTH REPORT\n';
        resp += repeat('\u2550', 40) + '\n\n';
        resp += 'Health Score : ' + score + '\n';
        resp += 'Total issues : ' + totalIssues + '\n\n';

        resp += '\U0001f4ca ORG SIZE SUMMARY\n';
        resp += '  Flows           : ' + flows.total  + ' (' + flows.active + ' active, '  + flows.inactive + ' inactive)\n';
        resp += '  Apex Classes    : ' + apex.total   + ' (' + apex.used   + ' used, '    + apex.unused    + ' unused)\n';
        resp += '  Triggers        : ' + trigs.total  + ' (' + trigs.active + ' active, '  + trigs.inactive + ' inactive)\n';
        resp += '  LWC Components  : ' + lwc.total   + ' (' + lwcUnref     + ' unreferenced)\n';
        resp += '  Aura Components : ' + aura.total  + ' (' + auraUnref    + ' unreferenced)\n';
        resp += '  Profiles        : ' + profs.total + ' (' + profs.used   + ' assigned, ' + profs.unused  + ' unassigned)\n';
        resp += '  Permission Sets : ' + perms.total + ' (' + perms.used   + ' assigned, ' + perms.unused  + ' unassigned)\n';
        resp += '  Custom Fields   : ' + fields.total + ' (' + emptyFields + ' with no data)\n';
        resp += '  Custom Objects  : ' + objs.total  + ' (' + emptyObjs   + ' with 0 records)\n';
        resp += '  Validation Rules: ' + vrs.total   + ' (' + vrs.active  + ' active, '   + vrs.inactive  + ' inactive)\n\n';

        if (totalIssues == 0) {
            resp += '\u2705 Your org looks clean! No immediate cleanup needed.\n';
            return resp;
        }

        resp += '\U0001f5d1\ufe0f PRIORITIZED CLEANUP RECOMMENDATIONS\n';
        resp += repeat('\u2500', 40) + '\n\n';

        Integer priority = 1;

        if (apex.unused > 0) {
            resp += priority++ + '. [HIGH] ' + apex.unused + ' unused Apex class(es)\n';
            resp += '   \u2192 Type \"show unused apex classes\" to review\n';
            resp += '   \u2192 Type \"delete apex class <Name>\" to remove\n\n';
        }
        if (flows.inactive > 0) {
            resp += priority++ + '. [HIGH] ' + flows.inactive + ' inactive flow(s)\n';
            resp += '   \u2192 Type \"show inactive flows\" to review\n';
            resp += '   \u2192 Type \"delete flow <ApiName>\" to remove\n\n';
        }
        if (emptyObjs > 0) {
            resp += priority++ + '. [HIGH] ' + emptyObjs + ' custom object(s) with 0 records\n';
            resp += '   \u2192 Type \"show empty objects\" to review\n';
            resp += '   \u2192 Type \"delete custom object <Name>\" to remove\n\n';
        }
        if (emptyFields > 0) {
            resp += priority++ + '. [MEDIUM] ' + emptyFields + ' custom field(s) with no data\n';
            resp += '   \u2192 Type \"show fields with no data\" to review\n';
            resp += '   \u2192 Type \"delete field Object.FieldName\" to remove\n\n';
        }
        if (lwcUnref > 0) {
            resp += priority++ + '. [MEDIUM] ' + lwcUnref + ' unreferenced LWC component(s)\n';
            resp += '   \u2192 Type \"show unreferenced lwc\" to review\n';
            resp += '   \u2192 Type \"delete lwc <ComponentName>\" to remove\n\n';
        }
        if (auraUnref > 0) {
            resp += priority++ + '. [MEDIUM] ' + auraUnref + ' unreferenced Aura component(s)\n';
            resp += '   \u2192 Type \"show unreferenced aura\" to review\n';
            resp += '   \u2192 Type \"delete aura <ComponentName>\" to remove\n\n';
        }
        if (trigs.inactive > 0) {
            resp += priority++ + '. [MEDIUM] ' + trigs.inactive + ' inactive trigger(s)\n';
            resp += '   \u2192 Type \"show inactive triggers\" to review\n\n';
        }
        if (profs.unused > 0) {
            resp += priority++ + '. [MEDIUM] ' + profs.unused + ' unassigned profile(s)\n';
            resp += '   \u2192 Type \"show unassigned profiles\" to review\n\n';
        }
        if (perms.unused > 0) {
            resp += priority++ + '. [LOW] ' + perms.unused + ' unassigned permission set(s)\n';
            resp += '   \u2192 Type \"show unassigned permission sets\" to review\n\n';
        }
        if (vrs.inactive > 0) {
            resp += priority++ + '. [LOW] ' + vrs.inactive + ' inactive validation rule(s)\n';
            resp += '   \u2192 Type \"show inactive validation rules\" to review\n\n';
        }

        return resp;
    }
    // ── SHARED UTILITY: extract object name from query ────────
    private static String extractObjectNameFromQuery(String originalQuery, String lower) {
        // Patterns: "fields on Account", "what fields does Account have", "fields of Account", "fields for Account"
        List<String> words = originalQuery.trim().split('\\s+');
        String[] prepositions = new String[]{ 'on', 'does', 'of', 'for' };
        for (String prep : prepositions) {
            for (Integer i = 0; i < words.size(); i++) {
                if (words[i].equalsIgnoreCase(prep) && i + 1 < words.size()) {
                    String candidate = words[i + 1].replaceAll('[^A-Za-z0-9_]', '');
                    if (String.isNotBlank(candidate) && candidate.length() > 1) {
                        return candidate;
                    }
                }
            }
        }
        return null;
    }
}