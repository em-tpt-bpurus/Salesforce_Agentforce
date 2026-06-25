import { LightningElement, track } from 'lwc';
import getFlowSummary           from '@salesforce/apex/MetadataAgentAction.getFlowSummary';
import getApexSummary           from '@salesforce/apex/ApexClassAgentAction.getApexSummary';
import getTriggerSummary        from '@salesforce/apex/TriggerAgentAction.getTriggerSummary';
import getLwcSummary            from '@salesforce/apex/LwcAgentAction.getLwcSummary';
import getAuraSummary           from '@salesforce/apex/AuraAgentAction.getAuraSummary';
import getGovernanceRegistry    from '@salesforce/apex/AuraAgentAction.getGovernanceRegistry';
import getProfileSummary        from '@salesforce/apex/ProfileAgentAction.getProfileSummary';
import getPermissionSetSummary  from '@salesforce/apex/PermissionSetAgentAction.getPermissionSetSummary';
import getCustomFieldSummary    from '@salesforce/apex/CustomFieldAgentAction.getCustomFieldSummary';
import getCustomObjectSummary   from '@salesforce/apex/CustomObjectAgentAction.getCustomObjectSummary';
import getValidationRuleSummary from '@salesforce/apex/ValidationRuleAgentAction.getValidationRuleSummary';
import getVfSummary             from '@salesforce/apex/VfPageAgentAction.getVfSummary';
import getVfComponentSummary    from '@salesforce/apex/VfComponentAgentAction.getVfComponentSummary';
import deleteVf                 from '@salesforce/apex/DeleteVfPageAction.deleteVfFromLWC';
import massDeleteVfPages        from '@salesforce/apex/DeleteVfPageAction.massDeleteVfPagesDirect';
import deleteVfComponent        from '@salesforce/apex/DeleteVfPageAction.deleteVfComponentFromLWC';
import massDeleteVfComponents   from '@salesforce/apex/DeleteVfPageAction.massDeleteVfComponentsDirect';
import findReferencesForVfPage  from '@salesforce/apex/DeleteVfPageAction.findReferencesForVfPage';

// Agent actions — new backend class
import handleAgentQuery         from '@salesforce/apex/OrgCleanupAgentAction.handleAgentQuery';
import getCombinedScore          from '@salesforce/apex/OrgHealthScoreEngine.getCombinedScore';
import checkReferences          from '@salesforce/apex/OrgCleanupAgentAction.checkReferences';
import deleteApexClass          from '@salesforce/apex/DeleteApexClassAction.deleteApexClassDirect';
import massDeleteApexClasses    from '@salesforce/apex/DeleteApexClassAction.massDeleteApexClassesDirect';
import saveToOrgFiles           from '@salesforce/apex/ExportMetadataAction.saveToFiles';
import deleteFlow               from '@salesforce/apex/DeleteFlowAction.deleteFlowDirect';
import massDeleteFlows          from '@salesforce/apex/DeleteFlowAction.massDeleteFlowsDirect';
import deleteTrigger            from '@salesforce/apex/DeleteTriggerAction.deleteTriggerDirect';
import massDeleteTriggers       from '@salesforce/apex/DeleteTriggerAction.massDeleteTriggersDirect';
import deleteLwc                from '@salesforce/apex/DeleteLwcAction.deleteLwcFromLWC';
import massDeleteLwc            from '@salesforce/apex/DeleteLwcAction.massDeleteLwcDirect';
import deleteAura               from '@salesforce/apex/DeleteAuraAction.deleteAuraFromLWC';
import massDeleteAura           from '@salesforce/apex/DeleteAuraAction.massDeleteAuraDirect';
import deleteCustomField        from '@salesforce/apex/DeleteCustomFieldAction.deleteFieldFromLWC';
import massDeleteCustomFields   from '@salesforce/apex/DeleteCustomFieldAction.massDeleteCustomFieldsDirect';
import deleteCustomObject       from '@salesforce/apex/DeleteCustomObjectAction.deleteObjectFromLWC';
import massDeleteCustomObjects  from '@salesforce/apex/DeleteCustomObjectAction.massDeleteCustomObjectsDirect';
import deletePermSet            from '@salesforce/apex/DeletePermissionSetAction.deletePermSetFromLWC';
import massDeletePermSets       from '@salesforce/apex/DeletePermissionSetAction.massDeletePermSetsDirect';
import deactivateProfile        from '@salesforce/apex/DeactivateProfileAction.deactivateProfileFromLWC';
import massDeactivateProfiles   from '@salesforce/apex/DeactivateProfileAction.massDeactivateProfilesDirect';
import deleteValidationRule     from '@salesforce/apex/DeleteValidationRuleAction.deleteVRFromLWC';
import massDeleteValidationRules from '@salesforce/apex/DeleteValidationRuleAction.massDeleteValidationRulesDirect';

// ─────────────────────────────────────────────────────────────
// CONSTANTS — single source of truth for all magic strings
// ─────────────────────────────────────────────────────────────

/** Dashboard tab identifiers */
const TAB = {
    FLOWS    : 'flows',
    APEX     : 'apex',
    TRIGGERS : 'triggers',
    LWC      : 'lwc',
    AURA     : 'aura',
    PROFILES : 'profiles',
    PERMSETS : 'permsets',
    FIELDS   : 'fields',
    OBJECTS  : 'objects',
    VR       : 'vr',
    VF       : 'vf',
    VFC      : 'vfc'
};

/** Stat-card filter keys */
const FILTER = {
    ALL          : 'all',
    TOTAL        : 'total',
    ACTIVE       : 'active',
    INACTIVE     : 'inactive',
    USED         : 'used',
    UNUSED       : 'unused',
    STANDARD     : 'standard',
    TEST         : 'test',
    WITH_NS      : 'withNs',
    NO_NS        : 'noNs',
    EMPTY        : 'empty',
    UNREFERENCED : 'unreferenced',
    REFERENCED   : 'referenced'
};

/** Export format keys */
const FORMAT = {
    CSV  : 'csv',
    JSON : 'json',
    TXT  : 'txt'
};

/** Metadata type keys used in delete/intent routing */
const META_TYPE = {
    APEX    : 'apex',
    FLOW    : 'flow',
    TRIGGER : 'trigger',
    LWC     : 'lwc',
    AURA    : 'aura',
    FIELD   : 'field',
    OBJECT  : 'object',
    PERMSET : 'permset',
    PROFILE : 'profile',
    VR      : 'vr',
    VF      : 'vf',
    VFC     : 'vfc'
};

/** Agent panel display strings */
const AGENT = {
    HEADER_NAME   : 'Org Cleanup Agent',
    HEADER_STATUS : 'Online',
    MODE_NAME     : 'Rule-Based (Custom)',
    WELCOME_MSG   : 'Hi! I can help you audit and clean your Salesforce org. ' +
                    'Ask me about flows, Apex classes, triggers, profiles, and more — ' +
                    'or ask me to delete specific unused components.'
};

/** Confirmation keywords the user can type */
const CONFIRM_YES = new Set(['yes', 'confirm', 'delete', 'yes, delete it']);
const CONFIRM_NO  = new Set(['no', 'cancel']);

/** Timing (ms) */
const TIMING = {
    SCROLL_DELAY         : 50,
    TOAST_DISMISS        : 4500,
    NS_DEBOUNCE          : 300   // debounce delay for client-side namespace filter
};

// ─────────────────────────────────────────────────────────────

let _msgIdCounter = 0;
function nextId() { return 'msg_' + (++_msgIdCounter); }

export default class MetadataDashboard extends LightningElement {

    // ── Dashboard state (unchanged) ─────────────────────────
    @track activeTab = TAB.FLOWS;

    @track activeCardFilter = FILTER.ALL; // 'all' | 'total' | 'standard' | 'used' | 'unused' | 'test' | 'active' | 'inactive'
    // Section visibility getters — read directly from @track activeCardFilter.
    // 'all' and 'total' both show every section — Total is a summary card, not a filter.
    // Each specific filter (active/inactive/used/unused/etc.) shows only its own section.
    get showAllSections()       { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.WITH_NS || this.activeCardFilter === FILTER.NO_NS; }
    get showTotalSection()      { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL; }
    get showStandardSection()   { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.STANDARD; }
    get showUsedSection()       { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.USED; }
    get showUnusedSection()     { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.UNUSED; }
    get showTestSection()       { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.TEST; }
    get showActiveSection()     { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.ACTIVE; }
    get showInactiveSection()   { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.INACTIVE; }
    get showAssignedSection()   { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.USED; }
    get showUnassignedSection() { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.UNUSED; }
    get showWithNsSection()     { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.WITH_NS; }
    get showNoNsSection()       { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.NO_NS; }
    get showEmptySection()      { return this.activeCardFilter === FILTER.EMPTY; }
    get showUnreferencedSection(){ return this.activeCardFilter === FILTER.UNREFERENCED; }
    get showReferencedSection() { return this.activeCardFilter === FILTER.REFERENCED; }
    @track isLoading    = false;
    @track exportModalOpen   = false;
    @track exportFormat      = FORMAT.CSV; // 'csv' | 'json' | 'txt'
    @track _exportTabLabel   = '';
    @track _toastMessage     = '';
    @track _toastLink        = '';  // optional URL shown in toast
    @track _exportFormatKey  = 0; // force getter re-evaluation on format change
    @track isSaving          = false;
    @track hasError     = false;
    @track errorMessage = '';
    @track namespaceInput = '';
    @track nsFilterInput  = '';   // client-side filter — updates after debounce
    _nsDebounceTimer      = null; // debounce timer handle

    @track flowSummary    = { totalCount: '—', activeCount: '—', inactiveCount: '—', usedCount: '—', unusedCount: '—', activeFlows: '', inactiveFlows: '',
                               filteredCount: '—', namespaceFilterApplied: '—',
                               filteredActiveFlows: '', filteredInactiveFlows: '' };
    @track apexSummary    = { totalCount: '—', standardCount: '—', usedCount: '—', unusedCount: '—', testCount: '—',
                               standardClasses: '', usedClasses: '', unusedClasses: '', testClasses: '',
                               filteredCount: '—', namespaceFilterApplied: '—', filteredClasses: '' };
    @track triggerSummary = { totalCount: '—', activeCount: '—', inactiveCount: '—', usedCount: '—', unusedCount: '—',
                               activeTriggers: '', inactiveTriggers: '', unusedTriggers: '', usedTriggers: '',
                               filteredCount: '—', namespaceFilterApplied: '—', filteredTriggers: '' };
    @track lwcSummary     = { totalCount: '—', withNamespaceCount: '—', withoutNamespaceCount: '—',
                               filteredCount: '—', namespaceFilterApplied: '—',
                               allComponents: '', filteredComponents: '',
                               unreferencedCount: '0', unreferencedComponents: '' };
    @track auraSummary    = { totalCount: '—', withNamespaceCount: '—', withoutNamespaceCount: '—',
                               filteredCount: '—', namespaceFilterApplied: '—',
                               allComponents: '', filteredComponents: '',
                               unreferencedCount: '0', unreferencedComponents: '' };
    @track governanceRegistry = [];
    _governanceLoaded = false;
    @track profileSummary   = { totalCount: '—', usedCount: '—', unusedCount: '—',
                                 usedProfiles: '', unusedProfiles: '',
                                 filteredCount: '—', namespaceFilterApplied: '—', filteredProfiles: '' };
    @track permSetSummary   = { totalCount: '—', usedCount: '—', unusedCount: '—',
                                 usedPermSets: '', unusedPermSets: '',
                                 filteredCount: '—', namespaceFilterApplied: '—', filteredPermSets: '' };
    @track fieldSummary     = { totalCount: '—', withNamespaceCount: '—', withoutNamespaceCount: '—',
                                 filteredCount: '—', namespaceFilterApplied: '—',
                                 allFields: '', filteredFields: '',
                                 emptyCount: '0', emptyFields: '' };
    @track objectSummary    = { totalCount: '—', withNamespaceCount: '—', withoutNamespaceCount: '—',
                                 filteredCount: '—', namespaceFilterApplied: '—',
                                 allObjects: '', filteredObjects: '',
                                 emptyCount: '0', emptyObjects: '' };
    @track vrSummary        = { totalCount: '—', activeCount: '—', inactiveCount: '—',
                                 filteredCount: '—', namespaceFilterApplied: '—',
                                 activeRules: '', inactiveRules: '', filteredRules: '' };
    @track vfSummary        = { totalCount: '—', referencedCount: '—', unreferencedCount: '—',
                                 withNamespaceCount: '—', withoutNamespaceCount: '—',
                                 allPages: '', unreferencedPages: '', allPageObjects: [] };
    @track vfcSummary       = { totalCount: '—', referencedCount: '—', unreferencedCount: '—',
                                 withNamespaceCount: '—', withoutNamespaceCount: '—',
                                 allComponents: '', unreferencedComponents: '', allComponentObjects: [] };

    _flowsLoaded    = false;
    _apexLoaded     = false;
    _triggersLoaded = false;
    _lwcLoaded      = false;
    _auraLoaded     = false;
    _profilesLoaded = false;
    _permSetsLoaded = false;
    _fieldsLoaded   = false;
    _objectsLoaded  = false;
    _vrLoaded       = false;
    _vfLoaded       = false;
    _vfcLoaded      = false;

    // ── Agent panel state ────────────────────────────────────
    @track agentMessages = [];
    @track agentInput = '';
    @track agentIsProcessing = false;

    // ── Live health score state ──────────────────────────────
    @track _prevIssueCount = null;   // snapshot before a delete, for before/after animation
    @track _scoreFlash = false;      // triggers CSS animation after successful delete
    @track _agentIssueCount = null;  // total issues parsed from agent org-health response
    @track _agentHealthScore = null; // health score parsed from agent org-health response

    // Last meaningful data response (fields list, flows list etc.) — used for export
    _lastDataResponse = null;

    // Last parsed org health report — used for export
    _lastOrgHealthData = null;

    // Pending delete confirmation: { type, name }
    _pendingDelete = null;
    _pendingMassDelete = null; // { type, names: [] } — waiting for mass delete confirmation
    _pendingTypeSelect = null; // { name, matches: [{type, label}] } — waiting for user to pick a type

    connectedCallback() {
        this._loadFlows();
        this._agentWelcome();
        // FIX: silently prefetch org health on load so the gauge shows real org-wide
        // counts immediately, not just the partial sum from the Flows tab (which made
        // the initial gauge show "34 issues" instead of the true ~130+).
        this._prefetchOrgHealth();
        this._boundOutsideClick = this._handleOutsideClick.bind(this);
        document.addEventListener('click', this._boundOutsideClick);
    }

