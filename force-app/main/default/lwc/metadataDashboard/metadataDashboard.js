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
import saveToOrgFiles           from '@salesforce/apex/ExportMetadataAction.saveToFiles';
import deleteFlow               from '@salesforce/apex/DeleteFlowAction.deleteFlowDirect';
import deleteTrigger            from '@salesforce/apex/DeleteTriggerAction.deleteTriggerDirect';
import deleteLwc                from '@salesforce/apex/DeleteLwcAction.deleteLwcFromLWC';
import deleteAura               from '@salesforce/apex/DeleteAuraAction.deleteAuraFromLWC';
import deleteCustomField        from '@salesforce/apex/DeleteCustomFieldAction.deleteFieldFromLWC';
import deleteCustomObject       from '@salesforce/apex/DeleteCustomObjectAction.deleteObjectFromLWC';
import deletePermSet            from '@salesforce/apex/DeletePermissionSetAction.deletePermSetFromLWC';
import deactivateProfile        from '@salesforce/apex/DeactivateProfileAction.deactivateProfileFromLWC';
import deleteValidationRule     from '@salesforce/apex/DeleteValidationRuleAction.deleteVRFromLWC';

let _msgIdCounter = 0;
function nextId() { return 'msg_' + (++_msgIdCounter); }

export default class MetadataDashboard extends LightningElement {

