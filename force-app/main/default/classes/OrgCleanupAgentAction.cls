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

    // ── Type detection ────────────────────────────────────────
    @TestVisible
    private static String detectType(String lower) {
        String result = TYPE_UNKNOWN;
        if (lower.contains('flow')) {
            result = TYPE_FLOW;
        } else if (lower.contains('apex') || lower.contains('class')) {
            result = TYPE_APEX;
        } else if (lower.contains('trigger')) {
            result = TYPE_TRIGGER;
        } else if (lower.contains('lwc') || lower.contains('lightning web component')) {
            result = TYPE_LWC;
        } else if (lower.contains('aura')) {
            result = TYPE_AURA;
        } else if (lower.contains('profile')) {
            result = TYPE_PROFILE;
        } else if (lower.contains('permission set') || lower.contains('perm set') || lower.contains('permset')) {
            result = TYPE_PERMSET;
        } else if (lower.contains('field')) {
            result = TYPE_FIELD;
        } else if (lower.contains('object')) {
            result = TYPE_OBJECT;
        } else if (lower.contains('validation') || lower.contains('val rule')) {
            result = TYPE_VR;
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
            response = buildLwcResponse(MetadataEngine.getLwcComponents(ns), ns);
        } else if (detectedType == TYPE_AURA) {
            response = buildAuraResponse(MetadataEngine.getAuraComponents(ns), ns);
        } else if (detectedType == TYPE_PROFILE) {
            response = buildProfileResponse(MetadataEngine.getProfiles(), lower);
        } else if (detectedType == TYPE_PERMSET) {
            response = buildPermSetResponse(MetadataEngine.getPermissionSets(), lower);
        } else if (detectedType == TYPE_FIELD) {
            response = buildFieldResponse(MetadataEngine.getCustomFields(ns), ns);
        } else if (detectedType == TYPE_OBJECT) {
            response = buildObjectResponse(MetadataEngine.getCustomObjects(ns), ns);
        } else if (detectedType == TYPE_VR) {
            response = buildVrResponse(MetadataEngine.getValidationRules(ns), lower, ns);
        } else {
            response = 'I can help with: Flows, Apex Classes, Triggers, LWC, Aura, Profiles, '
                     + 'Permission Sets, Custom Fields, Custom Objects, and Validation Rules. '
                     + 'Try asking: "Show unused Apex classes" or "List flows in ITSMS namespace".';
        }
        return response;
    }

    // ── Namespace extractor ───────────────────────────────────
    private static String extractNamespace(String query) {
        Set<String> stopWords = new Set<String>{
            'the','all','show','list','get','find','unused','inactive',
            'active','my','our','this','that','class','apex','flow',
            'trigger','lwc','aura'
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

    // ── Response builders ─────────────────────────────────────

    private static String buildFlowResponse(MetadataEngine.FlowSummary s, String lower, String ns) {
        String resp = 'Your org has ' + s.total + ' Flow(s) total — '
                    + s.active + ' active, ' + s.inactive + ' inactive.\n\n';

        if (String.isNotBlank(ns) && s.filteredTotal != null && s.filteredTotal > 0) {
            resp += 'Namespace "' + ns + '" — ' + s.filteredTotal + ' flow(s):\n';
            if (s.filteredActiveFlows != null) {
                for (String f : s.filteredActiveFlows) {
                    resp += '  * ' + f + '\n';
                }
            }
            if (s.filteredInactiveFlows != null) {
                for (String f : s.filteredInactiveFlows) {
                    resp += '  - ' + f + ' (inactive)\n';
                }
            }
        } else if (lower.contains('inactive') || lower.contains('unused')) {
            resp += 'Inactive flows (' + s.inactive + ') — candidates for cleanup:\n';
            if (s.inactiveFlows != null && !s.inactiveFlows.isEmpty()) {
                for (String f : s.inactiveFlows) {
                    resp += '  - ' + f + '\n';
                }
            } else {
                resp += '  None found.\n';
            }
        } else if (lower.contains('active')) {
            resp += 'Active flows (' + s.active + '):\n';
            if (s.activeFlows != null && !s.activeFlows.isEmpty()) {
                Integer shown = 0;
                for (String f : s.activeFlows) {
                    if (shown >= 10) {
                        resp += '  and ' + (s.active - 10) + ' more.\n';
                        break;
                    }
                    resp += '  * ' + f + '\n';
                    shown++;
                }
            }
        } else {
            resp += 'Use the Flows tab to see the full list. '
                  + 'You can also ask "show inactive flows" or "show flows in <namespace>".';
        }
        return resp;
    }

    private static String buildApexResponse(MetadataEngine.ApexSummary s, String lower, String ns) {
        String resp = 'Your org has ' + s.total + ' Apex class(es) — '
                    + s.used + ' used, ' + s.unused + ' unused, '
                    + s.testCount + ' test, ' + s.standard + ' standard/package.\n\n';

        if (String.isNotBlank(ns) && s.filteredTotal != null && s.filteredTotal > 0) {
            resp += 'Namespace "' + ns + '" — ' + s.filteredTotal + ' class(es):\n';
            if (s.filteredClasses != null) {
                for (MetadataEngine.ApexClassInfo c : s.filteredClasses) {
                    resp += '  * ' + c.name + '\n';
                }
            }
        } else if (lower.contains('unused')) {
            resp += 'Unused Apex classes (' + s.unused + ') — safe to review:\n';
            if (s.unusedClasses != null && !s.unusedClasses.isEmpty()) {
                for (MetadataEngine.ApexClassInfo c : s.unusedClasses) {
                    resp += '  - ' + c.name
                          + ' (' + c.linesOfCode + ' lines, modified ' + c.lastModifiedDate + ')\n';
                }
            } else {
                resp += '  No unused classes found.\n';
            }
        } else {
            resp += 'Use the Apex tab to browse all categories. '
                  + 'Ask "show unused Apex" or "list classes in <namespace>".';
        }
        return resp;
    }

    private static String buildTriggerResponse(MetadataEngine.TriggerSummary s, String lower, String ns) {
        String resp = 'Your org has ' + s.total + ' trigger(s) — '
                    + s.activeTriggers.size() + ' active, '
                    + s.inactiveTriggers.size() + ' inactive, '
                    + s.unusedTriggers.size() + ' unused.\n\n';

        if (String.isNotBlank(ns) && s.filteredTotal != null && s.filteredTotal > 0) {
            resp += 'Namespace "' + ns + '" — ' + s.filteredTotal + ' trigger(s):\n';
            if (s.filteredTriggers != null) {
                for (MetadataEngine.TriggerInfo t : s.filteredTriggers) {
                    resp += '  * ' + t.name + '\n';
                }
            }
        } else if (lower.contains('unused') || lower.contains('inactive')) {
            resp += 'Unused / Inactive triggers:\n';
            if (!s.unusedTriggers.isEmpty()) {
                for (MetadataEngine.TriggerInfo t : s.unusedTriggers) {
                    resp += '  - ' + t.name + ' | ' + t.objectName + '\n';
                }
            } else {
                resp += '  None found.\n';
            }
        } else {
            resp += 'Use the Triggers tab for the full breakdown. '
                  + 'Ask "show unused triggers" to see candidates for deletion.';
        }
        return resp;
    }

    private static String buildLwcResponse(MetadataEngine.LwcSummary s, String ns) {
        String resp = 'Your org has ' + s.total + ' LWC component(s) — '
                    + s.withNamespace + ' with namespace, ' + s.withoutNamespace + ' without.\n';
        if (String.isNotBlank(ns) && s.filteredComponents != null && !s.filteredComponents.isEmpty()) {
            resp += '\nNamespace "' + ns + '" — ' + s.filteredComponents.size() + ' component(s):\n';
            for (MetadataEngine.LwcComponentInfo c : s.filteredComponents) {
                resp += '  * ' + c.name + '\n';
            }
        }
        return resp;
    }

    private static String buildAuraResponse(MetadataEngine.AuraSummary s, String ns) {
        String resp = 'Your org has ' + s.total + ' Aura component(s) — '
                    + s.withNamespace + ' with namespace, ' + s.withoutNamespace + ' without.\n';
        if (String.isNotBlank(ns) && s.filteredComponents != null && !s.filteredComponents.isEmpty()) {
            resp += '\nNamespace "' + ns + '" — ' + s.filteredComponents.size() + ' component(s):\n';
            for (MetadataEngine.AuraComponentInfo c : s.filteredComponents) {
                resp += '  * ' + c.name + '\n';
            }
        }
        return resp;
    }

    private static String buildProfileResponse(MetadataEngine.ProfileSummary s, String lower) {
        String resp = 'Your org has ' + s.total + ' Profile(s) — '
                    + s.used + ' assigned, ' + s.unused + ' unassigned.\n\n';
        if (lower.contains('unassigned') || lower.contains('unused')) {
            resp += 'Unassigned profiles (no active users):\n';
            if (!s.unusedProfiles.isEmpty()) {
                for (MetadataEngine.ProfileInfo p : s.unusedProfiles) {
                    resp += '  - ' + p.name + '\n';
                }
            } else {
                resp += '  All profiles are assigned.\n';
            }
        } else {
            resp += 'Ask "show unassigned profiles" to see cleanup candidates.';
        }
        return resp;
    }

    private static String buildPermSetResponse(MetadataEngine.PermissionSetSummary s, String lower) {
        String resp = 'Your org has ' + s.total + ' Permission Set(s) — '
                    + s.used + ' assigned, ' + s.unused + ' unassigned.\n\n';
        if (lower.contains('unassigned') || lower.contains('unused')) {
            resp += 'Unassigned Permission Sets:\n';
            if (!s.unusedPermSets.isEmpty()) {
                for (MetadataEngine.PermissionSetInfo p : s.unusedPermSets) {
                    resp += '  - ' + p.name + '\n';
                }
            } else {
                resp += '  All permission sets have assignments.\n';
            }
        } else {
            resp += 'Ask "show unused permission sets" to see cleanup candidates.';
        }
        return resp;
    }

    private static String buildFieldResponse(MetadataEngine.CustomFieldSummary s, String ns) {
        String resp = 'Your org has ' + s.total + ' Custom Field(s) — '
                    + s.withNamespace + ' with namespace, ' + s.withoutNamespace + ' without.\n';
        if (String.isNotBlank(ns) && s.filteredFields != null && !s.filteredFields.isEmpty()) {
            resp += '\nNamespace "' + ns + '" — ' + s.filteredFields.size() + ' field(s):\n';
            for (MetadataEngine.CustomFieldInfo f : s.filteredFields) {
                resp += '  * ' + f.name + ' on ' + f.objectName + '\n';
            }
        }
        return resp;
    }

    private static String buildObjectResponse(MetadataEngine.CustomObjectSummary s, String ns) {
        String resp = 'Your org has ' + s.total + ' Custom Object(s) — '
                    + s.withNamespace + ' with namespace, ' + s.withoutNamespace + ' without.\n';
        if (String.isNotBlank(ns) && s.filteredObjects != null && !s.filteredObjects.isEmpty()) {
            resp += '\nNamespace "' + ns + '" — ' + s.filteredObjects.size() + ' object(s):\n';
            for (MetadataEngine.CustomObjectInfo o : s.filteredObjects) {
                resp += '  * ' + o.name + '\n';
            }
        }
        return resp;
    }

    private static String buildVrResponse(MetadataEngine.ValidationRuleSummary s, String lower, String ns) {
        String resp = 'Your org has ' + s.total + ' Validation Rule(s) — '
                    + s.active + ' active, ' + s.inactive + ' inactive.\n\n';
        if (lower.contains('inactive') || lower.contains('unused')) {
            resp += 'Inactive Validation Rules (candidates for review):\n';
            if (s.inactiveRules != null && !s.inactiveRules.isEmpty()) {
                for (MetadataEngine.ValidationRuleInfo v : s.inactiveRules) {
                    resp += '  - ' + v.name + ' (' + v.objectName + ')\n';
                }
            } else {
                resp += '  None found.\n';
            }
        } else {
            resp += 'Ask "show inactive validation rules" to see cleanup candidates.';
        }
        return resp;
    }
}