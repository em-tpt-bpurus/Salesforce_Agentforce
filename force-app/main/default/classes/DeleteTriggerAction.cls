public without sharing class DeleteTriggerAction {

    public class DeleteTriggerRequest {
        @InvocableVariable(label='Trigger Name' description='The API Name of the Apex Trigger to delete')
        public String triggerName;
    }

    public class DeleteTriggerOutput {
        @InvocableVariable(label='Success' description='Whether the deletion was successful')
        public Boolean success;

        @InvocableVariable(label='Message' description='Result message describing what happened')
        public String message;
    }

    // ── Called by Agentforce via @InvocableMethod ──────────────
    @InvocableMethod(label='Delete Trigger' description='Deletes an unused or inactive Apex Trigger by its Name')
    public static List<DeleteTriggerOutput> deleteTrigger(List<DeleteTriggerRequest> requests) {
        List<DeleteTriggerOutput> outputs = new List<DeleteTriggerOutput>();
        for (DeleteTriggerRequest req : requests) {
            MetadataEngine.DeleteResult result = MetadataEngine.deleteTriggerByName(req.triggerName);
            DeleteTriggerOutput out = new DeleteTriggerOutput();
            out.success = result.success;
            out.message = result.message;
            outputs.add(out);
        }
        return outputs;
    }

    // ── Called directly by LWC agent panel ────────────────────
    @AuraEnabled(cacheable=false)
    public static MetadataEngine.DeleteResult deleteTriggerDirect(String triggerName) {
        if (String.isBlank(triggerName)) {
            MetadataEngine.DeleteResult r = new MetadataEngine.DeleteResult();
            r.success = false;
            r.message = 'Trigger name is required.';
            return r;
        }
        return MetadataEngine.deleteTriggerByName(triggerName.trim());
    }
}
