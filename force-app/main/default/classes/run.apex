// ================================================================
// run.apex — Comprehensive test script for Org Metadata Dashboard
// Execute in: Setup → Developer Console → Execute Anonymous
// ================================================================

// ── 1. FLOWS (with namespace filter) ─────────────────────────────
List<MetadataAgentAction.FlowRequest> flowReqs = new List<MetadataAgentAction.FlowRequest>();
MetadataAgentAction.FlowRequest flowReq = new MetadataAgentAction.FlowRequest();
flowReq.input = 'list flows';
flowReq.namespaceFilter = ''; // leave blank for all, or set e.g. 'ITSms'
flowReqs.add(flowReq);
List<MetadataAgentAction.FlowOutput> flowOut = MetadataAgentAction.run(flowReqs);
System.debug('✅ FLOWS — Total: ' + flowOut[0].totalCount + ' | Active: ' + flowOut[0].activeCount + ' | Inactive: ' + flowOut[0].inactiveCount);
System.debug('INACTIVE (UNUSED):\n' + flowOut[0].inactiveFlows);

// ── 2. APEX CLASSES (with namespace filter) ───────────────────────
List<ApexClassAgentAction.ApexRequest> apexReqs = new List<ApexClassAgentAction.ApexRequest>();
ApexClassAgentAction.ApexRequest apexReq = new ApexClassAgentAction.ApexRequest();
apexReq.input = 'list classes';
apexReq.namespaceFilter = ''; // e.g. 'ITSms'
apexReqs.add(apexReq);
List<ApexClassAgentAction.ApexOutput> apexOut = ApexClassAgentAction.run(apexReqs);
System.debug('✅ APEX — Total: ' + apexOut[0].totalCount + ' | Unused: ' + apexOut[0].unusedCount);
System.debug('UNUSED CLASSES:\n' + apexOut[0].unusedClasses);

// ── 3. TRIGGERS (with namespace filter) ──────────────────────────
List<TriggerAgentAction.TriggerRequest> trigReqs = new List<TriggerAgentAction.TriggerRequest>();
TriggerAgentAction.TriggerRequest trigReq = new TriggerAgentAction.TriggerRequest();
trigReq.input = 'list triggers';
trigReq.namespaceFilter = '';
trigReqs.add(trigReq);
List<TriggerAgentAction.TriggerOutput> trigOut = TriggerAgentAction.run(trigReqs);
System.debug('✅ TRIGGERS — Total: ' + trigOut[0].totalCount + ' | Unused: ' + trigOut[0].unusedCount);

// ── 4. LWC COMPONENTS (namespace filter = FinanceApp) ────────────
List<LwcAgentAction.LwcRequest> lwcReqs = new List<LwcAgentAction.LwcRequest>();
LwcAgentAction.LwcRequest lwcReq = new LwcAgentAction.LwcRequest();
lwcReq.namespaceFilter = 'FinanceApp'; // change or leave blank
lwcReqs.add(lwcReq);
List<LwcAgentAction.LwcOutput> lwcOut = LwcAgentAction.run(lwcReqs);
System.debug('✅ LWC — Total: ' + lwcOut[0].totalCount + ' | Filtered: ' + lwcOut[0].filteredCount);
System.debug('FILTERED LWC:\n' + lwcOut[0].filteredComponents);

// ── 5. AURA COMPONENTS ────────────────────────────────────────────
List<AuraAgentAction.AuraRequest> auraReqs = new List<AuraAgentAction.AuraRequest>();
AuraAgentAction.AuraRequest auraReq = new AuraAgentAction.AuraRequest();
auraReq.namespaceFilter = '';
auraReqs.add(auraReq);
List<AuraAgentAction.AuraOutput> auraOut = AuraAgentAction.run(auraReqs);
System.debug('✅ AURA — Total: ' + auraOut[0].totalCount);

// ── 6. PROFILES (unused detection) ───────────────────────────────
List<ProfileAgentAction.ProfileRequest> profReqs = new List<ProfileAgentAction.ProfileRequest>();
profReqs.add(new ProfileAgentAction.ProfileRequest());
List<ProfileAgentAction.ProfileOutput> profOut = ProfileAgentAction.run(profReqs);
System.debug('✅ PROFILES — Total: ' + profOut[0].totalCount + ' | Unassigned: ' + profOut[0].unusedCount);
System.debug('UNASSIGNED PROFILES:\n' + profOut[0].unusedProfiles);

// ── 7. PERMISSION SETS (unused detection) ────────────────────────
List<PermissionSetAgentAction.PermSetRequest> psReqs = new List<PermissionSetAgentAction.PermSetRequest>();
psReqs.add(new PermissionSetAgentAction.PermSetRequest());
List<PermissionSetAgentAction.PermSetOutput> psOut = PermissionSetAgentAction.run(psReqs);
System.debug('✅ PERM SETS — Total: ' + psOut[0].totalCount + ' | Unassigned: ' + psOut[0].unusedCount);

