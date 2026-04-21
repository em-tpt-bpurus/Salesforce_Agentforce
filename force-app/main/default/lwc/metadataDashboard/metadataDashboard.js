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
import deleteApexClass          from '@salesforce/apex/DeleteApexClassAction.deleteApexClassDirect';
import deleteFlow               from '@salesforce/apex/DeleteFlowAction.deleteFlowDirect';
import deleteTrigger            from '@salesforce/apex/DeleteTriggerAction.deleteTriggerDirect';

let _msgIdCounter = 0;
function nextId() { return 'msg_' + (++_msgIdCounter); }

export default class MetadataDashboard extends LightningElement {

    // ── Dashboard state (unchanged) ─────────────────────────
    @track activeTab = 'flows';
    @track isLoading    = false;
    @track hasError     = false;
    @track errorMessage = '';
    @track namespaceInput = '';

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
                               allComponents: '', filteredComponents: '' };
    @track auraSummary    = { totalCount: '—', withNamespaceCount: '—', withoutNamespaceCount: '—',
                               filteredCount: '—', namespaceFilterApplied: '—',
                               allComponents: '', filteredComponents: '' };
    @track profileSummary   = { totalCount: '—', usedCount: '—', unusedCount: '—',
                                 usedProfiles: '', unusedProfiles: '' };
    @track permSetSummary   = { totalCount: '—', usedCount: '—', unusedCount: '—',
                                 usedPermSets: '', unusedPermSets: '' };
    @track fieldSummary     = { totalCount: '—', withNamespaceCount: '—', withoutNamespaceCount: '—',
                                 filteredCount: '—', namespaceFilterApplied: '—',
                                 allFields: '', filteredFields: '' };
    @track objectSummary    = { totalCount: '—', withNamespaceCount: '—', withoutNamespaceCount: '—',
                                 filteredCount: '—', namespaceFilterApplied: '—',
                                 allObjects: '', filteredObjects: '' };
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

    // Pending delete confirmation: { type, name }
    _pendingDelete = null;

    connectedCallback() {
        this._loadFlows();
        this._agentWelcome();
    }

    // ────────────────────────────────────────────────────────
    // AGENT WELCOME
    // ────────────────────────────────────────────────────────
    _agentWelcome() {
        this._addAgentMsg(
            'Hi! I can help you audit and clean your Salesforce org. ' +
            'Ask me about flows, Apex classes, triggers, profiles, and more — ' +
            'or ask me to delete specific unused components.',
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
        this.agentMessages = [...this.agentMessages, {
            id      : nextId(),
            text,
            isAgent : true,
            isTyping: false,
            isSuccess,
            isError,
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
        }, 50);
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
        const query = event.currentTarget.dataset.query;
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
        const type = event.currentTarget.dataset.type;
        const name = event.currentTarget.dataset.name;
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

        // ── Check if this is a delete confirmation ───────────
        if (this._pendingDelete) {
            const lower = query.toLowerCase();
            if (lower === 'yes' || lower === 'confirm' || lower === 'delete' || lower === 'yes, delete it') {
                const { type, name } = this._pendingDelete;
                this._pendingDelete = null;
                this._removeMessage(typingId);
                this._executeDelete(type, name);
                return;
            } else if (lower === 'no' || lower === 'cancel') {
                this._pendingDelete = null;
                this._removeMessage(typingId);
                this.agentIsProcessing = false;
                this._addAgentMsg('Deletion cancelled. Let me know if you need anything else.');
                return;
            }
            // Not a confirmation — clear pending and process as new query
            this._pendingDelete = null;
        }

        // ── Parse intent ─────────────────────────────────────
        const intent = this._parseIntent(query);

        if (intent.action === 'delete') {
            this._removeMessage(typingId);
            this.agentIsProcessing = false;
            this._handleDeleteIntent(intent);
            return;
        }

        // ── Query intent — call backend ───────────────────────
        handleAgentQuery({ userQuery: query })
            .then(result => {
                this._removeMessage(typingId);
                this._addAgentMsg(result || 'No results returned.');
                // Refresh the relevant dashboard tab
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
        const deleteMatch = lower.match(/delete\s+(apex\s+class|apex|flow|trigger|lwc|aura|field|object|profile|permission\s+set|validation\s+rule)?\s*(.+)?/i);
        if (deleteMatch) {
            let type = 'apex';
            const raw = lower;
            if (raw.includes('flow'))                          type = 'flow';
            else if (raw.includes('trigger'))                  type = 'trigger';
            else if (raw.includes('lwc') || raw.includes('lightning web')) type = 'lwc';
            else if (raw.includes('aura'))                     type = 'aura';
            else if (raw.includes('apex'))                     type = 'apex';

            // Extract the name — everything after the type keyword
            const nameMatch = query.match(/delete\s+(?:apex\s+class|apex|flow|trigger|lwc|aura)?\s*([A-Za-z0-9_]+)/i);
            const name = nameMatch ? nameMatch[1].trim() : null;
            return { action: 'delete', type, name };
        }

        // Query patterns
        if (lower.includes('inactive flow') || lower.includes('unused flow'))  return { action: 'query', tab: 'flows' };
        if (lower.includes('active flow'))                                       return { action: 'query', tab: 'flows' };
        if (lower.includes('flow'))                                              return { action: 'query', tab: 'flows' };
        if (lower.includes('unused apex') || lower.includes('apex class'))      return { action: 'query', tab: 'apex' };
        if (lower.includes('apex'))                                              return { action: 'query', tab: 'apex' };
        if (lower.includes('trigger'))                                           return { action: 'query', tab: 'triggers' };
        if (lower.includes('lwc') || lower.includes('lightning web'))           return { action: 'query', tab: 'lwc' };
        if (lower.includes('aura'))                                              return { action: 'query', tab: 'aura' };
        if (lower.includes('profile'))                                           return { action: 'query', tab: 'profiles' };
        if (lower.includes('permission set') || lower.includes('perm set'))     return { action: 'query', tab: 'permsets' };
        if (lower.includes('field'))                                             return { action: 'query', tab: 'fields' };
        if (lower.includes('object'))                                            return { action: 'query', tab: 'objects' };
        if (lower.includes('validation'))                                        return { action: 'query', tab: 'vr' };

        return { action: 'query', tab: null };
    }

    // ── Delete intent: show confirmation message ──────────────
    _handleDeleteIntent(intent) {
        if (!intent.name) {
            this._addAgentMsg('Please specify the name of the component to delete. Example: "Delete apex class LeadScoringBatch"');
            return;
        }
        this._pendingDelete = { type: intent.type, name: intent.name };
        this._addAgentMsg(
            `Found: ${intent.name} (${intent.type})\n` +
            `Are you sure you want to delete this component? This cannot be undone.\n\n` +
            `Reply "yes" to confirm or "no" to cancel.`
        );
    }

    // ── Execute the actual delete ─────────────────────────────
    _executeDelete(type, name) {
        const typingId = this._addTypingIndicator();
        this.agentIsProcessing = true;

        let deletePromise;
        if (type === 'apex') {
            deletePromise = deleteApexClass({ apexClassName: name });
        } else if (type === 'flow') {
            deletePromise = deleteFlow({ flowApiName: name });
        } else if (type === 'trigger') {
            deletePromise = deleteTrigger({ triggerName: name });
        } else {
            this._removeMessage(typingId);
            this.agentIsProcessing = false;
            this._addAgentMsg(`Deletion of ${type} components is not yet supported from the dashboard. Please use the Agentforce chat.`, false, true);
            return;
        }

        deletePromise
            .then(result => {
                this._removeMessage(typingId);
                if (result && result.success) {
                    this._addAgentMsg(`${name} has been successfully deleted.`, true, false);
                    // Refresh relevant tab
                    this._refreshAfterDelete(type);
                } else {
                    const msg = result ? result.message : 'Unknown error.';
                    this._addAgentMsg(`Could not delete ${name}: ${msg}`, false, true);
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
        if (type === 'apex')    { this._apexLoaded     = false; if (this.activeTab === 'apex')     this._loadApex();     }
        if (type === 'flow')    { this._flowsLoaded    = false; if (this.activeTab === 'flows')    this._loadFlows();    }
        if (type === 'trigger') { this._triggersLoaded = false; if (this.activeTab === 'triggers') this._loadTriggers(); }
    }

    // ── Navigate dashboard tab based on query intent ─────────
    _refreshTabForIntent(intent) {
        if (!intent.tab) return;
        const tabLoaderMap = {
            flows   : () => { this.activeTab = 'flows';    this._flowsLoaded    = false; this._loadFlows();    },
            apex    : () => { this.activeTab = 'apex';     this._apexLoaded     = false; this._loadApex();     },
            triggers: () => { this.activeTab = 'triggers'; this._triggersLoaded = false; this._loadTriggers(); },
            lwc     : () => { this.activeTab = 'lwc';      this._lwcLoaded      = false; this._loadLwc();      },
            aura    : () => { this.activeTab = 'aura';     this._auraLoaded     = false; this._loadAura();     },
            profiles: () => { this.activeTab = 'profiles'; this._profilesLoaded = false; this._loadProfiles(); },
            permsets: () => { this.activeTab = 'permsets'; this._permSetsLoaded = false; this._loadPermSets(); },
            fields  : () => { this.activeTab = 'fields';   this._fieldsLoaded   = false; this._loadFields();   },
            objects : () => { this.activeTab = 'objects';  this._objectsLoaded  = false; this._loadObjects();  },
            vr      : () => { this.activeTab = 'vr';       this._vrLoaded       = false; this._loadVr();       },
        };
        if (tabLoaderMap[intent.tab]) tabLoaderMap[intent.tab]();
    }

    // ────────────────────────────────────────────────────────
    // DASHBOARD TAB HELPERS (unchanged)
    // ────────────────────────────────────────────────────────
    get showFlowsTab()     { return this.activeTab === 'flows';     }
    get showApexTab()      { return this.activeTab === 'apex';      }
    get showTriggersTab()  { return this.activeTab === 'triggers';  }
    get showLwcTab()       { return this.activeTab === 'lwc';       }
    get showAuraTab()      { return this.activeTab === 'aura';      }
    get showProfilesTab()  { return this.activeTab === 'profiles';  }
    get showPermSetsTab()  { return this.activeTab === 'permsets';  }
    get showFieldsTab()    { return this.activeTab === 'fields';    }
    get showObjectsTab()   { return this.activeTab === 'objects';   }
    get showVrTab()        { return this.activeTab === 'vr';        }

    get showNamespaceFilter() {
        return ['flows','apex','triggers','lwc','aura','fields','objects','vr'].includes(this.activeTab);
    }

    get flowTabClass()    { return this._tabClass('flows');    }
    get apexTabClass()    { return this._tabClass('apex');     }
    get triggerTabClass() { return this._tabClass('triggers'); }
    get lwcTabClass()     { return this._tabClass('lwc');      }
    get auraTabClass()    { return this._tabClass('aura');     }
    get profileTabClass() { return this._tabClass('profiles'); }
    get permSetTabClass() { return this._tabClass('permsets'); }
    get fieldTabClass()   { return this._tabClass('fields');   }
    get objectTabClass()  { return this._tabClass('objects');  }
    get vrTabClass()      { return this._tabClass('vr');       }

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

    showFlows()    { this.activeTab = 'flows';    if (!this._flowsLoaded)    this._loadFlows();    }
    showApex()     { this.activeTab = 'apex';     if (!this._apexLoaded)     this._loadApex();     }
    showTriggers() { this.activeTab = 'triggers'; if (!this._triggersLoaded) this._loadTriggers(); }
    showLwc()      { this.activeTab = 'lwc';      if (!this._lwcLoaded)      this._loadLwc();      }
    showAura()     { this.activeTab = 'aura';     if (!this._auraLoaded)     this._loadAura();     }
    showProfiles() { this.activeTab = 'profiles'; if (!this._profilesLoaded) this._loadProfiles(); }
    showPermSets() { this.activeTab = 'permsets'; if (!this._permSetsLoaded) this._loadPermSets(); }
    showFields()   { this.activeTab = 'fields';   if (!this._fieldsLoaded)   this._loadFields();   }
    showObjects()  { this.activeTab = 'objects';  if (!this._objectsLoaded)  this._loadObjects();  }
    showVr()       { this.activeTab = 'vr';       if (!this._vrLoaded)       this._loadVr();       }

    handleRefreshAll() {
        this._flowsLoaded = this._apexLoaded = this._triggersLoaded = false;
        this._lwcLoaded   = this._auraLoaded = this._profilesLoaded = false;
        this._permSetsLoaded = this._fieldsLoaded = this._objectsLoaded = this._vrLoaded = false;
        this.hasError     = false;
        this.errorMessage = '';
        this._dispatchCurrentTab();
    }

    handleNamespaceInput(event) { this.namespaceInput = event.target.value; }

    handleNamespaceApply() {
        if (this.activeTab === 'flows')    { this._flowsLoaded    = false; this._loadFlows();    }
        if (this.activeTab === 'apex')     { this._apexLoaded     = false; this._loadApex();     }
        if (this.activeTab === 'triggers') { this._triggersLoaded = false; this._loadTriggers(); }
        if (this.activeTab === 'lwc')      { this._lwcLoaded      = false; this._loadLwc();      }
        if (this.activeTab === 'aura')     { this._auraLoaded     = false; this._loadAura();     }
        if (this.activeTab === 'fields')   { this._fieldsLoaded   = false; this._loadFields();   }
        if (this.activeTab === 'objects')  { this._objectsLoaded  = false; this._loadObjects();  }
        if (this.activeTab === 'vr')       { this._vrLoaded       = false; this._loadVr();       }
    }

    _dispatchCurrentTab() {
        const map = {
            flows:    () => this._loadFlows(),    apex:    () => this._loadApex(),
            triggers: () => this._loadTriggers(), lwc:     () => this._loadLwc(),
            aura:     () => this._loadAura(),     profiles: () => this._loadProfiles(),
            permsets: () => this._loadPermSets(), fields:  () => this._loadFields(),
            objects:  () => this._loadObjects(),  vr:      () => this._loadVr()
        };
        if (map[this.activeTab]) map[this.activeTab]();
    }

    // ────────────────────────────────────────────────────────
    // DATA LOADERS (unchanged)
    // ────────────────────────────────────────────────────────
    _loadFlows() {
        this.isLoading = true; this.hasError = false;
        getFlowSummary({ namespaceFilter: this.namespaceInput || null })
            .then(r => { if (r) { this.flowSummary = { ...this.flowSummary, ...r }; this._flowsLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadApex() {
        this.isLoading = true; this.hasError = false;
        getApexSummary({ namespaceFilter: this.namespaceInput || null })
            .then(r => { if (r) { this.apexSummary = { ...this.apexSummary, ...r }; this._apexLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadTriggers() {
        this.isLoading = true; this.hasError = false;
        getTriggerSummary({ namespaceFilter: this.namespaceInput || null })
            .then(r => { if (r) { this.triggerSummary = { ...this.triggerSummary, ...r }; this._triggersLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadLwc() {
        this.isLoading = true; this.hasError = false;
        getLwcSummary({ namespaceFilter: this.namespaceInput || null })
            .then(r => { if (r) { this.lwcSummary = { ...this.lwcSummary, ...r }; this._lwcLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadAura() {
        this.isLoading = true; this.hasError = false;
        getAuraSummary({ namespaceFilter: this.namespaceInput || null })
            .then(r => { if (r) { this.auraSummary = { ...this.auraSummary, ...r }; this._auraLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadProfiles() {
        this.isLoading = true; this.hasError = false;
        getProfileSummary()
            .then(r => { if (r) { this.profileSummary = { ...this.profileSummary, ...r }; this._profilesLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadPermSets() {
        this.isLoading = true; this.hasError = false;
        getPermissionSetSummary()
            .then(r => { if (r) { this.permSetSummary = { ...this.permSetSummary, ...r }; this._permSetsLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadFields() {
        this.isLoading = true; this.hasError = false;
        getCustomFieldSummary({ namespaceFilter: this.namespaceInput || null })
            .then(r => { if (r) { this.fieldSummary = { ...this.fieldSummary, ...r }; this._fieldsLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadObjects() {
        this.isLoading = true; this.hasError = false;
        getCustomObjectSummary({ namespaceFilter: this.namespaceInput || null })
            .then(r => { if (r) { this.objectSummary = { ...this.objectSummary, ...r }; this._objectsLoaded = true; } })
            .catch(e => { this.hasError = true; this.errorMessage = this._errorMsg(e); })
            .finally(() => { this.isLoading = false; });
    }
    _loadVr() {
        this.isLoading = true; this.hasError = false;
        getValidationRuleSummary({ namespaceFilter: this.namespaceInput || null })
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
    get allLwcList()              { return this._parseDetailedList(this.lwcSummary.allComponents);        }
    get filteredLwcList()         { return this._parseDetailedList(this.lwcSummary.filteredComponents);   }
    get allAuraList()             { return this._parseDetailedList(this.auraSummary.allComponents);       }
    get filteredAuraList()        { return this._parseDetailedList(this.auraSummary.filteredComponents);  }
    get usedProfileList()         { return this._parseDetailedList(this.profileSummary.usedProfiles);     }
    get unusedProfileList()       { return this._parseDetailedList(this.profileSummary.unusedProfiles);   }
    get usedPermSetList()         { return this._parseDetailedList(this.permSetSummary.usedPermSets);     }
    get unusedPermSetList()       { return this._parseDetailedList(this.permSetSummary.unusedPermSets);   }
    get allFieldList()            { return this._parseDetailedList(this.fieldSummary.allFields);          }
    get filteredFieldList()       { return this._parseDetailedList(this.fieldSummary.filteredFields);     }
    get allObjectList()           { return this._parseDetailedList(this.objectSummary.allObjects);        }
    get filteredObjectList()      { return this._parseDetailedList(this.objectSummary.filteredObjects);   }
    get activeVrList()            { return this._parseDetailedList(this.vrSummary.activeRules);           }
    get inactiveVrList()          { return this._parseDetailedList(this.vrSummary.inactiveRules);         }
    get filteredVrList()          { return this._parseDetailedList(this.vrSummary.filteredRules);         }

    get flowHasFilter()    { return this._hasFilter(this.flowSummary.namespaceFilterApplied);    }
    get apexHasFilter()    { return this._hasFilter(this.apexSummary.namespaceFilterApplied);    }
    get triggerHasFilter() { return this._hasFilter(this.triggerSummary.namespaceFilterApplied); }
    get lwcHasFilter()     { return this._hasFilter(this.lwcSummary.namespaceFilterApplied);     }
    get auraHasFilter()    { return this._hasFilter(this.auraSummary.namespaceFilterApplied);    }
    get fieldHasFilter()   { return this._hasFilter(this.fieldSummary.namespaceFilterApplied);   }
    get objectHasFilter()  { return this._hasFilter(this.objectSummary.namespaceFilterApplied);  }
    get vrHasFilter()      { return this._hasFilter(this.vrSummary.namespaceFilterApplied);      }

    _hasFilter(v) { return v && v !== 'None (showing all)' && v !== '—'; }

    get filteredActiveFlowList()   { return this._parseSimpleList(this.flowSummary.filteredActiveFlows);   }
    get filteredInactiveFlowList() { return this._parseSimpleList(this.flowSummary.filteredInactiveFlows); }
    get filteredApexList()         { return this._parseDetailedList(this.apexSummary.filteredClasses);     }
    get filteredTriggerList()      { return this._parseDetailedList(this.triggerSummary.filteredTriggers); }
}
