import { LightningElement, track } from 'lwc';
import getFlowSummary           from '@salesforce/apex/MetadataAgentAction.getFlowSummary';
import getApexSummary           from '@salesforce/apex/ApexClassAgentAction.getApexSummary';
import getTriggerSummary        from '@salesforce/apex/TriggerAgentAction.getTriggerSummary';
import getLwcSummary            from '@salesforce/apex/LwcAgentAction.getLwcSummary';
import getAuraSummary           from '@salesforce/apex/AuraAgentAction.getAuraSummary';
import getProfileSummary        from '@salesforce/apex/ProfileAgentAction.getProfileSummary';
import getPermissionSetSummary  from '@salesforce/apex/PermissionSetAgentAction.getPermissionSetSummary';
import getCustomFieldSummary    from '@salesforce/apex/CustomFieldAgentAction.getCustomFieldSummary';
import getCustomObjectSummary   from '@salesforce/apex/CustomObjectAgentAction.getCustomObjectSummary';
import getValidationRuleSummary from '@salesforce/apex/ValidationRuleAgentAction.getValidationRuleSummary';

// Agent actions — new backend class
import handleAgentQuery         from '@salesforce/apex/OrgCleanupAgentAction.handleAgentQuery';
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
    VR       : 'vr'
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
    UNREFERENCED : 'unreferenced'
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
    VR      : 'vr'
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
    get showAllSections()       { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL; }
    get showTotalSection()      { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL; }
    get showStandardSection()   { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.STANDARD; }
    get showUsedSection()       { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.USED;     }
    get showUnusedSection()     { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.UNUSED;   }
    get showTestSection()       { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.TEST;     }
    get showActiveSection()     { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.ACTIVE;   }
    get showInactiveSection()   { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.INACTIVE; }
    get showAssignedSection()   { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.USED;     }
    get showUnassignedSection() { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.UNUSED;   }
    get showWithNsSection()     { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.WITH_NS;   }
    get showNoNsSection()       { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.NO_NS;     }
    get showEmptySection()      { return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.EMPTY;        }
    get showUnreferencedSection(){ return this.activeCardFilter === FILTER.ALL || this.activeCardFilter === FILTER.TOTAL || this.activeCardFilter === FILTER.UNREFERENCED; }
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

    @track flowSummary    = { totalCount: '—', activeCount: '—', inactiveCount: '—', activeFlows: '', inactiveFlows: '',
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

    // ── Agent panel state ────────────────────────────────────
    @track agentMessages = [];
    @track agentInput = '';
    @track agentIsProcessing = false;

    // Last meaningful data response (fields list, flows list etc.) — used for export
    _lastDataResponse = null;

    // Pending delete confirmation: { type, name }
    _pendingDelete = null;
    _pendingMassDelete = null; // { type, names: [] } — waiting for mass delete confirmation
    _pendingTypeSelect = null; // { name, matches: [{type, label}] } — waiting for user to pick a type

    connectedCallback() {
        this._loadFlows();
        this._agentWelcome();
        this._boundOutsideClick = this._handleOutsideClick.bind(this);
        document.addEventListener('click', this._boundOutsideClick);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._boundOutsideClick);
    }

    _handleOutsideClick(event) {
    }

    get agentHeaderName()    { return AGENT.HEADER_NAME; }
    get agentHeaderStatus()  { return AGENT.HEADER_STATUS; }
    get agentModeName()      { return AGENT.MODE_NAME; }

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
        // Detect if this is a reference-blocking report (has grouped reference sections)
        const isReferenceReport = isError && text && (
            text.includes('Cannot delete') ||
            text.includes('reference(s) must be removed first')
        );
        this.agentMessages = [...this.agentMessages, {
            id      : nextId(),
            text,
            isAgent : true,
            isTyping: false,
            isSuccess,
            isError,
            isReferenceReport,
            cssClass: 'agent-msg agent-msg--agent'
        }];
        this._scrollMessages();
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
                const hasMetadata = msg.length > 50 || /flow|apex|trigger|lwc|aura|profile|permission|field|object|validation/i.test(msg);
                if (hasMetadata) this._lastDataResponse = msg;
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
        const lower = query.toLowerCase();

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

            const afterDelete = query.replace(/^delete\s+/i, '').trim();
            const tokens      = afterDelete.split(/\s+/);
            const p1 = tokens[0] ? tokens[0].toLowerCase() : '';
            const p2 = (tokens[0] && tokens[1]) ? (tokens[0] + ' ' + tokens[1]).toLowerCase() : '';
            const p3 = (tokens[0] && tokens[1] && tokens[2])
                       ? (tokens[0] + ' ' + tokens[1] + ' ' + tokens[2]).toLowerCase() : '';

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
                rawName = tokens.slice(typeStrip).join(' ').trim() || null;
            } else {
                // No type keyword — dot notation check for field/vr, otherwise ambiguous
                const dotNameMatch = query.match(/delete\s+([A-Za-z0-9_]+\.[A-Za-z0-9_]+)/i);
                if (dotNameMatch) {
                    type    = META_TYPE.FIELD;
                    rawName = afterDelete;
                } else {
                    rawName = afterDelete || null;
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

        if (tabs.length > 0) {
            return { action: 'query', tab: tabs[0], tabs };
        }

        return { action: 'query', tab: null, tabs: [] };
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
            check([...(this.unusedProfileList || []), ...(this.usedProfileList || [])],   META_TYPE.PROFILE, 'Profile');
            check([...(this.unusedPermSetList || []), ...(this.usedPermSetList || [])],   META_TYPE.PERMSET, 'Permission Set');
            check([...(this.activeVrList || []), ...(this.inactiveVrList || [])],         META_TYPE.VR,      'Validation Rule');
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
                    `  • delete lwc ${intent.name}\n\n` +
                    `Or make sure the relevant tab is loaded first.`
                );
                return;
            } else if (matches.length === 1) {
                // Exactly one match — proceed directly, use apiName override if present (fields)
                intent.type = matches[0].type;
                if (matches[0].apiName) intent.name = matches[0].apiName;
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
            permset: 'Permission Set', profile: 'Profile', vr: 'Validation Rule'
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
            profile: 'Profile'
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
                    // References found — show them and block delete
                    this._addAgentMsg(
                        `⚠️ Cannot delete ${typeLabel} "${intent.name}" — references found:\n\n` +
                        refReport
                    );
                } else {
                    // No references — show confirmation
                    this._pendingDelete = { type: intent.type, name: intent.name };
                    this._addAgentMsg(
                        `Found: ${intent.name} (${typeLabel})\n` +
                        `No active references found. Safe to delete.\n\n` +
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
        };

        const typeLabel = typeLabels[type] || type;
        const nameList  = names.map((n, i) => `  ${i + 1}. ${n}`).join('\n');

        // Extra hint for dot-notation types
        let hint = '';
        if (type === META_TYPE.FIELD) hint = '\n⚠️ Format required: ObjectName.FieldName';
        if (type === META_TYPE.VR)    hint = '\n⚠️ Format required: ObjectName.RuleName';
        if (type === META_TYPE.PROFILE) hint = `\n⚠️ Users will be moved to the default fallback profile.`;

        this._pendingMassDelete = { type, names };
        this._addAgentMsg(
            `⚠️ Mass Delete Confirmation\n\n` +
            `You are about to delete ${names.length} ${typeLabel}(s):${hint}\n${nameList}\n\n` +
            `This action cannot be undone. Reply "yes" to confirm or "no" to cancel.`
        );
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
        this.activeCardFilter = FILTER.ALL;

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

    get showNamespaceFilter() {
        return [TAB.FLOWS, TAB.APEX, TAB.TRIGGERS, TAB.LWC, TAB.AURA, TAB.PROFILES, TAB.PERMSETS, TAB.FIELDS, TAB.OBJECTS, TAB.VR].includes(this.activeTab);
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
            this.activeCardFilter = FILTER.ALL;
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

    // Namespace-based filtered lists for LWC / Aura / Fields / Objects

    _filterByNs(list, hasNs) {
        return list.filter(item => {
            const hasNamespace = item.name && item.name.includes('__') && item.meta && item.meta.includes('NS:');
            return hasNs ? hasNamespace : !hasNamespace;
        });
    }
    _hasNamespace(item)  {
        // Checks both 'NS: xxx' in meta (trigger/apex format) and '[xxx]' in name (lwc/aura/field/object format)
        return (item.meta && item.meta.toLowerCase().includes('ns:')) ||
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
        return this._clientNsFilter(list);
    }
    get auraDisplayList()   {
        let list = this.allAuraList;
        if (this.activeCardFilter === FILTER.WITH_NS)      list = this.auraWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)        list = this.auraNoNsList;
        if (this.activeCardFilter === FILTER.UNREFERENCED) list = this.unreferencedAuraList;
        return this._clientNsFilter(list);
    }
    get fieldDisplayList()  {
        let list = this.allFieldList;
        if (this.activeCardFilter === FILTER.WITH_NS) list = this.fieldWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)   list = this.fieldNoNsList;
        if (this.activeCardFilter === FILTER.EMPTY)   list = this.emptyFieldList;
        return this._clientNsFilter(list);
    }
    get objectDisplayList() {
        let list = this.allObjectList;
        if (this.activeCardFilter === FILTER.WITH_NS) list = this.objectWithNsList;
        if (this.activeCardFilter === FILTER.NO_NS)   list = this.objectNoNsList;
        if (this.activeCardFilter === FILTER.EMPTY)   list = this.emptyObjectList;
        return this._clientNsFilter(list);
    }
    get unreferencedLwcDisplayList()  { return this._clientNsFilter(this.unreferencedLwcList);  }
    get unreferencedAuraDisplayList() { return this._clientNsFilter(this.unreferencedAuraList); }
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

    // Reset card filter when switching tabs
    _switchTab(tab, loadedFlag, loadFn) {
        // Reset namespace input AND filter when switching tabs
        if (this.activeTab !== tab) {
            this.namespaceInput   = '';
            this.nsFilterInput    = ''; // clear active filter too
            this._lastDataResponse = null; // clear chat export — tab data takes over
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

    handleRefreshAll() {
        this._flowsLoaded = this._apexLoaded = this._triggersLoaded = false;
        this._lwcLoaded   = this._auraLoaded = this._profilesLoaded = false;
        this._permSetsLoaded = this._fieldsLoaded = this._objectsLoaded = this._vrLoaded = false;
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
            [TAB.OBJECTS]:'Custom Objects', [TAB.VR]:'Validation Rules'
        };
        this._exportTabLabel  = tabLabels[this.activeTab] || 'Metadata';
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
    // ── Smart export: use chat data only if it matches active tab ───
    _getExportSource() {
        if (!this._lastDataResponse) return null;
        const text  = this._lastDataResponse.toLowerCase();
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
            [TAB.OBJECTS]:'custom-objects', [TAB.VR]:'validation-rules'
        };
        return tabTags[this.activeTab] || ('dashboard-' + this.activeTab);
    }

    _buildExportContent(chatText) {
        const e = v => (v || '').toString().replace(/"/g, '""');

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
            } else if (ct === TAB.FLOWS && chatText) {
                // Parse Label / API Name / Type directly from the chatbot block-format response
                // The summary fields (activeFlows/inactiveFlows) contain detailed strings that
                // _parseSimpleList cannot split correctly — use parseChatList on chatText instead
                const flowItems = parseChatList(chatText).filter(i => i.type && /flow|Appointments|RoutingFlow|AutoLaunched|EvaluationFlow|PromptFlow|IndividualObject|DataCapture|ApprovalWorkflow|ManagedContent|FieldService/i.test(i.type));
                if (flowItems.length) {
                    flowItems.forEach(r => items.push({ label: r.label || r.apiName, apiName: r.apiName || r.label, type: 'Flow', meta: '' }));
                } else if (this._flowsLoaded && this.flowSummary) {
                    // Fallback: summary loaded — parse active/inactive simple lists
                    this._parseSimpleList(this.flowSummary.activeFlows)
                        .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Flow', status: 'Active',   meta: '' }));
                    this._parseSimpleList(this.flowSummary.inactiveFlows)
                        .forEach(r => items.push({ label: r.name, apiName: r.name, type: 'Flow', status: 'Inactive', meta: '' }));
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

        const tab = this.activeTab;

        // ── FLOWS ─────────────────────────────────────────────
        if (tab === TAB.FLOWS && this._flowsLoaded && this.flowSummary && this.flowSummary.allFlowObjects) {
            for (const f of this.flowSummary.allFlowObjects) {
                row(f.label, f.apiName, f.processType || 'Flow');
            }
        }

        // ── APEX CLASSES ───────────────────────────────────────
        if (tab === TAB.APEX && this._apexLoaded && this.apexSummary) {
            const s = this.apexSummary;
            // Unused — use parsed string list as source of truth
            for (const c of this.unusedClassList) {
                row(c.name, c.name, 'Apex Class');
            }
            // Used
            for (const c of this.usedClassList) {
                row(c.name, c.name, 'Apex Class');
            }
            // Test
            for (const c of this.testClassList) {
                row(c.name, c.name, 'Apex Class');
            }
            // Standard/Package
            for (const c of this.standardClassList) {
                row(c.name, c.name, 'Apex Class');
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
            addTriggers(this.activeTriggerList);
            addTriggers(this.inactiveTriggerList);
        }

        // ── LWC ───────────────────────────────────────────────
        if (tab === TAB.LWC && this._lwcLoaded) {
            for (const c of this.allLwcList) {
                row(c.name, c.name, 'LWC Component');
            }
        }

        // ── AURA ──────────────────────────────────────────────
        if (tab === TAB.AURA && this._auraLoaded) {
            for (const c of this.allAuraList) {
                row(c.name, c.name, 'Aura Component');
            }
        }

        // ── PROFILES ──────────────────────────────────────────
        if (tab === TAB.PROFILES && this._profilesLoaded) {
            for (const p of this.usedProfileList)   { row(p.name, p.name, 'Profile'); }
            for (const p of this.unusedProfileList) { row(p.name, p.name, 'Profile'); }
        }

        // ── PERMISSION SETS ───────────────────────────────────
        if (tab === TAB.PERMSETS && this._permSetsLoaded) {
            for (const p of this.usedPermSetList)   { row(p.name, p.name, 'Permission Set'); }
            for (const p of this.unusedPermSetList) { row(p.name, p.name, 'Permission Set'); }
        }

        // ── CUSTOM FIELDS ─────────────────────────────────────
        if (tab === TAB.FIELDS && this._fieldsLoaded) {
            for (const f of this.allFieldList) {
                row(f.name, f.name, 'Custom Field');
            }
        }

        // ── CUSTOM OBJECTS ────────────────────────────────────
        if (tab === TAB.OBJECTS && this._objectsLoaded) {
            for (const o of this.allObjectList) {
                row(o.name, o.name, 'Custom Object');
            }
        }

        // ── VALIDATION RULES ──────────────────────────────────
        if (tab === TAB.VR && this._vrLoaded) {
            for (const r of this.activeVrList)   { row(r.name, r.name, 'Validation Rule'); }
            for (const r of this.inactiveVrList) { row(r.name, r.name, 'Validation Rule'); }
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
        };
        if (loadIfNeeded[this.activeTab]) loadIfNeeded[this.activeTab]();
    }

    _dispatchCurrentTab() {
        const map = {
            [TAB.FLOWS]:    () => this._loadFlows(),    [TAB.APEX]:     () => this._loadApex(),
            [TAB.TRIGGERS] : () => this._loadTriggers(), [TAB.LWC]:      () => this._loadLwc(),
            [TAB.AURA]:     () => this._loadAura(),     [TAB.PROFILES] : () => this._loadProfiles(),
            [TAB.PERMSETS] : () => this._loadPermSets(), [TAB.FIELDS]:   () => this._loadFields(),
            [TAB.OBJECTS]:  () => this._loadObjects(),  [TAB.VR]:       () => this._loadVr()
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
        getAuraSummary({ namespaceFilter: this.namespaceInput.trim() || null })
            .then(r => { if (r) { this.auraSummary = { ...this.auraSummary, ...r }; this._auraLoaded = true; } })
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

    _errorMsg(err) {
        if (err && err.body) return err.body.message || err.body.pageErrors?.[0]?.message || JSON.stringify(err.body);
        return 'An unexpected error occurred.';
    }

    // ────────────────────────────────────────────────────────
    // LIST PARSERS (unchanged)
    // ────────────────────────────────────────────────────────
    _parseSimpleList(raw) {
        if (!raw || raw.trim() === 'None' || raw.trim() === '') return [];
        return raw.trim().split('\n').filter(l => l.trim()).map(line => {
            const m = line.match(/^(\d+)\.\s+(.+)$/);
            return m ? { index: m[1], name: m[2].trim() } : null;
        }).filter(Boolean);
    }
    _parseDetailedList(raw) {
        if (!raw || raw.trim() === 'None' || raw.trim() === '') return [];
        return raw.trim().split('\n').filter(l => l.trim()).map(line => {
            const m = line.match(/^(\d+)\.\s+([^|]+)\|?(.*)$/);
            if (!m) return null;
            return { index: m[1], name: m[2].trim(), meta: m[3] ? m[3].replace(/\|/g, '·').trim() : '' };
        }).filter(Boolean);
    }

    get activeFlowList()          { return this._parseSimpleList(this.flowSummary.activeFlows);           }
    get inactiveFlowList()        { return this._parseSimpleList(this.flowSummary.inactiveFlows);         }
    get standardClassList()       { return this._parseSimpleList(this.apexSummary.standardClasses);       }
    get usedClassList()           { return this._parseSimpleList(this.apexSummary.usedClasses);           }
    get unusedClassList()         { return this._parseDetailedList(this.apexSummary.unusedClasses);       }
    get testClassList()           { return this._parseSimpleList(this.apexSummary.testClasses);           }
    get usedTriggerList()         { return this._parseSimpleList(this.triggerSummary.usedTriggers);       }
    get activeTriggerList()       { return this._parseDetailedList(this.triggerSummary.activeTriggers);   }
    get inactiveTriggerList()     { return this._parseDetailedList(this.triggerSummary.inactiveTriggers); }
    get unusedTriggerList()       { return this._parseDetailedList(this.triggerSummary.unusedTriggers);   }
    get allLwcList()              { return this._parseDetailedList(this.lwcSummary.allComponents);               }
    get filteredLwcList()         { return this._parseDetailedList(this.lwcSummary.filteredComponents);          }
    get unreferencedLwcList()     { return this._parseDetailedList(this.lwcSummary.unreferencedComponents);      }
    get allAuraList()             { return this._parseDetailedList(this.auraSummary.allComponents);              }
    get filteredAuraList()        { return this._parseDetailedList(this.auraSummary.filteredComponents);         }
    get unreferencedAuraList()    { return this._parseDetailedList(this.auraSummary.unreferencedComponents);     }
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
    get activeVrList()            { return this._parseDetailedList(this.vrSummary.activeRules);           }
    get inactiveVrList()          { return this._parseDetailedList(this.vrSummary.inactiveRules);         }
    get filteredVrList()          { return this._parseDetailedList(this.vrSummary.filteredRules);         }

    // ────────────────────────────────────────────────────────
    // STAT CARD DISPLAY COUNTS — reflect client-side ns filter
    // When nsFilterInput is active, show filtered counts
    // When no filter, show original summary counts
    // ────────────────────────────────────────────────────────

    // FLOWS
    get flowTotalDisplay()    { return this.nsFilterInput ? (this.activeFlowDisplayList.length + this.inactiveFlowDisplayList.length) : this.flowSummary.totalCount; }
    get flowActiveDisplay()   { return this.nsFilterInput ? this.activeFlowDisplayList.length    : this.flowSummary.activeCount;   }
    get flowInactiveDisplay() { return this.nsFilterInput ? this.inactiveFlowDisplayList.length  : this.flowSummary.inactiveCount; }

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

    // AURA
    get auraTotalDisplay()        { return this.nsFilterInput ? this.auraDisplayList.length : this.auraSummary.totalCount;            }
    get auraWithNsDisplay()       { return this.nsFilterInput ? this._filterWithNs(this.auraDisplayList).length : this.auraSummary.withNamespaceCount;    }
    get auraNoNsDisplay()         { return this.nsFilterInput ? this._filterNoNs(this.auraDisplayList).length   : this.auraSummary.withoutNamespaceCount; }
    get auraUnreferencedDisplay() { return this.nsFilterInput ? this.unreferencedAuraDisplayList.length : this.auraSummary.unreferencedCount; }

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

    // OBJECTS
    get objectTotalDisplay()  { return this.nsFilterInput ? this.objectDisplayList.length : this.objectSummary.totalCount;            }
    get objectWithNsDisplay() { return this.nsFilterInput ? this._filterWithNs(this.objectDisplayList).length : this.objectSummary.withNamespaceCount;    }
    get objectNoNsDisplay()   { return this.nsFilterInput ? this._filterNoNs(this.objectDisplayList).length   : this.objectSummary.withoutNamespaceCount; }
    get objectEmptyDisplay()  { return this.nsFilterInput ? this.emptyObjectDisplayList.length : this.objectSummary.emptyCount; }

    // VR
    get vrTotalDisplay()    { return this.nsFilterInput ? (this.activeVrDisplayList.length + this.inactiveVrDisplayList.length) : this.vrSummary.totalCount;    }
    get vrActiveDisplay()   { return this.nsFilterInput ? this.activeVrDisplayList.length   : this.vrSummary.activeCount;   }
    get vrInactiveDisplay() { return this.nsFilterInput ? this.inactiveVrDisplayList.length : this.vrSummary.inactiveCount; }
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