    // ── Dashboard state (unchanged) ─────────────────────────
    @track activeTab = 'flows';
    @track activeCardFilter = 'all'; // 'all' | 'total' | 'standard' | 'used' | 'unused' | 'test' | 'active' | 'inactive'
    // Section visibility getters — read directly from @track activeCardFilter.
    // 'all' and 'total' both show every section — Total is a summary card, not a filter.
    // Each specific filter (active/inactive/used/unused/etc.) shows only its own section.
    get showAllSections()       { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total'; }
    get showTotalSection()      { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total'; }
    get showStandardSection()   { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'standard'; }
    get showUsedSection()       { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'used';     }
    get showUnusedSection()     { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'unused';   }
    get showTestSection()       { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'test';     }
    get showActiveSection()     { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'active';   }
    get showInactiveSection()   { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'inactive'; }
    get showAssignedSection()   { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'used';     }
    get showUnassignedSection() { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'unused';   }
    get showWithNsSection()     { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'withNs';   }
    get showNoNsSection()       { return this.activeCardFilter === 'all' || this.activeCardFilter === 'total' || this.activeCardFilter === 'noNs';     }
    @track isLoading    = false;
    @track exportModalOpen   = false;
    @track exportFormat      = 'csv'; // 'csv' | 'json' | 'txt'
    @track _toastMessage     = '';
    @track _exportFormatKey  = 0; // force getter re-evaluation on format change
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

    // Last meaningful data response (fields list, flows list etc.) — used for export
    _lastDataResponse = null;

    // Pending delete confirmation: { type, name }
    _pendingDelete = null;

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

    get agentHeaderName()    { return 'Org Cleanup Agent'; }
    get agentHeaderStatus()  { return 'Online'; }
    get agentModeName()      { return 'Rule-Based (Custom)'; }

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

        // ── Rule-based backend ────────────────────────────────
        handleAgentQuery({ userQuery: query })
            .then(result => {
                this._removeMessage(typingId);
                const msg = result || 'No results returned.';
                this._addAgentMsg(msg);
                // Store as last data response for export (only real data, not short messages)
                if (msg.length > 100) this._lastDataResponse = msg;
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
            // Detect type from keywords
            let type = 'apex'; // default
            if      (lower.includes('custom field') || lower.includes('field '))   type = 'field';
            else if (lower.includes('custom object') || lower.includes('object ')) type = 'object';
            else if (lower.includes('validation rule') || lower.includes('val rule')) type = 'vr';
            else if (lower.includes('permission sets') || lower.includes('permission set') || lower.includes('permsets') || lower.includes('permset') || lower.includes('perm sets') || lower.includes('perm set')) type = 'permset';
            else if (lower.includes('profile'))                                    type = 'profile';
            else if (lower.includes('flow'))                                       type = 'flow';
            else if (lower.includes('trigger'))                                    type = 'trigger';
            else if (lower.includes('lwc') || lower.includes('lightning web'))     type = 'lwc';
            else if (lower.includes('aura'))                                       type = 'aura';
            else if (lower.includes('apex'))                                       type = 'apex';
            else {
                // No explicit type keyword — try to infer from name format
                // ObjectName.FieldName format → field
                const dotNameMatch = query.match(/delete\s+([A-Za-z0-9_]+\.[A-Za-z0-9_]+)/i);
                if (dotNameMatch) type = 'field';
            }

            // Extract name — skip type keyword, supports dotted names like Account.EM_Kishore
            // Order matters: longer phrases first
            const nameMatch = query.match(
                /delete\s+(?:custom\s+field|custom\s+object|validation\s+rule|val\s+rule|permission\s+sets|permission\s+set|perm\s+sets|perm\s+set|permsets|permset|apex\s+class|lightning\s+web\s+component|apex|flow|trigger|lwc|aura|field|object|profile|vr)?\s*([A-Za-z0-9_.]+)/i
            );
            const name = nameMatch ? nameMatch[1].trim() : null;
            return { action: 'delete', type, name };
        }

        // ── Multi-tab detection — collect ALL matching tabs ───────────
        const tabs = [];

        if (lower.includes('flow'))                                                         tabs.push('flows');
        if (lower.includes('apex') || lower.includes('class'))                              tabs.push('apex');
        if (lower.includes('trigger'))                                                      tabs.push('triggers');
        if (lower.includes('lwc') || lower.includes('lightning web') ||
            lower.includes('lightning component'))                                          tabs.push('lwc');
        if (lower.includes('aura'))                                                         tabs.push('aura');
        if (lower.includes('profile'))                                                      tabs.push('profiles');
        if (lower.includes('permission sets') || lower.includes('permission set') ||
            lower.includes('perm sets') || lower.includes('perm set') ||
            lower.includes('permsets') || lower.includes('permset') ||
            lower.includes('permission'))                                                   tabs.push('permsets');
        if (lower.includes('field'))                                                        tabs.push('fields');
        if (lower.includes('object') || lower.includes('sobject') ||
            lower.includes('custom object'))                                                tabs.push('objects');
        if (lower.includes('validation') || lower.includes('val rule') ||
            lower.includes('validation rule') || lower.includes('rules'))                   tabs.push('vr');

        if (tabs.length > 0) {
            return { action: 'query', tab: tabs[0], tabs };
        }

        return { action: 'query', tab: null, tabs: [] };
    }

    // ── Delete intent: show confirmation message ──────────────
    _handleDeleteIntent(intent) {
        if (!intent.name) {
            this._addAgentMsg('Please specify the name of the component to delete.\nExamples:\n• "delete apex class LeadScoringBatch"\n• "delete flow MyFlow"\n• "delete field Account.EM_Kishore"\n• "delete vr Account.MyRule"\n• "delete object MyObject__c"');
            return;
        }
        // For field/vr without dot, prompt for correct format before confirming
        if ((intent.type === 'field' || intent.type === 'vr') && !intent.name.includes('.')) {
            const ex = intent.type === 'field' ? 'Account.EM_Kishore' : 'Account.MyRule';
            this._addAgentMsg(`Please include the object name.\nFormat: "delete ${intent.type} ObjectName.ComponentName"\nExample: "delete ${intent.type} ${ex}"`);
            return;
        }
        const typeLabels = {
            apex: 'Apex Class', flow: 'Flow', trigger: 'Trigger', lwc: 'LWC Component',
            aura: 'Aura Component', field: 'Custom Field', object: 'Custom Object',
            permset: 'Permission Set', profile: 'Profile', vr: 'Validation Rule'
        };
        const typeLabel = typeLabels[intent.type] || intent.type;
        this._pendingDelete = { type: intent.type, name: intent.name };
        this._addAgentMsg(
            `Found: ${intent.name} (${typeLabel})\n` +
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
        } else if (type === 'lwc') {
            deletePromise = deleteLwc({ componentName: name });
        } else if (type === 'aura') {
            deletePromise = deleteAura({ componentName: name });
        } else if (type === 'field') {
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
        } else if (type === 'object') {
            deletePromise = deleteCustomObject({ objectName: name });
        } else if (type === 'permset') {
            deletePromise = deletePermSet({ permSetName: name });
        } else if (type === 'profile') {
            deletePromise = deactivateProfile({ profileName: name, fallbackProfileName: null });
        } else if (type === 'vr') {
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
        if (type === 'lwc')     { this._lwcLoaded      = false; if (this.activeTab === 'lwc')      this._loadLwc();      }
        if (type === 'aura')    { this._auraLoaded     = false; if (this.activeTab === 'aura')     this._loadAura();     }
        if (type === 'field')   { this._fieldsLoaded   = false; if (this.activeTab === 'fields')   this._loadFields();   }
        if (type === 'object')  { this._objectsLoaded  = false; if (this.activeTab === 'objects')  this._loadObjects();  }
        if (type === 'permset') { this._permSetsLoaded = false; if (this.activeTab === 'permsets') this._loadPermSets(); }
        if (type === 'profile') { this._profilesLoaded = false; if (this.activeTab === 'profiles') this._loadProfiles(); }
        if (type === 'vr')      { this._vrLoaded       = false; if (this.activeTab === 'vr')       this._loadVr();       }
    }

    // ── Navigate dashboard tab based on query intent ─────────
    _refreshTabForIntent(intent) {
        if (!intent.tabs || intent.tabs.length === 0) return;

        // Switch dashboard to the first matched tab
        this.activeTab = intent.tabs[0];
        this.activeCardFilter = 'all';

        // For each matched tab — only load data if not already loaded (Bug 1 fix)
        const loadIfNeeded = {
            flows   : () => { if (!this._flowsLoaded)    this._loadFlows();    },
            apex    : () => { if (!this._apexLoaded)     this._loadApex();     },
            triggers: () => { if (!this._triggersLoaded) this._loadTriggers(); },
            lwc     : () => { if (!this._lwcLoaded)      this._loadLwc();      },
            aura    : () => { if (!this._auraLoaded)     this._loadAura();     },
            profiles: () => { if (!this._profilesLoaded) this._loadProfiles(); },
            permsets: () => { if (!this._permSetsLoaded) this._loadPermSets(); },
            fields  : () => { if (!this._fieldsLoaded)   this._loadFields();   },
            objects : () => { if (!this._objectsLoaded)  this._loadObjects();  },
            vr      : () => { if (!this._vrLoaded)       this._loadVr();       },
        };

        intent.tabs.forEach(tab => {
            if (loadIfNeeded[tab]) loadIfNeeded[tab]();
        });
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
        if (filter === 'total') {
            this.activeCardFilter = 'all';
        } else {
            this.activeCardFilter = (this.activeCardFilter === filter) ? 'all' : filter;
        }
    }

    // CSS class helpers for active card highlighting
    get cardClassTotal()    { return 'stat-card stat-total'    + (this.activeCardFilter === 'total'    ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassStandard() { return 'stat-card'               + (this.activeCardFilter === 'standard' ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassUsed()     { return 'stat-card stat-active'   + (this.activeCardFilter === 'used'     ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassUnused()   { return 'stat-card stat-inactive' + (this.activeCardFilter === 'unused'   ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassTest()     { return 'stat-card'               + (this.activeCardFilter === 'test'     ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassActive()   { return 'stat-card stat-active'   + (this.activeCardFilter === 'active'   ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassInactive() { return 'stat-card stat-inactive' + (this.activeCardFilter === 'inactive' ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassFlowTotal(){ return 'stat-card stat-total'    + (this.activeCardFilter === 'total'    ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassWithNs()   { return 'stat-card'               + (this.activeCardFilter === 'withNs'   ? ' stat-card--active' : '') + ' stat-card--clickable'; }
    get cardClassNoNs()     { return 'stat-card'               + (this.activeCardFilter === 'noNs'     ? ' stat-card--active' : '') + ' stat-card--clickable'; }

    // Namespace-based filtered lists for LWC / Aura / Fields / Objects

    _filterByNs(list, hasNs) {
        return list.filter(item => {
            const hasNamespace = item.name && item.name.includes('__') && item.meta && item.meta.includes('NS:');
            return hasNs ? hasNamespace : !hasNamespace;
        });
    }
    _filterWithNs(list)  { return list.filter(i => i.meta && i.meta.toLowerCase().includes('ns:')); }
    _filterNoNs(list)    { return list.filter(i => !i.meta || !i.meta.toLowerCase().includes('ns:')); }

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
        if (this.activeCardFilter === 'withNs') return this.lwcWithNsList;
        if (this.activeCardFilter === 'noNs')   return this.lwcNoNsList;
        return this.allLwcList;
    }
    get auraDisplayList()   {
        if (this.activeCardFilter === 'withNs') return this.auraWithNsList;
        if (this.activeCardFilter === 'noNs')   return this.auraNoNsList;
        return this.allAuraList;
    }
    get fieldDisplayList()  {
        if (this.activeCardFilter === 'withNs') return this.fieldWithNsList;
        if (this.activeCardFilter === 'noNs')   return this.fieldNoNsList;
        return this.allFieldList;
    }
    get objectDisplayList() {
        if (this.activeCardFilter === 'withNs') return this.objectWithNsList;
        if (this.activeCardFilter === 'noNs')   return this.objectNoNsList;
        return this.allObjectList;
    }

    // Label for the filtered list header
    get nsFilterLabel() {
        if (this.activeCardFilter === 'withNs') return 'With Namespace';
        if (this.activeCardFilter === 'noNs')   return 'No Namespace';
        return 'All';
    }

    // Reset card filter when switching tabs
    showFlows()    { this.activeTab = 'flows';    this.activeCardFilter = 'all'; if (!this._flowsLoaded)    this._loadFlows();    }
    showApex()     { this.activeTab = 'apex';     this.activeCardFilter = 'all'; if (!this._apexLoaded)     this._loadApex();     }
    showTriggers() { this.activeTab = 'triggers'; this.activeCardFilter = 'all'; if (!this._triggersLoaded) this._loadTriggers(); }
    showLwc()      { this.activeTab = 'lwc';      this.activeCardFilter = 'all'; if (!this._lwcLoaded)      this._loadLwc();      }
    showAura()     { this.activeTab = 'aura';     this.activeCardFilter = 'all'; if (!this._auraLoaded)     this._loadAura();     }
    showProfiles() { this.activeTab = 'profiles'; this.activeCardFilter = 'all'; if (!this._profilesLoaded) this._loadProfiles(); }
    showPermSets() { this.activeTab = 'permsets'; this.activeCardFilter = 'all'; if (!this._permSetsLoaded) this._loadPermSets(); }
    showFields()   { this.activeTab = 'fields';   this.activeCardFilter = 'all'; if (!this._fieldsLoaded)   this._loadFields();   }
    showObjects()  { this.activeTab = 'objects';  this.activeCardFilter = 'all'; if (!this._objectsLoaded)  this._loadObjects();  }
    showVr()       { this.activeTab = 'vr';       this.activeCardFilter = 'all'; if (!this._vrLoaded)       this._loadVr();       }

    handleRefreshAll() {
        this._flowsLoaded = this._apexLoaded = this._triggersLoaded = false;
        this._lwcLoaded   = this._auraLoaded = this._profilesLoaded = false;
        this._permSetsLoaded = this._fieldsLoaded = this._objectsLoaded = this._vrLoaded = false;
        this.hasError     = false;
        this.errorMessage = '';
        this._dispatchCurrentTab();
    }

    handleNamespaceInput(event) { this.namespaceInput = event.target.value; }

    // ── Export Modal — HTML-aligned handlers & getters ────────

    // Getters that match HTML template bindings
    get showExportModal() { return this.exportModalOpen; }

    get exportTabLabel() {
        // If the last agent response was about unused apex classes, label it clearly
        if (this._lastDataResponse && /unused.*apex|apex.*unused/i.test(this._lastDataResponse)) {
            return 'Unused Apex Classes';
        }
        if (this._lastDataResponse) return 'Agent Response';
        const labels = { flows:'Flows', apex:'Apex Classes', triggers:'Triggers', lwc:'LWC',
                         aura:'Aura', profiles:'Profiles', permsets:'Perm Sets',
                         fields:'Fields', objects:'Objects', vr:'Validation Rules' };
        return labels[this.activeTab] || 'Metadata';
    }

    get exportCsvClass()  { return 'export-fmt-btn' + (this._exportFormatKey >= 0 && this.exportFormat === 'csv'  ? ' export-fmt-btn--active' : ''); }
    get exportJsonClass() { return 'export-fmt-btn' + (this._exportFormatKey >= 0 && this.exportFormat === 'json' ? ' export-fmt-btn--active' : ''); }
    get exportTxtClass()  { return 'export-fmt-btn' + (this._exportFormatKey >= 0 && this.exportFormat === 'txt'  ? ' export-fmt-btn--active' : ''); }

    get exportSaveDisabled()  { return false; }
    get exportSaveBtnLabel()  { return 'Save to Org Files'; }

    get showToast()    { return !!this._toastMessage; }
    get toastMessage() { return this._toastMessage || ''; }

    // Stop click propagation on modal body (prevents overlay close)
    _stopProp(event) { event.stopPropagation(); }

    // Open/close
    openExportModal()   { this.exportModalOpen = true; this.exportFormat = 'csv'; }
    handleCloseExport() { this.exportModalOpen = false; }

    // Format toggle — matches HTML data-format attribute
    handleExportFormatChange(event) {
        this.exportFormat = event.currentTarget.getAttribute('data-format') || 'csv';
        this._exportFormatKey = this._exportFormatKey + 1; // trigger re-render
    }

    // ── Download button in modal ──────────────────────────────
    handleDownload() {
        this.exportModalOpen = false;
        const date    = new Date().toISOString().slice(0, 10);
        const content = this._buildExportContent(this._lastDataResponse);
        if (!content) {
            this._showToast('No data to export. Open the Apex tab or ask the agent about unused apex classes first.');
            return;
        }
        const ext      = this.exportFormat;
        const tag      = this._getExportTag();
        const fileName = `org-${tag}-${date}.${ext}`;
        const mime     = ext === 'json' ? 'application/json' : ext === 'txt' ? 'text/plain' : 'text/csv';
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
        this.exportModalOpen = false;
        const date    = new Date().toISOString().slice(0, 10);
        const content = this._buildExportContent(this._lastDataResponse);
        if (!content) {
            this._showToast('No data to export. Open the Apex tab or ask the agent about unused apex classes first.');
            return;
        }
        const ext      = this.exportFormat;
        const tag      = this._getExportTag();
        const fileName = `org-${tag}-${date}.${ext}`;
        saveToOrgFiles({ fileName, fileContent: content, fileType: ext })
            .then(result => {
                if (result && result.success) {
                    this._showToast(`✅ "${fileName}" saved to Org Files!`);
                } else {
                    this._showToast('Error saving: ' + (result ? result.message : 'Unknown error'));
                }
            })
            .catch(err => this._showToast('Error saving: ' + (err.body?.message || err.message || err)));
    }

    // Returns a short tag for the filename based on context
    _getExportTag() {
        if (this._lastDataResponse) {
            const t = this._lastDataResponse;
            if (/unused.*apex|apex.*unused/i.test(t))           return 'unused-apex-classes';
            if (/apex\s*class|all.*apex/i.test(t))              return 'apex-classes';
            if (/flow/i.test(t))                                return 'flows';
            if (/trigger/i.test(t))                             return 'triggers';
            if (/\blwc\b|lightning\s*web\s*component/i.test(t)) return 'lwc-components';
            if (/\baura\b/i.test(t))                            return 'aura-components';
            if (/profile/i.test(t))                             return 'profiles';
            if (/permission\s*set|permset/i.test(t))            return 'permission-sets';
            if (/custom\s*field/i.test(t))                      return 'custom-fields';
            if (/custom\s*object/i.test(t))                     return 'custom-objects';
            if (/validation\s*rule/i.test(t))                   return 'validation-rules';
            return 'agent-response';
        }
        if (this.activeTab === 'apex' && this._apexLoaded) return 'unused-apex-classes';
        return 'dashboard-' + this.activeTab;
    }

    _buildExportContent(chatText) {
        const e = v => (v || '').toString().replace(/"/g, '""');

        // ── Detect which type the chat response is about ───────
        const chatType = (() => {
            if (!chatText) return null;
            if (/unused.*apex|apex.*unused/i.test(chatText))           return 'unusedApex';
            if (/apex\s*class|all.*apex|\bapex\b/i.test(chatText))     return 'apex';
            if (/\bflow/i.test(chatText))                              return 'flows';
            if (/\btrigger/i.test(chatText))                           return 'triggers';
            if (/\blwc\b|lightning\s*web\s*component/i.test(chatText)) return 'lwc';
            if (/\baura\b/i.test(chatText))                            return 'aura';
            if (/\bprofile/i.test(chatText))                           return 'profiles';
            if (/permission\s*set|\bpermset\b/i.test(chatText))        return 'permsets';
            if (/custom\s*field/i.test(chatText))                      return 'fields';
            if (/custom\s*object/i.test(chatText))                     return 'objects';
            if (/validation\s*rule/i.test(chatText))                   return 'vr';
            return 'generic';
        })();

        // ── CSV builder helpers ────────────────────────────────
        const toCsv = (headers, dataRows) => {
            const hRow = headers.map(h => `"${e(h)}"`).join(',');
            const lines = dataRows.map(r => headers.map(h => `"${e(r[h] || '')}"`).join(','));
            return lines.length ? [hRow, ...lines].join('\n') : null;
        };
        const toJson = obj => JSON.stringify(obj, null, 2);
        const toTxt  = (title, lines) => [title, '='.repeat(40), '', ...lines].join('\n');

        // ── Unused Apex (chat) ─────────────────────────────────
        if (chatType === 'unusedApex') {
            if (this.exportFormat === 'csv')  return this._unusedApexToCSV(chatText);
            if (this.exportFormat === 'json') return this._unusedApexToJSON(chatText);
            if (this.exportFormat === 'txt')  return this._unusedApexToTXT(chatText);
        }

        // ── All other types: use loaded summary data ───────────
        // For each type, if the summary data is loaded use it directly (most accurate).
        // If not loaded yet, fall back to parsing the chat text generically.

        // FLOWS
        if (chatType === 'flows' && this._flowsLoaded && this.flowSummary?.allFlowObjects?.length) {
            const data = this.flowSummary.allFlowObjects.map(f => ({
                'API Name': f.apiName, 'Label': f.label, 'Type': f.processType || 'Flow',
                'Status': f.isActive ? 'Active' : 'Inactive', 'Namespace': f.namespacePrefix || ''
            }));
            if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','Type','Status','Namespace'], data);
            if (this.exportFormat === 'json') return toJson(data);
            if (this.exportFormat === 'txt')  return toTxt('Flows', data.map((r,i) => `${i+1}. ${r['API Name']} | ${r['Status']} | ${r['Type']}`));
        }

        // APEX (all classes)
        if (chatType === 'apex' && this._apexLoaded && this.apexSummary) {
            const s = this.apexSummary;
            const data = [];
            (s.unusedApexObjects  || []).forEach(c => data.push({ 'API Name': c.name, 'Label': c.name, 'Status': 'Unused',            'Lines': c.linesOfCode || '', 'Last Modified': (c.lastModifiedDate || '').slice(0,10) }));
            (s.usedClassNames     || []).forEach(n => data.push({ 'API Name': n,      'Label': n,      'Status': 'Used',              'Lines': '', 'Last Modified': '' }));
            (s.testClasses        ? s.testClasses.split('\n').filter(Boolean)    : []).forEach(n => { const nm = n.replace(/^\d+\.\s*/,'').trim(); if (nm) data.push({ 'API Name': nm, 'Label': nm, 'Status': 'Test',             'Lines': '', 'Last Modified': '' }); });
            (s.standardClasses    ? s.standardClasses.split('\n').filter(Boolean): []).forEach(n => { const nm = n.replace(/^\d+\.\s*/,'').trim(); if (nm) data.push({ 'API Name': nm, 'Label': nm, 'Status': 'Standard/Package', 'Lines': '', 'Last Modified': '' }); });
            if (data.length) {
                if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','Status','Lines','Last Modified'], data);
                if (this.exportFormat === 'json') return toJson(data);
                if (this.exportFormat === 'txt')  return toTxt('Apex Classes', data.map((r,i) => `${i+1}. ${r['API Name']} | ${r['Status']}${r['Lines'] ? ' | Lines: '+r['Lines'] : ''}`));
            }
        }

        // TRIGGERS
        if (chatType === 'triggers' && this._triggersLoaded && this.triggerSummary) {
            const s = this.triggerSummary;
            const data = [];
            const addTriggers = (list, status) => (list || []).forEach(t => data.push({ 'API Name': t.name, 'Label': t.name, 'Object': t.objectName, 'Status': status, 'Lines': t.linesOfCode || '' }));
            addTriggers(s.unusedTriggerObjects,  'Unused');
            addTriggers(s.activeTriggerObjects,  'Active');
            addTriggers(s.inactiveTriggerObjects,'Inactive');
            if (data.length) {
                if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','Object','Status','Lines'], data);
                if (this.exportFormat === 'json') return toJson(data);
                if (this.exportFormat === 'txt')  return toTxt('Triggers', data.map((r,i) => `${i+1}. ${r['API Name']} | ${r['Object']} | ${r['Status']}`));
            }
        }

        // LWC
        if (chatType === 'lwc' && this._lwcLoaded && this.lwcSummary?.allLwcObjects?.length) {
            const data = this.lwcSummary.allLwcObjects.map(c => ({
                'API Name': c.name, 'Label': c.name, 'API Version': c.apiVersion || '', 'Namespace': c.namespacePrefix || ''
            }));
            if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','API Version','Namespace'], data);
            if (this.exportFormat === 'json') return toJson(data);
            if (this.exportFormat === 'txt')  return toTxt('LWC Components', data.map((r,i) => `${i+1}. ${r['API Name']}${r['Namespace'] ? ' | '+r['Namespace'] : ''}`));
        }

        // AURA
        if (chatType === 'aura' && this._auraLoaded && this.auraSummary?.allAuraObjects?.length) {
            const data = this.auraSummary.allAuraObjects.map(c => ({
                'API Name': c.name, 'Label': c.name, 'API Version': c.apiVersion || '', 'Namespace': c.namespacePrefix || ''
            }));
            if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','API Version','Namespace'], data);
            if (this.exportFormat === 'json') return toJson(data);
            if (this.exportFormat === 'txt')  return toTxt('Aura Components', data.map((r,i) => `${i+1}. ${r['API Name']}${r['Namespace'] ? ' | '+r['Namespace'] : ''}`));
        }

        // PROFILES
        if (chatType === 'profiles' && this._profilesLoaded && this.profileSummary) {
            const s = this.profileSummary;
            const data = [];
            (s.usedProfileObjects   || []).forEach(p => data.push({ 'API Name': p.name, 'Label': p.name, 'Status': 'Assigned',   'User Count': p.assignedUserCount || '', 'License': p.userLicenseName || '' }));
            (s.unusedProfileObjects || []).forEach(p => data.push({ 'API Name': p.name, 'Label': p.name, 'Status': 'Unassigned', 'User Count': 0,                         'License': p.userLicenseName || '' }));
            if (data.length) {
                if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','Status','User Count','License'], data);
                if (this.exportFormat === 'json') return toJson(data);
                if (this.exportFormat === 'txt')  return toTxt('Profiles', data.map((r,i) => `${i+1}. ${r['API Name']} | ${r['Status']} | Users: ${r['User Count']}`));
            }
        }

        // PERMISSION SETS
        if (chatType === 'permsets' && this._permSetsLoaded && this.permSetSummary) {
            const s = this.permSetSummary;
            const data = [];
            (s.usedPermSetObjects   || []).forEach(p => data.push({ 'API Name': p.name, 'Label': p.label || p.name, 'Status': 'Assigned',   'Assignments': p.assignmentCount || '', 'Namespace': p.namespacePrefix || '' }));
            (s.unusedPermSetObjects || []).forEach(p => data.push({ 'API Name': p.name, 'Label': p.label || p.name, 'Status': 'Unassigned', 'Assignments': 0,                       'Namespace': p.namespacePrefix || '' }));
            if (data.length) {
                if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','Status','Assignments','Namespace'], data);
                if (this.exportFormat === 'json') return toJson(data);
                if (this.exportFormat === 'txt')  return toTxt('Permission Sets', data.map((r,i) => `${i+1}. ${r['API Name']} | ${r['Status']} | Assignments: ${r['Assignments']}`));
            }
        }

        // CUSTOM FIELDS
        if (chatType === 'fields' && this._fieldsLoaded && this.fieldSummary?.allFieldObjects?.length) {
            const data = this.fieldSummary.allFieldObjects.map(f => ({
                'API Name': f.objectName + '.' + f.name + '__c', 'Label': f.name,
                'Object': f.objectName, 'Data Type': f.dataType || ''
            }));
            if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','Object','Data Type'], data);
            if (this.exportFormat === 'json') return toJson(data);
            if (this.exportFormat === 'txt')  return toTxt('Custom Fields', data.map((r,i) => `${i+1}. ${r['API Name']} | ${r['Data Type']}`));
        }

        // CUSTOM OBJECTS
        if (chatType === 'objects' && this._objectsLoaded && this.objectSummary?.allObjectObjects?.length) {
            const data = this.objectSummary.allObjectObjects.map(o => ({
                'API Name': o.name + '__c', 'Label': o.label || o.name, 'Namespace': o.namespacePrefix || ''
            }));
            if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','Namespace'], data);
            if (this.exportFormat === 'json') return toJson(data);
            if (this.exportFormat === 'txt')  return toTxt('Custom Objects', data.map((r,i) => `${i+1}. ${r['API Name']}${r['Namespace'] ? ' | '+r['Namespace'] : ''}`));
        }

        // VALIDATION RULES
        if (chatType === 'vr' && this._vrLoaded && this.vrSummary) {
            const s = this.vrSummary;
            const data = [];
            (s.activeRuleObjects   || []).forEach(v => data.push({ 'API Name': v.objectName+'.'+v.name, 'Label': v.name, 'Object': v.objectName, 'Status': 'Active',   'Namespace': v.namespacePrefix || '' }));
            (s.inactiveRuleObjects || []).forEach(v => data.push({ 'API Name': v.objectName+'.'+v.name, 'Label': v.name, 'Object': v.objectName, 'Status': 'Inactive', 'Namespace': v.namespacePrefix || '' }));
            if (data.length) {
                if (this.exportFormat === 'csv')  return toCsv(['API Name','Label','Object','Status','Namespace'], data);
                if (this.exportFormat === 'json') return toJson(data);
                if (this.exportFormat === 'txt')  return toTxt('Validation Rules', data.map((r,i) => `${i+1}. ${r['API Name']} | ${r['Object']} | ${r['Status']}`));
            }
        }

        // ── Fallback: generic chat text parser ─────────────────
        if (this.exportFormat === 'json') {
            if (chatText) {
                const parsed = this._parseChatTextToObjects(chatText);
                return toJson(parsed.length ? parsed : { raw: chatText });
            }
            const rows = this._buildExportRows();
            return rows.length ? toJson(rows) : null;
        }
        if (this.exportFormat === 'txt') {
            if (chatText) return chatText;
            const rows = this._buildExportRows();
            if (!rows.length) return null;
            const headers = ['API Name', 'Label', 'Type', 'Status', 'Detail 1', 'Detail 2'];
            return [headers.join('\t'), ...rows.map(r => headers.map(h => r[h] || '').join('\t'))].join('\n');
        }
        // CSV last resort
        if (chatText) {
            const csv = this._chatTextToCSV(chatText);
            if (csv) return csv;
        }
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
        const lines = ['Unused Apex Classes', '='.repeat(40), ''];
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

        const flushRow = () => {
            if (pendingApi || pendingLabel) {
                rows.push({ name: pendingApi || pendingLabel, lines: '', modified: '' });
            }
            pendingLabel = ''; pendingApi = '';
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

            // Block style: "Type     : Apex Class" — flush the row
            const typeMatch = trimmed.match(/^Type\s*:\s*(.+)/i);
            if (typeMatch) { flushRow(); continue; }

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
                if (name) rows.push({ name, lines: linesVal, modified: modVal });
            }
        }
        flushRow(); // flush any trailing block row
        return rows;
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
        const headers = ['API Name', 'Label', 'Type', 'Status', 'Detail 1', 'Detail 2'];
        return [headers.join(','), ...rows.map(r =>
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
        const e = (v) => (v || '').toString().replace(/"/g, '""');
        const row = (apiName, label, type, status, extra1Key, extra1Val, extra2Key, extra2Val) =>
            rows.push({
                'API Name' : apiName  || '',
                'Label'    : label    || apiName || '',
                'Type'     : type     || '',
                'Status'   : status   || '',
                [extra1Key || 'Detail 1'] : extra1Val || '',
                [extra2Key || 'Detail 2'] : extra2Val || '',
            });

        // ── FLOWS ─────────────────────────────────────────────
        if (this._flowsLoaded && this.flowSummary && this.flowSummary.allFlowObjects) {
            for (const f of this.flowSummary.allFlowObjects) {
                row(f.apiName, f.label, f.processType || 'Flow',
                    f.isActive ? 'Active' : 'Inactive',
                    'Namespace', f.namespacePrefix || '');
            }
        }

        // ── APEX CLASSES ───────────────────────────────────────
        if (this._apexLoaded && this.apexSummary) {
            const s = this.apexSummary;
            if (s.unusedApexObjects) {
                for (const c of s.unusedApexObjects) {
                    row(c.name, c.name, 'Apex Class', 'Unused',
                        'Lines', c.linesOfCode, 'Last Modified', (c.lastModifiedDate || '').slice(0, 10));
                }
            }
            if (s.usedClassNames) {
                for (const n of s.usedClassNames) {
                    row(n, n, 'Apex Class', 'Used', '', '', '', '');
                }
            }
            if (s.testClasses) {
                for (const n of (s.testClasses || '').split('\n').filter(Boolean)) {
                    const name = n.replace(/^\d+\.\s*/, '').trim();
                    if (name) row(name, name, 'Apex Class', 'Test', '', '', '', '');
                }
            }
            if (s.standardClasses) {
                for (const n of (s.standardClasses || '').split('\n').filter(Boolean)) {
                    const name = n.replace(/^\d+\.\s*/, '').trim();
                    if (name) row(name, name, 'Apex Class', 'Standard/Package', '', '', '', '');
                }
            }
        }

        // ── TRIGGERS ──────────────────────────────────────────
        if (this._triggersLoaded && this.triggerSummary) {
            const s = this.triggerSummary;
            const processTriggers = (list, status) => {
                if (!list) return;
                for (const t of list) {
                    row(t.name, t.name, 'Trigger', status,
                        'Object', t.objectName,
                        'Lines', t.linesOfCode);
                }
            };
            processTriggers(s.unusedTriggerObjects, 'Unused');
            processTriggers(s.activeTriggerObjects, 'Active');
            processTriggers(s.inactiveTriggerObjects, 'Inactive');
        }

        // ── LWC ───────────────────────────────────────────────
        if (this._lwcLoaded && this.lwcSummary && this.lwcSummary.allLwcObjects) {
            for (const c of this.lwcSummary.allLwcObjects) {
                row(c.name, c.name, 'LWC', 'Active',
                    'API Version', c.apiVersion,
                    'Namespace', c.namespacePrefix || '');
            }
        }

        // ── AURA ──────────────────────────────────────────────
        if (this._auraLoaded && this.auraSummary && this.auraSummary.allAuraObjects) {
            for (const c of this.auraSummary.allAuraObjects) {
                row(c.name, c.name, 'Aura Component', 'Active',
                    'API Version', c.apiVersion,
                    'Namespace', c.namespacePrefix || '');
            }
        }

        // ── PROFILES ──────────────────────────────────────────
        if (this._profilesLoaded && this.profileSummary) {
            const s = this.profileSummary;
            if (s.usedProfileObjects) {
                for (const p of s.usedProfileObjects) {
                    row(p.name, p.name, 'Profile', 'Assigned',
                        'User Count', p.assignedUserCount,
                        'License', p.userLicenseName || '');
                }
            }
            if (s.unusedProfileObjects) {
                for (const p of s.unusedProfileObjects) {
                    row(p.name, p.name, 'Profile', 'Unassigned',
                        'User Count', 0,
                        'License', p.userLicenseName || '');
                }
            }
        }

        // ── PERMISSION SETS ───────────────────────────────────
        if (this._permSetsLoaded && this.permSetSummary) {
            const s = this.permSetSummary;
            if (s.usedPermSetObjects) {
                for (const p of s.usedPermSetObjects) {
                    row(p.name, p.label || p.name, 'Permission Set', 'Assigned',
                        'Assignments', p.assignmentCount,
                        'Namespace', p.namespacePrefix || '');
                }
            }
            if (s.unusedPermSetObjects) {
                for (const p of s.unusedPermSetObjects) {
                    row(p.name, p.label || p.name, 'Permission Set', 'Unassigned',
                        'Assignments', 0,
                        'Namespace', p.namespacePrefix || '');
                }
            }
        }

        // ── CUSTOM FIELDS ─────────────────────────────────────
        if (this._fieldsLoaded && this.fieldSummary && this.fieldSummary.allFieldObjects) {
            for (const f of this.fieldSummary.allFieldObjects) {
                row(f.objectName + '.' + f.name + '__c',
                    f.name,
                    'Custom Field',
                    '',
                    'Object', f.objectName,
                    'Data Type', f.dataType || '');
            }
        }

        // ── CUSTOM OBJECTS ────────────────────────────────────
        if (this._objectsLoaded && this.objectSummary && this.objectSummary.allObjectObjects) {
            for (const o of this.objectSummary.allObjectObjects) {
                row(o.name + '__c', o.label || o.name, 'Custom Object', '',
                    'Namespace', o.namespacePrefix || '', '', '');
            }
        }

        // ── VALIDATION RULES ──────────────────────────────────
        if (this._vrLoaded && this.vrSummary) {
            const s = this.vrSummary;
            const processRules = (list, status) => {
                if (!list) return;
                for (const v of list) {
                    row(v.objectName + '.' + v.name,
                        v.name,
                        'Validation Rule',
                        status,
                        'Object', v.objectName,
                        'Namespace', v.namespacePrefix || '');
                }
            };
            processRules(s.activeRuleObjects,   'Active');
            processRules(s.inactiveRuleObjects, 'Inactive');
        }

        return rows;
    }

    _showToast(message) {
        this._toastMessage = message;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._toastMessage = ''; }, 3500);
    }

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