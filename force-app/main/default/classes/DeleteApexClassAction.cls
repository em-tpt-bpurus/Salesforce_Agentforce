public without sharing class DeleteApexClassAction {

    public class DeleteApexRequest {
        @InvocableVariable(label='Apex Class Name' description='The API Name of the Apex class to delete')
        public String apexClassName;
    }

    public class DeleteApexOutput {
        @InvocableVariable(label='Success' description='Whether the deletion was successful')
        public Boolean success;

        @InvocableVariable(label='Message' description='Result message describing what happened')
        public String message;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Delete Apex Class' description='Deletes an unused Apex Class by its Name')
    public static List<DeleteApexOutput> deleteApexClass(List<DeleteApexRequest> requests) {
        List<DeleteApexOutput> outputs = new List<DeleteApexOutput>();
        for (DeleteApexRequest req : requests) {
            MetadataEngine.DeleteResult result = MetadataEngine.deleteApexClassByName(req.apexClassName);
            DeleteApexOutput out = new DeleteApexOutput();
            out.success = result.success;
            out.message = result.message;
            outputs.add(out);
        }
        return outputs;
    }

    // ── Called directly by LWC agent panel ────────────────────
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.DeleteResult deleteApexClassDirect(String apexClassName) {
        if (String.isBlank(apexClassName)) {
            MetadataEngine.DeleteResult r = new MetadataEngine.DeleteResult();
            r.success = false;
            r.message = 'Apex class name is required.';
            return r;
        }
        return MetadataEngine.deleteApexClassByName(apexClassName.trim());
    }

    // ── Mass delete: called by LWC for bulk operations ────────
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.MassDeleteResult massDeleteApexClassesDirect(List<String> apexClassNames) {
        if (apexClassNames == null || apexClassNames.isEmpty()) {
            MetadataEngine.MassDeleteResult r = new MetadataEngine.MassDeleteResult();
            r.totalRequested = 0;
            r.successCount   = 0;
            r.failureCount   = 0;
            r.succeeded      = new List<String>();
            r.failed         = new List<String>();
            r.summary        = 'No Apex class names provided.';
            return r;
        }
        return MetadataEngine.massDeleteApexClasses(apexClassNames);
    }
}