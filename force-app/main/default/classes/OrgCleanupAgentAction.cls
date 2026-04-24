/**
 * OrgCleanupAgentAction
 *
 * Backend for the LWC Org Cleanup Agent panel.
 * Receives a plain-English query from the LWC, parses intent,
 * delegates to the appropriate MetadataEngine method, and
 * returns a human-readable text response.
 *
 * Called by: metadataDashboard LWC (handleAgentQuery import)
 */
@SuppressWarnings('PMD.NcssMethodCount,PMD.ExcessiveClassLength,PMD.CognitiveComplexity,PMD.IfStmtsMustUseBraces,PMD.IfElseStmtsMustUseBraces')
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
    private static final String TYPE_UNKNOWN = 'unknown';

    // ── LWC entry point ───────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static String handleAgentQuery(String userQuery) {
        if (String.isBlank(userQuery)) {
            return 'Please ask me something about your org.';
        }
        try {
            String lower        = userQuery.toLowerCase();
            String detectedType = detectType(lower);
            String ns           = extractNamespace(userQuery);
            return dispatchQuery(detectedType, lower, ns);
        } catch (Exception ex) {
            System.debug(
                'OrgCleanupAgentAction error: ' + ex.getMessage()
                + '\n' + ex.getStackTraceString()
            );
            return 'Sorry, I encountered an error: ' + ex.getMessage();
        }
    }

    // ── Type detection ✅ FIXED — more keywords covered ───────
    @TestVisible
    private static String detectType(String lower) {
        String result = TYPE_UNKNOWN;

        if (lower.contains('flow')) {
            result = TYPE_FLOW;

        } else if (lower.contains('apex') || lower.contains('class')) {
            result = TYPE_APEX;

        } else if (lower.contains('trigger')) {
            result = TYPE_TRIGGER;

        } else if (lower.contains('lwc') || lower.contains('lightning web component')
                || lower.contains('lightning component')) {
            result = TYPE_LWC;

        } else if (lower.contains('aura')) {
            result = TYPE_AURA;

        } else if (lower.contains('profile')) {
            result = TYPE_PROFILE;

        } else if (lower.contains('permission set') || lower.contains('perm set')
                || lower.contains('permset') || lower.contains('permission')) {
            result = TYPE_PERMSET;

        } else if (lower.contains('validation') || lower.contains('val rule')
                || lower.contains('validation rule') || lower.contains('rules')) {
            // ✅ FIX: Check VR before FIELD/OBJECT so "rules" doesn't fall through
            result = TYPE_VR;

        } else if (lower.contains('field')) {
            result = TYPE_FIELD;

        } else if (lower.contains('object') || lower.contains('custom object')
                || lower.contains('sobject')) {
            result = TYPE_OBJECT;

        }

        return result;
    }

    // ── Dispatch to the correct MetadataEngine method ─────────
    private static String dispatchQuery(String detectedType, String lower, String ns) {
        String response;
        if (detectedType == TYPE_FLOW) {
            response = buildFlowResponse(MetadataEngine.getFlows(ns), lower, ns);
        } else if (detectedType == TYPE_APEX) {
            response = buildApexResponse(MetadataEngine.getApexClasses(ns), lower, ns);
        } else if (detectedType == TYPE_TRIGGER) {
            response = buildTriggerResponse(MetadataEngine.getTriggers(ns), lower, ns);
        } else if (detectedType == TYPE_LWC) {
            response = buildLwcResponse(MetadataEngine.getLwcComponents(ns), lower, ns);
        } else if (detectedType == TYPE_AURA) {
            response = buildAuraResponse(MetadataEngine.getAuraComponents(ns), lower, ns);
        } else if (detectedType == TYPE_PROFILE) {
            response = buildProfileResponse(MetadataEngine.getProfiles(), lower);
        } else if (detectedType == TYPE_PERMSET) {
            response = buildPermSetResponse(MetadataEngine.getPermissionSets(), lower);
        } else if (detectedType == TYPE_FIELD) {
            response = buildFieldResponse(MetadataEngine.getCustomFields(ns), lower, ns);
        } else if (detectedType == TYPE_OBJECT) {
            response = buildObjectResponse(MetadataEngine.getCustomObjects(ns), lower, ns);
        } else if (detectedType == TYPE_VR) {
            response = buildVrResponse(MetadataEngine.getValidationRules(ns), lower, ns);
        } else {
            response = 'I can help with: Flows, Apex Classes, Triggers, LWC, Aura, Profiles, '
                     + 'Permission Sets, Custom Fields, Custom Objects, and Validation Rules.\n\n'
                     + 'Try asking:\n'
                     + '  • "show all flows"\n'
                     + '  • "show unused apex classes"\n'
                     + '  • "find all custom fields"\n'
                     + '  • "show inactive validation rules"\n'
                     + '  • "list triggers"\n'
                     + '  • "show profiles"\n'
                     + '  • "find permission sets"';
        }
        return response;
    }

    // ── Namespace extractor ───────────────────────────────────
    private static String extractNamespace(String query) {
        Set<String> stopWords = new Set<String>{
            'the','all','show','list','get','find','unused','inactive',
            'active','my','our','this','that','class','apex','flow',
            'trigger','lwc','aura','rules','rule','fields','field',
            'objects','object','profiles','profile','permission','sets'
        };

        Pattern p1 = Pattern.compile(
            '(?i)(?:in|for|namespace|belonging to|from)\\s+([A-Za-z0-9_]+)\\s*(?:namespace|app|application)?'
        );
        Matcher m1 = p1.matcher(query);
        if (m1.find()) {
            String candidate = m1.group(1);
            if (!stopWords.contains(candidate.toLowerCase())) {
                return candidate;
            }
        }

        Pattern p2 = Pattern.compile(
            '(?i)([A-Za-z0-9_]+)\\s+(?:namespace|app|application)'
        );
        Matcher m2 = p2.matcher(query);
        if (m2.find()) {
            String candidate = m2.group(1);
            if (!stopWords.contains(candidate.toLowerCase())) {
                return candidate;
            }
        }

        return null;
    }

    // =========================================================
    // RESPONSE BUILDERS  ✅ ALL FIXED
    // Every builder now always returns a useful answer,
    // whether or not a namespace / keyword filter is given.
    // =========================================================

    // ── Flows ─────────────────────────────────────────────────
    private static String buildFlowResponse(MetadataEngine.FlowSummary s, String lower, String ns) {
        String resp = 'Here are all the flows in your org. Want details on a specific flow or want me to filter by a specific namespace or process type?\n'
                    + 'This org has ' + s.total + ' flow(s) in total. '
                    + s.active + ' are active, ' + s.inactive + ' are inactive.\n\n';

        if (String.isNotBlank(ns)) {
            resp += 'Namespace Filter: ' + ns + ' (showing ' + s.filteredTotal + ' matching)\n\n';
            if (s.filteredActiveFlows != null && !s.filteredActiveFlows.isEmpty()) {
                resp += '--- ACTIVE (' + s.filteredActiveFlows.size() + ') ---\n';
                for (String f : s.filteredActiveFlows)  resp += '  * ' + f + '\n';
            }
            if (s.filteredInactiveFlows != null && !s.filteredInactiveFlows.isEmpty()) {
                resp += '--- INACTIVE (' + s.filteredInactiveFlows.size() + ') ---\n';
                for (String f : s.filteredInactiveFlows) resp += '  - ' + f + '\n';
            }
            if (s.filteredTotal == 0) resp += '  No flows found for namespace "' + ns + '".\n';

        } else if (lower.contains('inactive') || lower.contains('unused')) {
            resp += '--- INACTIVE FLOWS (' + s.inactive + ') ---\n';
            if (s.inactiveFlows != null && !s.inactiveFlows.isEmpty()) {
                for (String f : s.inactiveFlows) resp += '  - ' + f + '\n';
            } else {
                resp += '  None found.\n';
            }

        } else if (lower.contains('active')) {
            resp += '--- ACTIVE FLOWS (' + s.active + ') ---\n';
            if (s.activeFlows != null && !s.activeFlows.isEmpty()) {
                Integer shown = 0;
                for (String f : s.activeFlows) {
                    if (shown >= 20) { resp += '  ... and ' + (s.active - 20) + ' more.\n'; break; }
                    resp += '  * ' + f + '\n';
                    shown++;
                }
            }

        } else {
            // ✅ FIX: Always show full list split by active/inactive
            if (s.activeFlows != null && !s.activeFlows.isEmpty()) {
                resp += '--- ACTIVE (' + s.active + ') ---\n';
                Integer shown = 0;
                for (String f : s.activeFlows) {
                    if (shown >= 20) { resp += '  ... and ' + (s.active - 20) + ' more.\n'; break; }
                    resp += '  * ' + f + '\n';
                    shown++;
                }
            }
            if (s.inactiveFlows != null && !s.inactiveFlows.isEmpty()) {
                resp += '\n--- INACTIVE (' + s.inactive + ') ---\n';
                for (String f : s.inactiveFlows) resp += '  - ' + f + '\n';
            }
        }
        return resp;
    }

    // ── Apex Classes ──────────────────────────────────────────
    private static String buildApexResponse(MetadataEngine.ApexSummary s, String lower, String ns) {
        String resp = 'Here are the Apex classes in your org. Want details on a specific class or want me to filter by namespace?\n'
                    + 'This org has ' + s.total + ' Apex class(es) in total. '
                    + s.used + ' used, ' + s.unused + ' unused, '
                    + s.testCount + ' test, ' + s.standard + ' standard/package.\n\n';

        if (String.isNotBlank(ns)) {
            resp += 'Namespace Filter: ' + ns + ' (' + s.filteredTotal + ' matching)\n';
            if (s.filteredClasses != null && !s.filteredClasses.isEmpty()) {
                for (MetadataEngine.ApexClassInfo c : s.filteredClasses)
                    resp += '  * ' + c.name + '\n';
            } else {
                resp += '  No classes found for namespace "' + ns + '".\n';
            }

        } else if (lower.contains('unused')) {
            resp += '--- UNUSED CLASSES (' + s.unused + ') ---\n';
            if (s.unusedClasses != null && !s.unusedClasses.isEmpty()) {
                for (MetadataEngine.ApexClassInfo c : s.unusedClasses)
                    resp += '  - ' + c.name + ' (' + c.linesOfCode + ' lines, modified ' + c.lastModifiedDate + ')\n';
            } else {
                resp += '  No unused classes found.\n';
            }

        } else if (lower.contains('used')) {
            resp += '--- USED CLASSES (' + s.used + ') ---\n';
            if (s.usedClassNames != null && !s.usedClassNames.isEmpty()) {
                for (String n : s.usedClassNames) resp += '  * ' + n + '\n';
            }

        } else if (lower.contains('test')) {
            resp += '--- TEST CLASSES (' + s.testCount + ') ---\n';
            if (s.testClassNames != null && !s.testClassNames.isEmpty()) {
                for (String n : s.testClassNames) resp += '  * ' + n + '\n';
            }

        } else {
            // ✅ FIX: Always show all categories
            if (s.unusedClasses != null && !s.unusedClasses.isEmpty()) {
                resp += '--- UNUSED (' + s.unused + ') ---\n';
                for (MetadataEngine.ApexClassInfo c : s.unusedClasses)
                    resp += '  - ' + c.name + ' (' + c.linesOfCode + ' lines)\n';
            }
            if (s.usedClassNames != null && !s.usedClassNames.isEmpty()) {
                resp += '\n--- USED (' + s.used + ') ---\n';
                Integer shown = 0;
                for (String n : s.usedClassNames) {
                    if (shown >= 20) { resp += '  ... and ' + (s.used - 20) + ' more.\n'; break; }
                    resp += '  * ' + n + '\n';
                    shown++;
                }
            }
            if (s.testClassNames != null && !s.testClassNames.isEmpty()) {
                resp += '\n--- TEST (' + s.testCount + ') ---\n';
                for (String n : s.testClassNames) resp += '  * ' + n + '\n';
            }
        }
        return resp;
    }

    // ── Triggers ──────────────────────────────────────────────
    private static String buildTriggerResponse(MetadataEngine.TriggerSummary s, String lower, String ns) {
        String resp = 'Here are the triggers in your org.\n'
                    + 'This org has ' + s.total + ' trigger(s) — '
                    + s.active + ' active, ' + s.inactive + ' inactive, '
                    + s.unused + ' unused.\n\n';

        if (String.isNotBlank(ns)) {
            resp += 'Namespace Filter: ' + ns + ' (' + s.filteredTotal + ' matching)\n';
            if (s.filteredTriggers != null && !s.filteredTriggers.isEmpty()) {
                for (MetadataEngine.TriggerInfo t : s.filteredTriggers)
                    resp += '  * ' + t.name + ' on ' + t.objectName + '\n';
            } else {
                resp += '  No triggers found for namespace "' + ns + '".\n';
            }

        } else if (lower.contains('unused') || lower.contains('inactive')) {
            resp += '--- UNUSED / INACTIVE (' + s.unusedTriggers.size() + ') ---\n';
            if (!s.unusedTriggers.isEmpty()) {
                for (MetadataEngine.TriggerInfo t : s.unusedTriggers)
                    resp += '  - ' + t.name + ' on ' + t.objectName
                          + ' (' + (t.isActive ? 'active' : 'inactive') + ')\n';
            } else {
                resp += '  None found.\n';
            }

        } else if (lower.contains('active')) {
            resp += '--- ACTIVE (' + s.activeTriggers.size() + ') ---\n';
            if (!s.activeTriggers.isEmpty()) {
                for (MetadataEngine.TriggerInfo t : s.activeTriggers)
                    resp += '  * ' + t.name + ' on ' + t.objectName + '\n';
            }

        } else {
            // ✅ FIX: Always show full breakdown
            if (!s.activeTriggers.isEmpty()) {
                resp += '--- ACTIVE (' + s.active + ') ---\n';
                for (MetadataEngine.TriggerInfo t : s.activeTriggers)
                    resp += '  * ' + t.name + ' on ' + t.objectName + '\n';
            }
            if (!s.inactiveTriggers.isEmpty()) {
                resp += '\n--- INACTIVE (' + s.inactive + ') ---\n';
                for (MetadataEngine.TriggerInfo t : s.inactiveTriggers)
                    resp += '  - ' + t.name + ' on ' + t.objectName + '\n';
            }
            if (!s.unusedTriggers.isEmpty()) {
                resp += '\n--- UNUSED (' + s.unused + ') ---\n';
                for (MetadataEngine.TriggerInfo t : s.unusedTriggers)
                    resp += '  - ' + t.name + ' on ' + t.objectName + '\n';
            }
            if (s.usedTriggerNames != null && !s.usedTriggerNames.isEmpty()) {
                resp += '\n--- USED (' + s.used + ') ---\n';
                for (String n : s.usedTriggerNames) resp += '  * ' + n + '\n';
            }
        }
        return resp;
    }

    // ── LWC ───────────────────────────────────────────────────
    private static String buildLwcResponse(MetadataEngine.LwcSummary s, String lower, String ns) {
        String resp = 'Here are the LWC components in your org.\n'
                    + 'This org has ' + s.total + ' LWC component(s) — '
                    + s.withNamespace + ' with namespace, ' + s.withoutNamespace + ' without.\n\n';

        if (String.isNotBlank(ns)) {
            resp += 'Namespace Filter: ' + ns + ' (' + s.filteredComponents.size() + ' matching)\n';
            if (s.filteredComponents != null && !s.filteredComponents.isEmpty()) {
                for (MetadataEngine.LwcComponentInfo c : s.filteredComponents)
                    resp += '  * ' + c.name + ' (v' + c.apiVersion + ')\n';
            } else {
                resp += '  No LWC found for namespace "' + ns + '".\n';
            }

        } else {
            // ✅ FIX: Always show full list
            resp += '--- ALL LWC COMPONENTS (' + s.total + ') ---\n';
            if (s.allComponents != null && !s.allComponents.isEmpty()) {
                Integer shown = 0;
                for (MetadataEngine.LwcComponentInfo c : s.allComponents) {
                    if (shown >= 30) { resp += '  ... and ' + (s.total - 30) + ' more.\n'; break; }
                    resp += '  * ' + c.name
                          + (String.isNotBlank(c.namespacePrefix) ? ' [ns:' + c.namespacePrefix + ']' : '')
                          + '\n';
                    shown++;
                }
            } else {
                resp += '  None found.\n';
            }
        }
        return resp;
    }

    // ── Aura ──────────────────────────────────────────────────
    private static String buildAuraResponse(MetadataEngine.AuraSummary s, String lower, String ns) {
        String resp = 'Here are the Aura components in your org.\n'
                    + 'This org has ' + s.total + ' Aura component(s) — '
                    + s.withNamespace + ' with namespace, ' + s.withoutNamespace + ' without.\n\n';

        if (String.isNotBlank(ns)) {
            resp += 'Namespace Filter: ' + ns + ' (' + s.filteredComponents.size() + ' matching)\n';
            if (s.filteredComponents != null && !s.filteredComponents.isEmpty()) {
                for (MetadataEngine.AuraComponentInfo c : s.filteredComponents)
                    resp += '  * ' + c.name + ' (v' + c.apiVersion + ')\n';
            } else {
                resp += '  No Aura components found for namespace "' + ns + '".\n';
            }

        } else {
            // ✅ FIX: Always show full list
            resp += '--- ALL AURA COMPONENTS (' + s.total + ') ---\n';
            if (s.allComponents != null && !s.allComponents.isEmpty()) {
                Integer shown = 0;
                for (MetadataEngine.AuraComponentInfo c : s.allComponents) {
                    if (shown >= 30) { resp += '  ... and ' + (s.total - 30) + ' more.\n'; break; }
                    resp += '  * ' + c.name
                          + (String.isNotBlank(c.namespacePrefix) ? ' [ns:' + c.namespacePrefix + ']' : '')
                          + '\n';
                    shown++;
                }
            } else {
                resp += '  None found.\n';
            }
        }
        return resp;
    }

    // ── Profiles ──────────────────────────────────────────────
    private static String buildProfileResponse(MetadataEngine.ProfileSummary s, String lower) {
        String resp = 'Here are all the profiles in your org. Want details on a specific profile?\n'
                    + 'This org has ' + s.total + ' Profile(s) — '
                    + s.used + ' assigned, ' + s.unused + ' unassigned.\n\n';

        if (lower.contains('unassigned') || lower.contains('unused')) {
            resp += '--- UNASSIGNED PROFILES (' + s.unused + ') ---\n';
            if (!s.unusedProfiles.isEmpty()) {
                for (MetadataEngine.ProfileInfo p : s.unusedProfiles)
                    resp += '  - ' + p.name + ' [' + p.userLicenseName + ']\n';
            } else {
                resp += '  All profiles have active users assigned.\n';
            }

        } else if (lower.contains('assigned') || lower.contains('used')) {
            resp += '--- ASSIGNED PROFILES (' + s.used + ') ---\n';
            if (!s.usedProfiles.isEmpty()) {
                for (MetadataEngine.ProfileInfo p : s.usedProfiles)
                    resp += '  * ' + p.name + ' (' + p.assignedUserCount + ' users) [' + p.userLicenseName + ']\n';
            }

        } else {
            // ✅ FIX: Always show all profiles split by assigned/unassigned
            if (!s.usedProfiles.isEmpty()) {
                resp += '--- ASSIGNED (' + s.used + ') ---\n';
                for (MetadataEngine.ProfileInfo p : s.usedProfiles)
                    resp += '  * ' + p.name + ' (' + p.assignedUserCount + ' users)\n';
            }
            if (!s.unusedProfiles.isEmpty()) {
                resp += '\n--- UNASSIGNED (' + s.unused + ') ---\n';
                for (MetadataEngine.ProfileInfo p : s.unusedProfiles)
                    resp += '  - ' + p.name + ' [' + p.userLicenseName + ']\n';
            }
        }
        return resp;
    }

    // ── Permission Sets ───────────────────────────────────────
    private static String buildPermSetResponse(MetadataEngine.PermissionSetSummary s, String lower) {
        String resp = 'Here are all the permission sets in your org.\n'
                    + 'This org has ' + s.total + ' Permission Set(s) — '
                    + s.used + ' assigned, ' + s.unused + ' unassigned.\n\n';

        if (lower.contains('unassigned') || lower.contains('unused')) {
            resp += '--- UNASSIGNED PERMISSION SETS (' + s.unused + ') ---\n';
            if (!s.unusedPermSets.isEmpty()) {
                for (MetadataEngine.PermissionSetInfo p : s.unusedPermSets)
                    resp += '  - ' + p.label + ' (' + p.name + ')'
                          + (String.isNotBlank(p.namespacePrefix) ? ' [ns:' + p.namespacePrefix + ']' : '') + '\n';
            } else {
                resp += '  All permission sets have assignments.\n';
            }

        } else if (lower.contains('assigned') || lower.contains('used')) {
            resp += '--- ASSIGNED PERMISSION SETS (' + s.used + ') ---\n';
            if (!s.usedPermSets.isEmpty()) {
                for (MetadataEngine.PermissionSetInfo p : s.usedPermSets)
                    resp += '  * ' + p.label + ' (' + p.assignmentCount + ' assignments)\n';
            }

        } else {
            // ✅ FIX: Always show all permission sets
            if (!s.usedPermSets.isEmpty()) {
                resp += '--- ASSIGNED (' + s.used + ') ---\n';
                for (MetadataEngine.PermissionSetInfo p : s.usedPermSets)
                    resp += '  * ' + p.label + ' (' + p.assignmentCount + ' assignments)\n';
            }
            if (!s.unusedPermSets.isEmpty()) {
                resp += '\n--- UNASSIGNED (' + s.unused + ') ---\n';
                for (MetadataEngine.PermissionSetInfo p : s.unusedPermSets)
                    resp += '  - ' + p.label
                          + (String.isNotBlank(p.namespacePrefix) ? ' [ns:' + p.namespacePrefix + ']' : '') + '\n';
            }
        }
        return resp;
    }

    // ── Custom Fields ─────────────────────────────────────────
    private static String buildFieldResponse(MetadataEngine.CustomFieldSummary s, String lower, String ns) {
        String resp = 'Here are all the custom fields in your org. Want details on a specific field or want me to filter by a specific namespace or application?\n'
                    + 'This org has ' + s.total + ' custom field(s) in total. '
                    + s.withNamespace + ' have a namespace prefix, '
                    + s.withoutNamespace + ' do not.\n\n';

        if (String.isNotBlank(ns)) {
            resp += 'Namespace Filter: ' + ns + ' (showing ' + s.filteredFields.size() + ')\n\n';
            if (s.filteredFields != null && !s.filteredFields.isEmpty()) {
                resp += '--- MATCHING FIELDS (' + s.filteredFields.size() + ') ---\n';
                for (MetadataEngine.CustomFieldInfo f : s.filteredFields)
                    resp += '  * ' + f.name + ' on ' + f.objectName + '\n';
            } else {
                resp += '  No fields found for namespace "' + ns + '".\n';
            }

        } else {
            // ✅ FIX: Always show all fields (capped at 30 for readability)
            resp += 'Namespace Filter: None (showing all)\n';
            resp += 'Matching Fields: ' + s.total + '\n\n';
            if (s.allFields != null && !s.allFields.isEmpty()) {
                resp += '--- ALL CUSTOM FIELDS (' + s.total + ') ---\n';
                Integer shown = 0;
                for (MetadataEngine.CustomFieldInfo f : s.allFields) {
                    if (shown >= 30) {
                        resp += '  ... and ' + (s.total - 30) + ' more. Use namespace filter to narrow results.\n';
                        break;
                    }
                    resp += '  * ' + f.name + ' on ' + f.objectName
                          + (String.isNotBlank(f.namespacePrefix) ? ' [ns:' + f.namespacePrefix + ']' : '')
                          + '\n';
                    shown++;
                }
            } else {
                resp += '--- ALL CUSTOM FIELDS (0) ---\n  None found.\n';
            }
        }
        return resp;
    }

    // ── Custom Objects ────────────────────────────────────────
    private static String buildObjectResponse(MetadataEngine.CustomObjectSummary s, String lower, String ns) {
        String resp = 'Here are all the custom objects in your org.\n'
                    + 'This org has ' + s.total + ' custom object(s) — '
                    + s.withNamespace + ' with namespace, ' + s.withoutNamespace + ' without.\n\n';

        if (String.isNotBlank(ns)) {
            resp += 'Namespace Filter: ' + ns + ' (' + s.filteredObjects.size() + ' matching)\n';
            if (s.filteredObjects != null && !s.filteredObjects.isEmpty()) {
                for (MetadataEngine.CustomObjectInfo o : s.filteredObjects)
                    resp += '  * ' + o.name + '__c'
                          + (String.isNotBlank(o.namespacePrefix) ? ' [ns:' + o.namespacePrefix + ']' : '')
                          + '\n';
            } else {
                resp += '  No objects found for namespace "' + ns + '".\n';
            }

        } else {
            // ✅ FIX: Always show full list
            resp += '--- ALL CUSTOM OBJECTS (' + s.total + ') ---\n';
            if (s.allObjects != null && !s.allObjects.isEmpty()) {
                for (MetadataEngine.CustomObjectInfo o : s.allObjects)
                    resp += '  * ' + o.name + '__c'
                          + (String.isNotBlank(o.namespacePrefix) ? ' [ns:' + o.namespacePrefix + ']' : '')
                          + '\n';
            } else {
                resp += '  None found.\n';
            }
        }
        return resp;
    }

    // ── Validation Rules ──────────────────────────────────────
    private static String buildVrResponse(MetadataEngine.ValidationRuleSummary s, String lower, String ns) {
        String resp = 'Here are all the validation rules in your org. Want details on a specific rule or want me to filter by object or namespace?\n'
                    + 'This org has ' + s.total + ' Validation Rule(s) — '
                    + s.active + ' active, ' + s.inactive + ' inactive.\n\n';

        if (String.isNotBlank(ns)) {
            resp += 'Namespace Filter: ' + ns + ' (' + s.filteredRules.size() + ' matching)\n';
            if (s.filteredRules != null && !s.filteredRules.isEmpty()) {
                for (MetadataEngine.ValidationRuleInfo v : s.filteredRules)
                    resp += '  ' + (v.isActive ? '*' : '-') + ' '
                          + v.objectName + '.' + v.name
                          + ' (' + (v.isActive ? 'active' : 'inactive') + ')\n';
            } else {
                resp += '  No rules found for namespace "' + ns + '".\n';
            }

        } else if (lower.contains('inactive') || lower.contains('unused')) {
            resp += '--- INACTIVE RULES (' + s.inactive + ') ---\n';
            if (s.inactiveRules != null && !s.inactiveRules.isEmpty()) {
                for (MetadataEngine.ValidationRuleInfo v : s.inactiveRules)
                    resp += '  - ' + v.objectName + '.' + v.name + '\n';
            } else {
                resp += '  None found.\n';
            }

        } else if (lower.contains('active')) {
            resp += '--- ACTIVE RULES (' + s.active + ') ---\n';
            if (s.activeRules != null && !s.activeRules.isEmpty()) {
                for (MetadataEngine.ValidationRuleInfo v : s.activeRules)
                    resp += '  * ' + v.objectName + '.' + v.name + '\n';
            } else {
                resp += '  None found.\n';
            }

        } else {
            // ✅ FIX: Always show both active and inactive
            if (s.activeRules != null && !s.activeRules.isEmpty()) {
                resp += '--- ACTIVE RULES (' + s.active + ') ---\n';
                Integer shown = 0;
                for (MetadataEngine.ValidationRuleInfo v : s.activeRules) {
                    if (shown >= 20) { resp += '  ... and ' + (s.active - 20) + ' more.\n'; break; }
                    resp += '  * ' + v.objectName + '.' + v.name + '\n';
                    shown++;
                }
            }
            if (s.inactiveRules != null && !s.inactiveRules.isEmpty()) {
                resp += '\n--- INACTIVE RULES (' + s.inactive + ') ---\n';
                for (MetadataEngine.ValidationRuleInfo v : s.inactiveRules)
                    resp += '  - ' + v.objectName + '.' + v.name + '\n';
            }
        }
        return resp;
    }
}