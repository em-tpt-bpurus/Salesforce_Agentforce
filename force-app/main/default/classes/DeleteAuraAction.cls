public without sharing class DeleteAuraAction {
    public class DeleteAuraRequest {
        @InvocableVariable(label='Aura Component Name' description='DeveloperName of the Aura component to delete')
        public String componentName;
    }
    public class DeleteAuraOutput {
        @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled public String  message;
    }
    @InvocableMethod(label='Delete Aura Component' description='Deletes an Aura (Lightning) component by its DeveloperName')
    public static List<DeleteAuraOutput> deleteAura(List<DeleteAuraRequest> requests) {
        List<DeleteAuraOutput> outputs = new List<DeleteAuraOutput>();
        for (DeleteAuraRequest req : requests) {
            DeleteAuraOutput out = new DeleteAuraOutput();
            if (String.isBlank(req.componentName)) {
                out.success = false; out.message = 'Aura component name was not provided.';
            } else {
                MetadataEngine.DeleteResult r = MetadataEngine.deleteAuraByName(req.componentName.trim());
                out.success = r.success; out.message = r.message;
            }
            outputs.add(out);
        }
        return outputs;
    }

    @AuraEnabled(cacheable=false)
    public static DeleteAuraOutput deleteAuraFromLWC(String componentName) {
        DeleteAuraOutput out = new DeleteAuraOutput();
        if (String.isBlank(componentName)) {
            out.success = false; out.message = 'Aura component name was not provided.';
            return out;
        }
        MetadataEngine.DeleteResult r = MetadataEngine.deleteAuraByName(componentName.trim());
        out.success = r.success; out.message = r.message;
        return out;
    }

    // ── Mass delete: called by LWC for bulk operations ────────
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.MassDeleteResult massDeleteAuraDirect(List<String> componentNames) {
        if (componentNames == null || componentNames.isEmpty()) {
            MetadataEngine.MassDeleteResult r = new MetadataEngine.MassDeleteResult();
            r.totalRequested = 0; r.successCount = 0; r.failureCount = 0;
            r.succeeded = new List<String>(); r.failed = new List<String>();
            r.summary = 'No Aura component names provided.';
            return r;
        }
        return MetadataEngine.massDeleteAuraComponents(componentNames);
    }
}