    // Background-only org health fetch — populates _agentIssueCount + _agentHealthScore
    // so the gauge is accurate on first paint. Does NOT add a message to the chat.
    _prefetchOrgHealth() {
        // Silently fetch the combined health score using the structured Apex method —
        // avoids going through handleAgentQuery (which triggers Agentforce / adds a chat message).
        // Only updates the gauge numbers; never adds a visible message to the chat.
        const metadataIssues = this.liveIssueCount;
        const metadataScore  = Math.max(0, Math.round(100 - Math.min(metadataIssues / 2, 100)));
        getCombinedScore({ metadataScore })
            .then(result => {
                if (!result) return;
                if (result.combinedScore != null && !isNaN(result.combinedScore)) {
                    this._agentHealthScore = result.combinedScore;
                }
                // Derive issue count from scores — (100 - score) * 2 approximation
                const inferredIssues = Math.round((100 - (result.combinedScore || 50)) * 2);
                if (inferredIssues > this._agentIssueCount || this._agentIssueCount === null) {
                    this._agentIssueCount = inferredIssues;
                }
            })
            .catch(() => {
                // Silently ignore — gauge falls back to locally computed values
            });
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._boundOutsideClick);
    }

    _handleOutsideClick(event) {
    }

    get agentHeaderName()    { return AGENT.HEADER_NAME; }
    get agentHeaderStatus()  { return AGENT.HEADER_STATUS; }
    get agentModeName()      { return AGENT.MODE_NAME; }

    // ── Live Org Health Score ────────────────────────────────
    // Computed from live @track summaries — recalculates on every delete/refresh
    get liveIssueCount() {
        const n = v => (v !== undefined && v !== null && v !== '—' && v !== '') ? parseInt(v, 10) || 0 : 0;
        const fromSummaries = n(this.apexSummary.unusedCount)
             + n(this.flowSummary.inactiveCount)
             + n(this.triggerSummary.inactiveCount)
             + n(this.lwcSummary.unreferencedCount)
             + n(this.auraSummary.unreferencedCount)
             + n(this.profileSummary.unusedCount)
             + n(this.permSetSummary.unusedCount)
             + n(this.vrSummary.inactiveCount)
             + n(this.fieldSummary.emptyCount)
             + n(this.objectSummary.emptyCount);

        // BUG FIX: previously this returned fromSummaries whenever it was > 0, even if
        // only a few tabs had loaded their summaries. Result: gauge subtitle showed
        // "34 issues" (just Flows tab) while the agent's full-org scan returned 131.
        //
        // New behaviour: if agent returned an authoritative org-wide count, prefer it
        // when it's HIGHER than what we've computed locally. Live summaries take over
        // once they exceed the agent's snapshot (after a delete makes live count drop).
        if (this._agentIssueCount !== null && this._agentIssueCount > fromSummaries) {
            return this._agentIssueCount;
        }
        return fromSummaries;
    }
    get liveHealthScore() {
        // If agent returned a direct score, use it (most accurate)
        if (this._agentHealthScore !== null) return this._agentHealthScore;
        const issues = this.liveIssueCount;
        // Scale: 0 issues = 100, 200+ issues = 0. Capped so large orgs still show > 0.
        const score = Math.max(0, Math.round(100 - Math.min(issues / 2, 100)));
        return score;
    }
    get liveHealthPercent() { return this.liveHealthScore; }
    get liveHealthLabel() {
        const s = this.liveHealthScore;
        if (s >= 90) return 'Excellent';
        if (s >= 70) return 'Good';
        if (s >= 45) return 'Needs Attention';
        return 'Cleanup Recommended';
    }
    get liveHealthColor() {
        const s = this.liveHealthScore;
        if (s >= 90) return '#2e844a';
        if (s >= 70) return '#dd7a00';
        if (s >= 45) return '#c45500';
        return '#c23934';
    }
    get liveHealthRingOffset() {
        // SVG stroke-dashoffset for a circle with r=28, circumference ≈ 175.9
        const circ = 175.9;
        return circ - (circ * this.liveHealthScore / 100);
    }
    get liveScoreFlashClass() {
        return 'health-gauge' + (this._scoreFlash ? ' health-gauge--flash' : '');
    }
    get prevIssueCount() { return this._prevIssueCount; }
    get issuesDelta() {
        if (this._prevIssueCount === null) return null;
        return this._prevIssueCount - this.liveIssueCount;
    }
    get showDeltaBadge() { return this.issuesDelta !== null && this.issuesDelta > 0; }
    get deltaBadgeText() { return this.issuesDelta !== null ? '-' + this.issuesDelta + ' issue' + (this.issuesDelta !== 1 ? 's' : '') : ''; }

    // ────────────────────────────────────────────────────────
    // AGENT WELCOME
    // ────────────────────────────────────────────────────────
    _agentWelcome() {
        this._addAgentMsg(
            
            
            AGENT.WELCOME_MSG,
            false, false
        );
    }

    // ────────────────────────────────────────────────────────
    // AGENT MESSAGING HELPERS
    // ────────────────────────────────────────────────────────
    _addUserMsg(text) {
        this.agentMessages = [...this.agentMessages, {
            id      : nextId(),
            text,
            isAgent : false,
            isTyping: false,
            isSuccess: false,
            isError : false,
            cssClass: 'agent-msg agent-msg--user'
        }];
        this._scrollMessages();
    }

    _addAgentMsg(text, isSuccess = false, isError = false) {
        // Detect if this is a reference-blocking report
        const isDataLossReport = isError && text && (
            text.includes('live data') ||
            text.includes('LiveData') ||
            text.includes('permanently destroy this data') ||
            text.includes('Export via Data Loader')
        );
        const isReferenceReport = isError && text && (
            text.includes('Cannot delete') ||
            text.includes('reference(s) must be removed first') ||
            isDataLossReport
        );
        // Detect org health report and parse into structured data for rich rendering
        const isOrgHealth = text && (
            text.includes('ORG HEALTH REPORT') ||
            text.includes('Org Health Report') ||    // Agentforce title-case format
            text.includes('Org health report') ||
            text.includes('Total Issues:') ||        // Agentforce: capital I, no space
            text.includes('Total issues :') ||       // Apex backend: lowercase i, space before colon
            text.includes('Total issues:') ||        // compact variant
            text.includes('Health Score :') ||       // Apex backend score line
            text.includes('Cleanup Recommended') ||
            text.includes('Needs Attention') ||
            text.includes('Org Size Summary')        // Agentforce section header (title-case)
        );
        const orgHealth = isOrgHealth ? this._parseOrgHealth(text) : null;

        // Sync gauge with agent-parsed health data
        if (isOrgHealth && orgHealth) {
            const parsed = parseInt(orgHealth.totalIssues, 10);
            if (!isNaN(parsed)) this._agentIssueCount = parsed;

            // FIX: The gauge must always show the true weighted combined score
            // (40% Metadata + 35% Security + 25% License) already fetched from
            // OrgHealthScoreEngine.getCombinedScore() via _prefetchOrgHealth().
            // The report text contains a metadata-only derived score (e.g. 31%)
            // which is lower than the combined score (e.g. 57%) and must NOT
            // overwrite the accurate prefetched value.
            // Only set from the report text if no prefetch score exists yet.
            if (this._agentHealthScore === null) {
                if (orgHealth.scorePct != null && !isNaN(orgHealth.scorePct)) {
                    this._agentHealthScore = orgHealth.scorePct;
                } else {
                    this._agentHealthScore = isNaN(parsed) ? null : Math.max(0, Math.round(100 - Math.min(parsed / 2, 100)));
                }
            }

            // Inject CSS vars for progress bar widths (LWC blocks inline style bindings)
            if (orgHealth.licData && orgHealth.licData.summary) {
                const s = orgHealth.licData.summary;
                this.template.host.style.setProperty('--ul-bar-width',  `${s.ulUsedPct  || 2}%`);
                this.template.host.style.setProperty('--psl-bar-width', `${s.pslUtil    || 2}%`);
            }

            // Store parsed org health for export
            this._lastOrgHealthData = orgHealth;
        }

        this.agentMessages = [...this.agentMessages, {
            id      : nextId(),
            text,
            isAgent : true,
            isTyping: false,
            isSuccess,
            isError,
            isReferenceReport,
            isDataLossReport,
            isOrgHealth,
            orgHealth,
            cssClass: 'agent-msg agent-msg--agent'
        }];
        this._scrollMessages();
    }

    _parseOrgHealth(text) {
        const lines = text.split('\n');

        // ── Score detection — handles multiple formats ──────────────────────
        // Format 1 (NEW): "Health Score : 55% — 🟠 Needs Attention"
        // Format 2:       "Health Score : 🔴 Cleanup Recommended"
        // Format 3:       "Org Health Reportf534 Cleanup Recommended" (title line, legacy bug)
        // Format 4:       plain "Cleanup Recommended" anywhere
        const scoreLine  = lines.find(l => l.includes('Health Score')) ||
                           lines.find(l => /org health report/i.test(l)) || '';
        const rawScore   = scoreLine
            ? scoreLine.replace(/.*Health Score\s*:\s*/i, '').replace(/.*org health report\w*/i, '').trim()
            : '';

        // Extract explicit percentage if present (e.g. "55%" in "55% — Needs Attention")
        const pctMatch  = rawScore.match(/(\d{1,3})\s*%/);
        const scorePct  = pctMatch ? Math.min(100, Math.max(0, parseInt(pctMatch[1], 10))) : null;

        // Strip leading emoji / non-ASCII symbols / digits / % / dash so we get plain label
        const score = rawScore.replace(/^[\u0000-\u001F\u007F-\uFFFF\s\d%—–\-]+/, '').trim() || 'Cleanup Recommended';

        // ── Total issues ─────────────────────────────────────────────────────
        // Handles "Total Issues: 124" and "Total issues : 124"
        const issuesLine = lines.find(l => /total issues/i.test(l));
        const totalIssues = issuesLine
            ? issuesLine.replace(/.*total issues\s*:\s*/i, '').trim()
            : '0';

        // ── Score badge colour ───────────────────────────────────────────────
        let scoreClass = 'health-score--red';
        if (/excellent/i.test(score))      scoreClass = 'health-score--green';
        else if (/good/i.test(score))      scoreClass = 'health-score--yellow';
        else if (/attention/i.test(score)) scoreClass = 'health-score--orange';

        // ── Org Size Summary rows ────────────────────────────────────────────
        // Handles ALL known formats:
        //   Apex backend:    "  Flows           : 85 (51 active, 34 inactive)"  (colon, leading spaces)
        //   Agentforce:      "Flows85 (51 active, 34 inactive)"                 (label runs into number)
        //   Generic:         "Flows  85 (51 active, 34 inactive)"               (2+ space separator)
        const SUMMARY_TYPES = [
            'Apex Classes','LWC Components','Aura Components',
            'Permission Sets','Custom Fields','Custom Objects','Validation Rules',
            'Flows','Triggers','Profiles','VF Pages','VF Components'
        ];
        const summaryRows = [];
        let inSummary = false;
        for (const l of lines) {
            // Apex backend: section starts at "PILLAR 1 — METADATA" or "Org Size Summary"
            if (/org size summary/i.test(l))                    { inSummary = true;  continue; }
            if (/pillar\s+1.*metadata/i.test(l))                { inSummary = true;  continue; }
            // End of summary section
            if (/pillar\s+[23]/i.test(l))                       { inSummary = false; }
            if (/prioritized|cleanup rec|looks clean/i.test(l)) { inSummary = false; }
            if (!inSummary) continue;
            const raw = l.trim();
            if (!raw) continue;
            // Skip the "Total issues: X out of Y" line — not a summary row
            if (/total issues/i.test(raw)) continue;

            // Format 1 — "Flows  85 (51 active, 34 inactive)"  (2+ space gap)
            const parenMatch = raw.match(/^([A-Za-z][\w\s,]+?)\s{2,}(\d.*)$/);
            if (parenMatch) {
                summaryRows.push({ label: parenMatch[1].trim(), value: parenMatch[2].trim() });
                continue;
            }

            // Format 2 — "Flows : 85 (...)" or "Flows: 85 (...)"  (colon separator)
            // Guard: label must start with a letter AND not contain emoji/symbols
            // to avoid "⚠ Total Issues:131" being captured here
            const colonIdx = raw.indexOf(':');
            if (colonIdx > 0 && /^[A-Za-z]/.test(raw)) {
                const lbl = raw.slice(0, colonIdx).trim();
                const val = raw.slice(colonIdx + 1).trim();
                // Only accept known metadata type labels (not "Health Score", "Total issues" etc.)
                if (SUMMARY_TYPES.some(t => lbl.toLowerCase().includes(t.toLowerCase()))) {
                    summaryRows.push({ label: lbl, value: val });
                    continue;
                }
            }

            // Format 3 — "Flows85 (51 active, 34 inactive)"  (label runs into digit, Agentforce)
            for (const t of SUMMARY_TYPES) {
                if (raw.startsWith(t)) {
                    const value = raw.slice(t.length).trim();
                    if (value && /^\d/.test(value)) {
                        summaryRows.push({ label: t, value });
                    }
                    break;
                }
            }
        }

        // ── Recommendations ──────────────────────────────────────────────────
        // Handles:
        //   "1. [HIGH] 26 unused Apex class(es)"           (old format)
        //   "HIGH1. 26 unused Apex class(es)"              (new UI format)
        //   "→ Type "show unused apex classes" to review" (action lines)
        const recs = [];
        let inRecs = false;
        let current = null;

        for (const l of lines) {
            // Apex backend header: "🗑️ PRIORITIZED CLEANUP RECOMMENDATIONS"
            if (/prioritized\s+cleanup|cleanup\s+rec/i.test(l)) { inRecs = true; continue; }
            // Also fire on first numbered rec line (both format variants)
            if (!inRecs && /^(HIGH|MEDIUM|LOW)\d+\./.test(l.trim())) inRecs = true;
            if (!inRecs && /^\d+\.\s*\[(HIGH|MEDIUM|LOW)\]/.test(l.trim())) inRecs = true;
            if (!inRecs) continue;

            const raw = l.trim();

            // Format A: "1. [HIGH] text"  ← Apex backend output
            const fmtA = raw.match(/^(\d+)\.\s*\[(HIGH|MEDIUM|LOW)\]\s*(.+)/);
            // Format B: "HIGH1. text"     ← alternate UI format
            const fmtB = raw.match(/^(HIGH|MEDIUM|LOW)(\d+)\.\s*(.+)/);

            if (fmtA || fmtB) {
                if (current) recs.push(current);
                const num   = fmtA ? fmtA[1] : fmtB[2];
                const lvl   = fmtA ? fmtA[2] : fmtB[1];
                const label = fmtA ? fmtA[3] : fmtB[3];
                const levelClass = lvl === 'HIGH'   ? 'health-rec__badge health-rec__badge--high'
                                 : lvl === 'MEDIUM' ? 'health-rec__badge health-rec__badge--medium'
                                 :                    'health-rec__badge health-rec__badge--low';
                current = { num, level: lvl, levelClass, text: label.trim(), actions: [] };
                continue;
            }

            // Action lines — Apex outputs "   → Type \"show...\" to review"
            // raw is already l.trim() so starts directly with → (U+2192) if present
            if (current && (raw.startsWith('\u2192') || /^Type "/i.test(raw))) {
                current.actions.push(raw.replace(/^[\u2192\s]+/, '').trim());
            }
        }
        if (current) recs.push(current);

        // Add helper flags used in template
        const hasSummaryRows = summaryRows.length > 0;

        // Add recClass (border-left color per priority)
        recs.forEach(r => {
            r.recClass = r.level === 'HIGH'   ? 'health-rec health-rec--high'
                       : r.level === 'MEDIUM' ? 'health-rec health-rec--medium'
                       :                        'health-rec health-rec--low';
        });

        // ── Pillar Breakdown (from banner lines) ─────────────────────────────
        // Apex format: "  🗂️  Metadata Score  : 31%  🔴 Critical  (40% weight)"
        // Strip emojis from status — capture only the plain English word(s) after the emoji
        const stripEmoji = s => s.replace(/[\u{1F000}-\u{1FFFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\uFE0F\u20E3\u200D]+/gu, '').trim();
        const pillars = [];
        for (const l of lines) {
            // Match "Score  : 31%  <anything>  (40% weight)"
            const pm = l.match(/Metadata Score\s*:\s*(\d+)%\s+(.+?)\s+\(\d+%/);
            const ps = l.match(/Security Score\s*:\s*(\d+)%\s+(.+?)\s+\(\d+%/);
            const pl = l.match(/License Score\s*:\s*(\d+)%\s+(.+?)\s+\(\d+%/);
            const pillarColor = pct => parseInt(pct, 10) >= 90 ? 'green' : parseInt(pct, 10) >= 70 ? 'yellow' : parseInt(pct, 10) >= 50 ? 'orange' : 'red';
            if (pm) pillars.push({ icon: '🗂️', label: 'Metadata', pct: pm[1], status: stripEmoji(pm[2]), weight: '40%', pillarClass: `health-pillar health-pillar--${pillarColor(pm[1])}` });
            if (ps) pillars.push({ icon: '🔐', label: 'Security', pct: ps[1], status: stripEmoji(ps[2]), weight: '35%', pillarClass: `health-pillar health-pillar--${pillarColor(ps[1])}` });
            if (pl) pillars.push({ icon: '💰', label: 'License',  pct: pl[1], status: stripEmoji(pl[2]), weight: '25%', pillarClass: `health-pillar health-pillar--${pillarColor(pl[1])}` });
        }

        // ── Security Pillar detail ───────────────────────────────────────────
        const secFindings = [];
        let secChecks = '';
        let inSec = false;
        for (const l of lines) {
            if (/pillar\s+2.*security/i.test(l)) { inSec = true; continue; }
            if (/pillar\s+3/i.test(l))            { inSec = false; }
            if (!inSec) continue;
            const raw = l.trim();
            if (!raw) continue;
            if (/^[━─═\-]{3,}/.test(raw)) continue; // skip separator lines
            const cm = raw.match(/Checks passed:\s*(\d+\s*\/\s*\d+)/i);
            if (cm) { secChecks = cm[1]; continue; }
            secFindings.push(raw);
        }

        // ── License Pillar detail — structured parsing ───────────────────────
        const licWasted = [];   // 💸 user license waste items
        const pslWasted = [];   // 💸 PSL waste items
        const licFindings = []; // ✅ / ⚠️ summary findings
        let licSummary = null;  // { ulPurchased, ulUsed, ulUtil, ulWasted, pslPurchased, pslUsed, pslWasted }
        let inLic = false;
        for (const l of lines) {
            if (/pillar\s+3.*license/i.test(l))          { inLic = true; continue; }
            if (/metadata cleanup|prioritized/i.test(l)) { inLic = false; }
            if (!inLic) continue;
            const raw = l.trim();
            if (!raw) continue;
            if (/^[━─═\-]{3,}/.test(raw)) continue; // skip separator lines
            const ulMatch = raw.match(/User Licenses\s*:\s*([\d,]+)\s+purchased,\s*([\d,]+)\s+used.*\(([\d.]+)%/i);
            if (ulMatch) {
                if (!licSummary) licSummary = {};
                licSummary.ulPurchased = ulMatch[1];
                licSummary.ulUsed      = ulMatch[2];
                licSummary.ulUtil      = ulMatch[3];
                const ulPct = Math.min(100, Math.round(parseFloat(ulMatch[3])));
                licSummary.ulUsedPct   = Math.max(2, ulPct);
                continue;
            }
            const ulWastedMatch = raw.match(/Wasted Lic types\s*:\s*(\d+)/i);
            if (ulWastedMatch) {
                if (!licSummary) licSummary = {};
                licSummary.ulWasted = ulWastedMatch[1];
                continue;
            }
            const pslMatch = raw.match(/PSL Licenses\s*:\s*([\d,]+)\s+purchased,\s*([\d,]+)\s+used/i);
            if (pslMatch) {
                if (!licSummary) licSummary = {};
                licSummary.pslPurchased = pslMatch[1];
                licSummary.pslUsed      = pslMatch[2];
                const pslUtil = licSummary.pslPurchased > 0
                    ? Math.min(100, Math.round((parseInt(pslMatch[2], 10) / parseInt(pslMatch[1], 10)) * 100))
                    : 0;
                licSummary.pslUtil     = Math.max(2, pslUtil);
                licSummary.pslUtilPct  = pslUtil + '%';
                continue;
            }
            const pslWastedMatch = raw.match(/Wasted PSL types\s*:\s*(\d+)/i);
            if (pslWastedMatch) {
                if (!licSummary) licSummary = {};
                licSummary.pslWasted = pslWastedMatch[1];
                continue;
            }

            // Waste findings: "💸 PSL "Name": N purchased, 0 assigned"  or  "💸 Name: N purchased, 0 used"
            if (/^💸/.test(raw)) {
                const pslFinding = raw.match(/💸\s+PSL\s+"([^"]+)":\s*([\d,]+)\s+purchased/i);
                if (pslFinding) {
                    pslWasted.push({ name: pslFinding[1], qty: pslFinding[2] });
                } else {
                    const ulFinding = raw.match(/💸\s+([^:]+):\s*([\d,]+)\s+purchased/i);
                    if (ulFinding) licWasted.push({ name: ulFinding[1].trim(), qty: ulFinding[2] });
                }
                continue;
            }

            // Remaining ✅ / ⚠️ findings
            if (/^[✅⚠❌🔴🟡🟢ℹ]/.test(raw)) licFindings.push(raw);
        }

        // Attach wasted counts to summary if not already parsed from text
        if (licSummary) {
            if (!licSummary.ulWasted)  licSummary.ulWasted  = licWasted.length;
            if (!licSummary.pslWasted) licSummary.pslWasted = pslWasted.length;
        }

        const licData = licSummary
            ? { hasSummary: true, summary: licSummary, licWasted, pslWasted, licFindings,
                hasLicWasted: licWasted.length > 0, hasPslWasted: pslWasted.length > 0,
                hasFindings: licFindings.length > 0 }
            : null;

        return { score, scorePct, scoreClass, totalIssues, summaryRows, hasSummaryRows, recs,
                 pillars, secFindings, secChecks, licData };
    }

    _addTypingIndicator() {
        const id = nextId();
        this.agentMessages = [...this.agentMessages, {
            id,
            text    : '',
            isAgent : true,
            isTyping: true,
            isSuccess: false,
            isError : false,
            cssClass: 'agent-msg agent-msg--agent'
        }];
        this._scrollMessages();
        return id;
    }

    _removeMessage(id) {
        this.agentMessages = this.agentMessages.filter(m => m.id !== id);
    }

    _scrollMessages() {
        // Scroll to bottom after render
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const container = this.template.querySelector('.agent-messages');
            if (container) container.scrollTop = container.scrollHeight;
        }, TIMING.SCROLL_DELAY);
    }

    // ────────────────────────────────────────────────────────
    // AGENT INPUT HANDLING
    // ────────────────────────────────────────────────────────
    handleAgentInputChange(event) {
        this.agentInput = event.target.value;
    }

    handleAgentInputKeydown(event) {
        if (event.key === 'Enter' && !this.agentSendDisabled) {
            this.handleAgentSend();
        }
    }

    get agentSendDisabled() {
        return this.agentIsProcessing || !this.agentInput || !this.agentInput.trim();
    }

    handleChipClick(event) {
        // Use getAttribute instead of dataset — dataset is unreliable in LWC shadow DOM
        const query = event.currentTarget.getAttribute('data-query');
        this.agentInput = query;
        this._processAgentQuery(query);
        this.agentInput = '';
    }

    handleAgentSend() {
        const query = (this.agentInput || '').trim();
        if (!query) return;
        this.agentInput = '';
        this._processAgentQuery(query);
    }

    // ── Called by the trash icon on list items ───────────────
    handleAgentDeleteFromList(event) {
        // Use getAttribute instead of dataset — dataset is unreliable in LWC shadow DOM
        const type = event.currentTarget.getAttribute('data-type');
        const name = event.currentTarget.getAttribute('data-name');
        const query = `Delete ${type} ${name}`;
        this._processAgentQuery(query);
    }

    // ────────────────────────────────────────────────────────
    // CORE AGENT QUERY PROCESSOR
    // ────────────────────────────────────────────────────────
    _processAgentQuery(rawQuery) {
        const query = rawQuery.trim();
        if (!query) return;

        this._addUserMsg(query);
        this.agentIsProcessing = true;
        const typingId = this._addTypingIndicator();

        // ── Check if waiting for type clarification ──────────
        if (this._pendingTypeSelect) {
            const lower = query.toLowerCase().trim();
            if (CONFIRM_NO.has(lower)) {
                this._pendingTypeSelect = null;
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                this._addAgentMsg('Deletion cancelled. Let me know if you need anything else.');
                return;
            }
            const { name, matches, replies } = this._pendingTypeSelect;
            // Match by reply keyword (e.g. "field1", "aura") or label
            let picked = null;
            if (replies) {
                const idx = replies.indexOf(lower);
                if (idx !== -1) picked = matches[idx];
            }
            if (!picked) {
                picked = matches.find(m =>
                    lower === m.type ||
                    lower === m.label.toLowerCase() ||
                    m.label.toLowerCase().includes(lower)
                );
            }
            if (picked) {
                this._pendingTypeSelect = null;
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                // Use apiName override for fields (Object.FieldName format)
                const resolvedName = picked.apiName || name;
                this._handleDeleteIntent({ action: 'delete', type: picked.type, name: resolvedName });
                return;
            } else {
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                const options = matches.map((m, i) => `• ${m.label} → reply "${replies ? replies[i] : m.type}"`).join('\n');
                this._addAgentMsg(`Sorry, I didn't understand. Please reply with the type to delete:\n${options}\n\nOr reply "no" to cancel.`);
                return;
            }
        }

        // ── Check if this is a delete confirmation ───────────
        if (this._pendingDelete) {
            const lower = query.toLowerCase();
            if (CONFIRM_YES.has(lower)) {
                const { type, name } = this._pendingDelete;
                this._pendingDelete = null;
                this._removeMessage(typingId);
                this._executeDelete(type, name);
                return;
            } else if (CONFIRM_NO.has(lower)) {
                this._pendingDelete = null;
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                this._addAgentMsg('Deletion cancelled. Let me know if you need anything else.');
                return;
            }
            // Not a confirmation — clear pending and process as new query
            this._pendingDelete = null;
        }

        // ── Check if this is a mass delete confirmation ───────
        if (this._pendingMassDelete) {
            const lower = query.toLowerCase();
            if (CONFIRM_YES.has(lower)) {
                const { type, names } = this._pendingMassDelete;
                this._pendingMassDelete = null;
                this._removeMessage(typingId);
                this._executeMassDelete(type, names);
                return;
            } else if (CONFIRM_NO.has(lower)) {
                this._pendingMassDelete = null;
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                this._addAgentMsg('Mass deletion cancelled. Let me know if you need anything else.');
                return;
            }
            this._pendingMassDelete = null;
        }

        // ── Parse intent ─────────────────────────────────────
        const intent = this._parseIntent(query);

        if (intent.action === 'delete') {
            this._removeMessage(typingId);
            this.agentIsProcessing = false;
            this._handleDeleteIntent(intent);
            return;
        }

        if (intent.action === 'mass-delete') {
            this._removeMessage(typingId);
            this.agentIsProcessing = false;
            this._handleMassDeleteIntent(intent);
            return;
        }

        // ── Rule-based backend ────────────────────────────────
        handleAgentQuery({ userQuery: query })
            .then(result => {
                this._removeMessage(typingId);
                const msg = result || 'No results returned.';
                this._addAgentMsg(msg);
                // Store as last data response for export — store whenever it contains metadata content
                const isHealthMsg = /ORG HEALTH REPORT|Org Health Report|Org health report|Total Issues:|Health Score|Org Size Summary/i.test(msg);
                const hasMetadata = isHealthMsg || msg.length > 50 || /flow|apex|trigger|lwc|aura|profile|permission|field|object|validation/i.test(msg);
                if (hasMetadata) this._lastDataResponse = msg;
                // If not a health report, clear stale org health export data so tab export takes over
                if (!isHealthMsg) this._lastOrgHealthData = null;
                this._refreshTabForIntent(intent);
            })
            .catch(err => {
                this._removeMessage(typingId);
                this._addAgentMsg('Sorry, I ran into an error: ' + this._errorMsg(err), false, true);
            })
            .finally(() => {
                this.agentIsProcessing = false;
            });
    }

    // ── Parse intent from plain-English query ────────────────
    _parseIntent(query) {

        // ════════════════════════════════════════════════════════════════════
        // PHASE 0 — PRE-NORMALISE  (Priority order: Synonyms → Cross-type → Typos)
        //
        // Designed for non-technical admins and clients who:
        //   • Don't remember exact Salesforce keyword names (synonyms)
        //   • Ask broad "what can I clean up?" questions (cross-type)
        //   • Type fast on mobile and make mistakes (typo tolerance)
        //
        // All transforms run on a working copy — original query never mutated.
        // Result feeds the rest of _parseIntent as if the user typed it correctly.
        // ════════════════════════════════════════════════════════════════════


        // ════════════════════════════════════════════════════════════════════
        // PRIORITY 1 — SYNONYM EXPANSION
        // "old flows", "dead classes", "cleanup candidates" — the most natural
        // way non-technical admins describe metadata.  Without this the tool
        // feels rigid and frustrating.
        //
        // Rules:
        //   • Multi-word phrases run BEFORE single-word patterns to avoid
        //     partial matches ("cleanup candidates" before "cleanup").
        //   • Filter synonyms run AFTER type synonyms so "old flows" first
        //     resolves "flows", then "old" → "unused".
        //   • Only replaces with canonical keywords already understood by
        //     the downstream detection logic — never invents new tokens.
        // ════════════════════════════════════════════════════════════════════
        const SYNONYMS = [
            // ── Flows ──────────────────────────────────────────────────────
            // Client language: "my automations", "process builder", "old workflows"
            { pattern: /\bprocess\s+builders?\b/gi,          replacement: 'flows' },
            { pattern: /\bscreen\s+flows?\b/gi,              replacement: 'flows' },
            { pattern: /\bauto[\s-]?launched?\s+flows?\b/gi, replacement: 'flows' },
            { pattern: /\bautomations?\b/gi,                 replacement: 'flows' },
            { pattern: /\bworkflows?\b/gi,                   replacement: 'flows' },
            { pattern: /\bscheduled\s+flows?\b/gi,           replacement: 'flows' },
            { pattern: /\bflow\s+processes?\b/gi,            replacement: 'flows' },

            // ── Apex Classes ───────────────────────────────────────────────
            // Client language: "scripts", "controllers", "batch jobs"
            { pattern: /\bbatch\s+(apex\s+)?jobs?\b/gi,      replacement: 'apex class' },
            { pattern: /\bscheduled\s+(apex\s+)?jobs?\b/gi,  replacement: 'apex class' },
            { pattern: /\bapex\s+scripts?\b/gi,              replacement: 'apex class' },
            { pattern: /\bapex\s+controllers?\b/gi,          replacement: 'apex class' },
            { pattern: /\bapex\s+helpers?\b/gi,              replacement: 'apex class' },
            { pattern: /\bapex\s+utilities\b/gi,             replacement: 'apex class' },
            { pattern: /\bapex\s+utils?\b/gi,                replacement: 'apex class' },
            { pattern: /\bcontrollers?\b/gi,                 replacement: 'apex class' },
            { pattern: /\bscripts?\b/gi,                     replacement: 'apex class' },

            // ── Triggers ───────────────────────────────────────────────────
            // Client language: "event handlers", "object triggers"
            { pattern: /\bobject\s+triggers?\b/gi,           replacement: 'triggers' },
            { pattern: /\bevent\s+handlers?\b/gi,            replacement: 'triggers' },
            { pattern: /\brecord[\s-]?triggered?\b/gi,       replacement: 'triggers' },

            // ── LWC ────────────────────────────────────────────────────────
            // Client language: "lightning components", "web components", "UI bits"
            { pattern: /\blightning\s+web\s+components?\b/gi, replacement: 'lwc' },
            { pattern: /\blwc\s+components?\b/gi,            replacement: 'lwc' },
            { pattern: /\bweb\s+components?\b/gi,            replacement: 'lwc' },
            { pattern: /\blightning\s+components?\b/gi,      replacement: 'lwc' },
            { pattern: /\bui\s+components?\b/gi,             replacement: 'lwc' },
            { pattern: /\bfront[\s-]?end\s+components?\b/gi, replacement: 'lwc' },

            // ── Aura ───────────────────────────────────────────────────────
            // Client language: "classic components", "old lightning components"
            { pattern: /\baura\s+components?\b/gi,           replacement: 'aura' },
            { pattern: /\bclassic\s+components?\b/gi,        replacement: 'aura' },
            { pattern: /\bold\s+lightning\s+components?\b/gi, replacement: 'aura' },
            { pattern: /\blegacy\s+components?\b/gi,         replacement: 'aura' },

            // ── Profiles ───────────────────────────────────────────────────
            // Client language: "user profiles", "access profiles", "user roles"
            { pattern: /\buser\s+profiles?\b/gi,             replacement: 'profiles' },
            { pattern: /\baccess\s+profiles?\b/gi,           replacement: 'profiles' },
            { pattern: /\bsecurity\s+profiles?\b/gi,         replacement: 'profiles' },

            // ── Permission Sets ────────────────────────────────────────────
            // Client language: "perm sets", "access sets", "user permissions"
            { pattern: /\bpermission\s+sets?\b/gi,           replacement: 'permset' },
            { pattern: /\bperm\s+sets?\b/gi,                 replacement: 'permset' },
            { pattern: /\baccess\s+sets?\b/gi,               replacement: 'permset' },
            { pattern: /\buser\s+permissions?\b/gi,          replacement: 'permset' },

            // ── Custom Fields ──────────────────────────────────────────────
            // Client language: "columns", "data fields", "sobject fields"
            { pattern: /\bcustom\s+fields?\b/gi,             replacement: 'field' },
            { pattern: /\bsobject\s+fields?\b/gi,            replacement: 'field' },
            { pattern: /\bdata\s+fields?\b/gi,               replacement: 'field' },
            { pattern: /\brecord\s+fields?\b/gi,             replacement: 'field' },
            { pattern: /\bcolumns?\b/gi,                     replacement: 'field' },

            // ── Custom Objects ─────────────────────────────────────────────
            // Client language: "tables", "entities", "data models", "sobjects"
            { pattern: /\bcustom\s+objects?\b/gi,            replacement: 'object' },
            { pattern: /\bsobjects?\b/gi,                    replacement: 'object' },
            { pattern: /\bdata\s+models?\b/gi,               replacement: 'object' },
            { pattern: /\bentities\b/gi,                     replacement: 'object' },
            { pattern: /\btables?\b/gi,                      replacement: 'object' },

            // ── Validation Rules ───────────────────────────────────────────
            // Client language: "val rules", "field rules", "record rules"
            { pattern: /\bvalidation\s+rules?\b/gi,          replacement: 'validation' },
            { pattern: /\bval\s+rules?\b/gi,                 replacement: 'validation' },
            { pattern: /\bfield\s+rules?\b/gi,               replacement: 'validation' },
            { pattern: /\brecord\s+rules?\b/gi,              replacement: 'validation' },
            { pattern: /\binput\s+rules?\b/gi,               replacement: 'validation' },

            // ── Visualforce ────────────────────────────────────────────────
            // Client language: "vf pages", "classic pages", "old pages"
            { pattern: /\bvf\s+components?\b/gi,             replacement: 'visualforce component' },
            { pattern: /\bvf\s+pages?\b/gi,                  replacement: 'visualforce page' },
            { pattern: /\bclassic\s+pages?\b/gi,             replacement: 'visualforce page' },
            { pattern: /\bold\s+pages?\b/gi,                 replacement: 'visualforce page' },
            { pattern: /\bapex\s+pages?\b/gi,                replacement: 'visualforce page' },

            // ── Filter intent — "unused / cleanup" language ────────────────
            // These are the MOST IMPORTANT synonyms for a cleanup tool.
            // Client language: "what can I delete?", "cleanup candidates", "dead code"
            { pattern: /\bcleanup\s+candidates?\b/gi,        replacement: 'unused' },
            { pattern: /\bdelete\s+candidates?\b/gi,         replacement: 'unused' },
            { pattern: /\bremoval\s+candidates?\b/gi,        replacement: 'unused' },
            { pattern: /\bcan\s+be\s+deleted\b/gi,           replacement: 'unused' },
            { pattern: /\bsafe\s+to\s+(delete|remove)\b/gi,  replacement: 'unused' },
            { pattern: /\bok\s+to\s+(delete|remove)\b/gi,    replacement: 'unused' },
            { pattern: /\bno\s+longer\s+needed\b/gi,         replacement: 'unused' },
            { pattern: /\bnot\s+(in\s+)?used?\b/gi,          replacement: 'unused' },
            { pattern: /\bnot\s+being\s+used\b/gi,           replacement: 'unused' },
            { pattern: /\bno[t]?\s+used\b/gi,                replacement: 'unused' },
            { pattern: /\bnever\s+used\b/gi,                 replacement: 'unused' },
            { pattern: /\bdead\s+code\b/gi,                  replacement: 'unused' },
            { pattern: /\bdead\b/gi,                         replacement: 'unused' },
            { pattern: /\blegacy\b/gi,                       replacement: 'unused' },   // "legacy flows" → "unused flows"
            { pattern: /\bold\b/gi,                          replacement: 'unused' },   // "old classes"  → "unused classes"
            { pattern: /\bobsolete\b/gi,                     replacement: 'unused' },
            { pattern: /\bstale\b/gi,                        replacement: 'unused' },
            { pattern: /\bjunk\b/gi,                         replacement: 'unused' },
            { pattern: /\bleftover\b/gi,                     replacement: 'unused' },
            { pattern: /\babandon(ed)?\b/gi,                 replacement: 'unused' },
            { pattern: /\borphan(ed)?\b/gi,                  replacement: 'unused' },

            // ── Filter intent — "inactive / disabled" language ─────────────
            { pattern: /\bnot\s+active\b/gi,                 replacement: 'inactive' },
            { pattern: /\bturned\s+off\b/gi,                 replacement: 'inactive' },
            { pattern: /\bdisabled\b/gi,                     replacement: 'inactive' },
            { pattern: /\bdeactivated\b/gi,                  replacement: 'inactive' },
            { pattern: /\bpaused\b/gi,                       replacement: 'inactive' },
            { pattern: /\bswitched\s+off\b/gi,               replacement: 'inactive' },

            // ── Filter intent — "active / running" language ────────────────
            { pattern: /\bcurrently\s+running\b/gi,          replacement: 'active' },
            { pattern: /\bturned\s+on\b/gi,                  replacement: 'active' },
            { pattern: /\benabled\b/gi,                      replacement: 'active' },
            { pattern: /\blive\b/gi,                         replacement: 'active' },
            { pattern: /\bin\s+use\b/gi,                     replacement: 'used' },
            { pattern: /\bactually\s+used\b/gi,              replacement: 'used' },
            { pattern: /\bstill\s+used\b/gi,                 replacement: 'used' },
            { pattern: /\bstill\s+active\b/gi,               replacement: 'active' },
            { pattern: /\bstill\s+running\b/gi,              replacement: 'active' },

            // ── Filter intent — "unassigned / empty" language ──────────────
            { pattern: /\bnot\s+assigned\b/gi,               replacement: 'unused' },
            { pattern: /\bno\s+assignees?\b/gi,              replacement: 'unused' },
            { pattern: /\bzero\s+users?\b/gi,                replacement: 'unused' },
            { pattern: /\bno\s+users?\b/gi,                  replacement: 'unused' },
            { pattern: /\bempty\s+profiles?\b/gi,            replacement: 'unused profiles' },
            { pattern: /\bunassigned\b/gi,                   replacement: 'unused' },
        ];

        const synonymExpand = (text) => {
            let out = text;
            for (const { pattern, replacement } of SYNONYMS) {
                out = out.replace(pattern, replacement);
            }
            return out;
        };


        // ════════════════════════════════════════════════════════════════════
        // PRIORITY 2 — CROSS-TYPE INTENT DETECTION
        // "What can I clean up?", "show me everything unused", "org health" —
        // the single most common question a client opens this dashboard to ask.
        // Returns ALL tabs at once with the appropriate filter applied.
        //
        // Runs AFTER synonym expansion so "what can I remove?" → "what unused?"
        // is caught here before the downstream single-tab logic runs.
        // ════════════════════════════════════════════════════════════════════
        const ALL_TABS = Object.values(TAB);

        // Helper: extract cardFilter from a normalized string
        const _extractCardFilter = (s) => {
            if      (/\bunused\b/i.test(s))                                       return FILTER.UNUSED;
            else if (/\binactive\b/i.test(s))                                     return FILTER.INACTIVE;
            else if (/\bactive\b/i.test(s) && !/\binactive\b/i.test(s))          return FILTER.ACTIVE;
            else if (/\bstandard\b/i.test(s))                                     return FILTER.STANDARD;
            else if (/\bunreferenced\b/i.test(s))                                 return FILTER.UNREFERENCED;
            else if (/\breferenced\b/i.test(s) && !/\bunreferenced\b/i.test(s))  return FILTER.REFERENCED;
            else if (/\bused\b/i.test(s) && !/\bunused\b/i.test(s))              return FILTER.USED;
            return null;
        };

        // Patterns that signal "show me everything" regardless of type.
        // Ordered: question forms first (most specific), then broad nouns.
        const CROSS_TYPE_PATTERNS = [
            // ── Direct cleanup questions (most natural client queries)
            /\bwhat\s+(can|should)\s+i\s+(delete|remove|clean\s*up|get\s*rid\s*of)\b/i,
            /\bwhat('s|\s+is)\s+(safe|ok|okay)\s+to\s+(delete|remove)\b/i,
            /\bwhat\s+unused\b/i,
            /\bshow\s+me\s+(what('s|\s+is)\s+)?(unused|inactive|everything|all)\b/i,
            /\bgive\s+me\s+(the\s+)?(full\s+)?(picture|overview|summary|report)\b/i,
            /\borg\s+(health|audit|review|report|summary|overview|cleanup)\b/i,
            /\bfull\s+(org\s+)?(overview|picture|audit|summary|report)\b/i,
            /\bcleanup\s+report\b/i,
            /\bwhat\s+should\s+i\s+know\b/i,
            /\bwhere\s+do\s+i\s+start\b/i,
            /\bwhat('s|\s+is)\s+in\s+my\s+org\b/i,
            /\bwhat\s+do\s+i\s+have\b/i,
            /\bshow\s+me\s+everything\b/i,
            /\breduce\s+(my\s+)?org\s+size\b/i,
            /\bshrink\s+(my\s+)?org\b/i,
            // ── Broad scope signals
            /\beverything\b/i,
            /\bwhole\s+org\b/i,
            /\bentire\s+org\b/i,
            /\ball\s+metadata\b/i,
            /\ball\s+types\b/i,
            /\ball\s+components\b/i,
            /\ball\s+of\s+(it|them|my\s+org)\b/i,
            /\ball\s+(unused|inactive|active|dead|stale|obsolete)\b/i,
            /\ball\s+(the\s+)?(my\s+)?(org\s+)?(items?|stuff|things?)\b/i,
        ];

        // ── Apply pipeline: synonym expansion first ───────────────────────
        // Synonyms run first so "cleanup candidates" → "unused", "automations" → "flows"
        // BEFORE cross-type and typo logic evaluate the text.
        const afterSynonyms = synonymExpand(query.toLowerCase());

        // Cross-type short-circuit — must happen before typo correction and
        // before single-tab detection so broad queries don't partially match one tab.
        for (const pat of CROSS_TYPE_PATTERNS) {
            if (pat.test(afterSynonyms)) {
                return {
                    action    : 'query',
                    tab       : ALL_TABS[0],
                    tabs      : ALL_TABS,
                    cardFilter: _extractCardFilter(afterSynonyms)
                };
            }
        }


        // ════════════════════════════════════════════════════════════════════
        // PRIORITY 3 — TYPO TOLERANCE
        // Clients type fast on mobile: "shwo flows", "apx class", "permisson set"
        // Silent failures feel like bugs.  We correct distance-1 typos for short
        // keywords and distance-2 for longer ones (≥8 chars).
        //
        // Runs AFTER synonym expansion and cross-type so it never interferes
        // with the higher-priority transforms.
        // ════════════════════════════════════════════════════════════════════

        // _lev(a,b) — standard Levenshtein with early exit on length diff
        const _lev = (a, b) => {
            if (a === b) return 0;
            if (Math.abs(a.length - b.length) > 2) return 99;
            const m = a.length, n = b.length;
            const dp = Array.from({ length: m + 1 }, (_, i) => {
                const row = new Array(n + 1).fill(0);
                row[0] = i;
                return row;
            });
            for (let j = 0; j <= n; j++) dp[0][j] = j;
            for (let i = 1; i <= m; i++) {
                for (let j = 1; j <= n; j++) {
                    dp[i][j] = a[i-1] === b[j-1]
                        ? dp[i-1][j-1]
                        : 1 + Math.min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]);
                }
            }
            return dp[m][n];
        };

        // Canonical keywords to fuzzy-correct toward, ordered longest-first so
        // "triggers" beats "trigger" when both are distance-1 from a typo.
        const TYPO_TARGETS = [
            // type keywords (longer first)
            'triggers', 'trigger',
            'visualforce', 'validation',
            'profiles', 'profile',
            'permsets', 'permset', 'permission',
            'classes', 'class',
            'fields', 'field',
            'objects', 'object',
            'flows', 'flow',
            'aura', 'apex', 'lwc',
            // action / filter keywords
            'inactive', 'active',
            'unused', 'used',
            'standard',
            'unreferenced', 'referenced',
            'delete', 'show', 'list',
        ];

        // Real English words that happen to be 1–2 edits away from our keywords.
        // These must NEVER be auto-corrected.
        const TYPO_GUARD = new Set([
            // near "flow/flows"
            'blow', 'slow', 'glow', 'plow', 'flew', 'flaw', 'slows', 'glows',
            // near "apex"
            'apes', 'axes',
            // near "class/classes"
            'clash', 'claws', 'glass', 'brass',
            // near "field/fields"
            'yield', 'wield', 'fiend', 'filed',
            // near "object"
            'abject',
            // near "active/inactive"
            'native', 'captive',
            // near "show"
            'shoe', 'shot', 'shop', 'shod', 'shook',
            // near "list"
            'fist', 'mist', 'gist', 'last', 'lost', 'lust', 'lest',
            // near "used/unused"
            'user', 'uses', 'fused', 'mused',
            // near "delete"
            'dilute', 'devote',
            // keep these intact always
            'aura', 'lwc', 'vf', 'vr',
        ]);

        const typoNormalize = (raw) => {
            return raw.split(/\b/).map(tok => {
                const t = tok.toLowerCase();
                if (!/^[a-z]{3,}$/.test(t)) return tok;  // skip non-alpha or <3 chars
                if (TYPO_GUARD.has(t))       return tok;  // protect real English words
                for (const canonical of TYPO_TARGETS) {
                    if (t === canonical) return tok;       // already correct — skip
                    // Allow distance-2 for longer keywords (≥8 chars like "validation")
                    // to catch "validaton", "permisson", "unrefrenced"
                    const maxDist = canonical.length >= 8 ? 2 : 1;
                    if (_lev(t, canonical) <= maxDist) return canonical;
                }
                return tok;
            }).join('');
        };

        // Final normalized query — typo-corrected on top of synonym-expanded text
        const normalized = typoNormalize(afterSynonyms);
        const lower = normalized.toLowerCase();

        // ════════════════════════════════════════════════════════════════════
        // END PHASE 0 — downstream logic unchanged below
        // ════════════════════════════════════════════════════════════════════

        // Delete patterns
        const deleteMatch = lower.match(/^delete\s+/i);
        if (deleteMatch) {
            // ── TYPE DETECTION — strict prefix-only, zero ambiguity ──────────
            //
            // The only reliable way to distinguish the type keyword from the
            // component name is to check whether the string immediately after
            // "delete " is an EXACT known type token.
            //
            // Component names like "BSR_Flow_Call_Apex_Class" or
            // "My_Apex_Trigger_Handler" must NEVER trigger type detection —
            // they start with "BSR_" / "My_", not with a type keyword.
            //
            // Rules:
            //   • Two-word tokens checked first (e.g. "apex class", "custom field")
            //   • Single-word tokens checked second
            //   • If first token(s) do NOT match any type → type = null
            //     → _handleDeleteIntent searches all loaded lists by name
            //
            // What the user types       → prefixOne / prefixTwo   → type
            // ─────────────────────────────────────────────────────────────
            // delete flow My_Flow        → "flow"                  → FLOW
            // delete BSR_Flow_Call_Apex  → "bsr_flow_call_apex"    → null (ambiguous lookup)
            // delete apex class MyClass  → "apex class"            → APEX
            // delete apex MyClass        → "apex"                  → APEX
            // delete BSR_Apex_Handler    → "bsr_apex_handler"      → null
            // ─────────────────────────────────────────────────────────────

            const afterDelete = normalized.replace(/^delete\s+/i, '').trim();
            const tokens      = afterDelete.split(/\s+/);
            const p1 = tokens[0] ? tokens[0].toLowerCase() : '';
            const p2 = (tokens[0] && tokens[1]) ? (tokens[0] + ' ' + tokens[1]).toLowerCase() : '';
            const p3 = (tokens[0] && tokens[1] && tokens[2])
                       ? (tokens[0] + ' ' + tokens[1] + ' ' + tokens[2]).toLowerCase() : '';
            // Case-preserved version — used ONLY for rawName extraction below.
            // normalized is derived from query.toLowerCase(), so it loses original casing.
            // Salesforce FlowDefinitionView.ApiName SOQL WHERE clauses are case-sensitive,
            // so "bsr_case" won't match "BSR_Case". We extract names from the original query.
            const afterDeleteOrigCase = query.replace(/^delete\s+/i, '').trim();

            // Strict exact-match type token table
            // Two-word tokens must be checked before one-word to avoid "apex" matching "apex class"
            const TYPE_TOKENS = [
                // two-word
                { match: p2, types: ['validation rule', 'val rule'],    type: META_TYPE.VR,      strip: 2 },
                { match: p2, types: ['custom field'],                   type: META_TYPE.FIELD,   strip: 2 },
                { match: p2, types: ['custom object'],                  type: META_TYPE.OBJECT,  strip: 2 },
                { match: p2, types: ['permission set', 'perm set'],     type: META_TYPE.PERMSET, strip: 2 },
                { match: p2, types: ['permission sets', 'perm sets'],   type: META_TYPE.PERMSET, strip: 2 },
                { match: p2, types: ['apex class', 'apex classes'],     type: META_TYPE.APEX,    strip: 2 },
                { match: p2, types: ['vf page', 'vf pages'],            type: META_TYPE.VF,      strip: 2 },
                { match: p2, types: ['vf component', 'vf components'],  type: META_TYPE.VFC,     strip: 2 },
                { match: p2, types: ['apex page', 'apex pages'],        type: META_TYPE.VF,      strip: 2 },
                { match: p2, types: ['visualforce page', 'visualforce pages'],       type: META_TYPE.VF,  strip: 2 },
                { match: p2, types: ['visualforce component', 'visualforce components'], type: META_TYPE.VFC, strip: 2 },
                { match: p2, types: ['lightning web'],                  type: META_TYPE.LWC,     strip: 2 },
                // three-word
                { match: p3, types: ['lightning web component',
                                     'lightning web components'],       type: META_TYPE.LWC,     strip: 3 },
                // one-word
                { match: p1, types: ['flow', 'flows'],                  type: META_TYPE.FLOW,    strip: 1 },
                { match: p1, types: ['trigger', 'triggers'],            type: META_TYPE.TRIGGER, strip: 1 },
                { match: p1, types: ['lwc'],                            type: META_TYPE.LWC,     strip: 1 },
                { match: p1, types: ['aura'],                           type: META_TYPE.AURA,    strip: 1 },
                { match: p1, types: ['apex'],                           type: META_TYPE.APEX,    strip: 1 },
                { match: p1, types: ['profile', 'profiles'],            type: META_TYPE.PROFILE, strip: 1 },
                { match: p1, types: ['permset', 'permsets'],            type: META_TYPE.PERMSET, strip: 1 },
                { match: p1, types: ['field'],                          type: META_TYPE.FIELD,   strip: 1 },
                { match: p1, types: ['object'],                         type: META_TYPE.OBJECT,  strip: 1 },
                { match: p1, types: ['vr'],                             type: META_TYPE.VR,      strip: 1 },
                { match: p1, types: ['vf', 'vfpage', 'vfpages'],        type: META_TYPE.VF,      strip: 1 },
                { match: p1, types: ['vfc', 'vfcomponent', 'vfcomponents'], type: META_TYPE.VFC, strip: 1 },
                { match: p1, types: ['visualforce'],                    type: META_TYPE.VF,      strip: 1 },
            ];

            let type        = null;
            let typeStrip   = 0; // how many tokens to strip for the name

            for (const entry of TYPE_TOKENS) {
                if (entry.types.includes(entry.match)) {
                    type      = entry.type;
                    typeStrip = entry.strip;
                    break;
                }
            }

            // Extract name — strip the type token(s) from the front
            let rawName = null;
            if (typeStrip > 0) {
                // Strip the type keyword token(s) from the ORIGINAL-CASE string so the
                // component name preserves its casing (e.g. "BSR_Case" not "bsr_case").
                // Salesforce SOQL WHERE ApiName = '...' is case-sensitive.
                const origTokens = afterDeleteOrigCase.split(/\s+/);
                rawName = origTokens.slice(typeStrip).join(' ').trim() || null;
            } else {
                // No type keyword — dot notation check for field/vr, otherwise ambiguous
                const dotNameMatch = query.match(/delete\s+([A-Za-z0-9_]+\.[A-Za-z0-9_]+)/i);
                if (dotNameMatch) {
                    const dotName = afterDeleteOrigCase.trim();
                    // Search VR lists (now enriched with dotName) to distinguish VR from Field
                    const allVr = [...(this.activeVrList || []), ...(this.inactiveVrList || [])];
                    const vrMatch = allVr.find(r => r.dotName && r.dotName.toLowerCase() === dotName.toLowerCase());
                    type    = vrMatch ? META_TYPE.VR : META_TYPE.FIELD;
                    rawName = dotName;
                } else {
                    rawName = afterDeleteOrigCase || null;
                }
            }

            // ── Mass delete: detect comma-separated names ─────
            if (rawName && rawName.includes(',')) {
                // Split by comma; for non-dot types trim spaces; for dot-types (field/vr) keep dots
                const names = rawName.split(',').map(n => {
                    const t = n.trim();
                    // Only replace spaces with underscores for Apex (API names can't have spaces)
                    // Flow, Trigger, LWC, Aura, Object, PermSet, Profile keep spaces as-is
                    // because the user may type the API name with underscores already
                    return type === META_TYPE.APEX ? t.replace(/\s+/g, '_') : t;
                }).filter(Boolean);
                if (names.length > 1) {
                    return { action: 'mass-delete', type, names };
                }
                // Only one after split — fall through to single delete
                rawName = names[0] || rawName;
            }

            // Single name — only normalise spaces→underscores for Apex
            const name = rawName
                ? (type === META_TYPE.APEX ? rawName.replace(/\s+/g, '_') : rawName)
                : null;

            // Auto-detect object type from __c suffix if no explicit type keyword
            if (type === null && name && name.toLowerCase().endsWith('__c')) {
                type = META_TYPE.OBJECT;
            }
            // Do NOT default to APEX here — leave type as null so _handleDeleteIntent
            // can search all loaded lists (flows, apex, triggers, etc.) and find the right type.
            // Defaulting to APEX caused "delete Send Verification Code" to attempt Apex deletion
            // even when that name belonged to a Flow.

            return { action: 'delete', type, name };
        }

        // ── Multi-tab detection — collect ALL matching tabs ───────────
        const tabs = [];

        if (lower.includes('flow'))                                                         tabs.push(TAB.FLOWS);
        // Trigger keywords → triggers only
        if (lower.includes('trigger'))                                                      tabs.push(TAB.TRIGGERS);
        // 'apex class' or 'class' explicitly → classes only
        if ((lower.includes('apex') && lower.includes('class')) || 
            (lower.includes('class') && !lower.includes('trigger')))                        tabs.push(TAB.APEX);
        // 'apex' alone (no 'class', no 'trigger') → show BOTH apex classes + triggers
        if (lower.includes('apex') && !lower.includes('class') && !lower.includes('trigger')) {
            tabs.push(TAB.APEX);
            tabs.push(TAB.TRIGGERS);
        }
        if (lower.includes('lwc') || lower.includes('lightning web') ||
            lower.includes('lightning component'))                                          tabs.push(TAB.LWC);
        if (lower.includes('aura'))                                                         tabs.push(TAB.AURA);
        if (lower.includes('profile'))                                                      tabs.push(TAB.PROFILES);
        if (lower.includes('permission sets') || lower.includes('permission set') ||
            lower.includes('perm sets') || lower.includes('perm set') ||
            lower.includes('permsets') || lower.includes('permset') ||
            lower.includes('permission'))                                                   tabs.push(TAB.PERMSETS);
        if (lower.includes('field'))                                                        tabs.push(TAB.FIELDS);
        if (lower.includes('object') || lower.includes('sobject') ||
            lower.includes('custom object'))                                                tabs.push(TAB.OBJECTS);
        if (lower.includes('validation') || lower.includes('val rule') ||
            lower.includes('validation rule') || lower.includes('rules'))                   tabs.push(TAB.VR);
        if ((lower.includes('visualforce') || lower.includes('vf page') ||
            lower.includes('vf pages') || lower.includes('apex page')) &&
            !lower.includes('component'))                                                    tabs.push(TAB.VF);
        if (lower.includes('vf component') || lower.includes('vf components') ||
            lower.includes('visualforce component') || lower.includes('apex component'))     tabs.push(TAB.VFC);

        // ── Sub-filter detection — detect which card filter to activate ──────
        // Maps natural-language keywords to FILTER constants so that
        // "show standard apex classes" → FILTER.STANDARD
        // "show referenced triggers"   → FILTER.REFERENCED
        // etc.
        let cardFilter = null;
        if      (/\bstandard\b/i.test(lower))                              cardFilter = FILTER.STANDARD;
        else if (/\btest class|\btest apex\b/i.test(lower))                cardFilter = FILTER.TEST;
        else if (/\bunused\b/i.test(lower))                                cardFilter = FILTER.UNUSED;
        else if (/\bused\b/i.test(lower) && !/\bunused\b/i.test(lower))   cardFilter = FILTER.USED;
        else if (/\binactive\b/i.test(lower))                              cardFilter = FILTER.INACTIVE;
        else if (/\bactive\b/i.test(lower) && !/\binactive\b/i.test(lower)) cardFilter = FILTER.ACTIVE;
        else if (/\bunreferenced\b/i.test(lower))                          cardFilter = FILTER.UNREFERENCED;
        else if (/\breferenced\b/i.test(lower) && !/\bunreferenced\b/i.test(lower)) cardFilter = FILTER.REFERENCED;

        if (tabs.length > 0) {
            return { action: 'query', tab: tabs[0], tabs, cardFilter };
        }

        return { action: 'query', tab: null, tabs: [], cardFilter: null };
    }

    // ── Delete intent: show confirmation message ──────────────
    _handleDeleteIntent(intent) {
        if (!intent.name) {
            this._addAgentMsg('Please specify the name of the component to delete.\nExamples:\n• "delete apex class LeadScoringBatch"\n• "delete flow MyFlow"\n• "delete aura BSR"\n• "delete field Account.EM_Kishore"\n• "delete vr Account.MyRule"\n• "delete object MyObject__c"');
            return;
        }
        // For field/vr without dot, prompt for correct format before confirming
        if ((intent.type === META_TYPE.FIELD || intent.type === META_TYPE.VR) && !intent.name.includes('.')) {
            const ex = intent.type === META_TYPE.FIELD ? 'Account.EM_Kishore' : 'Account.MyRule';
            this._addAgentMsg(`Please include the object name.\nFormat: "delete ${intent.type} ObjectName.ComponentName"\nExample: "delete ${intent.type} ${ex}"`);
            return;
        }

        // ── No explicit type — search all loaded data ─────────
        if (!intent.type) {
            const n = intent.name.toLowerCase();
            const matches = [];
            const check = (list, type, label) => {
                if (list && list.some(item => item.name && item.name.toLowerCase() === n)) {
                    if (!matches.find(m => m.type === type)) matches.push({ type, label });
                }
            };
            // Flows: search allFlowObjects which has separate label and apiName.
            // item.name in activeFlowList/inactiveFlowList is the full formatted string
            // (e.g. "Send Verification Code (Send_Verification_Code) [AutoLaunchedFlow] [ACTIVE]")
            // so we must match against f.label and store f.apiName for the delete call.
            const checkFlows = () => {
                if (!this.flowSummary || !this.flowSummary.allFlowObjects) return;
                // Normalised version of what the user typed: spaces→underscores
                // e.g. "bsr_create opp related on account" → "bsr_create_opp_related_on_account"
                const nNorm = n.replace(/\s+/g, '_');
                for (const f of this.flowSummary.allFlowObjects) {
                    const labelLower = f.label   ? f.label.toLowerCase()   : '';
                    const apiLower   = f.apiName ? f.apiName.toLowerCase() : '';
                    // Normalise label too (replace spaces with underscores for comparison)
                    const labelNorm  = labelLower.replace(/\s+/g, '_');

                    const matched =
                        labelLower === n     ||   // exact label match  (BSR_Case Create Related On Account)
                        apiLower   === n     ||   // exact apiName match (BSR_Create_Opp_Related_On_Account)
                        apiLower   === nNorm ||   // user typed spaces, API has underscores
                        labelNorm  === nNorm ||   // label normalised == input normalised
                        labelNorm  === n;         // normalised label matches raw input

                    if (matched) {
                        if (!matches.find(m => m.type === META_TYPE.FLOW)) {
                            matches.push({ type: META_TYPE.FLOW, label: `Flow (${f.apiName})`, apiName: f.apiName });
                        }
                        break;
                    }
                }
            };
            // Fields: item.name is label only (e.g. "EM_Mayank"), but delete needs full "Object.Field"
            // So search by label, but store all matching api names for clarification
            const checkFields = (list) => {
                if (!list) return;
                const hits = list.filter(item => {
                    const parts = item.name.split('.');
                    const fieldLabel = (parts[1] || parts[0]).replace(/__c$/i, '').toLowerCase();
                    return fieldLabel === n || item.name.toLowerCase() === n;
                });
                hits.forEach(item => {
                    if (!matches.find(m => m.type === META_TYPE.FIELD && m.apiName === item.name)) {
                        matches.push({ type: META_TYPE.FIELD, label: `Custom Field (${item.name})`, apiName: item.name });
                    }
                });
            };
            checkFlows();
            check([...(this.unusedClassList || []), ...(this.usedClassList || []), ...(this.testClassList || []), ...(this.standardClassList || [])], META_TYPE.APEX, 'Apex Class');
            check([...(this.activeTriggerList || []), ...(this.inactiveTriggerList || []), ...(this.unusedTriggerList || [])], META_TYPE.TRIGGER, 'Trigger');
            check(this.allLwcList,  META_TYPE.LWC,    'LWC Component');
            check(this.allAuraList, META_TYPE.AURA,   'Aura Component');
            // PermSets checked BEFORE Profiles — same name can exist in both.
            // Use raw objects (.name = API name) so spaces in labels don't break delete.
            const psObjects = [
                ...((this.permSetSummary && this.permSetSummary.usedPermSetObjects)   || []),
                ...((this.permSetSummary && this.permSetSummary.unusedPermSetObjects) || [])
            ];
            if (psObjects.length > 0) {
                // Match on API name (Name) OR label — store API name as apiName for delete
                psObjects.forEach(ps => {
                    if (!ps) return;
                    const apiName = ps.name || '';
                    const lbl     = (ps.label || ps.name || '').toLowerCase();
                    if (apiName.toLowerCase() === n || lbl === n) {
                        if (!matches.find(m => m.type === META_TYPE.PERMSET && m.apiName === apiName)) {
                            matches.push({ type: META_TYPE.PERMSET, label: `Permission Set (${apiName})`, apiName });
                        }
                    }
                });
            } else {
                // Fallback: parsed display list (label only)
                check([...(this.unusedPermSetList || []), ...(this.usedPermSetList || [])], META_TYPE.PERMSET, 'Permission Set');
            }
            check([...(this.unusedProfileList || []), ...(this.usedProfileList || [])],   META_TYPE.PROFILE, 'Profile');
            // VR: match on dotName (Object.Rule) OR just rule name
            const allVrItems = [...(this.activeVrList || []), ...(this.inactiveVrList || [])];
            if (allVrItems.some(item =>
                (item.dotName  && item.dotName.toLowerCase()  === n) ||
                (item.name     && item.name.toLowerCase()     === n)
            )) {
                const vrHit = allVrItems.find(item =>
                    (item.dotName  && item.dotName.toLowerCase()  === n) ||
                    (item.name     && item.name.toLowerCase()     === n)
                );
                if (!matches.find(m => m.type === META_TYPE.VR)) {
                    matches.push({ type: META_TYPE.VR, label: `Validation Rule (${vrHit.dotName || vrHit.name})`, apiName: vrHit.dotName });
                }
            }
            checkFields(this.allFieldList);
            // Custom objects: item.name is "EM_Mayank__c" format
            if (this.allObjectList) {
                this.allObjectList.forEach(item => {
                    const objName = (item.name || '').toLowerCase().replace(/__c$/i, '');
                    if (objName === n || item.name.toLowerCase() === n || item.name.toLowerCase() === n + '__c') {
                        if (!matches.find(m => m.type === META_TYPE.OBJECT)) {
                            const apiName = item.name.endsWith('__c') ? item.name : item.name + '__c';
                            matches.push({ type: META_TYPE.OBJECT, label: `Custom Object (${apiName})`, apiName });
                        }
                    }
                });
            }

            if (matches.length === 0) {
                // Nothing found in loaded data — ask the user to include the type keyword
                // rather than blindly defaulting to Apex (which caused flow names to be sent
                // to the Apex delete function).
                this._addAgentMsg(
                    `⚠️ Could not find "${intent.name}" in the loaded metadata.\n\n` +
                    `Please include the type in your command. Examples:\n` +
                    `  • delete flow ${intent.name}\n` +
                    `  • delete apex class ${intent.name}\n` +
                    `  • delete trigger ${intent.name}\n` +
                    `  • delete lwc ${intent.name}\n` +
                    `  • delete permset ${intent.name}\n` +
                    `  • delete profile ${intent.name}\n\n` +
                    `Or make sure the relevant tab is loaded first.`
                );
                return;
            } else if (matches.length === 1) {
                // Exactly one match — but tell the user what type was matched
                // so they can correct it if wrong (e.g. Profile matched instead of PermSet)
                intent.type = matches[0].type;
                if (matches[0].apiName) intent.name = matches[0].apiName;
                // Inject the matched type into the confirmation message so the user sees it
                // The _showDeleteConfirmation flow below will show the typeLabel anyway,
                // so no additional message needed here.
            } else {
                // Multiple matches — ask user to clarify
                // For fields, show numbered options since same label can exist on multiple objects
                this._pendingTypeSelect = { name: intent.name, matches };
                const options = matches.map((m, i) => `• ${m.label} → reply "${m.apiName ? 'field' + (i+1) : m.type}"`).join('\n');
                const replies = matches.map((m, i) => m.apiName ? `field${i+1}` : m.type);
                this._pendingTypeSelect.replies = replies;
                this._addAgentMsg(`Found "${intent.name}" in multiple types:\n${options}\n\nWhich one do you want to delete? (or reply "no" to cancel)`);
                return;
            }
        }

        const typeLabels = {
            apex: 'Apex Class', flow: 'Flow', trigger: 'Trigger', lwc: 'LWC Component',
            aura: 'Aura Component', field: 'Custom Field', object: 'Custom Object',
            permset: 'Permission Set', profile: 'Profile', vr: 'Validation Rule',
            vf: 'Visualforce Page', vfc: 'VF Component'
        };
        const typeLabel  = typeLabels[intent.type] || intent.type;

        // ── Map LWC type to MetadataEngine componentType string ──────────────────
        const typeToMCDType = {
            flow:    'Flow',
            apex:    'ApexClass',
            trigger: 'ApexTrigger',
            lwc:     'LightningComponentBundle',
            aura:    'AuraDefinitionBundle',
            object:  'CustomObject',
            field:   'CustomField',
            vr:      'ValidationRule',
            permset: 'PermissionSet',
            profile: 'Profile',
            vf:      'ApexPage',
            vfc:     'ApexComponent'
        };
        const mcdType = typeToMCDType[intent.type] || intent.type;

        // ── Check references BEFORE showing confirmation ──────────────────────────
        const typingId = this._addTypingIndicator();
        this.agentIsProcessing = true;

        checkReferences({ componentName: intent.name, componentType: mcdType })
            .then(refReport => {
                this._removeMessage(typingId);
                this.agentIsProcessing = false;

                if (refReport) {
                    // References found — block delete.
                    // If the Apex side already returned a fully-formatted, self-contained
                    // message (starts with ❌ or ⚠️ — typically Profile / PermSet / Field /
                    // VR / VF blockers), show it as-is. Otherwise wrap it in the legacy
                    // "Cannot delete ... — references found:" shell.
                    const trimmed       = refReport.trimStart();
                    const isPreFormatted = trimmed.startsWith('❌') || trimmed.startsWith('⚠️');
                    if (isPreFormatted) {
                        this._addAgentMsg(refReport);
                    } else {
                        this._addAgentMsg(
                            `⚠️ Cannot delete ${typeLabel} "${intent.name}" — references found:\n\n` +
                            refReport
                        );
                    }
                } else {
                    // No references found in pre-check — show confirmation
                    this._pendingDelete = { type: intent.type, name: intent.name };

                    // For inactive flows: warn that Salesforce MCD does not reliably index
                    // inactive flows, so references may exist that the pre-check missed.
                    let inactiveWarning = '';
                    if (intent.type === META_TYPE.FLOW) {
                        const flowObj = this.flowSummary && this.flowSummary.allFlowObjects &&
                            this.flowSummary.allFlowObjects.find(f =>
                                (f.apiName && f.apiName.toLowerCase() === intent.name.toLowerCase()) ||
                                (f.label   && f.label.toLowerCase()   === intent.name.toLowerCase())
                            );
                        if (flowObj && !flowObj.isActive) {
                            inactiveWarning = `⚠️ This flow is INACTIVE. Salesforce does not always index inactive flows in its dependency tracker, so references may exist that the pre-check could not detect.\n\n`;
                        }
                    }

                    this._addAgentMsg(
                        `Found: ${intent.name} (${typeLabel})\n` +
                        `No references found in pre-check.\n\n` +
                        inactiveWarning +
                        `Are you sure you want to delete this component? This cannot be undone.\n\n` +
                        `Reply "yes" to confirm or "no" to cancel.`
                    );
                }
            })
            .catch(() => {
                // Reference check failed — still show confirmation (fail open)
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                this._pendingDelete = { type: intent.type, name: intent.name };
                this._addAgentMsg(
                    `Found: ${intent.name} (${typeLabel})\n` +
                    `Are you sure you want to delete this component? This cannot be undone.\n\n` +
                    `Reply "yes" to confirm or "no" to cancel.`
                );
            });
    }

    // ── Execute the actual delete ─────────────────────────────
    _executeDelete(type, name) {
        // Snapshot the issue count BEFORE delete for before/after comparison
        this._prevIssueCount = this.liveIssueCount;
        this._scoreFlash = false;
        const typingId = this._addTypingIndicator();
        this.agentIsProcessing = true;

        let deletePromise;

        if (type === META_TYPE.APEX) {
            deletePromise = deleteApexClass({ apexClassName: name });
        } else if (type === META_TYPE.FLOW) {
            deletePromise = deleteFlow({ flowApiName: name });
        } else if (type === META_TYPE.TRIGGER) {
            deletePromise = deleteTrigger({ triggerName: name });
        } else if (type === META_TYPE.LWC) {
            deletePromise = deleteLwc({ componentName: name });
        } else if (type === META_TYPE.AURA) {
            deletePromise = deleteAura({ componentName: name });
        } else if (type === META_TYPE.FIELD) {
            // name format must be: ObjectName.FieldName
            const parts = name.split('.');
            if (parts.length < 2) {
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                this._addAgentMsg(`Please use the format "delete field ObjectName.FieldName"\nExample: "delete field Account.EM_Kishore"`, false, true);
                return;
            }
            const objectName = parts[0];
            const fieldName  = parts[1];
            deletePromise = deleteCustomField({ objectName, fieldName });
        } else if (type === META_TYPE.OBJECT) {
            deletePromise = deleteCustomObject({ objectName: name });
        } else if (type === META_TYPE.PERMSET) {
            deletePromise = deletePermSet({ permSetName: name });
        } else if (type === META_TYPE.PROFILE) {
            deletePromise = deactivateProfile({ profileName: name, fallbackProfileName: null });
        } else if (type === META_TYPE.VR) {
            // name format must be: ObjectName.RuleName
            const parts = name.split('.');
            if (parts.length < 2) {
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                this._addAgentMsg(`Please use the format "delete vr ObjectName.RuleName"\nExample: "delete vr Account.MyRule"`, false, true);
                return;
            }
            const objectName = parts[0];
            const ruleName   = parts[1];
            deletePromise = deleteValidationRule({ objectName, ruleName });
        } else if (type === TAB.VF) {
            deletePromise = deleteVf({ pageName: name });
        } else if (type === TAB.VFC) {
            deletePromise = deleteVfComponent({ componentName: name });
        } else {
            this._removeMessage(typingId);
            this.agentIsProcessing = false;
            this._addAgentMsg(`Deletion of "${type}" components is not supported.`, false, true);
            return;
        }

        deletePromise
            .then(result => {
                this._removeMessage(typingId);
                if (result && result.success) {
                    const successMsg = (result.message && result.message.trim()) ? result.message : `${name} has been successfully deleted.`;
                    this._addAgentMsg(successMsg, true, false);
                    // Refresh relevant tab
                    this._refreshAfterDelete(type);
                    // Flash the health gauge after a brief delay (let summaries reload first)
                    setTimeout(() => {
                        this._scoreFlash = true;
                        setTimeout(() => { this._scoreFlash = false; }, 1800);
                    }, 600);
                } else {
                    // Show result.message directly — it already contains full details
                    // (reference list, safety status, or production guard explanation)
                    const msg = (result && result.message && result.message.trim())
                        ? result.message
                        : `Could not delete ${name}: Unknown error.`;
                    // If it's a reference-blocking message, show as warning (no "Failed" badge)
                    // A blocked delete is NOT a failure — it's a "remove references first" guide
                    const isBlocked = msg.includes('Cannot delete') || msg.includes('reference(s) must be removed first');
                    this._addAgentMsg(msg, false, !isBlocked);
                }
            })
            .catch(err => {
                this._removeMessage(typingId);
                this._addAgentMsg('Delete failed: ' + this._errorMsg(err), false, true);
            })
            .finally(() => {
                this.agentIsProcessing = false;
            });
    }

    // ── Refresh dashboard after delete ───────────────────────
    _refreshAfterDelete(type) {
        if (type === META_TYPE.APEX)    { this._apexLoaded     = false; if (this.activeTab === TAB.APEX)     this._loadApex();     }
        if (type === META_TYPE.FLOW)    { this._flowsLoaded    = false; if (this.activeTab === TAB.FLOWS)    this._loadFlows();    }
        if (type === META_TYPE.TRIGGER) { this._triggersLoaded = false; if (this.activeTab === TAB.TRIGGERS) this._loadTriggers(); }
        if (type === META_TYPE.LWC)     { this._lwcLoaded      = false; if (this.activeTab === TAB.LWC)      this._loadLwc();      }
        if (type === META_TYPE.AURA)    { this._auraLoaded     = false; if (this.activeTab === TAB.AURA)     this._loadAura();     }
        if (type === META_TYPE.FIELD)   { this._fieldsLoaded   = false; if (this.activeTab === TAB.FIELDS)   this._loadFields();   }
        if (type === META_TYPE.OBJECT)  { this._objectsLoaded  = false; if (this.activeTab === TAB.OBJECTS)  this._loadObjects();  }
        if (type === META_TYPE.PERMSET) { this._permSetsLoaded = false; if (this.activeTab === TAB.PERMSETS) this._loadPermSets(); }
        if (type === META_TYPE.PROFILE) { this._profilesLoaded = false; this._loadProfiles(); }
        if (type === META_TYPE.VR)      { this._vrLoaded       = false; if (this.activeTab === TAB.VR)       this._loadVr();       }
        if (type === META_TYPE.VF)      { this._vfLoaded       = false; if (this.activeTab === TAB.VF)       this._loadVf();       }
        if (type === META_TYPE.VFC)     { this._vfcLoaded      = false; if (this.activeTab === TAB.VFC)      this._loadVfc();      }

        // ── Auto-refresh the Org Health gauge after every successful delete ──
        // Without this, the sidebar shows stale numbers (e.g. "34 / 128 issues")
        // until the user manually re-types "show org health" or reloads the page.
        // Re-runs the same prefetch used on initial load — silently updates
        // _agentIssueCount + _agentHealthScore so the gauge reflects the new state.
        this._prefetchOrgHealth();
    }

    // ── Mass delete intent: show confirmation message ─────────
    _handleMassDeleteIntent(intent) {
        let { type, names } = intent;

        if (!names || names.length === 0) {
            this._addAgentMsg('No component names detected. Please use comma-separated names.\nExamples:\n  "delete apex ClassA, ClassB, ClassC"\n  "delete flow Flow1, Flow2"\n  "delete field Account.Field1__c, Account.Field2__c"');
            return;
        }

        // ── Auto-detect type if missing: probe with first name against loaded lists ──
        if (!type) {
            const probe = (names[0] || '').replace(/ /g, '_').toLowerCase();
            const checkList = (list) => list && list.some(item => item.name && item.name.toLowerCase() === probe);

            // Flows: must match against allFlowObjects.label or .apiName, not the formatted list string
            const flowMatch = this.flowSummary && this.flowSummary.allFlowObjects &&
                this.flowSummary.allFlowObjects.some(f =>
                    (f.label  && f.label.toLowerCase().replace(/ /g, '_')  === probe) ||
                    (f.apiName && f.apiName.toLowerCase() === probe)
                );
            if (flowMatch) {
                type = META_TYPE.FLOW;
            } else if (checkList([...(this.unusedClassList || []), ...(this.usedClassList || []), ...(this.testClassList || []), ...(this.standardClassList || [])])) {
                type = META_TYPE.APEX;
            } else if (checkList([...(this.activeTriggerList || []), ...(this.inactiveTriggerList || []), ...(this.unusedTriggerList || [])])) {
                type = META_TYPE.TRIGGER;
            } else if (checkList(this.allLwcList)) {
                type = META_TYPE.LWC;
            } else if (checkList(this.allAuraList)) {
                type = META_TYPE.AURA;
            }

            // Still null — ask user to clarify
            if (!type) {
                this._addAgentMsg(
                    `⚠️ Could not detect metadata type for: "${names[0]}"\n\n` +
                    `Please include the type in your command. Examples:\n` +
                    `  "delete flow ${names.join(', ')}"\n` +
                    `  "delete apex class ${names.join(', ')}"\n` +
                    `  "delete trigger ${names.join(', ')}"`
                );
                return;
            }
        }

        const typeLabels = {
            [META_TYPE.APEX]    : 'Apex Class',
            [META_TYPE.FLOW]    : 'Flow',
            [META_TYPE.TRIGGER] : 'Trigger',
            [META_TYPE.LWC]     : 'LWC Component',
            [META_TYPE.AURA]    : 'Aura Component',
            [META_TYPE.PERMSET] : 'Permission Set',
            [META_TYPE.PROFILE] : 'Profile',
            [META_TYPE.FIELD]   : 'Custom Field',
            [META_TYPE.OBJECT]  : 'Custom Object',
            [META_TYPE.VR]      : 'Validation Rule',
            [META_TYPE.VF]      : 'Visualforce Page',
            [META_TYPE.VFC]     : 'VF Component',
        };

        const typeLabel = typeLabels[type] || type;
        const nameList  = names.map((n, i) => `  ${i + 1}. ${n}`).join('\n');

        // Extra hint for dot-notation types
        let hint = '';
        if (type === META_TYPE.FIELD) hint = '\n⚠️ Format required: ObjectName.FieldName';
        if (type === META_TYPE.VR)    hint = '\n⚠️ Format required: ObjectName.RuleName';
        if (type === META_TYPE.PROFILE) hint = `\n⚠️ Users will be moved to the default fallback profile.`;

        // ── Pre-check references for each component before confirming ──
        const typingId = this._addTypingIndicator();
        this.agentIsProcessing = true;

        const typeToMCDType = {
            [META_TYPE.APEX]    : 'ApexClass',
            [META_TYPE.FLOW]    : 'Flow',
            [META_TYPE.TRIGGER] : 'ApexTrigger',
            [META_TYPE.LWC]     : 'LightningComponentBundle',
            [META_TYPE.AURA]    : 'AuraDefinitionBundle',
            [META_TYPE.PERMSET] : 'PermissionSet',
            [META_TYPE.PROFILE] : 'Profile',
            [META_TYPE.FIELD]   : 'CustomField',
            [META_TYPE.OBJECT]  : 'CustomObject',
            [META_TYPE.VR]      : 'ValidationRule',
            [META_TYPE.VF]      : 'ApexPage',
            [META_TYPE.VFC]     : 'ApexComponent',
        };
        const mcdType = typeToMCDType[type] || type;

        Promise.all(
            names.map(name =>
                checkReferences({ componentName: name, componentType: mcdType })
                    .then(refReport => ({ name, refReport: refReport || null }))
                    .catch(() => ({ name, refReport: null })) // fail open per item
            )
        ).then(results => {
            this._removeMessage(typingId);
            this.agentIsProcessing = false;

            const blocked  = results.filter(r => r.refReport);
            const safe     = results.filter(r => !r.refReport);

            // ── Some or all blocked — show per-component reference reports ──
            if (blocked.length > 0) {
                let msg = `⚠️ Mass Delete Pre-Check — ${blocked.length} of ${names.length} ${typeLabel}(s) have references:\n\n`;
                blocked.forEach(r => {
                    msg += `❌ ${r.name}\n${r.refReport}\n\n`;
                });

                if (safe.length === 0) {
                    // All blocked — nothing to delete
                    msg += `All ${names.length} components are referenced. Remove the references above first, then retry.`;
                    this._addAgentMsg(msg, false, true);
                } else {
                    // Partial — offer to delete only the safe ones
                    const safeList = safe.map((r, i) => `  ${i + 1}. ${r.name}`).join('\n');
                    msg += `──────────────────────────────\n`;
                    msg += `✅ ${safe.length} component(s) have no references and can be deleted:\n${safeList}\n\n`;
                    msg += `Reply "yes" to delete only the ${safe.length} safe component(s), or "no" to cancel.`;
                    this._pendingMassDelete = { type, names: safe.map(r => r.name) };
                    this._addAgentMsg(msg, false, false);
                }
            } else {
                // All clear — show standard confirmation
                this._pendingMassDelete = { type, names };
                this._addAgentMsg(
                    `⚠️ Mass Delete Confirmation\n\n` +
                    `No references found in pre-check. You are about to delete ${names.length} ${typeLabel}(s):${hint}\n${nameList}\n\n` +
                    `This action cannot be undone. Reply "yes" to confirm or "no" to cancel.`
                );
            }
        });
    }

    // ── Execute mass delete ───────────────────────────────────
    _executeMassDelete(type, names) {
        const typingId = this._addTypingIndicator();
        this.agentIsProcessing = true;

        let massDeletePromise;

        if (type === META_TYPE.APEX) {
            massDeletePromise = massDeleteApexClasses({ apexClassNames: names });
        } else if (type === META_TYPE.FLOW) {
            massDeletePromise = massDeleteFlows({ flowApiNames: names });
        } else if (type === META_TYPE.TRIGGER) {
            massDeletePromise = massDeleteTriggers({ triggerNames: names });
        } else if (type === META_TYPE.LWC) {
            massDeletePromise = massDeleteLwc({ componentNames: names });
        } else if (type === META_TYPE.AURA) {
            massDeletePromise = massDeleteAura({ componentNames: names });
        } else if (type === META_TYPE.PERMSET) {
            massDeletePromise = massDeletePermSets({ permSetNames: names });
        } else if (type === META_TYPE.PROFILE) {
            massDeletePromise = massDeactivateProfiles({ profileNames: names });
        } else if (type === META_TYPE.OBJECT) {
            massDeletePromise = massDeleteCustomObjects({ objectNames: names });
        } else if (type === META_TYPE.FIELD) {
            // names are in "Object.Field" format
            massDeletePromise = massDeleteCustomFields({ dotNames: names });
        } else if (type === META_TYPE.VR) {
            // names are in "Object.RuleName" format
            massDeletePromise = massDeleteValidationRules({ dotNames: names });
        } else if (type === TAB.VF) {
            massDeletePromise = massDeleteVfPages({ pageNames: names });
        } else if (type === TAB.VFC) {
            massDeletePromise = massDeleteVfComponents({ componentNames: names });
        } else {
            this._removeMessage(typingId);
            this.agentIsProcessing = false;
            this._addAgentMsg(`Mass deletion of "${type}" is not supported.`, false, true);
            return;
        }

        massDeletePromise
            .then(result => {
                this._removeMessage(typingId);

                // Build result message
                const allSucceeded = result.failureCount === 0;
                const allFailed    = result.successCount === 0;

                let msg = `${allSucceeded ? '✅' : allFailed ? '❌' : '⚠️'} Mass Delete Complete\n\n${result.summary}`;

                if (result.succeeded && result.succeeded.length > 0) {
                    msg += `\n\n✔ Deleted (${result.successCount}):\n` +
                           result.succeeded.map(n => `  • ${n}`).join('\n');
                }
                if (result.failed && result.failed.length > 0) {
                    msg += `\n\n✘ Failed (${result.failureCount}):\n` +
                           result.failed.map(n => `  • ${n}`).join('\n');
                }

                // isError only when ALL items failed; partial success shows as warning (not red)
                this._addAgentMsg(msg, allSucceeded, allFailed);
                this._refreshAfterDelete(type);
            })
            .catch(err => {
                this._removeMessage(typingId);
                this._addAgentMsg('Mass delete failed: ' + this._errorMsg(err), false, true);
            })
            .finally(() => {
                this.agentIsProcessing = false;
            });
    }

    // ── Navigate dashboard tab based on query intent ─────────
    _refreshTabForIntent(intent) {
        if (!intent.tabs || intent.tabs.length === 0) return;

        // Switch dashboard to the first matched tab
        this.activeTab = intent.tabs[0];
        // Apply specific card filter if detected in the query, otherwise reset to ALL
        this.activeCardFilter = intent.cardFilter || FILTER.ALL;

        // For each matched tab — only load data if not already loaded (Bug 1 fix)
        const loadIfNeeded = {
            [TAB.FLOWS]    : () => { if (!this._flowsLoaded)    this._loadFlows();    },
            [TAB.APEX]     : () => { if (!this._apexLoaded)     this._loadApex();     },
            [TAB.TRIGGERS] : () => { if (!this._triggersLoaded) this._loadTriggers(); },
            [TAB.LWC]      : () => { if (!this._lwcLoaded)      this._loadLwc();      },
            [TAB.AURA]     : () => { if (!this._auraLoaded)     this._loadAura();     },
            [TAB.PROFILES] : () => { if (!this._profilesLoaded) this._loadProfiles(); },
            [TAB.PERMSETS] : () => { if (!this._permSetsLoaded) this._loadPermSets(); },
            [TAB.FIELDS]   : () => { if (!this._fieldsLoaded)   this._loadFields();   },
            [TAB.OBJECTS]  : () => { if (!this._objectsLoaded)  this._loadObjects();  },
            [TAB.VR]       : () => { if (!this._vrLoaded)       this._loadVr();       },
            [TAB.VF]       : () => { if (!this._vfLoaded)       this._loadVf();       },
            [TAB.VFC]      : () => { if (!this._vfcLoaded)      this._loadVfc();      },
        };

        intent.tabs.forEach(tab => {
            if (loadIfNeeded[tab]) loadIfNeeded[tab]();
        });
    }

    // ────────────────────────────────────────────────────────
    // DASHBOARD TAB HELPERS (unchanged)
    // ────────────────────────────────────────────────────────
    get showFlowsTab()     { return this.activeTab === TAB.FLOWS;     }
    get showApexTab()      { return this.activeTab === TAB.APEX;      }
    get showTriggersTab()  { return this.activeTab === TAB.TRIGGERS;  }
    get showLwcTab()       { return this.activeTab === TAB.LWC;       }
    get showAuraTab()      { return this.activeTab === TAB.AURA;      }
    get showProfilesTab()  { return this.activeTab === TAB.PROFILES;  }
    get showPermSetsTab()  { return this.activeTab === TAB.PERMSETS;  }
    get showFieldsTab()    { return this.activeTab === TAB.FIELDS;    }
    get showObjectsTab()   { return this.activeTab === TAB.OBJECTS;   }
    get showVrTab()        { return this.activeTab === TAB.VR;        }
    get showVfTab()        { return this.activeTab === TAB.VF;        }
    get showVfcTab()       { return this.activeTab === TAB.VFC;       }

    get showNamespaceFilter() {
        return [TAB.FLOWS, TAB.APEX, TAB.TRIGGERS, TAB.LWC, TAB.AURA, TAB.PROFILES, TAB.PERMSETS, TAB.FIELDS, TAB.OBJECTS, TAB.VR, TAB.VF, TAB.VFC].includes(this.activeTab);
    }

    get flowTabClass()    { return this._tabClass(TAB.FLOWS);    }
    get apexTabClass()    { return this._tabClass(TAB.APEX);     }
    get triggerTabClass() { return this._tabClass(TAB.TRIGGERS); }
    get lwcTabClass()     { return this._tabClass(TAB.LWC);      }
    get auraTabClass()    { return this._tabClass(TAB.AURA);     }
    get profileTabClass() { return this._tabClass(TAB.PROFILES); }
    get permSetTabClass() { return this._tabClass(TAB.PERMSETS); }
    get fieldTabClass()   { return this._tabClass(TAB.FIELDS);   }
    get objectTabClass()  { return this._tabClass(TAB.OBJECTS);  }
    get vrTabClass()      { return this._tabClass(TAB.VR);       }
    get vfTabClass()      { return this._tabClass(TAB.VF);       }
    get vfcTabClass()     { return this._tabClass(TAB.VFC);      }


    _tabClass(tab) {
        return `tab-btn${this.activeTab === tab ? ' tab-btn--active' : ''}`;
    }

    get refreshLabel()     { return this.isLoading ? 'Loading…' : 'Refresh'; }
    get refreshIconClass() { return this.isLoading ? 'spin-icon' : ''; }

    get flowTotal()    { return this.flowSummary.totalCount    !== '—' ? this.flowSummary.totalCount    : ''; }
    get apexTotal()    { return this.apexSummary.totalCount    !== '—' ? this.apexSummary.totalCount    : ''; }
    get triggerTotal() { return this.triggerSummary.totalCount !== '—' ? this.triggerSummary.totalCount : ''; }
    get lwcTotal()     { return this.lwcSummary.totalCount     !== '—' ? this.lwcSummary.totalCount     : ''; }
    get auraTotal()    { return this.auraSummary.totalCount    !== '—' ? this.auraSummary.totalCount    : ''; }
    get profileTotal() { return this.profileSummary.totalCount !== '—' ? this.profileSummary.totalCount : ''; }
    get permSetTotal() { return this.permSetSummary.totalCount !== '—' ? this.permSetSummary.totalCount : ''; }
    get fieldTotal()   { return this.fieldSummary.totalCount   !== '—' ? this.fieldSummary.totalCount   : ''; }
    get objectTotal()  { return this.objectSummary.totalCount  !== '—' ? this.objectSummary.totalCount  : ''; }
    get vrTotal()      { return this.vrSummary.totalCount      !== '—' ? this.vrSummary.totalCount      : ''; }
    get vfTotal()      { return this.vfSummary.totalCount      !== '—' ? this.vfSummary.totalCount      : ''; }
    get vfcTotal()     { return this.vfcSummary.totalCount     !== '—' ? this.vfcSummary.totalCount     : ''; }

    // ── Tab badge — shows "filtered/total" when ns filter active, else just total ──
    get flowTabBadge()    { return this.nsFilterInput ? this.flowTotalDisplay    + '/' + this.flowTotal    : this.flowTotal;    }
    get apexTabBadge()    { return this.nsFilterInput ? this.apexTotalDisplay    + '/' + this.apexTotal    : this.apexTotal;    }
    get triggerTabBadge() { return this.nsFilterInput ? this.triggerTotalDisplay + '/' + this.triggerTotal : this.triggerTotal; }
    get lwcTabBadge()     { return this.nsFilterInput ? this.lwcTotalDisplay     + '/' + this.lwcTotal     : this.lwcTotal;     }
    get auraTabBadge()    { return this.nsFilterInput ? this.auraTotalDisplay    + '/' + this.auraTotal    : this.auraTotal;    }
    get profileTabBadge() { return this.nsFilterInput ? this.profileTotalDisplay + '/' + this.profileTotal : this.profileTotal; }
    get permSetTabBadge() { return this.nsFilterInput ? this.permSetTotalDisplay + '/' + this.permSetTotal : this.permSetTotal; }
    get fieldTabBadge()   { return this.nsFilterInput ? this.fieldTotalDisplay   + '/' + this.fieldTotal   : this.fieldTotal;   }
    get objectTabBadge()  { return this.nsFilterInput ? this.objectTotalDisplay  + '/' + this.objectTotal  : this.objectTotal;  }
    get vrTabBadge()      { return this.nsFilterInput ? this.vrTotalDisplay      + '/' + this.vrTotal      : this.vrTotal;      }
    get vfTabBadge()      { return this.nsFilterInput ? this.vfTotalDisplay      + '/' + this.vfTotal      : this.vfTotal;      }
    get vfcTabBadge()     { return this.nsFilterInput ? this.vfcTotalDisplay     + '/' + this.vfcTotal     : this.vfcTotal;     }

    // ── Tab badge CSS class — highlighted orange when filter active ──
    get flowTabBadgeClass()    { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get apexTabBadgeClass()    { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get triggerTabBadgeClass() { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get lwcTabBadgeClass()     { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get auraTabBadgeClass()    { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get profileTabBadgeClass() { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get permSetTabBadgeClass() { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get fieldTabBadgeClass()   { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get objectTabBadgeClass()  { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get vrTabBadgeClass()      { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get vfTabBadgeClass()      { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }
    get vfcTabBadgeClass()     { return this.nsFilterInput ? 'tab-badge tab-badge--filtered' : 'tab-badge'; }

    // ── Filter active bar label ───────────────────────────────
    get nsActiveFilterLabel() { return '"' + this.namespaceInput.trim() + '"'; }

    // ────────────────────────────────────────────────────────
    // STAT CARD CLICK — filter the lists below
    // ────────────────────────────────────────────────────────
    handleStatCardClick(event) {
        const card = event.target.closest('[data-filter]');
        if (!card) return;
        const filter = card.getAttribute('data-filter');
        if (!filter) return;
        // 'total' always resets to show everything (it's a summary, not a filter)
        // Any other filter: clicking it activates it, clicking again resets to 'all'
        if (filter === FILTER.TOTAL) {
            this.activeCardFilter = (this.activeCardFilter === FILTER.TOTAL) ? FILTER.ALL : FILTER.TOTAL;
        } else {
            this.activeCardFilter = (this.activeCardFilter === filter) ? FILTER.ALL : filter;
        }
    }

    // CSS class helpers for active card highlighting
    get cardClassTotal()    { return 'stat-card stat-total'    + (this.activeCardFilter === FILTER.TOTAL    ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassStandard() { return 'stat-card'               + (this.activeCardFilter === FILTER.STANDARD ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassUsed()     { return 'stat-card stat-active'   + (this.activeCardFilter === FILTER.USED     ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassUnused()   { return 'stat-card stat-inactive' + (this.activeCardFilter === FILTER.UNUSED   ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassTest()     { return 'stat-card'               + (this.activeCardFilter === FILTER.TEST     ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassActive()   { return 'stat-card stat-active'   + (this.activeCardFilter === FILTER.ACTIVE   ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassInactive() { return 'stat-card stat-inactive' + (this.activeCardFilter === FILTER.INACTIVE ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassFlowTotal(){ return 'stat-card stat-total'    + (this.activeCardFilter === FILTER.TOTAL    ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassWithNs()   { return 'stat-card'               + (this.activeCardFilter === FILTER.WITH_NS   ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassNoNs()     { return 'stat-card'               + (this.activeCardFilter === FILTER.NO_NS     ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassEmpty()    { return 'stat-card stat-inactive'  + (this.activeCardFilter === FILTER.EMPTY        ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassUnref()    { return 'stat-card stat-inactive'  + (this.activeCardFilter === FILTER.UNREFERENCED ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    // ── Referenced card ───────────────────────────────────────────────
    // Same styling family as the "Used" / "With Namespace" tiles (info tone,
    // not warning) since referenced ≠ a problem — it's the healthy state.
    get cardClassRef()      { return 'stat-card'                + (this.activeCardFilter === FILTER.REFERENCED   ? ' stat-card--active' : '') + ' stat-card--clickable'; }

    // Namespace-based filtered lists for LWC / Aura / Fields / Objects

    _filterByNs(list, hasNs) {
        return list.filter(item => {
            const hasNamespace = item.name && item.name.includes('__') && item.meta && item.meta.includes('NS:');
            return hasNs ? hasNamespace : !hasNamespace;
        });
    }
    _hasNamespace(item)  {
        // Checks both 'NS: xxx' in meta (trigger/apex format) and '[xxx]' in name (lwc/aura/field/object format)
        // Also checks nsDisplay field added by enriched Aura/LWC lists
        return (item.nsDisplay && item.nsDisplay !== '—') ||
               (item.meta && item.meta.toLowerCase().includes('ns:')) ||
               (item.name && /\[[A-Za-z0-9_]+\]/.test(item.name));
    }
    _filterWithNs(list)  { return list.filter(i => this._hasNamespace(i)); }
    _filterNoNs(list)    { return list.filter(i => !this._hasNamespace(i)); }

    // ── Client-side filtered display lists ───────────────────
    // Flows
    get activeFlowDisplayList()    { return this._clientNsFilter(this.activeFlowList);    }
    get inactiveFlowDisplayList()  { return this._clientNsFilter(this.inactiveFlowList);  }
    // Apex
    get standardClassDisplayList() { return this._clientNsFilter(this.standardClassList); }
    get usedClassDisplayList()     { return this._clientNsFilter(this.usedClassList);     }
    get unusedClassDisplayList()   { return this._clientNsFilter(this.unusedClassList);   }
    get testClassDisplayList()     { return this._clientNsFilter(this.testClassList);     }
    // Triggers
    get usedTriggerDisplayList()     { return this._clientNsFilter(this.usedTriggerList);     }
    get activeTriggerDisplayList()   { return this._clientNsFilter(this.activeTriggerList);   }
    get inactiveTriggerDisplayList() { return this._clientNsFilter(this.inactiveTriggerList); }
    get unusedTriggerDisplayList()   { return this._clientNsFilter(this.unusedTriggerList);   }
    // Profiles
    get usedProfileDisplayList()   { return this._clientNsFilter(this.usedProfileList);   }
    get unusedProfileDisplayList() { return this._clientNsFilter(this.unusedProfileList); }
    // PermSets
    get usedPermSetDisplayList()   { return this._clientNsFilter(this.usedPermSetList);   }
    get unusedPermSetDisplayList() { return this._clientNsFilter(this.unusedPermSetList); }
    // VR
    get activeVrDisplayList()      { return this._clientNsFilter(this.activeVrList);      }
    get inactiveVrDisplayList()    { return this._clientNsFilter(this.inactiveVrList);    }
    get lwcWithNsList()     { return this._filterWithNs(this.allLwcList);    }
    get lwcNoNsList()       { return this._filterNoNs(this.allLwcList);      }
    get auraWithNsList()    { return this._filterWithNs(this.allAuraList);   }
    get auraNoNsList()      { return this._filterNoNs(this.allAuraList);     }
    get fieldWithNsList()   { return this._filterWithNs(this.allFieldList);  }
    get fieldNoNsList()     { return this._filterNoNs(this.allFieldList);    }
    get objectWithNsList()  { return this._filterWithNs(this.allObjectList); }
    get objectNoNsList()    { return this._filterNoNs(this.allObjectList);   }

    // Computed display lists based on active filter
    get lwcDisplayList()    {
        let list = this.allLwcList;
        if (this.activeCardFilter === FILTER.WITH_NS)      list = this.lwcWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)        list = this.lwcNoNsList;
        if (this.activeCardFilter === FILTER.UNREFERENCED) list = this.unreferencedLwcList;
        if (this.activeCardFilter === FILTER.REFERENCED)   list = this.referencedLwcList;
        return this._clientNsFilter(list);
    }
    get auraDisplayList()   {
        let list = this.allAuraList;
        if (this.activeCardFilter === FILTER.WITH_NS)      list = this.auraWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)        list = this.auraNoNsList;
        if (this.activeCardFilter === FILTER.UNREFERENCED) list = this.unreferencedAuraList;
        if (this.activeCardFilter === FILTER.REFERENCED)   list = this.referencedAuraList;
        return this._clientNsFilter(list);
    }
    get fieldDisplayList()  {
        let list = this.allFieldList;
        if (this.activeCardFilter === FILTER.WITH_NS)    list = this.fieldWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)      list = this.fieldNoNsList;
        if (this.activeCardFilter === FILTER.EMPTY)      list = this.emptyFieldList;
        if (this.activeCardFilter === FILTER.REFERENCED) list = this.fieldInUseList;
        return this._clientNsFilter(list);
    }
    get objectDisplayList() {
        let list = this.allObjectList;
        if (this.activeCardFilter === FILTER.WITH_NS)    list = this.objectWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)      list = this.objectNoNsList;
        if (this.activeCardFilter === FILTER.EMPTY)      list = this.emptyObjectList;
        if (this.activeCardFilter === FILTER.REFERENCED) list = this.objectWithRecordsList;
        return this._clientNsFilter(list);
    }
    get unreferencedLwcDisplayList()  { return this._clientNsFilter(this.unreferencedLwcList);  }
    get referencedLwcDisplayList()    { return this._clientNsFilter(this.referencedLwcList);    }
    get unreferencedAuraDisplayList() { return this._clientNsFilter(this.unreferencedAuraList); }
    get referencedAuraDisplayList()   { return this._clientNsFilter(this.referencedAuraList);   }
    get emptyFieldDisplayList()       { return this._clientNsFilter(this.emptyFieldList);        }
    get emptyObjectDisplayList()      { return this._clientNsFilter(this.emptyObjectList);       }

    // ────────────────────────────────────────────────────────
    // CLIENT-SIDE NAMESPACE FILTER HELPER
    // ────────────────────────────────────────────────────────
    // Handles 3 name formats:
    //   1. SimpleClass         → ApexClass, Trigger, LWC, Aura, Profile, PermSet
    //   2. Object.FieldName    → CustomField, ValidationRule (check part after dot)
    //   3. [NS] bracket in meta → namespace prefix tag from Apex output
    // Applies same nextChar guard as MetadataEngine Apex logic
    _clientNsFilter(list) {
        const ns = this.nsFilterInput; // already lowercased
        if (!ns) return list;
        return list.filter(item => {
            const rawName  = item.name  || '';
            const rawMeta  = item.meta  || '';

            // Check 1: [NS] bracket in meta OR name — e.g. "getStartedAgentforce [devedapp]"
            if (rawMeta.toLowerCase().includes('[' + ns + ']')) return true;
            if (rawName.toLowerCase().includes('[' + ns + ']')) return true;

            // Helper: check if a single name token matches with nextChar guard
            const matchesToken = (token) => {
                const lower = token.toLowerCase();
                if (!lower.startsWith(ns)) return false;
                const nextIdx = ns.length;
                if (nextIdx >= lower.length) return true; // exact match
                const nextChar = token.substring(nextIdx, nextIdx + 1);
                return nextChar === '_' || nextChar === nextChar.toUpperCase();
            };

            // Check 2: direct name match (Apex, LWC, Aura, Profile, PermSet, Trigger)
            if (matchesToken(rawName)) return true;

            // Check 3: ObjectName.ComponentName format (Field, VR)
            // e.g. "Account.EM_Mayank__c" → check "EM_Mayank__c" part after dot
            const dotIdx = rawName.indexOf('.');
            if (dotIdx > -1) {
                const afterDot = rawName.substring(dotIdx + 1);
                if (matchesToken(afterDot)) return true;
            }

            return false;
        });
    }

    get nsFilterLabel() {
        if (this.nsFilterInput) return 'Namespace: ' + this.namespaceInput.trim();
        return 'All';
    }

    // Generic card filter label — used by LWC, Aura, Fields, Objects, VF tabs
    _cardFilterLabel(extraFilters) {
        if (this.activeCardFilter === FILTER.WITH_NS)      return 'With Namespace';
        if (this.activeCardFilter === FILTER.NO_NS)        return 'No Namespace';
        if (this.activeCardFilter === FILTER.UNREFERENCED) return 'Unreferenced';
        if (this.activeCardFilter === FILTER.EMPTY)        return 'Empty / No Data';
        if (extraFilters) {
            for (const [filter, label] of extraFilters) {
                if (this.activeCardFilter === filter) return label;
            }
        }
        if (this.nsFilterInput) return 'Namespace: ' + this.namespaceInput.trim();
        return 'All';
    }
    get lwcCardFilterLabel()    { return this._cardFilterLabel(); }
    get auraCardFilterLabel()   { return this._cardFilterLabel(); }
    get fieldCardFilterLabel()  { return this._cardFilterLabel(); }
    get objectCardFilterLabel() { return this._cardFilterLabel(); }
    get vfCardFilterLabel()     { return this._cardFilterLabel(); }

    // Reset card filter when switching tabs
    _switchTab(tab, loadedFlag, loadFn) {
        // Reset namespace input AND filter when switching tabs
        if (this.activeTab !== tab) {
            this.namespaceInput   = '';
            this.nsFilterInput    = ''; // clear active filter too
            // Only clear _lastDataResponse when switching to a tab whose type does NOT match
            // the last chatbot response. If the user asked the chatbot about flows and then
            // the Flows tab auto-activates (or they click it), we must keep _lastDataResponse
            // so the export button still exports what the chatbot showed.
            const tabMatches = {
                [TAB.FLOWS]    : /\bflow/i,
                [TAB.APEX]     : /\bapex class|\bunused class|\bused class|\bstandard class|\btest class/i,
                [TAB.TRIGGERS] : /\btrigger/i,
                [TAB.LWC]      : /\blwc\b|\blightning web/i,
                [TAB.AURA]     : /\baura component/i,
                [TAB.PROFILES] : /\bprofile/i,
                [TAB.PERMSETS] : /\bpermission set|\bpermset/i,
                [TAB.FIELDS]   : /\bcustom field/i,
                [TAB.OBJECTS]  : /\bcustom object/i,
                [TAB.VR]       : /\bvalidation rule/i,
            };
            const pattern = tabMatches[tab];
            const chatMatchesTab = pattern && this._lastDataResponse && pattern.test(this._lastDataResponse);
            // Never clear when the last response was an org health report — export must
            // survive tab switches (user on Flows tab after seeing health report in chat)
            const isHealthResponse = this._lastOrgHealthData && this._isOrgHealthExport();
            if (!chatMatchesTab && !isHealthResponse) {
                this._lastDataResponse  = null; // clear chat export — tab data takes over
                this._lastOrgHealthData = null;
            }
            if (this._nsDebounceTimer) {
                clearTimeout(this._nsDebounceTimer);
                this._nsDebounceTimer = null;
            }
        }
        this.activeTab        = tab;
        this.activeCardFilter = FILTER.ALL;
        if (!loadedFlag) loadFn();
    }

    showFlows()    { this._switchTab(TAB.FLOWS,    this._flowsLoaded,    () => this._loadFlows());    }
    showApex()     { this._switchTab(TAB.APEX,     this._apexLoaded,     () => this._loadApex());     }
    showTriggers() { this._switchTab(TAB.TRIGGERS, this._triggersLoaded, () => this._loadTriggers()); }
    showLwc()      { this._switchTab(TAB.LWC,      this._lwcLoaded,      () => this._loadLwc());      }
    showAura()     { this._switchTab(TAB.AURA,     this._auraLoaded,     () => this._loadAura());     }
    showProfiles() { this._switchTab(TAB.PROFILES, this._profilesLoaded, () => this._loadProfiles()); }
    showPermSets() { this._switchTab(TAB.PERMSETS, this._permSetsLoaded, () => this._loadPermSets()); }
    showFields()   { this._switchTab(TAB.FIELDS,   this._fieldsLoaded,   () => this._loadFields());   }
    showObjects()  { this._switchTab(TAB.OBJECTS,  this._objectsLoaded,  () => this._loadObjects());  }
    showVr()       { this._switchTab(TAB.VR,       this._vrLoaded,       () => this._loadVr());       }
    showVf()       { this._switchTab(TAB.VF,       this._vfLoaded,       () => this._loadVf());       }
    showVfc()      { this._switchTab(TAB.VFC,      this._vfcLoaded,      () => this._loadVfc());      }


    handleRefreshAll() {
        this._flowsLoaded = this._apexLoaded = this._triggersLoaded = false;
        this._lwcLoaded   = this._auraLoaded = this._profilesLoaded = false;
        this._permSetsLoaded = this._fieldsLoaded = this._objectsLoaded = this._vrLoaded = this._vfLoaded = this._vfcLoaded = false;
        this.hasError     = false;
        this.errorMessage = '';
        this._dispatchCurrentTab();
    }

    handleNamespaceInput(event) {
        this.namespaceInput = event.target.value;
        // Debounce — wait 300ms after user stops typing, then apply client-side filter
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        if (this._nsDebounceTimer) clearTimeout(this._nsDebounceTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._nsDebounceTimer = setTimeout(() => {
            this.nsFilterInput    = this.namespaceInput.trim().toLowerCase();
            this._nsDebounceTimer = null;
        }, TIMING.NS_DEBOUNCE);
    }

    // ── Export Modal — HTML-aligned handlers & getters ────────

    // Getters that match HTML template bindings
    get showExportModal() { return this.exportModalOpen; }

    get exportTabLabel() {
        return this._exportTabLabel || 'Metadata';
    }

    get exportCsvClass()  { return 'export-fmt-btn' + (this._exportFormatKey >= 0 && this.exportFormat === FORMAT.CSV  ? ' export-fmt-btn--active' : ''); }
    get exportJsonClass() { return 'export-fmt-btn' + (this._exportFormatKey >= 0 && this.exportFormat === FORMAT.JSON ? ' export-fmt-btn--active' : ''); }
    get exportTxtClass()  { return 'export-fmt-btn' + (this._exportFormatKey >= 0 && this.exportFormat === FORMAT.TXT  ? ' export-fmt-btn--active' : ''); }

    get exportSaveDisabled()  { return this.isSaving; }
    get exportSaveBtnLabel()  { return this.isSaving ? 'Saving…' : 'Save to Org Files'; }

    get showToast()    { return !!this._toastMessage; }
    get toastMessage() { return this._toastMessage || ''; }

    // Stop click propagation on modal body (prevents overlay close)
    _stopProp(event) { event.stopPropagation(); }

    // Open/close
    openExportModal() {
        const tabLabels = {
            [TAB.FLOWS]:'Flows', [TAB.APEX]:'Apex Classes', [TAB.TRIGGERS]:'Triggers',
            [TAB.LWC]:'LWC Components', [TAB.AURA]:'Aura Components', [TAB.PROFILES]:'Profiles',
            [TAB.PERMSETS]:'Permission Sets', [TAB.FIELDS]:'Custom Fields',
            [TAB.OBJECTS]:'Custom Objects', [TAB.VR]:'Validation Rules', [TAB.VF]:'Visualforce Pages', [TAB.VFC]:'Visualforce Components'
        };
        const filterLabels = {
            [FILTER.ACTIVE]       : ' — Active',
            [FILTER.INACTIVE]     : ' — Inactive',
            [FILTER.USED]         : ' — Assigned / Used',
            [FILTER.UNUSED]       : ' — Unassigned / Unused',
            [FILTER.STANDARD]     : ' — Standard / Package',
            [FILTER.TEST]         : ' — Test Classes',
            [FILTER.WITH_NS]      : ' — With Namespace',
            [FILTER.NO_NS]        : ' — No Namespace',
            [FILTER.EMPTY]        : ' — Empty / No Data',
            [FILTER.UNREFERENCED] : ' — Unreferenced',
            [FILTER.REFERENCED]   : ' — Referenced / In Use',
        };
        const baseLabel    = tabLabels[this.activeTab] || 'Metadata';
        const filterSuffix = (this.activeCardFilter && this.activeCardFilter !== FILTER.ALL && this.activeCardFilter !== FILTER.TOTAL)
            ? (filterLabels[this.activeCardFilter] || '')
            : '';
        // If last response was an org health report, label it accordingly
        const isHealthExport = this._lastOrgHealthData && this._isOrgHealthExport();
        this._exportTabLabel  = isHealthExport ? 'Org Health Report' : (baseLabel + filterSuffix);
        this.exportModalOpen  = true;
        this.exportFormat     = FORMAT.CSV;
    }
    handleCloseExport() { this.exportModalOpen = false; }

    // Format toggle — matches HTML data-format attribute
    handleExportFormatChange(event) {
        this.exportFormat = event.currentTarget.getAttribute('data-format') || FORMAT.CSV;
        this._exportFormatKey = this._exportFormatKey + 1; // trigger re-render
    }

    // ── Download button in modal ──────────────────────────────
    // Returns true when the last agent response was an org health report
    _isOrgHealthExport() {
        if (!this._lastDataResponse) return false;
        return !!(
            this._lastDataResponse.includes('ORG HEALTH REPORT') ||
            this._lastDataResponse.includes('Org Health Report') ||
            this._lastDataResponse.includes('Org health report') ||
            this._lastDataResponse.includes('Total Issues:') ||
            this._lastDataResponse.includes('Total issues :') ||
            this._lastDataResponse.includes('Total issues:') ||
            this._lastDataResponse.includes('Health Score :') ||
            this._lastDataResponse.includes('Org Size Summary')
        );
    }

    // ── Smart export: use chat data only if it matches active tab ───
    _getExportSource() {
        if (!this._lastDataResponse) return null;
        // Org health report takes priority — export structured health data
        if (this._lastOrgHealthData && this._isOrgHealthExport()) return '__orghealth__';
        const tab   = this.activeTab;
        // Check if chat response matches the active tab
        const tabMatches = {
            [TAB.FLOWS]    : /\bflow/i,
            [TAB.APEX]     : /\bapex class|\bunused class|\bused class|\bstandard class|\btest class/i,
            [TAB.TRIGGERS] : /\btrigger/i,
            [TAB.LWC]      : /\blwc\b|\blightning web/i,
            [TAB.AURA]     : /\baura component/i,
            [TAB.PROFILES] : /\bprofile/i,
            [TAB.PERMSETS] : /\bpermission set|\bpermset/i,
            [TAB.FIELDS]   : /\bcustom field/i,
            [TAB.OBJECTS]  : /\bcustom object/i,
            [TAB.VR]       : /\bvalidation rule/i,
        };
        const pattern = tabMatches[tab];
        // If chat data matches active tab → use it
        if (pattern && pattern.test(this._lastDataResponse)) return this._lastDataResponse;
        // Chat data is from a different tab → use tab data
        return null;
    }

    handleDownload() {
        this.exportModalOpen = false;
        const d = new Date(); const date = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
        // Smart: use chat data only if it matches active tab, else use tab data
        const content = this._buildExportContent(this._getExportSource());
        if (!content) {
            this._showToast('No data to export. Ask the agent a question first or open a dashboard tab.');
            return;
        }
        const ext      = this.exportFormat;
        const tag      = this._getExportTag();
        const fileName = `org-${tag}-${date}.${ext}`;
        const mime     = ext === FORMAT.JSON ? 'application/json' : ext === FORMAT.TXT ? 'text/plain' : 'text/csv';
        const dataUrl  = `data:${mime};charset=utf-8,${encodeURIComponent(content)}`;
        const link = document.createElement('a');
        link.style.display = 'none';
        link.href     = dataUrl;
        link.download = fileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        this._showToast(`Downloaded ${fileName} successfully!`);
    }

    // ── Save to Org Files button in modal ─────────────────────
    handleSaveToFiles() {
        const d = new Date(); const date = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;

        // Smart: use chat data only if it matches active tab, else use tab data
        let content = this._buildExportContent(this._getExportSource());

        if (!content) {
            this.exportModalOpen = false;
            this._showToast('No data to export. Load a tab or ask the agent first.');
            return;
        }

        const ext      = this.exportFormat;
        const tag      = this._getExportTag();
        const fileName = `org-${tag}-${date}.${ext}`;

        // Show spinner, keep modal open while Apex runs
        this.isSaving = true;

        saveToOrgFiles({ fileName, fileContent: content, fileType: ext })
            .then(result => {
                this.isSaving        = false;
                this.exportModalOpen = false;
                if (result && result.success) {
                    this._showToast(`✅ "${fileName}" saved to Org Files!`);
                } else {
                    const msg = (result && result.message) ? result.message : 'Unknown error';
                    this._showToast('❌ Save failed: ' + msg);
                }
            })
            .catch(err => {
                this.isSaving        = false;
                this.exportModalOpen = false;
                const errMsg = err && err.body && err.body.message
                    ? err.body.message
                    : (err && err.message ? err.message : JSON.stringify(err));
                this._showToast('❌ Save failed: ' + errMsg);
            });
    }

    _getExportTag() {
        // Org health report
        if (this._lastOrgHealthData && this._isOrgHealthExport()) return 'org-health';
        // ── Detect ALL metadata types present in the last chat response ──────
        // Uses strict patterns to avoid false positives (e.g. class names containing "trigger")
        const _detectTypes = (text) => {
            if (!text) return [];
            const found = [];
            // Apex — must appear as a clear section header or keyword, NOT just class names
            if (/\bAPEX\b|\bApex Class(es)?\b|\bapex class(es)?\b/i.test(text))          found.push('apex-classes');
            // Triggers — look for trigger section headers, not class names like "DeleteTriggerAction"
            if (/\bTRIGGERS?\b|\bApex Trigger(s)?\b|active trigger|inactive trigger|unused trigger/i.test(text)) found.push('triggers');
            // Flows
            if (/\bFLOWS?\b|\bactive flow|inactive flow/i.test(text))                    found.push('flows');
            // LWC
            if (/\bLWC\b|\bLightning Web Component/i.test(text))                         found.push('lwc-components');
            // Aura
            if (/\bAura Component/i.test(text))                                           found.push('aura-components');
            // Profiles
            if (/\bProfile(s)?\b/i.test(text) && !/permission/i.test(text.slice(0,50)))  found.push('profiles');
            // Permission Sets — only explicit "Permission Set" phrase, not partial matches
            if (/\bPermission Set(s)?\b|\bpermset\b/i.test(text))                        found.push('permission-sets');
            // Fields / Objects / VR
            if (/\bCustom Field(s)?\b/i.test(text))                                      found.push('custom-fields');
            if (/\bCustom Object(s)?\b/i.test(text))                                     found.push('custom-objects');
            if (/\bValidation Rule(s)?\b/i.test(text))                                   found.push('validation-rules');
            return found;
        };

        const detected = _detectTypes(this._lastDataResponse);

        // Multi-type: build combined slug from ALL detected types (max 3 then "-and-more")
        if (detected.length > 1) {
            if (detected.length <= 3) return detected.join('-and-');
            return detected.slice(0, 3).join('-and-') + '-and-more';
        }

        // Single detected type from chat
        if (detected.length === 1) return detected[0];

        // No chat data — fall back to active tab slug
        const tabTags = {
            [TAB.FLOWS]:'flows', [TAB.APEX]:'apex-classes', [TAB.TRIGGERS]:'triggers',
            [TAB.LWC]:'lwc-components', [TAB.AURA]:'aura-components', [TAB.PROFILES]:'profiles',
            [TAB.PERMSETS]:'permission-sets', [TAB.FIELDS]:'custom-fields',
            [TAB.OBJECTS]:'custom-objects', [TAB.VR]:'validation-rules',
            [TAB.VF]:'vf-pages', [TAB.VFC]:'vf-components'
        };
        return tabTags[this.activeTab] || ('dashboard-' + this.activeTab);
    }

    _buildExportContent(chatText) {
        const e = v => (v || '').toString().replace(/"/g, '""');

        // ── Org Health Report export ──────────────────────────────────────────
        if (chatText === '__orghealth__' && this._lastOrgHealthData) {
            const h = this._lastOrgHealthData;
            const now = new Date();
            const ts  = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')} ` +
                        `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;

            // ── shared helpers ──
            const licWastedList   = (h.licData && h.licData.licWasted)   ? h.licData.licWasted   : [];
            const pslWastedList   = (h.licData && h.licData.pslWasted)   ? h.licData.pslWasted   : [];
            const licFindingsList = (h.licData && h.licData.licFindings) ? h.licData.licFindings : [];
            const ls              = h.licData && h.licData.summary ? h.licData.summary : null;
            const secFindingsList = h.secFindings || [];

            if (this.exportFormat === FORMAT.JSON) {
                const payload = {
                    generatedAt     : ts,
                    healthScore     : h.score || 'N/A',
                    healthScorePct  : h.scorePct != null ? `${h.scorePct}%` : 'N/A',
                    totalIssues     : h.totalIssues || '0',
                    orgSizeSummary  : (h.summaryRows || []).map(r => ({ type: r.label, detail: r.value })),
                    recommendations : (h.recs || []).map(r => ({ priority: r.level, recommendation: r.text })),
                    pillarBreakdown : (h.pillars || []).map(p => ({ pillar: p.label, weight: p.weight, score: p.pct + '%', status: p.status })),
                    securityPillar  : {
                        checksPassedOf : h.secChecks || 'N/A',
                        findings       : secFindingsList
                    },
                    licensePillar   : {
                        userLicenses : ls ? {
                            purchased   : ls.ulPurchased || 'N/A',
                            used        : ls.ulUsed      || 'N/A',
                            utilisation : ls.ulUtil != null ? `${ls.ulUtil}%` : 'N/A',
                            wastedTypes : ls.ulWasted || 0
                        } : null,
                        permSetLicenses : ls ? {
                            purchased   : ls.pslPurchased || 'N/A',
                            used        : ls.pslUsed      || 'N/A',
                            utilisation : ls.pslUtilPct   || 'N/A',
                            wastedTypes : ls.pslWasted    || 0
                        } : null,
                        unusedUserLicenseTypes    : licWastedList.map(w => ({ name: w.name, purchased: w.qty })),
                        unusedPermSetLicenseTypes : pslWastedList.map(w => ({ name: w.name, purchased: w.qty })),
                        findings                  : licFindingsList
                    }
                };
                return JSON.stringify(payload, null, 2);
            }

            if (this.exportFormat === FORMAT.TXT) {
                const sep  = '='.repeat(55);
                const sep2 = '-'.repeat(55);
                const lines = [
                    'ORG HEALTH REPORT',
                    sep,
                    `Generated    : ${ts}`,
                    `Health Score : ${h.score || 'N/A'}${h.scorePct != null ? ` (${h.scorePct}%)` : ''}`,
                    `Total Issues : ${h.totalIssues || '0'}`,
                    '',
                    'ORG SIZE SUMMARY',
                    sep2,
                ];
                (h.summaryRows || []).forEach(r => {
                    lines.push(`  ${r.label.padEnd(30)} ${r.value}`);
                });
                lines.push('');
                lines.push('CLEANUP RECOMMENDATIONS');
                lines.push(sep2);
                if (h.recs && h.recs.length) {
                    h.recs.forEach((r, i) => lines.push(`  [${r.level}] ${i + 1}. ${r.text}`));
                } else {
                    lines.push('  ✅ No cleanup recommendations — org looks clean!');
                }
                if (h.pillars && h.pillars.length) {
                    lines.push('');
                    lines.push('PILLAR BREAKDOWN');
                    lines.push(sep2);
                    h.pillars.forEach(p => lines.push(`  ${p.label.padEnd(12)} Weight: ${p.weight.padEnd(6)} Score: ${p.pct}%  (${p.status})`));
                }
                lines.push('');
                lines.push('SECURITY FINDINGS');
                lines.push(sep2);
                if (h.secChecks) lines.push(`  Checks Passed : ${h.secChecks}`);
                if (secFindingsList.length) {
                    secFindingsList.forEach(f => lines.push(`  ${f}`));
                } else {
                    lines.push('  No security findings recorded.');
                }
                lines.push('');
                lines.push('LICENSE DETAILS');
                lines.push(sep2);
                if (ls) {
                    lines.push(`  User Licenses       : ${ls.ulPurchased || 'N/A'} purchased, ${ls.ulUsed || 'N/A'} used (${ls.ulUtil != null ? ls.ulUtil + '%' : 'N/A'} utilisation), ${ls.ulWasted || 0} wasted type(s)`);
                    lines.push(`  Perm Set Licenses   : ${ls.pslPurchased || 'N/A'} purchased, ${ls.pslUsed || 'N/A'} used (${ls.pslUtilPct || 'N/A'} utilisation), ${ls.pslWasted || 0} wasted type(s)`);
                }
                if (licFindingsList.length) { lines.push(''); licFindingsList.forEach(f => lines.push(`  ${f}`)); }
                if (licWastedList.length) {
                    lines.push('');
                    lines.push('  Unused User License Types:');
                    licWastedList.forEach(w => lines.push(`    - ${w.name}: ${w.qty} purchased`));
                }
                if (pslWastedList.length) {
                    lines.push('');
                    lines.push('  Unused Permission Set License Types:');
                    pslWastedList.forEach(w => lines.push(`    - ${w.name}: ${w.qty} purchased`));
                }
                return lines.join('\n');
            }

            // ── Default: CSV ──────────────────────────────────────────────────
            const csvLines = [
                '# ORG HEALTH REPORT',
                `# Generated: ${ts}`,
                `# Health Score: ${h.score || 'N/A'}${h.scorePct != null ? ` (${h.scorePct}%)` : ''}`,
                `# Total Issues: ${h.totalIssues || '0'}`,
                '',
                '# ORG SIZE SUMMARY',
                '"Type","Detail"',
            ];
            (h.summaryRows || []).forEach(r => {
                csvLines.push(`"${e(r.label)}","${e(r.value)}"`);
            });

            csvLines.push('');
            csvLines.push('# CLEANUP RECOMMENDATIONS');
            csvLines.push('"Priority","#","Recommendation"');
            if (h.recs && h.recs.length) {
                h.recs.forEach((r, i) => csvLines.push(`"${e(r.level)}","${i + 1}","${e(r.text)}"`));
            } else {
                csvLines.push('"","","No cleanup recommendations — org looks clean!"');
            }

            if (h.pillars && h.pillars.length) {
                csvLines.push('');
                csvLines.push('# PILLAR BREAKDOWN');
                csvLines.push('"Pillar","Weight","Score","Status"');
                h.pillars.forEach(p => csvLines.push(`"${e(p.label)}","${e(p.weight)}","${e(p.pct)}%","${e(p.status)}"`));
            }

            csvLines.push('');
            csvLines.push('# SECURITY FINDINGS');
            csvLines.push('"Checks Passed","Finding"');
            if (secFindingsList.length) {
                secFindingsList.forEach((f, i) => csvLines.push(`"${i === 0 ? e(h.secChecks || '') : ''}","${e(f)}"`));
            } else {
                csvLines.push(`"${e(h.secChecks || '')}","No security findings recorded."`);
            }

            csvLines.push('');
            csvLines.push('# LICENSE DETAILS');
            csvLines.push('"License Type","Purchased","Used","Utilisation","Wasted Types"');
            if (ls) {
                csvLines.push(`"User Licenses","${e(ls.ulPurchased || 'N/A')}","${e(ls.ulUsed || 'N/A')}","${e(ls.ulUtil != null ? ls.ulUtil + '%' : 'N/A')}","${e(ls.ulWasted || 0)}"`);
                csvLines.push(`"Permission Set Licenses","${e(ls.pslPurchased || 'N/A')}","${e(ls.pslUsed || 'N/A')}","${e(ls.pslUtilPct || 'N/A')}","${e(ls.pslWasted || 0)}"`);
            } else {
                csvLines.push('"N/A","N/A","N/A","N/A","N/A"');
            }

            if (licFindingsList.length) {
                csvLines.push('');
                csvLines.push('# LICENSE FINDINGS');
                csvLines.push('"Finding"');
                licFindingsList.forEach(f => csvLines.push(`"${e(f)}"`));
            }

            if (licWastedList.length) {
                csvLines.push('');
                csvLines.push('# UNUSED USER LICENSE TYPES');
                csvLines.push('"License Name","Purchased"');
                licWastedList.forEach(w => csvLines.push(`"${e(w.name)}","${e(w.qty)}"`));
            }

            if (pslWastedList.length) {
                csvLines.push('');
                csvLines.push('# UNUSED PERMISSION SET LICENSE TYPES');
                csvLines.push('"License Name","Purchased"');
                pslWastedList.forEach(w => csvLines.push(`"${e(w.name)}","${e(w.qty)}"`));
            }

            return csvLines.join('\n');
        }

        // ── Detect ALL metadata types present in chat text ────────────────────
        // Uses strict patterns — avoids false positives from class names like "DeleteTriggerAction"
        // Returns array of internal type keys (may be multiple for multi-type responses)
        const _detectChatTypes = (text) => {
            if (!text) return [];
            const found = [];
            // Apex — clear section keyword, NOT just class names containing "Apex"
            if (/unused.*apex|apex.*unused/i.test(text))                                   found.push('unusedApex');
            else if (/\bApex Class(es)?\b|\bAPEX CLASS(ES)?\b/i.test(text))               found.push(TAB.APEX);
            // Triggers — section-level keywords only; excludes class names like "DeleteTriggerAction"
            if (/\bApex Trigger(s)?\b|\bTRIGGERS?\b(?!Action)|active trigger|inactive trigger|unused trigger/i.test(text) &&
                !found.includes('unusedApex') && !found.includes(TAB.APEX))               found.push(TAB.TRIGGERS);
            else if (/\bApex Trigger(s)?\b|\bTRIGGERS?\b(?!Action)|active trigger|inactive trigger|unused trigger/i.test(text))
                                                                                            found.push(TAB.TRIGGERS);
            // Flows
            if (/\bFlow(s)?\b|\bactive flow|inactive flow/i.test(text))                   found.push(TAB.FLOWS);
            // LWC / Aura
            if (/\bLWC\b|\bLightning Web Component/i.test(text))                          found.push(TAB.LWC);
            if (/\bAura Component/i.test(text))                                            found.push(TAB.AURA);
            // Profiles / Permission Sets — explicit phrases only
            if (/\bProfile(s)?\b/i.test(text))                                            found.push(TAB.PROFILES);
            if (/\bPermission Set(s)?\b|\bpermset\b/i.test(text))                        found.push(TAB.PERMSETS);
            // Fields / Objects / VR
            if (/\bCustom Field(s)?\b/i.test(text))                                       found.push(TAB.FIELDS);
            if (/\bCustom Object(s)?\b/i.test(text))                                      found.push(TAB.OBJECTS);
            if (/inactive.*validation|unused.*validation/i.test(text))                    found.push('inactiveVr');
            else if (/\bValidation Rule(s)?\b/i.test(text))                               found.push(META_TYPE.VR);
            // VF Pages / VF Components
            if (/\bVisualforce Page(s)?\b|\bVF Page(s)?\b|\bApexPage\b/i.test(text) &&
                !/\bVF Component|Visualforce Component/i.test(text))                       found.push(TAB.VF);
            if (/\bVF Component(s)?\b|\bVisualforce Component(s)?\b|\bApexComponent\b/i.test(text)) found.push(TAB.VFC);
            return [...new Set(found)]; // deduplicate
        };

        const chatTypes  = _detectChatTypes(chatText);
        const isMultiType = chatTypes.length > 1;
        // Primary type (backward compat for single-type paths)
        const chatType   = chatTypes.length === 1 ? chatTypes[0] : (chatTypes.length > 1 ? '__multi__' : (chatText ? 'generic' : null));

        // ── Section label map — internal key → human label ────────────────────
        const TYPE_LABEL = {
            unusedApex      : 'Apex Classes',
            [TAB.APEX]      : 'Apex Classes',
            [TAB.TRIGGERS]  : 'Triggers',
            [TAB.FLOWS]     : 'Flows',
            [TAB.LWC]       : 'LWC Components',
            [TAB.AURA]      : 'Aura Components',
            [TAB.PROFILES]  : 'Profiles',
            [TAB.PERMSETS]  : 'Permission Sets',
            [TAB.FIELDS]    : 'Custom Fields',
            [TAB.OBJECTS]   : 'Custom Objects',
            inactiveVr      : 'Validation Rules',
            [META_TYPE.VR]  : 'Validation Rules',
            [TAB.VF]        : 'Visualforce Pages',
            [TAB.VFC]       : 'Visualforce Components',
        };

        // ── CSV / JSON / TXT helpers ───────────────────────────────────────────
        const HEADERS = ['Label', 'API Name', 'Type'];

        // normalise: ensure every item has exactly Label / API Name / Type keys
        const norm = (items, fallbackType) => items.map(i => ({
            'Label'   : i.label    || i.apiName || i.name || '',
            'API Name': i.apiName  || i.name    || i.label || '',
            'Type'    : i.type     || fallbackType || 'Metadata'
        }));

        // ── CSV (single section — no heading row needed, just data) ───────────
        const toCsv = (dataRows) => {
            const hRow  = HEADERS.map(h => `"${e(h)}"`).join(',');
            const lines = dataRows.map(r => HEADERS.map(h => `"${e(r[h] || '')}"`).join(','));
            return lines.length ? [hRow, ...lines].join('\n') : null;
        };

        // ── CSV (multi-section — # comment separator before each group) ───────
        const toCsvMulti = (sections) => {
            const lines = [HEADERS.map(h => `"${e(h)}"`).join(',')];
            sections.forEach((sec, si) => {
                if (si > 0) lines.push('');
                lines.push(`# === ${sec.title} (${sec.items.length}) ===`);
                sec.items.forEach(r => lines.push(HEADERS.map(h => `"${e(r[h] || '')}"`).join(',')));
            });
            return lines.join('\n');
        };

        // ── JSON (single section — { "Section Title": [ {Label, API Name, Type} ] }) ─
        const toJson = (title, dataRows) => JSON.stringify({ [title]: dataRows }, null, 2);

        // ── JSON (multi-section — { "Flows": [...], "Apex Classes": [...] }) ──
        const toJsonMulti = (sections) => {
            const obj = {};
            sections.forEach(sec => { obj[sec.title] = sec.items; });
            return JSON.stringify(obj, null, 2);
        };

        // ── TXT (single section) ───────────────────────────────────────────────
        const toTxt = (title, dataRows) => {
            const heading = [`${title} (${dataRows.length})`, '='.repeat(40), ''];
            const rows = dataRows.map((r, i) =>
                `${i+1}.\n   Label    : ${r['Label']}\n   API Name : ${r['API Name']}\n   Type     : ${r['Type']}\n`
            );
            return [...heading, ...rows].join('\n');
        };

        // ── TXT (multi-section) ────────────────────────────────────────────────
        const toTxtMulti = (sections) => sections.map((sec, si) => {
            const heading = [`${si > 0 ? '\n' : ''}${sec.title} (${sec.items.length})`, '='.repeat(40), ''];
            const rows = sec.items.map((r, i) =>
                `${i+1}.\n   Label    : ${r['Label']}\n   API Name : ${r['API Name']}\n   Type     : ${r['Type']}\n`
            );
            return [...heading, ...rows].join('\n');
        }).join('\n');

        // ── Helper: parse numbered/block list from chat text ──────────────────
        const parseChatList = (text) => {
            if (!text) return [];
            const items = [];
            const lines = text.split('\n');
            let pendingLabel = '', pendingApi = '', pendingType = '', pendingMeta = '';
            const flush = () => {
                const apiName = pendingApi || pendingLabel;
                if (apiName) items.push({ label: pendingLabel || apiName, apiName, type: pendingType, meta: pendingMeta });
                pendingLabel = ''; pendingApi = ''; pendingType = ''; pendingMeta = '';
            };
            for (const line of lines) {
                const t = line.trim();
                if (!t) continue;
                const lblM  = t.match(/^Label\s*:\s*(.+)/i);
                const apiM  = t.match(/^API\s*Name\s*:\s*(.+)/i);
                const typeM = t.match(/^Type\s*:\s*(.+)/i);
                const metaM = t.match(/^(?:Status|Object|Meta|Namespace)\s*:\s*(.+)/i);
                const numM  = t.match(/^\d+\.\s+(.+)/);
                if (lblM)  { pendingLabel = lblM[1].trim(); continue; }
                if (apiM)  { pendingApi   = apiM[1].trim(); continue; }
                if (typeM) { pendingType  = typeM[1].trim(); flush(); continue; }
                if (metaM) { pendingMeta  = metaM[1].trim(); continue; }
                if (numM)  {
                    flush();
                    const body  = numM[1].trim();
                    const parts = body.split('|').map(p => p.trim());
                    let pLabel = parts[0], pApi = parts[0], pType = '', pMeta = '';
                    for (let pi = 1; pi < parts.length; pi++) {
                        const aM = parts[pi].match(/^API\s*Name\s*:\s*(.+)/i);
                        const tM = parts[pi].match(/^Type\s*:\s*(.+)/i);
                        if (aM) { pApi  = aM[1].trim(); continue; }
                        if (tM) { pType = tM[1].trim(); continue; }
                        pMeta += (pMeta ? ' | ' : '') + parts[pi];
                    }
                    if (pLabel) items.push({ label: pLabel, apiName: pApi, type: pType, meta: pMeta });
                }
            }
            flush();
            return items;
        };

        // ── Collect items for a single chat type from loaded summary data ─────
        const _itemsForType = (ct) => {
            const items = [];
            if (ct === 'unusedApex') {
                const rows = this._extractUnusedApexRows(chatText);
                rows.forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Apex Class', meta: '' }));
                if (!items.length && this._apexLoaded && this.apexSummary) {
                    this._parseDetailedList(this.apexSummary.unusedClasses)
                        .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Apex Class', meta: r.meta }));
                }
            } else if (ct === TAB.APEX && this._apexLoaded && this.apexSummary) {
                this._parseSimpleList(this.apexSummary.standardClasses)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Apex Class',        meta: '' }));
                this._parseSimpleList(this.apexSummary.usedClasses)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Apex Class',        meta: '' }));
                this._parseDetailedList(this.apexSummary.unusedClasses)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Apex Class',        meta: r.meta }));
                this._parseSimpleList(this.apexSummary.testClasses)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Apex Class (Test)', meta: '' }));
            } else if (ct === TAB.TRIGGERS && this._triggersLoaded && this.triggerSummary) {
                const seen = new Set();
                const addTrig = (list, status) => this._parseDetailedList(list).forEach(r => {
                    if (seen.has(r.name)) return; seen.add(r.name);
                    items.push({ label: r.name, apiName: r.name, type: 'Trigger', status, meta: r.meta });
                });
                addTrig(this.triggerSummary.activeTriggers,   'Active');
                addTrig(this.triggerSummary.inactiveTriggers, 'Inactive');
                addTrig(this.triggerSummary.unusedTriggers,   'Unused');
            } else if (ct === TAB.FLOWS) {
                // Export must always reflect what the chatbot last showed — NOT the card filter.
                // The card filter is only for visual filtering in the UI; the agent's response
                // is the source of truth for export.
                //
                // Detect what the chatbot showed from the chat text:
                //   "unused" / "not actively referenced" → SAFE_TO_REVIEW only
                //   "used" / "actively referenced"       → IN_USE only
                //   "active"                             → isActive only
                //   "inactive"                           → !isActive only
                //   anything else / summary              → all flows
                if (this._flowsLoaded && this.flowSummary && this.flowSummary.allFlowObjects) {
                    // Derive filter from chatbot response text, not from UI card selection.
                    // Match section-header patterns ONLY -- the summary line always contains
                    // "Active: N | Inactive: N | Used: N | Unused: N" so simple word matching
                    // would incorrectly fire on "show all flows". We look for the actual section
                    // markers produced by buildFlowResponse for each specific intent instead.
                    let chatFilter = null;
                    if (chatText) {
                        // Match the exact section-header strings produced by OrgCleanupAgentAction.buildFlowResponse:
                        //   Unused  → "🗑️ Unused flows — not actively referenced"
                        //   Used    → "✅ Used flows — actively referenced"
                        //   Active  → "✅ ACTIVE" section header (show-active intent)
                        //   Inactive→ "⬜ INACTIVE" section header (show-inactive intent)
                        // Also match the intent=inactive/active section headers used by the show-inactive/active paths.
                        if (/🗑️ Unused flows|not actively referenced|safe to review/i.test(chatText))            chatFilter = 'unused';
                        else if (/✅ Used flows|actively referenced/i.test(chatText))                             chatFilter = 'used';
                        else if (/--- ✅ ACTIVE\b|✅ Active flows\b/i.test(chatText))                             chatFilter = 'active';
                        else if (/--- ⬜ INACTIVE\b|⬜ Inactive flows\b/i.test(chatText))                         chatFilter = 'inactive';
                        // null = chatbot showed a flat/all-flows summary → export everything
                    }
                    let flowObjs = this.flowSummary.allFlowObjects;
                    if (chatFilter === 'unused') {
                        flowObjs = flowObjs.filter(f => f.safetyStatus === 'SAFE_TO_REVIEW');
                    } else if (chatFilter === 'used') {
                        flowObjs = flowObjs.filter(f => f.safetyStatus === 'IN_USE');
                    } else if (chatFilter === 'active') {
                        flowObjs = flowObjs.filter(f => f.isActive);
                    } else if (chatFilter === 'inactive') {
                        flowObjs = flowObjs.filter(f => !f.isActive);
                    }
                    // null → chatbot showed all flows, export everything
                    for (const f of flowObjs) {
                        if (f.safetyStatus === 'SKIP') continue;
                        items.push({ label: f.label || f.apiName, apiName: f.apiName, type: f.processType || 'Flow', meta: '' });
                    }
                } else if (chatText) {
                    // Flows tab not yet loaded — fall back to parsing the chatbot response text
                    const flowItems = parseChatList(chatText).filter(i => i.type && /flow|Appointments|RoutingFlow|AutoLaunched|EvaluationFlow|PromptFlow|IndividualObject|DataCapture|ApprovalWorkflow|ManagedContent|FieldService/i.test(i.type));
                    if (flowItems.length) {
                        flowItems.forEach(r => items.push({ label: r.label || r.apiName, apiName: r.apiName || r.label, type: 'Flow', meta: '' }));
                    }
                }
            } else if (ct === TAB.LWC && this._lwcLoaded && this.lwcSummary) {
                this._parseDetailedList(this.lwcSummary.allComponents)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'LWC Component', meta: r.meta }));
            } else if (ct === TAB.AURA && this._auraLoaded && this.auraSummary) {
                this._parseDetailedList(this.auraSummary.allComponents)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Aura Component', meta: r.meta }));
            } else if (ct === TAB.PROFILES && this._profilesLoaded && this.profileSummary) {
                this._parseDetailedList(this.profileSummary.usedProfiles)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Profile', status: 'Assigned',   meta: r.meta }));
                this._parseDetailedList(this.profileSummary.unusedProfiles)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Profile', status: 'Unassigned', meta: r.meta }));
            } else if (ct === TAB.PERMSETS && this._permSetsLoaded && this.permSetSummary) {
                this._parseDetailedList(this.permSetSummary.usedPermSets)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Permission Set', status: 'Assigned',   meta: r.meta }));
                this._parseDetailedList(this.permSetSummary.unusedPermSets)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Permission Set', status: 'Unassigned', meta: r.meta }));
            } else if (ct === TAB.FIELDS && this._fieldsLoaded && this.fieldSummary) {
                this._parseDetailedList(this.fieldSummary.allFields)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Custom Field', meta: r.meta }));
            } else if (ct === TAB.OBJECTS && this._objectsLoaded && this.objectSummary) {
                this._parseDetailedList(this.objectSummary.allObjects)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Custom Object', meta: r.meta }));
            } else if ((ct === 'inactiveVr' || ct === META_TYPE.VR) && this._vrLoaded && this.vrSummary) {
                this._parseDetailedList(this.vrSummary.activeRules)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Validation Rule', status: 'Active',   meta: r.meta }));
                this._parseDetailedList(this.vrSummary.inactiveRules)
                    .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Validation Rule', status: 'Inactive', meta: r.meta }));
            } else if (ct === TAB.VF && this._vfLoaded && this.vfSummary) {
                for (const p of this.allVfList) {
                    items.push({ label: p.name, apiName: p.name, type: 'Visualforce Page', meta: p.meta || '' });
                }
            } else if (ct === TAB.VFC && this._vfcLoaded && this.vfcSummary) {
                for (const c of this.allVfcList) {
                    items.push({ label: c.name, apiName: c.name, type: 'Visualforce Component', meta: c.meta || '' });
                }
            }
            // Fallback: parse raw chat text if summary not loaded
            if (!items.length) {
                parseChatList(chatText).forEach(i => items.push(i));
            }
            // Deduplicate
            const seen = new Set();
            return items.filter(i => {
                const key = (i.apiName || i.label || '').toLowerCase();
                if (seen.has(key)) return false;
                seen.add(key); return true;
            });
        };

        // ── MULTI-TYPE: render each type as its own labeled section ──────────
        if (isMultiType && chatText) {
            const sections = chatTypes
                .map(ct => ({ title: TYPE_LABEL[ct] || ct, items: norm(_itemsForType(ct), TYPE_LABEL[ct]) }))
                .filter(s => s.items.length > 0);

            if (sections.length) {
                if (this.exportFormat === FORMAT.CSV)  return toCsvMulti(sections);
                if (this.exportFormat === FORMAT.JSON) return toJsonMulti(sections);
                if (this.exportFormat === FORMAT.TXT)  return toTxtMulti(sections);
            }
        }

        // ── SINGLE-TYPE path ──────────────────────────────────────────────────
        if (chatText && chatType && chatType !== 'generic' && chatType !== '__multi__') {
            const sectionLabel = TYPE_LABEL[chatType] || 'Metadata';
            let chatItems = _itemsForType(chatType);
            if (!chatItems.length) chatItems = parseChatList(chatText);

            if (chatItems.length) {
                const data = norm(chatItems, sectionLabel);
                if (this.exportFormat === FORMAT.CSV)  return toCsv(data);
                if (this.exportFormat === FORMAT.JSON) return toJson(sectionLabel, data);
                if (this.exportFormat === FORMAT.TXT)  return toTxt(sectionLabel, data);
            }
            if (chatType === 'unusedApex' || chatType === TAB.APEX) return null;
        }

        // ── No chat data (or chat parse yielded nothing) ───────
        // Export full tab data from loaded summary via parsed list getters
        const resolvedType = (() => {
            if (this.activeTab === TAB.FLOWS)    return TAB.FLOWS;
            if (this.activeTab === TAB.APEX)     return TAB.APEX;
            if (this.activeTab === TAB.TRIGGERS) return TAB.TRIGGERS;
            if (this.activeTab === TAB.LWC)      return TAB.LWC;
            if (this.activeTab === TAB.AURA)     return TAB.AURA;
            if (this.activeTab === TAB.PROFILES) return TAB.PROFILES;
            if (this.activeTab === TAB.PERMSETS) return TAB.PERMSETS;
            if (this.activeTab === TAB.FIELDS)   return TAB.FIELDS;
            if (this.activeTab === TAB.OBJECTS)  return TAB.OBJECTS;
            if (this.activeTab === TAB.VR)       return META_TYPE.VR;
            if (this.activeTab === TAB.VF)       return TAB.VF;
            if (this.activeTab === TAB.VFC)      return TAB.VFC;
            return chatType;
        })();

                // ── Fallback: generic chat text parser ─────────────────
        if (this.exportFormat === FORMAT.JSON) {
            const rows = this._buildExportRows();
            return rows.length ? JSON.stringify(rows, null, 2) : null;
        }
        if (this.exportFormat === FORMAT.TXT) {
            const rows = this._buildExportRows();
            if (!rows.length) return null;
            const lines = [];
            rows.forEach((r, i) => {
                lines.push((i + 1) + '.');
                lines.push('   Label    : ' + (r['Label']    || ''));
                lines.push('   API Name : ' + (r['API Name'] || ''));
                lines.push('   Type     : ' + (r['Type']     || ''));
                lines.push('');
            });
            return lines.join('\n');
        }
        // CSV last resort
        return this._buildDashboardCSV();
    }

    // ── Unused Apex → CSV ─────────────────────────────────────
    _unusedApexToCSV(text) {
        const rows = this._extractUnusedApexRows(text);
        if (!rows.length) return null;
        const header = '"API Name","Label","Type"';
        const lines  = rows.map(r =>
            `"${r.name}","${r.name}","Apex Class"`
        );
        return [header, ...lines].join('\n');
    }

    // ── Unused Apex → JSON ────────────────────────────────────
    _unusedApexToJSON(text) {
        const rows = this._extractUnusedApexRows(text);
        if (!rows.length) return null;
        return JSON.stringify(rows.map(r => ({
            'Label'   : r.name,
            'API Name': r.name,
            'Type'    : 'Apex Class'
        })), null, 2);
    }

    // ── Unused Apex → TXT ─────────────────────────────────────
    _unusedApexToTXT(text) {
        const rows = this._extractUnusedApexRows(text);
        if (!rows.length) return text; // fallback to raw
        const lines = ['Apex Classes', '='.repeat(40), ''];
        rows.forEach((r, i) => {
            lines.push(`${i+1}.`);
            lines.push(`   Label    : ${r.name}`);
            lines.push(`   API Name : ${r.name}`);
            lines.push(`   Type     : Apex Class`);
            lines.push('');
        });
        return lines.join('\n');
    }

    // ── Parse unused apex class entries from agent text ───────
    _extractUnusedApexRows(text) {
        const rows = [];
        const lines = text.split('\n');
        let inUnusedSection = false;
        let pendingLabel = '';
        let pendingApi   = '';
        let pendingType  = '';

        const flushRow = () => {
            if (pendingApi || pendingLabel) {
                rows.push({ name: pendingApi || pendingLabel, type: pendingType || 'Apex Class', lines: '', modified: '' });
            }
            pendingLabel = ''; pendingApi = ''; pendingType = '';
        };

        for (const line of lines) {
            const trimmed = line.trim();

            // Detect unused section start
            if (/unused|safe to delete/i.test(trimmed) && /apex|class/i.test(trimmed)) {
                inUnusedSection = true;
                continue;
            }
            // Stop at next major section
            if (inUnusedSection && /^---\s*(used|active|standard|test|package)/i.test(trimmed)) {
                flushRow();
                inUnusedSection = false;
                continue;
            }

            if (!inUnusedSection) continue;

            // Block style: "Label    : ClassName"
            const lblMatch = trimmed.match(/^Label\s*:\s*(.+)/i);
            if (lblMatch) { pendingLabel = lblMatch[1].trim(); continue; }

            // Block style: "API Name : ClassName"
            const apiMatch = trimmed.match(/^API\s*Name\s*:\s*(.+)/i);
            if (apiMatch) { pendingApi = apiMatch[1].trim(); continue; }

            // Block style: "Type     : Apex Class" — capture type then flush
            const typeMatch = trimmed.match(/^Type\s*:\s*(.+)/i);
            if (typeMatch) { pendingType = typeMatch[1].trim(); flushRow(); continue; }

            // Pipe style: "1. ClassName | Lines: 42 | Last Modified: ..."
            if (/^\d+\./.test(trimmed)) {
                flushRow();
                const body  = trimmed.replace(/^\d+\.\s*/, '').trim();
                const parts = body.split('|').map(p => p.trim());
                const name  = parts[0] || '';
                let linesVal = '', modVal = '';
                for (const p of parts) {
                    if (/^Lines\s*:/i.test(p))         linesVal = p.replace(/^Lines\s*:\s*/i, '').trim();
                    if (/^Last\s*Modified\s*:/i.test(p)) modVal  = p.replace(/^Last\s*Modified\s*:\s*/i, '').trim().slice(0, 10);
                }
                if (name) rows.push({ name, type: 'Apex Class', lines: linesVal, modified: modVal });
            }
        }
        flushRow(); // flush any trailing block row
        return rows;
    }

    // Parse flows from chatbot response text — respects whatever subset was shown
    // (inactive only, active only, or all). Handles the block-style format:
    //   Label    : My Flow
    //   API Name : MyFlow
    //   Type     : AutoLaunchedFlow
    _parseFlowsFromChat(text) {
        const flows = [];
        const lines = text.split('\n');
        let pendingLabel = '';
        let pendingApi   = '';
        let pendingType  = '';

        const flush = () => {
            if (pendingApi || pendingLabel) {
                flows.push({
                    label:  pendingLabel || pendingApi,
                    apiName: pendingApi  || pendingLabel,
                    type:   pendingType  || 'Flow'
                });
            }
            pendingLabel = ''; pendingApi = ''; pendingType = '';
        };

        for (const line of lines) {
            const t = line.trim();
            // Skip header / stats / footer lines
            if (!t || /^(🔀|FLOWS|Total:|Active:|Inactive:|To delete:|──)/i.test(t)) continue;
            if (/^---/.test(t)) { flush(); continue; }

            const lblMatch  = t.match(/^Label\s*:\s*(.+)/i);
            const apiMatch  = t.match(/^API\s*Name\s*:\s*(.+)/i);
            const typeMatch = t.match(/^Type\s*:\s*(.+)/i);

            if (lblMatch)  { pendingLabel = lblMatch[1].trim();  continue; }
            if (apiMatch)  { pendingApi   = apiMatch[1].trim();  continue; }
            if (typeMatch) { pendingType  = typeMatch[1].trim(); flush(); continue; }

            // Numbered list style: "1.    Label    : ..."  already handled above
            // Plain numbered: "1. ApiName | Type"
            const numMatch = t.match(/^\d+\.\s+(.+)/);
            if (numMatch) {
                flush();
                const parts = numMatch[1].split('|').map(p => p.trim());
                if (parts[0]) flows.push({ label: parts[0], apiName: parts[0], type: parts[1] || 'Flow' });
            }
        }
        flush();
        return flows;
    }

    // Parse agent chat text into structured objects for JSON export
    _parseChatTextToObjects(text) {
        const results = [];
        const lines   = text.split('\n').map(l => l.trim()).filter(Boolean);
        let currentType = '', currentStatus = '';

        for (const line of lines) {
            // Section headers
            if (/^(🗂️|⚡|🔀|🔷|🔶|👤|🔑|✔️|📋|🧩)/.test(line) ||
                /^(APEX|FLOW|TRIGGER|LWC|AURA|PROFILE|PERMISSION|FIELD|OBJECT|VALIDATION|CUSTOM)/i.test(line)) {
                currentType = line.replace(/[^a-zA-Z\s\/]/g, '').trim();
                currentStatus = '';
                continue;
            }
            // Status sub-headers
            if (/^---/.test(line) || /^(unused|used|active|inactive|unassigned|assigned|safe to)/i.test(line)) {
                if      (/unused|inactive|safe to delete/i.test(line)) currentStatus = 'Unused/Inactive';
                else if (/^used|^active|^assigned/i.test(line))        currentStatus = 'Used/Active';
                continue;
            }
            // Numbered: "1. FlowName | ..."  or "1.    Label : X"
            if (/^\d+\./.test(line)) {
                const body = line.replace(/^\d+\.\s*/, '').trim();
                // Label/API Name block style
                const labelMatch = body.match(/^Label\s*:\s*(.+)/i);
                if (labelMatch) { currentType = currentType || 'Component'; continue; }
                // Pipe style
                const pipeIdx = body.indexOf('|');
                const name    = pipeIdx > -1 ? body.substring(0, pipeIdx).trim() : body;
                const detail  = pipeIdx > -1 ? body.substring(pipeIdx + 1).trim() : '';
                if (name) results.push({ name, type: currentType, status: currentStatus, detail });
                continue;
            }
            // API Name lines (from structured block output)
            const apiMatch = line.match(/^API Name\s*:\s*(.+)/i);
            const lblMatch = line.match(/^Label\s*:\s*(.+)/i);
            if (apiMatch) {
                const last = results[results.length - 1];
                if (last) last.apiName = apiMatch[1].trim();
                else results.push({ apiName: apiMatch[1].trim(), type: currentType, status: currentStatus });
                continue;
            }
            if (lblMatch) {
                const last = results[results.length - 1];
                if (last && !last.name) last.name = lblMatch[1].trim();
                else if (!last || last.name) results.push({ name: lblMatch[1].trim(), type: currentType, status: currentStatus });
                continue;
            }
            // Bullet style
            if (/^[-*]\s/.test(line)) {
                const body    = line.replace(/^[-*]\s+/, '').trim();
                const parenIdx = body.indexOf('(');
                const name    = parenIdx > -1 ? body.substring(0, parenIdx).trim() : body;
                const detail  = parenIdx > -1 ? body.substring(parenIdx + 1).replace(')', '').trim() : '';
                if (name) results.push({ name, type: currentType, status: currentStatus, detail });
            }
        }
        return results;
    }

    // ── Export button in agent panel — opens the modal ────────
    toggleExportDropdown(event) {
        event.stopPropagation();
        this.openExportModal();
    }

    // Returns the last meaningful data response (for export)
    _getLastAgentResponseText() {
        return this._lastDataResponse || null;
    }

    // Convert raw agent text response into CSV rows
    _chatTextToCSV(text) {
        const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
        const e = v => (v || '').toString().replace(/"/g, '""');
        const rows = ['"API Name","Label","Type","Status","Detail"'];
        let currentType   = '';
        let currentStatus = '';

        // Block-style accumulator (Label / API Name / Type lines)
        let pendingLabel  = '';
        let pendingApi    = '';
        let pendingType   = '';

        const flushPending = () => {
            if (pendingApi || pendingLabel) {
                const api    = pendingApi    || pendingLabel;
                const label  = pendingLabel  || pendingApi;
                const type   = pendingType   || currentType  || 'Component';
                rows.push(`"${e(api)}","${e(label)}","${e(type)}","${e(currentStatus)}",""`);
            }
            pendingLabel = ''; pendingApi = ''; pendingType = '';
        };

        for (const line of lines) {
            // Skip separators / totals
            if (/^(Total:|To delete:|Showing|Namespace filter|─+|-{3,})/i.test(line)) { flushPending(); continue; }

            // Section header e.g. "🗂️ CUSTOM FIELDS", "🔀 FLOWS"
            if (/^[🗂️⚡🔀🔷🔶👤🔑✔️📋🧩]/.test(line) ||
                /^(APEX|FLOW|TRIGGER|LWC|AURA|PROFILE|PERMISSION|FIELD|OBJECT|VALIDATION|CUSTOM)/i.test(line)) {
                flushPending();
                currentType   = line.replace(/[^a-zA-Z\s\/]/g, '').trim();
                currentStatus = '';
                continue;
            }

            // Status sub-header
            if (/^(unused|used|active|inactive|unassigned|assigned|standard|test|safe to)/i.test(line) ||
                /^(🗑️|✅|⬜|🧪|📦|🔧)/.test(line)) {
                flushPending();
                if      (/unused|inactive|safe to delete/i.test(line)) currentStatus = 'Unused/Inactive';
                else if (/used|active|assigned/i.test(line))           currentStatus = 'Used/Active';
                else if (/test/i.test(line))                           currentStatus = 'Test';
                else if (/standard|package/i.test(line))               currentStatus = 'Standard/Package';
                continue;
            }

            // Block style: "Label    : FlowName"
            const lblMatch = line.match(/^Label\s*:\s*(.+)/i);
            if (lblMatch) { pendingLabel = lblMatch[1].trim(); continue; }

            // Block style: "API Name : Account.EM_Kishore"
            const apiMatch = line.match(/^API\s*Name\s*:\s*(.+)/i);
            if (apiMatch) { pendingApi = apiMatch[1].trim(); continue; }

            // Block style: "Type     : Custom Field"
            const typeMatch = line.match(/^Type\s*:\s*(.+)/i);
            if (typeMatch) { pendingType = typeMatch[1].trim(); flushPending(); continue; }

            // Pipe row: "Name | Detail"
            if (line.includes('|') && !/^API Name/i.test(line)) {
                flushPending();
                const parts = line.split('|').map(p => p.trim());
                if (parts.length >= 2 && parts[0]) {
                    rows.push(`"${e(parts[0])}","${e(parts[1] || parts[0])}","${e(parts[2] || currentType)}","${e(currentStatus)}",""`);
                }
                continue;
            }

            // Numbered: "1. FlowName" or "1.  FlowName | detail"
            if (/^\d+\.\s/.test(line)) {
                flushPending();
                const body    = line.replace(/^\d+\.\s*/, '').trim();
                const pipeIdx = body.indexOf('|');
                const name    = pipeIdx > -1 ? body.substring(0, pipeIdx).trim() : body;
                const detail  = pipeIdx > -1 ? body.substring(pipeIdx + 1).trim() : '';
                if (name) rows.push(`"${e(name)}","${e(name)}","${e(currentType)}","${e(currentStatus)}","${e(detail)}"`);
                continue;
            }

            // Bullet: "- Name (detail)"
            if (/^[-*]\s/.test(line)) {
                flushPending();
                const body    = line.replace(/^[-*]\s+/, '').trim();
                const pIdx    = body.indexOf('(');
                const name    = pIdx > -1 ? body.substring(0, pIdx).trim() : body;
                const detail  = pIdx > -1 ? body.substring(pIdx + 1).replace(')', '').trim() : '';
                if (name) rows.push(`"${e(name)}","${e(name)}","${e(currentType)}","${e(currentStatus)}","${e(detail)}"`);
                continue;
            }

            // If nothing matched and we have accumulated pending, flush
            flushPending();
        }
        flushPending(); // flush any trailing block
        return rows.length > 1 ? rows.join('\n') : null;
    }

    _buildDashboardCSV() {
        const rows = this._buildExportRows();
        if (!rows.length) return null;
        const headers = ['Label', 'API Name', 'Type'];
        return [headers.map(h => '"' + h + '"').join(','), ...rows.map(r =>
            headers.map(h => '"' + (r[h] || '').toString().replace(/"/g, '""') + '"').join(',')
        )].join('\n');
    }

    _triggerDownload(csv, fileName) {
        const link = document.createElement('a');
        link.style.display = 'none';
        link.href     = `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`;
        link.download = fileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    _buildExportRows() {
        const rows = [];
        // Simple 3-column format: Label, API Name, Type
        const row = (label, apiName, type) =>
            rows.push({ 'Label': label || apiName || '', 'API Name': apiName || label || '', 'Type': type || '' });

        const tab    = this.activeTab;
        const filter = this.activeCardFilter; // respect the active card filter

        // Helper: is the filter "show all" (no specific card selected)?
        const showAll = filter === FILTER.ALL || filter === FILTER.TOTAL;

        // ── FLOWS ─────────────────────────────────────────────
        if (tab === TAB.FLOWS && this._flowsLoaded && this.flowSummary && this.flowSummary.allFlowObjects) {
            // Helper: export directly from allFlowObjects by safetyStatus filter
            const exportFlowObjects = (statusFilter) => {
                const filtered = statusFilter
                    ? this.flowSummary.allFlowObjects.filter(statusFilter)
                    : this.flowSummary.allFlowObjects;
                for (const f of filtered) {
                    if (f.safetyStatus === 'SKIP') continue;
                    row(f.label || f.apiName, f.apiName, f.processType || 'Flow');
                }
            };
            if (showAll) {
                exportFlowObjects(null);
            } else if (filter === FILTER.ACTIVE) {
                exportFlowObjects(f => f.isActive);
            } else if (filter === FILTER.INACTIVE) {
                exportFlowObjects(f => !f.isActive);
            } else if (filter === FILTER.USED) {
                exportFlowObjects(f => f.safetyStatus === 'IN_USE');
            } else if (filter === FILTER.UNUSED) {
                exportFlowObjects(f => f.safetyStatus === 'SAFE_TO_REVIEW');
            } else {
                exportFlowObjects(null);
            }
        }

        // ── APEX CLASSES ───────────────────────────────────────
        if (tab === TAB.APEX && this._apexLoaded && this.apexSummary) {
            if (showAll) {
                for (const c of this.unusedClassList)   { row(c.name, c.name, 'Apex Class'); }
                for (const c of this.usedClassList)     { row(c.name, c.name, 'Apex Class'); }
                for (const c of this.testClassList)     { row(c.name, c.name, 'Apex Class'); }
                for (const c of this.standardClassList) { row(c.name, c.name, 'Apex Class'); }
            } else if (filter === FILTER.UNUSED) {
                for (const c of this.unusedClassDisplayList)   { row(c.name, c.name, 'Apex Class'); }
            } else if (filter === FILTER.USED) {
                for (const c of this.usedClassDisplayList)     { row(c.name, c.name, 'Apex Class'); }
            } else if (filter === FILTER.TEST) {
                for (const c of this.testClassDisplayList)     { row(c.name, c.name, 'Apex Class'); }
            } else if (filter === FILTER.STANDARD) {
                for (const c of this.standardClassDisplayList) { row(c.name, c.name, 'Apex Class'); }
            } else {
                for (const c of this.unusedClassList)   { row(c.name, c.name, 'Apex Class'); }
                for (const c of this.usedClassList)     { row(c.name, c.name, 'Apex Class'); }
                for (const c of this.testClassList)     { row(c.name, c.name, 'Apex Class'); }
                for (const c of this.standardClassList) { row(c.name, c.name, 'Apex Class'); }
            }
        }

        // ── TRIGGERS ──────────────────────────────────────────
        if (tab === TAB.TRIGGERS && this._triggersLoaded && this.triggerSummary) {
            const seen = new Set();
            const addTriggers = (list) => {
                for (const t of (list || [])) {
                    if (seen.has(t.name)) continue;
                    seen.add(t.name);
                    row(t.name, t.name, 'Apex Trigger');
                }
            };
            if (showAll) {
                addTriggers(this.activeTriggerList);
                addTriggers(this.inactiveTriggerList);
            } else if (filter === FILTER.ACTIVE) {
                addTriggers(this.activeTriggerDisplayList);
            } else if (filter === FILTER.INACTIVE) {
                addTriggers(this.inactiveTriggerDisplayList);
            } else if (filter === FILTER.USED) {
                addTriggers(this.usedTriggerDisplayList);
            } else if (filter === FILTER.UNUSED) {
                addTriggers(this.unusedTriggerDisplayList);
            } else {
                addTriggers(this.activeTriggerList);
                addTriggers(this.inactiveTriggerList);
            }
        }

        // ── LWC ───────────────────────────────────────────────
        if (tab === TAB.LWC && this._lwcLoaded) {
            if (showAll || filter === FILTER.WITH_NS || filter === FILTER.NO_NS) {
                for (const c of this.lwcDisplayList) { row(c.name, c.name, 'LWC Component'); }
            } else if (filter === FILTER.UNREFERENCED) {
                for (const c of this.unreferencedLwcDisplayList) { row(c.name, c.name, 'LWC Component'); }
            } else if (filter === FILTER.REFERENCED) {
                for (const c of this.referencedLwcDisplayList)   { row(c.name, c.name, 'LWC Component'); }
            } else {
                for (const c of this.allLwcList) { row(c.name, c.name, 'LWC Component'); }
            }
        }

        // ── AURA ──────────────────────────────────────────────
        if (tab === TAB.AURA && this._auraLoaded) {
            if (showAll || filter === FILTER.WITH_NS || filter === FILTER.NO_NS) {
                for (const c of this.auraDisplayList) { row(c.name, c.name, 'Aura Component'); }
            } else if (filter === FILTER.UNREFERENCED) {
                for (const c of this.unreferencedAuraDisplayList) { row(c.name, c.name, 'Aura Component'); }
            } else if (filter === FILTER.REFERENCED) {
                for (const c of this.referencedAuraDisplayList)   { row(c.name, c.name, 'Aura Component'); }
            } else {
                for (const c of this.allAuraList) { row(c.name, c.name, 'Aura Component'); }
            }
        }

        // ── PROFILES ──────────────────────────────────────────
        if (tab === TAB.PROFILES && this._profilesLoaded) {
            if (showAll) {
                for (const p of this.usedProfileList)   { row(p.name, p.name, 'Profile'); }
                for (const p of this.unusedProfileList) { row(p.name, p.name, 'Profile'); }
            } else if (filter === FILTER.USED) {
                for (const p of this.usedProfileDisplayList)   { row(p.name, p.name, 'Profile'); }
            } else if (filter === FILTER.UNUSED) {
                for (const p of this.unusedProfileDisplayList) { row(p.name, p.name, 'Profile'); }
            } else {
                for (const p of this.usedProfileList)   { row(p.name, p.name, 'Profile'); }
                for (const p of this.unusedProfileList) { row(p.name, p.name, 'Profile'); }
            }
        }

        // ── PERMISSION SETS ───────────────────────────────────
        if (tab === TAB.PERMSETS && this._permSetsLoaded) {
            if (showAll) {
                for (const p of this.usedPermSetList)   { row(p.name, p.name, 'Permission Set'); }
                for (const p of this.unusedPermSetList) { row(p.name, p.name, 'Permission Set'); }
            } else if (filter === FILTER.USED) {
                for (const p of this.usedPermSetDisplayList)   { row(p.name, p.name, 'Permission Set'); }
            } else if (filter === FILTER.UNUSED) {
                for (const p of this.unusedPermSetDisplayList) { row(p.name, p.name, 'Permission Set'); }
            } else {
                for (const p of this.usedPermSetList)   { row(p.name, p.name, 'Permission Set'); }
                for (const p of this.unusedPermSetList) { row(p.name, p.name, 'Permission Set'); }
            }
        }

        // ── CUSTOM FIELDS ─────────────────────────────────────
        if (tab === TAB.FIELDS && this._fieldsLoaded) {
            if (showAll || filter === FILTER.WITH_NS || filter === FILTER.NO_NS) {
                for (const f of this.fieldDisplayList)  { row(f.name, f.name, 'Custom Field'); }
            } else if (filter === FILTER.EMPTY) {
                for (const f of this.emptyFieldDisplayList)   { row(f.name, f.name, 'Custom Field'); }
            } else if (filter === FILTER.REFERENCED) {
                for (const f of this.fieldInUseDisplayList)   { row(f.name, f.name, 'Custom Field'); }
            } else {
                for (const f of this.allFieldList) { row(f.name, f.name, 'Custom Field'); }
            }
        }

        // ── CUSTOM OBJECTS ────────────────────────────────────
        if (tab === TAB.OBJECTS && this._objectsLoaded) {
            if (showAll || filter === FILTER.WITH_NS || filter === FILTER.NO_NS) {
                for (const o of this.objectDisplayList) { row(o.name, o.name, 'Custom Object'); }
            } else if (filter === FILTER.EMPTY) {
                for (const o of this.emptyObjectDisplayList)        { row(o.name, o.name, 'Custom Object'); }
            } else if (filter === FILTER.REFERENCED) {
                for (const o of this.objectWithRecordsDisplayList)  { row(o.name, o.name, 'Custom Object'); }
            } else {
                for (const o of this.allObjectList) { row(o.name, o.name, 'Custom Object'); }
            }
        }

        // ── VALIDATION RULES ──────────────────────────────────
        if (tab === TAB.VR && this._vrLoaded) {
            if (showAll) {
                for (const r of this.activeVrList)   { row(r.name, r.name, 'Validation Rule'); }
                for (const r of this.inactiveVrList) { row(r.name, r.name, 'Validation Rule'); }
            } else if (filter === FILTER.ACTIVE) {
                for (const r of this.activeVrDisplayList)   { row(r.name, r.name, 'Validation Rule'); }
            } else if (filter === FILTER.INACTIVE) {
                for (const r of this.inactiveVrDisplayList) { row(r.name, r.name, 'Validation Rule'); }
            } else {
                for (const r of this.activeVrList)   { row(r.name, r.name, 'Validation Rule'); }
                for (const r of this.inactiveVrList) { row(r.name, r.name, 'Validation Rule'); }
            }
        }

        // ── VISUALFORCE PAGES ─────────────────────────────────
        if (tab === TAB.VF && this._vfLoaded) {
            if (showAll || filter === FILTER.WITH_NS || filter === FILTER.NO_NS) {
                for (const p of this.vfDisplayList)             { row(p.name, p.name, 'Visualforce Page'); }
            } else if (filter === FILTER.UNREFERENCED) {
                for (const p of this.unreferencedVfDisplayList) { row(p.name, p.name, 'Visualforce Page'); }
            } else if (filter === FILTER.REFERENCED) {
                for (const p of this.referencedVfDisplayList)   { row(p.name, p.name, 'Visualforce Page'); }
            } else {
                for (const p of this.allVfList) { row(p.name, p.name, 'Visualforce Page'); }
            }
        }

        // ── VISUALFORCE COMPONENTS ────────────────────────────
        if (tab === TAB.VFC && this._vfcLoaded) {
            if (showAll || filter === FILTER.WITH_NS || filter === FILTER.NO_NS) {
                for (const c of this.vfcDisplayList)             { row(c.name, c.name, 'Visualforce Component'); }
            } else if (filter === FILTER.UNREFERENCED) {
                for (const c of this.unreferencedVfcDisplayList) { row(c.name, c.name, 'Visualforce Component'); }
            } else if (filter === FILTER.REFERENCED) {
                for (const c of this.referencedVfcDisplayList)   { row(c.name, c.name, 'Visualforce Component'); }
            } else {
                for (const c of this.allVfcList) { row(c.name, c.name, 'Visualforce Component'); }
            }
        }

        return rows;
    }
    _showToast(message) {
        this._toastMessage = message;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._toastMessage = ''; }, TIMING.TOAST_DISMISS);
    }

    handleNamespaceKeydown(event) {
        if (event.key === 'Enter') {
            // Enter key — apply immediately, cancel debounce timer
            if (this._nsDebounceTimer) {
                clearTimeout(this._nsDebounceTimer);
                this._nsDebounceTimer = null;
            }
            this.nsFilterInput = this.namespaceInput.trim().toLowerCase();
        }
    }

    handleNamespaceClear() {
        // Cancel any pending debounce
        if (this._nsDebounceTimer) {
            clearTimeout(this._nsDebounceTimer);
            this._nsDebounceTimer = null;
        }
        this.namespaceInput = '';
        this.nsFilterInput  = ''; // instantly clears client-side filter — no Apex call
    }

    get namespaceFilterActive() {
        return !!this.nsFilterInput;
    }

    get nsFilterApplyLabel() {
        return this.namespaceInput.trim() ? 'Apply' : 'Reset';
    }

    get nsFilterApplyClass() {
        return 'ns-filter-apply' + (this.nsFilterInput ? ' ns-filter-apply--active' : '');
    }

    handleNamespaceApply() {
        // Cancel debounce and apply immediately — client-side only, no Apex call
        if (this._nsDebounceTimer) {
            clearTimeout(this._nsDebounceTimer);
            this._nsDebounceTimer = null;
        }
        this.nsFilterInput = this.namespaceInput.trim().toLowerCase();
        // If current tab data not loaded yet, load it now so filter has data to work on
        const loadIfNeeded = {
            [TAB.FLOWS]    : () => { if (!this._flowsLoaded)    this._loadFlows();    },
            [TAB.APEX]     : () => { if (!this._apexLoaded)     this._loadApex();     },
            [TAB.TRIGGERS] : () => { if (!this._triggersLoaded) this._loadTriggers(); },
            [TAB.LWC]      : () => { if (!this._lwcLoaded)      this._loadLwc();      },
            [TAB.AURA]     : () => { if (!this._auraLoaded)     this._loadAura();     },
            [TAB.PROFILES] : () => { if (!this._profilesLoaded) this._loadProfiles(); },
            [TAB.PERMSETS] : () => { if (!this._permSetsLoaded) this._loadPermSets(); },
            [TAB.FIELDS]   : () => { if (!this._fieldsLoaded)   this._loadFields();   },
            [TAB.OBJECTS]  : () => { if (!this._objectsLoaded)  this._loadObjects();  },
            [TAB.VR]       : () => { if (!this._vrLoaded)       this._loadVr();       },
            [TAB.VF]       : () => { if (!this._vfLoaded)       this._loadVf();       },
        };
        if (loadIfNeeded[this.activeTab]) loadIfNeeded[this.activeTab]();
    }

    _dispatchCurrentTab() {
        const map = {
            [TAB.FLOWS]:    () => this._loadFlows(),    [TAB.APEX]:     () => this._loadApex(),
            [TAB.TRIGGERS] : () => this._loadTriggers(), [TAB.LWC]:      () => this._loadLwc(),
            [TAB.AURA]:     () => this._loadAura(),     [TAB.PROFILES] : () => this._loadProfiles(),
            [TAB.PERMSETS] : () => this._loadPermSets(), [TAB.FIELDS]:   () => this._loadFields(),
            [TAB.OBJECTS]:  () => this._loadObjects(),  [TAB.VR]:       () => this._loadVr(),
            [TAB.VF]:       () => this._loadVf()
        };
        if (map[this.activeTab]) map[this.activeTab]();
    }

    // ────────────────────────────────────────────────────────
    // DATA LOADERS (unchanged)
    // ────────────────────────────────────────────────────────
    _loadFlows() {
        this.isLoading = true; this.hasError = false;
        getFlowSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.flowSummary = { ...this.flowSummary, ...r }; this._flowsLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadApex() {
        this.isLoading = true; this.hasError = false;
        getApexSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.apexSummary = { ...this.apexSummary, ...r }; this._apexLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadTriggers() {
        this.isLoading = true; this.hasError = false;
        getTriggerSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.triggerSummary = { ...this.triggerSummary, ...r }; this._triggersLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadLwc() {
        this.isLoading = true; this.hasError = false;
        getLwcSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => {
                if (r) {
                    this.lwcSummary = { ...this.lwcSummary, ...r };
                    this._lwcLoaded = true;
                }
            })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadAura() {
        this.isLoading = true; this.hasError = false;
        const auraPromise = getAuraSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.auraSummary = { ...this.auraSummary, ...r }; this._auraLoaded = true; } });
        const regPromise = this._governanceLoaded
            ? Promise.resolve()
            : getGovernanceRegistry()
                .then(r => { this.governanceRegistry = r || []; this._governanceLoaded = true; });
        Promise.all([auraPromise, regPromise])
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadProfiles() {
        this.isLoading = true; this.hasError = false;
        getProfileSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.profileSummary = { ...this.profileSummary, ...r }; this._profilesLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadPermSets() {
        this.isLoading = true; this.hasError = false;
        getPermissionSetSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.permSetSummary = { ...this.permSetSummary, ...r }; this._permSetsLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadFields() {
        this.isLoading = true; this.hasError = false;
        getCustomFieldSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.fieldSummary = { ...this.fieldSummary, ...r }; this._fieldsLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadObjects() {
        this.isLoading = true; this.hasError = false;
        getCustomObjectSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.objectSummary = { ...this.objectSummary, ...r }; this._objectsLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadVr() {
        this.isLoading = true; this.hasError = false;
        getValidationRuleSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.vrSummary = { ...this.vrSummary, ...r }; this._vrLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadVf() {
        this.isLoading = true; this.hasError = false;
        getVfSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.vfSummary = { ...this.vfSummary, ...r }; this._vfLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }

    _loadVfc() {
        this.isLoading = true; this.hasError = false;
        getVfComponentSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.vfcSummary = { ...this.vfcSummary, ...r }; this._vfcLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }

    _errorMsg(err) {
        if (err && err.body) return err.body.message || err.body.pageErrors?.[0]?.message || JSON.stringify(err.body);
        return 'An unexpected error occurred.';
    }

    // ────────────────────────────────────────────────────────
    // LIST PARSERS (unchanged)
    // ────────────────────────────────────────────────────────
    _flowProcessTypeLabel(processType) {
        const map = {
            'AutoLaunchedFlow'    : 'Auto-Launched',
            'ScheduledFlow'       : 'Scheduled',
            'RecordTriggeredFlow' : 'Record-Triggered',
            'Screen'              : 'Screen Flow',
            'ContactRequestFlow'  : 'Contact Request',
            'ActionCadenceFlow'   : 'Action Cadence',
            'Orchestrator'        : 'Orchestrator',
            'CheckoutFlow'        : 'Checkout',
            'FSCLending'          : 'FSC Lending',
            'DigitalForm'         : 'Digital Form'
        };
        return map[processType] || processType || '';
    }
    _parseSimpleList(raw) {
        if (!raw || raw.trim() === 'None' || raw.trim() === '') return [];
        return raw.trim().split('\n').filter(l => l.trim()).map(line => {
            const m = line.match(/^(\d+)\.\s+(.+)$/);
            return m ? { index: m[1], name: m[2].trim() } : null;
        }).filter(Boolean);
    }
    _parseDetailedList(raw) {
        if (!raw || typeof raw !== 'string' || raw.trim() === 'None' || raw.trim() === '') return [];
        return raw.trim().split('\n').filter(l => l.trim()).map(line => {
            const m = line.match(/^(\d+)\.\s+([^|]+)\|?(.*)$/);
            if (!m) return null;
            let meta = m[3] ? m[3].replace(/\|/g, '·').trim() : '';
            return { index: m[1], name: m[2].trim(), meta };
        }).filter(Boolean);
    }

    // Enriches parsed display items with dotName for delete agent
    // ruleObjects = List<ValidationRuleInfo> from activeRuleObjects / inactiveRuleObjects
    _enrichVrWithDotName(items, ruleObjects) {
        if (!items || !items.length) return items;
        // Build lookup: ruleName.toLowerCase() → "ObjectName.RuleName"
        const dotMap = {};
        if (Array.isArray(ruleObjects)) {
            ruleObjects.forEach(r => {
                if (r && r.name) dotMap[r.name.toLowerCase()] = (r.objectName || '') + '.' + r.name;
            });
        }
        return items.map(item => ({
            ...item,
            dotName: dotMap[item.name.toLowerCase()] || item.name
        }));
    }

    get activeFlowList() {
        if (!this.flowSummary || !this.flowSummary.allFlowObjects) return [];
        return this.flowSummary.allFlowObjects
            .filter(f => f.safetyStatus !== 'SKIP' && f.isActive)
            .map((f, i) => ({
                index: i + 1,
                name: f.label || f.apiName,
                processTypeLabel: this._flowProcessTypeLabel(f.processType)
            }));
    }
    get inactiveFlowList() {
        if (!this.flowSummary || !this.flowSummary.allFlowObjects) return [];
        return this.flowSummary.allFlowObjects
            .filter(f => f.safetyStatus !== 'SKIP' && !f.isActive)
            .map((f, i) => ({
                index: i + 1,
                name: f.label || f.apiName,
                processTypeLabel: this._flowProcessTypeLabel(f.processType)
            }));
    }
    get usedFlowList() {
        // IN_USE = has references — show flow name + Inactive warning badge if flow is inactive
        if (!this.flowSummary || !this.flowSummary.allFlowObjects) return [];
        return this.flowSummary.allFlowObjects
            .filter(f => f.safetyStatus === 'IN_USE')
            .map((f, i) => ({
                index: i + 1,
                name: f.label || f.apiName,
                apiName: f.apiName,
                isInactive: !f.isActive
            }));
    }
    get unusedFlowList() {
        // SAFE_TO_REVIEW = zero references — show flow name + Active warning badge if flow is still active
        if (!this.flowSummary || !this.flowSummary.allFlowObjects) return [];
        return this.flowSummary.allFlowObjects
            .filter(f => f.safetyStatus === 'SAFE_TO_REVIEW')
            .map((f, i) => ({
                index: i + 1,
                name: f.label || f.apiName,
                apiName: f.apiName,
                isActive: f.isActive
            }));
    }
    get usedFlowDisplayList()     { return this._clientNsFilter(this.usedFlowList);   }
    get unusedFlowDisplayList()   { return this._clientNsFilter(this.unusedFlowList); }
    get standardClassList()       { return this._parseSimpleList(this.apexSummary.standardClasses);       }
    get usedClassList()           { return this._parseSimpleList(this.apexSummary.usedClasses);           }
    get unusedClassList()         { return this._parseDetailedList(this.apexSummary.unusedClasses);       }
    get testClassList()           { return this._parseSimpleList(this.apexSummary.testClasses);           }
    get usedTriggerList()         { return this._parseSimpleList(this.triggerSummary.usedTriggers);       }
    get activeTriggerList()       { return this._parseDetailedList(this.triggerSummary.activeTriggers);   }
    get inactiveTriggerList()     { return this._parseDetailedList(this.triggerSummary.inactiveTriggers); }
    get unusedTriggerList()       { return this._parseDetailedList(this.triggerSummary.unusedTriggers);   }
    get allLwcList()              {
        return this._parseDetailedList(this.lwcSummary.allComponents).map(item => {
            const raw  = item.meta || '';
            const meta = raw.toLowerCase();
            const apiMatch = raw.match(/API:\s*([\d.]+)/i);
            const displayMeta = apiMatch ? 'API: ' + apiMatch[1] : '';
            let dotClass = 'status-dot dot-blue';
            if (meta.includes('unknown') || meta.includes('scan incomplete')) {
                dotClass = 'status-dot dot-orange';
            } else if (meta.includes('usedby') || meta.includes('managed') || meta.includes('entry_point') || meta.includes('in_use')) {
                dotClass = 'status-dot dot-green';
            }
            return { ...item, meta: displayMeta, dotClass };
        });
    }
    get filteredLwcList()         { return this._parseDetailedList(this.lwcSummary.filteredComponents);          }
    get unreferencedLwcList()     {
        return this._parseDetailedList(this.lwcSummary.unreferencedComponents).map(item => {
            const apiMatch = (item.meta || '').match(/API:\s*([\d.]+)/i);
            return { ...item, meta: apiMatch ? 'API: ' + apiMatch[1] : '' };
        });
    }
    // ── Referenced LWC list ──────────────────────────────────────────
    // Server doesn't currently emit a separate "referencedComponents" payload
    // for LWC, so we derive it client-side: everything in allLwcList that is
    // NOT in unreferencedLwcList. Uses the component name as the key.
    // Result is the inverse view of unreferencedLwcList — clicking the new
    // tile shows only LWCs that ARE in use, with their UsedBy line preserved
    // because it's already part of `item.meta` from the server-side scan.
    get referencedLwcList() {
        // Use allLwcList (already enriched with clean meta/dotClass) instead of raw parse
        const unrefNames = new Set(
            this._parseDetailedList(this.lwcSummary.unreferencedComponents).map(c => (c.name || '').toLowerCase())
        );
        return this.allLwcList.filter(c => c.name && !unrefNames.has(c.name.toLowerCase()));
    }
    // ── Resolves Application name from governance registry by component name prefix ──
    _resolveAuraApp(componentName) {
        if (!this.governanceRegistry || !this.governanceRegistry.length) return null;
        for (const reg of this.governanceRegistry) {
            if (!reg.Prefix_Patterns__c) continue;
            const patterns = reg.Prefix_Patterns__c.split(',').map(p => p.trim()).filter(Boolean);
            for (const pattern of patterns) {
                if (componentName && componentName.startsWith(pattern)) {
                    return reg.Label || reg.Namespace__c;
                }
            }
        }
        return null;
    }

    get allAuraList()             {
        const items = this._parseDetailedList(this.auraSummary.allComponents);
        return items.map(item => {
            const app = this._resolveAuraApp(item.name);
            const appLabel = app ? ` · App: ${app}` : '';
            // Extract namespace prefix from name (e.g. "ITSMS_MyComp" → "ITSMS")
            const nsMatch = item.name ? item.name.match(/^([A-Za-z0-9]+)_/) : null;
            const nsDisplay = nsMatch ? nsMatch[1] : '—';
            const isUnref = item.meta && item.meta.toLowerCase().includes('unreferenced');
            const status = isUnref ? 'Unreferenced' : 'Active';
            const statusClass = isUnref ? 'gov-badge gov-badge--warn' : 'gov-badge gov-badge--active';
            return { ...item, meta: item.meta + appLabel, appName: app || '—', nsDisplay, status, statusClass };
        });
    }
    get filteredAuraList()        { return this._parseDetailedList(this.auraSummary.filteredComponents);         }
    get unreferencedAuraList()    { return this._parseDetailedList(this.auraSummary.unreferencedComponents);     }
    // ── Referenced Aura list ──────────────────────────────────────────
    // Derived client-side: everything in allAuraList that is NOT unreferenced.
    get referencedAuraList() {
        const unrefNames = new Set(
            this._parseDetailedList(this.auraSummary.unreferencedComponents).map(c => (c.name || '').toLowerCase())
        );
        return this.allAuraList.filter(c => c.name && !unrefNames.has(c.name.toLowerCase()));
    }
    get usedProfileList()         { return this._parseDetailedList(this.profileSummary.usedProfiles);     }
    get unusedProfileList()       { return this._parseDetailedList(this.profileSummary.unusedProfiles);   }
    get usedPermSetList()         { return this._parseDetailedList(this.permSetSummary.usedPermSets);     }
    get unusedPermSetList()       { return this._parseDetailedList(this.permSetSummary.unusedPermSets);   }
    get allFieldList()            { return this._parseDetailedList(this.fieldSummary.allFields);                 }
    get filteredFieldList()       { return this._parseDetailedList(this.fieldSummary.filteredFields);            }
    get emptyFieldList()          { return this._parseDetailedList(this.fieldSummary.emptyFields);               }
    get allObjectList()           { return this._parseDetailedList(this.objectSummary.allObjects);               }
    get filteredObjectList()      { return this._parseDetailedList(this.objectSummary.filteredObjects);          }
    get emptyObjectList()         { return this._parseDetailedList(this.objectSummary.emptyObjects);             }
    // ── In-Use / With-Records derived lists ──────────────────────────
    // Server doesn't emit a dedicated "in use" list for Fields/Objects, so
    // we derive it client-side: everything in the All list that is NOT in
    // the empty list. Same pattern used for referencedLwcList. Uses the
    // item name (case-insensitive) as the dedup key.
    get fieldInUseList() {
        const emptyNames = new Set(this.emptyFieldList.map(f => (f.name || '').toLowerCase()));
        return this.allFieldList.filter(f => f.name && !emptyNames.has(f.name.toLowerCase()));
    }
    get objectWithRecordsList() {
        const emptyNames = new Set(this.emptyObjectList.map(o => (o.name || '').toLowerCase()));
        return this.allObjectList.filter(o => o.name && !emptyNames.has(o.name.toLowerCase()));
    }
    get fieldInUseDisplayList()       { return this._clientNsFilter(this.fieldInUseList);        }
    get objectWithRecordsDisplayList(){ return this._clientNsFilter(this.objectWithRecordsList); }
    get activeVrList() {
        const items = this._parseDetailedList(this.vrSummary.activeRules);
        return this._enrichVrWithDotName(items, this.vrSummary.activeRuleObjects);
    }
    get inactiveVrList() {
        const items = this._parseDetailedList(this.vrSummary.inactiveRules);
        return this._enrichVrWithDotName(items, this.vrSummary.inactiveRuleObjects);
    }
    get filteredVrList() {
        const items = this._parseDetailedList(this.vrSummary.filteredRules);
        return this._enrichVrWithDotName(items, this.vrSummary.activeRuleObjects);
    }

    // VF page lists — built from allPageObjects returned by backend
    get allVfList() {
        const pages = this.vfSummary.allPageObjects;
        if (!pages || !pages.length) return [];
        return pages.map((p, i) => ({
            index : i + 1,
            name  : p.name,
            meta  : [
                p.namespacePrefix ? '[' + p.namespacePrefix + ']' : '',
                p.apiVersion      ? 'API: ' + p.apiVersion        : '',
                p.lastModifiedDate ? 'Modified: ' + p.lastModifiedDate : ''
            ].filter(Boolean).join(' · ')
        }));
    }
    get unreferencedVfList() {
        const pages = this.vfSummary.allPageObjects;
        if (!pages || !pages.length) return [];
        return pages
            .filter(p => !p.isReferenced && !p.isManagedPackage)
            .map((p, i) => ({
                index : i + 1,
                name  : p.name,
                meta  : [
                    p.namespacePrefix ? '[' + p.namespacePrefix + ']' : '',
                    p.apiVersion      ? 'API: ' + p.apiVersion        : '',
                    p.lastModifiedDate ? 'Modified: ' + p.lastModifiedDate : ''
                ].filter(Boolean).join(' · ')
            }));
    }
    get referencedVfList() {
        const pages = this.vfSummary.allPageObjects;
        if (!pages || !pages.length) return [];
        return pages
            .filter(p => p.isReferenced || p.isManagedPackage)
            .map((p, i) => ({
                index : i + 1,
                name  : p.name,
                meta  : [
                    p.namespacePrefix  ? '[' + p.namespacePrefix + ']' : '',
                    p.apiVersion       ? 'API: ' + p.apiVersion        : '',
                    p.referencedBy     ? '🔗 ' + p.referencedBy        : ''
                ].filter(Boolean).join(' · ')
            }));
    }
    get vfWithNsList()             { return this._filterWithNs(this.allVfList);  }
    get vfNoNsList()               { return this._filterNoNs(this.allVfList);    }
    get vfDisplayList() {
        let list = this.allVfList;
        if (this.activeCardFilter === FILTER.WITH_NS)      list = this.vfWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)        list = this.vfNoNsList;
        if (this.activeCardFilter === FILTER.UNREFERENCED) list = this.unreferencedVfList;
        if (this.activeCardFilter === FILTER.REFERENCED)   list = this.referencedVfList;
        return this._clientNsFilter(list);
    }
    get unreferencedVfDisplayList(){ return this._clientNsFilter(this.unreferencedVfList); }

    // VF component lists — built from allComponentObjects returned by backend
    get allVfcList() {
        const comps = this.vfcSummary.allComponentObjects;
        if (!comps || !comps.length) return [];
        return comps.map((c, i) => ({
            index : i + 1,
            name  : c.name,
            meta  : (c.namespacePrefix ? '[' + c.namespacePrefix + '] ' : '') +
                    (c.apiVersion ? 'v' + c.apiVersion : '') +
                    (c.lastModifiedDate ? ' · ' + c.lastModifiedDate : ''),
            safety: c.safetyStatus
        }));
    }
    get unreferencedVfcList() {
        return this.allVfcList.filter(c => c.safety === 'SAFE_TO_REVIEW');
    }
    get referencedVfcList() {
        return this.allVfcList.filter(c => c.safety !== 'SAFE_TO_REVIEW');
    }
    get vfcWithNsList()             { return this._filterWithNs(this.allVfcList); }
    get vfcNoNsList()               { return this._filterNoNs(this.allVfcList);   }
    get vfcDisplayList() {
        let list = this.allVfcList;
        if (this.activeCardFilter === FILTER.WITH_NS)      list = this.vfcWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)        list = this.vfcNoNsList;
        if (this.activeCardFilter === FILTER.UNREFERENCED) list = this.unreferencedVfcList;
        if (this.activeCardFilter === FILTER.REFERENCED)   list = this.referencedVfcList;
        return this._clientNsFilter(list);
    }
    get unreferencedVfcDisplayList(){ return this._clientNsFilter(this.unreferencedVfcList);    }
    get referencedVfcDisplayList()  { return this._clientNsFilter(this.referencedVfcList);      }
    get referencedVfDisplayList()  { return this._clientNsFilter(this.referencedVfList);   }

    // ────────────────────────────────────────────────────────
    // STAT CARD DISPLAY COUNTS — reflect client-side ns filter
    // When nsFilterInput is active, show filtered counts
    // When no filter, show original summary counts
    // ────────────────────────────────────────────────────────

    // FLOWS
    get flowTotalDisplay()    { return this.nsFilterInput ? (this.activeFlowDisplayList.length + this.inactiveFlowDisplayList.length) : this.flowSummary.totalCount; }
    get flowActiveDisplay()   { return this.nsFilterInput ? this.activeFlowDisplayList.length    : this.flowSummary.activeCount;   }
    get flowInactiveDisplay() { return this.nsFilterInput ? this.inactiveFlowDisplayList.length  : this.flowSummary.inactiveCount; }
    get flowUsedDisplay()     {
        if (this.nsFilterInput) return this.usedFlowDisplayList.length;
        return this.flowSummary.usedCount !== undefined ? this.flowSummary.usedCount : '—';
    }
    get flowUnusedDisplay()   {
        if (this.nsFilterInput) return this.unusedFlowDisplayList.length;
        return this.flowSummary.unusedCount !== undefined ? this.flowSummary.unusedCount : '—';
    }

    // APEX
    get apexTotalDisplay()    { return this.nsFilterInput ? (this.standardClassDisplayList.length + this.usedClassDisplayList.length + this.unusedClassDisplayList.length + this.testClassDisplayList.length) : this.apexSummary.totalCount; }
    get apexStandardDisplay() { return this.nsFilterInput ? this.standardClassDisplayList.length : this.apexSummary.standardCount; }
    get apexUsedDisplay()     { return this.nsFilterInput ? this.usedClassDisplayList.length     : this.apexSummary.usedCount;     }
    get apexUnusedDisplay()   { return this.nsFilterInput ? this.unusedClassDisplayList.length   : this.apexSummary.unusedCount;   }
    get apexTestDisplay()     { return this.nsFilterInput ? this.testClassDisplayList.length     : this.apexSummary.testCount;     }

    // TRIGGERS
    get triggerTotalDisplay()    { return this.nsFilterInput ? (this.activeTriggerDisplayList.length + this.inactiveTriggerDisplayList.length) : this.triggerSummary.totalCount; }
    get triggerActiveDisplay()   { return this.nsFilterInput ? this.activeTriggerDisplayList.length   : this.triggerSummary.activeCount;   }
    get triggerInactiveDisplay() { return this.nsFilterInput ? this.inactiveTriggerDisplayList.length : this.triggerSummary.inactiveCount; }
    get triggerUsedDisplay()     { return this.nsFilterInput ? this.usedTriggerDisplayList.length     : this.triggerSummary.usedCount;     }
    get triggerUnusedDisplay()   { return this.nsFilterInput ? this.unusedTriggerDisplayList.length   : this.triggerSummary.unusedCount;   }

    // LWC
    get lwcTotalDisplay()        { return this.nsFilterInput ? this.lwcDisplayList.length  : this.lwcSummary.totalCount;            }
    get lwcWithNsDisplay()       { return this.nsFilterInput ? this._filterWithNs(this.lwcDisplayList).length  : this.lwcSummary.withNamespaceCount;    }
    get lwcNoNsDisplay()         { return this.nsFilterInput ? this._filterNoNs(this.lwcDisplayList).length    : this.lwcSummary.withoutNamespaceCount; }
    get lwcUnreferencedDisplay() { return this.nsFilterInput ? this.unreferencedLwcDisplayList.length : this.lwcSummary.unreferencedCount; }
    // ── Referenced count ─────────────────────────────────────────────
    // Always derived from the in-memory list (referenced = total − unref).
    // Mirrors how `lwcUnreferencedDisplay` falls back to the ns-filtered list
    // when a namespace filter is active.
    get lwcReferencedDisplay()   { return this.nsFilterInput ? this.referencedLwcDisplayList.length   : this.referencedLwcList.length; }

    // AURA
    get auraTotalDisplay()        { return this.nsFilterInput ? this.auraDisplayList.length : this.auraSummary.totalCount;            }
    get auraWithNsDisplay()       { return this.auraWithNsList.length; }
    get auraNoNsDisplay()         { return this.auraNoNsList.length; }
    get auraUnreferencedDisplay() { return this.nsFilterInput ? this.unreferencedAuraDisplayList.length : this.auraSummary.unreferencedCount; }
    get auraReferencedDisplay()   { return this.nsFilterInput ? this.referencedAuraDisplayList.length   : this.referencedAuraList.length; }

    // PROFILES
    get profileTotalDisplay()    { return this.nsFilterInput ? (this.usedProfileDisplayList.length + this.unusedProfileDisplayList.length) : this.profileSummary.totalCount; }
    get profileUsedDisplay()     { return this.nsFilterInput ? this.usedProfileDisplayList.length   : this.profileSummary.usedCount;   }
    get profileUnusedDisplay()   { return this.nsFilterInput ? this.unusedProfileDisplayList.length : this.profileSummary.unusedCount; }

    // PERMSETS
    get permSetTotalDisplay()    { return this.nsFilterInput ? (this.usedPermSetDisplayList.length + this.unusedPermSetDisplayList.length) : this.permSetSummary.totalCount; }
    get permSetUsedDisplay()     { return this.nsFilterInput ? this.usedPermSetDisplayList.length   : this.permSetSummary.usedCount;   }
    get permSetUnusedDisplay()   { return this.nsFilterInput ? this.unusedPermSetDisplayList.length : this.permSetSummary.unusedCount; }

    // FIELDS
    get fieldTotalDisplay()   { return this.nsFilterInput ? this.fieldDisplayList.length  : this.fieldSummary.totalCount;            }
    get fieldWithNsDisplay()  { return this.nsFilterInput ? this._filterWithNs(this.fieldDisplayList).length  : this.fieldSummary.withNamespaceCount;    }
    get fieldNoNsDisplay()    { return this.nsFilterInput ? this._filterNoNs(this.fieldDisplayList).length    : this.fieldSummary.withoutNamespaceCount; }
    get fieldEmptyDisplay()   { return this.nsFilterInput ? this.emptyFieldDisplayList.length : this.fieldSummary.emptyCount; }
    get fieldInUseDisplay()   { return this.nsFilterInput ? (this.fieldDisplayList.length - this.emptyFieldDisplayList.length) : (parseInt(this.fieldSummary.totalCount) || 0) - (parseInt(this.fieldSummary.emptyCount) || 0); }

    // OBJECTS
    get objectTotalDisplay()  { return this.nsFilterInput ? this.objectDisplayList.length : this.objectSummary.totalCount;            }
    get objectWithNsDisplay() { return this.nsFilterInput ? this._filterWithNs(this.objectDisplayList).length : this.objectSummary.withNamespaceCount;    }
    get objectNoNsDisplay()   { return this.nsFilterInput ? this._filterNoNs(this.objectDisplayList).length   : this.objectSummary.withoutNamespaceCount; }
    get objectEmptyDisplay()  { return this.nsFilterInput ? this.emptyObjectDisplayList.length : this.objectSummary.emptyCount; }
    get objectWithRecordsDisplay() { return this.nsFilterInput ? (this.objectDisplayList.length - this.emptyObjectDisplayList.length) : (parseInt(this.objectSummary.totalCount) || 0) - (parseInt(this.objectSummary.emptyCount) || 0); }

    // VR
    get vrTotalDisplay()    { return this.nsFilterInput ? (this.activeVrDisplayList.length + this.inactiveVrDisplayList.length) : this.vrSummary.totalCount;    }
    get vrActiveDisplay()   { return this.nsFilterInput ? this.activeVrDisplayList.length   : this.vrSummary.activeCount;   }
    get vrInactiveDisplay() { return this.nsFilterInput ? this.inactiveVrDisplayList.length : this.vrSummary.inactiveCount; }

    get vfTotalDisplay()        { return this.nsFilterInput ? this.vfDisplayList.length         : this.vfSummary.totalCount;        }
    get vfReferencedDisplay()   { return this.nsFilterInput ? this.referencedVfDisplayList.length  : this.vfSummary.referencedCount;   }
    get vfUnreferencedDisplay() { return this.nsFilterInput ? this.unreferencedVfDisplayList.length : this.vfSummary.unreferencedCount; }
    get vfWithNsDisplay()       { return this.nsFilterInput ? this.vfDisplayList.filter(p => p.meta && p.meta.includes('[')).length : this.vfSummary.withNamespaceCount; }
    get vfNoNsDisplay()         { return this.nsFilterInput ? this.vfDisplayList.filter(p => !p.meta || !p.meta.includes('[')).length : this.vfSummary.withoutNamespaceCount; }
    get vfcTotalDisplay()        { return this.nsFilterInput ? this.vfcDisplayList.length          : this.vfcSummary.totalCount;        }
    get vfcUnreferencedDisplay() { return this.nsFilterInput ? this.unreferencedVfcDisplayList.length : this.vfcSummary.unreferencedCount; }
    get vfcReferencedDisplay()   { return this.nsFilterInput ? this.referencedVfcDisplayList.length   : this.referencedVfcList.length; }
    get vfcWithNsDisplay()       { return this.nsFilterInput ? this.vfcDisplayList.filter(c => c.meta && c.meta.includes('[')).length : this.vfcSummary.withNamespaceCount; }
    get vfcNoNsDisplay()         { return this.nsFilterInput ? this.vfcDisplayList.filter(c => !c.meta || !c.meta.includes('[')).length : this.vfcSummary.withoutNamespaceCount; }
    get apexHasFilter()       { return this._hasFilter(this.apexSummary.namespaceFilterApplied);       }
    get triggerHasFilter()    { return this._hasFilter(this.triggerSummary.namespaceFilterApplied);    }
    get lwcHasFilter()        { return this._hasFilter(this.lwcSummary.namespaceFilterApplied);        }
    get auraHasFilter()       { return this._hasFilter(this.auraSummary.namespaceFilterApplied);       }
    get profileHasFilter()    { return this._hasFilter(this.profileSummary.namespaceFilterApplied);    }
    get permSetHasFilter()    { return this._hasFilter(this.permSetSummary.namespaceFilterApplied);    }
    get fieldHasFilter()      { return this._hasFilter(this.fieldSummary.namespaceFilterApplied);      }
    get objectHasFilter()     { return this._hasFilter(this.objectSummary.namespaceFilterApplied);     }
    get vrHasFilter()         { return this._hasFilter(this.vrSummary.namespaceFilterApplied);         }

    _hasFilter(v) { return v && v !== 'None (showing all)' && v !== '—'; }

    get filteredActiveFlowList()   { return this._parseSimpleList(this.flowSummary.filteredActiveFlows);     }
    get filteredInactiveFlowList() { return this._parseSimpleList(this.flowSummary.filteredInactiveFlows);   }
    get filteredApexList()         { return this._parseDetailedList(this.apexSummary.filteredClasses);       }
    get filteredTriggerList()      { return this._parseDetailedList(this.triggerSummary.filteredTriggers);   }
    get filteredProfileList()      { return this._parseDetailedList(this.profileSummary.filteredProfiles);   }
    get filteredPermSetList()      { return this._parseDetailedList(this.permSetSummary.filteredPermSets);   }
}