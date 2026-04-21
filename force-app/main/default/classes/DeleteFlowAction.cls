public without sharing class DeleteFlowAction {

    public class DeleteFlowRequest {
        @InvocableVariable(label='Flow API Name' description='The API Name of the flow to delete')
        public String flowApiName;
    }

    public class DeleteFlowOutput {
        @InvocableVariable(label='Success' description='Whether the deletion was successful')
        public Boolean success;

        @InvocableVariable(label='Message' description='Result message describing what happened')
        public String message;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Delete Flow' description='Deactivates and deletes a Flow by its API Name')
    public static List<DeleteFlowOutput> deleteFlow(List<DeleteFlowRequest> requests) {
        List<DeleteFlowOutput> outputs = new List<DeleteFlowOutput>();
        for (DeleteFlowRequest req : requests) {
            MetadataEngine.DeleteResult result = MetadataEngine.deleteFlowByApiName(req.flowApiName);
            DeleteFlowOutput out = new DeleteFlowOutput();
            out.success = result.success;
            out.message = result.message;
            outputs.add(out);
        }
        return outputs;
    }

    // ── Called directly by LWC agent panel ────────────────────
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.DeleteResult deleteFlowDirect(String flowApiName) {
        if (String.isBlank(flowApiName)) {
            MetadataEngine.DeleteResult r = new MetadataEngine.DeleteResult();
            r.success = false;
            r.message = 'Flow API name is required.';
            return r;
        }
        return MetadataEngine.deleteFlowByApiName(flowApiName.trim());
    }
}
