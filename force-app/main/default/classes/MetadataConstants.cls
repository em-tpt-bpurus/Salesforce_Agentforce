/**
 * MetadataConstants
 *
 * Single source of truth for all shared string/value constants
 * used across AgentAction classes, delete actions, and export utilities.
 *
 * Usage: MetadataConstants.NONE, MetadataConstants.COL_LINES, etc.
 */
public class MetadataConstants {

    // ── Display fallbacks ─────────────────────────────────────
    public static final String NONE             = 'None';
    public static final String NA               = 'N/A';
    public static final String NS_ALL           = 'None (showing all)';

    // ── Column separator labels (used in numbered list rows) ──
    public static final String COL_LINES        = ' | Lines: ';
    public static final String COL_MODIFIED     = ' | Modified: ';
    public static final String COL_OBJECT       = ' | Object: ';
    public static final String COL_ACTIVE       = ' | Active: ';
    public static final String COL_API          = ' | API: ';
    public static final String COL_TYPE         = ' | Type: ';
    public static final String COL_LABEL        = ' | Label: ';
    public static final String COL_LICENSE      = ' | License: ';
    public static final String COL_USERS        = ' | Users: ';
    public static final String COL_ASSIGNMENTS  = ' | Assignments: ';
    public static final String COL_NS           = ' | NS: ';

    // ── Profile defaults ──────────────────────────────────────
    /** Default fallback profile when deactivating a profile from LWC without specifying one. */
    public static final String DEFAULT_PROFILE  = 'Standard User';

    // ── Export / file constants ───────────────────────────────
    /** Salesforce ContentVersion storage location — 'S' = Salesforce Files. */
    public static final String CONTENT_LOCATION = 'S';
    public static final String FORMAT_CSV        = 'csv';
    public static final String FORMAT_JSON       = 'json';
    public static final String FORMAT_TXT        = 'txt';
    public static final String MIME_JSON         = 'application/json';
    public static final String MIME_TXT          = 'text/plain';
    public static final String MIME_CSV          = 'text/csv';

    // ── Summary section header templates ─────────────────────
    // Flows
    public static final String SEC_ACTIVE_FLOWS         = '--- ACTIVE FLOWS';
    public static final String SEC_INACTIVE_FLOWS       = '--- INACTIVE FLOWS';
    public static final String SEC_FILTERED_NS          = '--- FILTERED BY NAMESPACE: ';

    // Apex
    public static final String SEC_STANDARD_CLASSES     = '--- STANDARD / PACKAGE CLASSES';
    public static final String SEC_USED_CLASSES         = '--- CUSTOM USED CLASSES';
    public static final String SEC_UNUSED_CLASSES       = '--- CUSTOM UNUSED CLASSES';
    public static final String SEC_TEST_CLASSES         = '--- TEST CLASSES';

    // Triggers
    public static final String SEC_USED_TRIGGERS        = '--- USED TRIGGERS';
    public static final String SEC_UNUSED_TRIGGERS      = '--- UNUSED TRIGGERS';
    public static final String SEC_ACTIVE_TRIGGERS      = '--- ACTIVE TRIGGERS';
    public static final String SEC_INACTIVE_TRIGGERS    = '--- INACTIVE TRIGGERS';

    // Profiles
    public static final String SEC_CUSTOM_PROFILES      = '--- CUSTOM PROFILES';
    public static final String SEC_STANDARD_PROFILES    = '--- STANDARD PROFILES';
    public static final String SEC_USED_PROFILES        = '--- USED PROFILES';
    public static final String SEC_UNUSED_PROFILES      = '--- UNUSED PROFILES';

    // Permission Sets
    public static final String SEC_USED_PERMSETS        = '--- USED PERMISSION SETS';
    public static final String SEC_UNUSED_PERMSETS      = '--- UNUSED PERMISSION SETS';

    // Validation Rules
    public static final String SEC_ACTIVE_VR            = '--- ACTIVE VALIDATION RULES';
    public static final String SEC_INACTIVE_VR          = '--- INACTIVE VALIDATION RULES';

    // Generic
    public static final String SEC_ALL_COMPONENTS       = '--- ALL';
    public static final String SEC_SUFFIX_CLOSE         = ') ---\n';
    public static final String SEC_HINT_NO_DELETE       = ' — Do NOT delete ---\n';
    public static final String SEC_HINT_SAFE_DELETE     = ' — Safe to delete ---\n';
    public static final String SEC_HINT_SAFE_REVIEW     = ' — Safe to review ---\n';
    public static final String SEC_HINT_ACTIVE_USERS    = ' — Assigned to active users ---\n';
    public static final String SEC_HINT_NO_USERS        = ' — No active user assignments ---\n';
    public static final String SEC_HINT_ACTIVE_ASSIGN   = ' — Have active assignments ---\n';
    public static final String SEC_HINT_NO_ASSIGN       = ' — No assignments — Safe to review ---\n';
    public static final String SEC_HINT_ACTIVE_REF      = ' — Actively referenced ---\n';
    public static final String SEC_HINT_IN_USE          = ' — Actively in use ---\n';
}