// ── 8. CUSTOM FIELDS (namespace filter = ITSms) ───────────────────
List<CustomFieldAgentAction.FieldRequest> fldReqs = new List<CustomFieldAgentAction.FieldRequest>();
CustomFieldAgentAction.FieldRequest fldReq = new CustomFieldAgentAction.FieldRequest();
fldReq.namespaceFilter = 'ITSms';
fldReqs.add(fldReq);
List<CustomFieldAgentAction.FieldOutput> fldOut = CustomFieldAgentAction.run(fldReqs);
System.debug('✅ FIELDS — Total: ' + fldOut[0].totalCount + ' | Filtered (ITSms): ' + fldOut[0].filteredCount);

// ── 9. CUSTOM OBJECTS ─────────────────────────────────────────────
List<CustomObjectAgentAction.ObjectRequest> objReqs = new List<CustomObjectAgentAction.ObjectRequest>();
objReqs.add(new CustomObjectAgentAction.ObjectRequest());
List<CustomObjectAgentAction.ObjectOutput> objOut = CustomObjectAgentAction.run(objReqs);
System.debug('✅ OBJECTS — Total: ' + objOut[0].totalCount);

// ── 10. VALIDATION RULES ──────────────────────────────────────────
List<ValidationRuleAgentAction.VRRequest> vrReqs = new List<ValidationRuleAgentAction.VRRequest>();
vrReqs.add(new ValidationRuleAgentAction.VRRequest());
List<ValidationRuleAgentAction.VROutput> vrOut = ValidationRuleAgentAction.run(vrReqs);
System.debug('✅ VALIDATION RULES — Total: ' + vrOut[0].totalCount + ' | Inactive: ' + vrOut[0].inactiveCount);

// ── 11. DELETE APEX CLASS (example) ──────────────────────────────
// Uncomment to test — replaces 'LeadScoringBatch' with your class name
/*
List<DeleteApexClassAction.DeleteApexRequest> delApexReqs = new List<DeleteApexClassAction.DeleteApexRequest>();
DeleteApexClassAction.DeleteApexRequest delApexReq = new DeleteApexClassAction.DeleteApexRequest();
delApexReq.apexClassName = 'LeadScoringBatch';
delApexReqs.add(delApexReq);
List<DeleteApexClassAction.DeleteApexOutput> delApexOut = DeleteApexClassAction.deleteApexClass(delApexReqs);
System.debug('✅ DELETE APEX: ' + delApexOut[0].message);
*/

// ── 12. DELETE LWC (example) ─────────────────────────────────────
/*
List<DeleteLwcAction.DeleteLwcRequest> delLwcReqs = new List<DeleteLwcAction.DeleteLwcRequest>();
DeleteLwcAction.DeleteLwcRequest delLwcReq = new DeleteLwcAction.DeleteLwcRequest();
delLwcReq.componentName = 'myOldComponent';
delLwcReqs.add(delLwcReq);
List<DeleteLwcAction.DeleteLwcOutput> delLwcOut = DeleteLwcAction.deleteLwc(delLwcReqs);
System.debug('✅ DELETE LWC: ' + delLwcOut[0].message);
*/

// ── 13. DELETE PERMISSION SET (example) ──────────────────────────
/*
List<DeletePermissionSetAction.DeletePSRequest> delPSReqs = new List<DeletePermissionSetAction.DeletePSRequest>();
DeletePermissionSetAction.DeletePSRequest delPSReq = new DeletePermissionSetAction.DeletePSRequest();
delPSReq.permSetName = 'OldPermissionSet';
delPSReqs.add(delPSReq);
List<DeletePermissionSetAction.DeletePSOutput> delPSOut = DeletePermissionSetAction.deletePS(delPSReqs);
System.debug('✅ DELETE PERM SET: ' + delPSOut[0].message);
*/

// ── 14. DEACTIVATE PROFILE (example) ─────────────────────────────
/*
List<DeactivateProfileAction.DeactivateProfileRequest> dpReqs = new List<DeactivateProfileAction.DeactivateProfileRequest>();
DeactivateProfileAction.DeactivateProfileRequest dpReq = new DeactivateProfileAction.DeactivateProfileRequest();
dpReq.profileName         = 'Custom Sales Profile';
dpReq.fallbackProfileName = 'Standard User';
dpReqs.add(dpReq);
List<DeactivateProfileAction.DeactivateProfileOutput> dpOut = DeactivateProfileAction.deactivateProfile(dpReqs);
System.debug('✅ DEACTIVATE PROFILE: ' + dpOut[0].message);
*/

System.debug('\n✅ All metadata checks complete. Check debug logs above.');
